import AppIntents
import WidgetKit
import FootMobKit

// Compiled into both the app and the widget extension.

enum LeagueFilter: String, AppEnum {
    case all, nfl, cfb

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "League"
    static let caseDisplayRepresentations: [LeagueFilter: DisplayRepresentation] = [
        .all: "NFL & College",
        .nfl: "NFL",
        .cfb: "College Football"
    ]

    var leagues: [League] {
        switch self {
        case .all: League.allCases
        case .nfl: [.nfl]
        case .cfb: [.cfb]
        }
    }
}

// MARK: - Team entity (for widget configuration and Siri)

struct TeamEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Team"
    static let defaultQuery = TeamEntityQuery()

    var id: String
    var name: String
    var abbreviation: String
    var leagueName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(leagueName)")
    }

    init(team: Team) {
        id = team.id
        name = team.displayName
        abbreviation = team.abbreviation
        leagueName = team.league.shortName
    }

    /// Splits `nfl:6` back into its league and ESPN ID.
    var parsed: (league: League, espnID: String)? {
        let parts = id.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let league = League(rawValue: parts[0]),
              InputValidation.isValidIdentifier(parts[1]) else { return nil }
        return (league, parts[1])
    }
}

struct TeamEntityQuery: EntityStringQuery {
    func entities(for identifiers: [TeamEntity.ID]) async throws -> [TeamEntity] {
        let all = await Self.allTeams()
        return identifiers.compactMap { id in all.first { $0.id == id }.map { TeamEntity(team: $0) } }
    }

    func entities(matching string: String) async throws -> [TeamEntity] {
        await Self.allTeams()
            .filter { $0.displayName.localizedStandardContains(string) || $0.abbreviation.localizedStandardContains(string) }
            .prefix(40)
            .map { TeamEntity(team: $0) }
    }

    func suggestedEntities() async throws -> [TeamEntity] {
        let favorites = FavoritesStorage.load()
        let rest = await Self.allTeams().filter { team in !favorites.contains { $0.id == team.id } }
        return (favorites + rest.filter { $0.league == .nfl }).map { TeamEntity(team: $0) }
    }

    /// Favorites + cached team directories, fetched fresh if the app hasn't cached them yet.
    static func allTeams() async -> [Team] {
        var teams = FavoritesStorage.load()
        for league in League.allCases {
            var list = SnapshotStore.read([Team].self, .teams(league)) ?? []
            if list.isEmpty, let fetched = try? await ESPNClient().teams(league: league) {
                list = fetched
                SnapshotStore.write(fetched, as: .teams(league))
            }
            teams += list.filter { team in !teams.contains { $0.id == team.id } }
        }
        return teams
    }
}

// MARK: - Widget configuration intents

struct ScoresWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Scores"
    static let description = IntentDescription("Live and upcoming games, your teams first.")

    @Parameter(title: "League", default: .all)
    var league: LeagueFilter

    @Parameter(title: "Only my teams", default: false)
    var favoritesOnly: Bool
}

struct TeamWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Team"
    static let description = IntentDescription("Follow one team's live, next or last game.")

    @Parameter(title: "Team")
    var team: TeamEntity?
}

// MARK: - Actions

/// Interactive widget button: refreshes scores in place.
struct RefreshScoresIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Scores"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Opens FootMob straight to live games. Used by the Control Center / Lock Screen button and Siri.
struct OpenLiveScoresIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Live Scores"
    static let description = IntentDescription("Jump straight to the games being played right now.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        DeepLinkInbox.post(DeepLink.live.url)
        return .result()
    }
}

/// Starts a Live Activity for one game. `LiveActivityIntent` runs in the app's process even
/// when tapped from a widget, so no push server is needed.
struct StartGameLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Track Game Live"
    static let isDiscoverable = false

    @Parameter(title: "Game ID")
    var gameID: String

    @Parameter(title: "League")
    var league: String

    init() {}

    init(game: Game) {
        gameID = game.id
        league = game.league.rawValue
    }

    func perform() async throws -> some IntentResult {
        guard let league = League(rawValue: league), InputValidation.isValidIdentifier(gameID) else {
            return .result()
        }
        if GameActivityController.trackedGameIDs.contains(gameID) {
            await GameActivityController.end(gameID: gameID)
        } else {
            let detail = try await ESPNClient().gameDetail(league: league, gameID: gameID)
            await ImageCache.shared.prefetchLogos(for: detail.game.teams)
            try GameActivityController.start(detail.game)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// "Track my team" — the one-tap live button. Finds your team's live (or next) game and
/// puts it on the Lock Screen and Dynamic Island.
struct TrackMyTeamIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Track My Team Live"
    static let description = IntentDescription("Start a Live Activity for your team's current or next game.")

    @Parameter(title: "Team")
    var team: TeamEntity?

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        var candidates: [(league: League, espnID: String)] = []
        if let parsed = team?.parsed {
            candidates = [parsed]
        } else {
            candidates = FavoritesStorage.load().map { (league: $0.league, espnID: $0.espnID) }
        }
        guard !candidates.isEmpty else {
            return .result(dialog: "Follow a team in FootMob first.")
        }

        let client = ESPNClient()
        var boards: [League: [Game]] = [:]
        for candidate in candidates where boards[candidate.league] == nil {
            boards[candidate.league] = (try? await client.scoreboard(league: candidate.league, week: nil).games) ?? []
        }
        let games = candidates.compactMap { candidate in
            GamePrioritizer.featured(for: Team.key(league: candidate.league, espnID: candidate.espnID),
                                     in: boards[candidate.league] ?? [])
        }
        guard let game = games.first(where: { $0.status.isLive })
                ?? games.filter({ !$0.status.isFinal }).min(by: { $0.date < $1.date }) else {
            return .result(dialog: "No upcoming games for your team this week.")
        }

        await ImageCache.shared.prefetchLogos(for: game.teams)
        _ = try GameActivityController.start(game)
        return .result(dialog: "Tracking \(game.shortName) live.")
    }
}
