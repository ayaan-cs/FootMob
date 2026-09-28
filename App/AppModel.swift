import SwiftUI
import WidgetKit
import FootMobKit

enum AppTab: Hashable {
    case matches, leagues, following, news, search
}

/// App-wide state: data provider, followed teams, navigation and Live Activity bookkeeping.
@MainActor
@Observable
final class AppModel {
    let provider: any SportsDataProvider

    private(set) var favorites: [Team]
    var selectedTab: AppTab = .matches
    private(set) var hasOnboarded: Bool

    /// Pushed onto the Matches stack when a deep link opens a game.
    var matchesPath = NavigationPath()
    var presentedArticle: URL?

    /// Latest games per league, shared with the tab-bar accessory and Live Activities.
    private(set) var latestGames: [League: [Game]] = [:]
    private(set) var trackedGameIDs: Set<String> = []

    private let directory: TeamDirectory

    init(provider: any SportsDataProvider = ESPNClient()) {
        self.provider = provider
        self.directory = TeamDirectory(provider: provider)
        self.favorites = FavoritesStorage.load()
        self.hasOnboarded = UserDefaults.standard.bool(forKey: "hasOnboarded")
        self.trackedGameIDs = GameActivityController.trackedGameIDs
    }

    func completeOnboarding() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: "hasOnboarded")
    }

    // MARK: Favorites

    var favoriteKeys: Set<String> { Set(favorites.map(\.id)) }

    func isFavorite(_ team: Team) -> Bool { favoriteKeys.contains(team.id) }

    func toggleFavorite(_ team: Team) {
        if let index = favorites.firstIndex(where: { $0.id == team.id }) {
            favorites.remove(at: index)
        } else {
            favorites.append(team)
        }
        FavoritesStorage.save(favorites)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func teams(for league: League) async -> [Team] {
        await directory.teams(for: league)
    }

    // MARK: Games

    /// Called whenever fresh scoreboard data arrives anywhere in the app.
    func ingest(_ games: [Game], league: League) {
        latestGames[league] = games
        SnapshotStore.write(games, as: .games(league))
        Task {
            await GameActivityController.update(with: games)
            trackedGameIDs = GameActivityController.trackedGameIDs
        }
        WidgetSync.reloadIfNeeded()
    }

    /// The game shown in the tab-bar accessory: a favorite's live game, else any live game.
    var accessoryGame: Game? {
        let all = latestGames.values.flatMap { $0 }
        let live = all.filter(\.status.isLive)
        return GamePrioritizer.featured(live.isEmpty ? all.filter(\.status.isUpcoming) : live, favorites: favoriteKeys)
    }

    func refreshTrackedGames() async {
        trackedGameIDs = GameActivityController.trackedGameIDs
        for league in League.allCases {
            let wanted = latestGames[league] ?? []
            let needsRefresh = wanted.contains { trackedGameIDs.contains($0.id) } || latestGames[league] == nil
            guard needsRefresh, let board = try? await provider.scoreboard(league: league, week: nil) else { continue }
            ingest(board.games, league: league)
        }
    }

    // MARK: Live Activities

    func isTracking(_ game: Game) -> Bool { trackedGameIDs.contains(game.id) }

    func toggleLiveActivity(for game: Game) async {
        if isTracking(game) {
            await GameActivityController.end(gameID: game.id)
        } else {
            _ = try? GameActivityController.start(game)
        }
        trackedGameIDs = GameActivityController.trackedGameIDs
    }

    // MARK: Deep links

    func handle(url: URL) {
        guard let link = DeepLink(url: url) else { return }
        switch link {
        case .live:
            selectedTab = .matches
            matchesPath = NavigationPath()
        case .news:
            selectedTab = .news
        case let .game(league, id):
            selectedTab = .matches
            matchesPath = NavigationPath()
            matchesPath.append(GameRoute(league: league, gameID: id))
        case let .team(league, id):
            selectedTab = .matches
            matchesPath = NavigationPath()
            matchesPath.append(TeamRoute(league: league, espnID: id))
        case let .article(url):
            presentedArticle = url
        }
    }
}

/// Navigation values. Lightweight so deep links can push them before data is loaded.
struct GameRoute: Hashable {
    var league: League
    var gameID: String
    var preview: Game?

    init(league: League, gameID: String, preview: Game? = nil) {
        self.league = league
        self.gameID = gameID
        self.preview = preview
    }

    init(_ game: Game) {
        self.init(league: game.league, gameID: game.id, preview: game)
    }
}

struct TeamRoute: Hashable {
    var league: League
    var espnID: String
    var preview: Team?

    init(league: League, espnID: String, preview: Team? = nil) {
        self.league = league
        self.espnID = espnID
        self.preview = preview
    }

    init(_ team: Team) {
        self.init(league: team.league, espnID: team.espnID, preview: team)
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
