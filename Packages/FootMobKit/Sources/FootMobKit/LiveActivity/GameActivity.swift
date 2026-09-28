import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Static and dynamic data for a game's Live Activity (Lock Screen, Dynamic Island,
/// StandBy, CarPlay and the Apple Watch Smart Stack).
public struct GameActivityAttributes: Codable, Hashable, Sendable {
    public struct TeamInfo: Codable, Hashable, Sendable {
        public var espnID: String
        public var abbreviation: String
        public var shortName: String
        public var colorHex: String?
        public var logoURL: URL?
        public var rank: Int?

        public init(_ competitor: Competitor) {
            espnID = competitor.team.espnID
            abbreviation = competitor.team.abbreviation
            shortName = competitor.team.shortDisplayName
            colorHex = competitor.team.colorHex
            logoURL = competitor.team.logoURL
            rank = competitor.rank
        }
    }

    public struct ContentState: Codable, Hashable, Sendable {
        public var awayScore: Int
        public var homeScore: Int
        public var state: GameStatus.State
        public var statusText: String
        public var period: Int
        public var possession: Side?
        public var downDistance: String?
        public var lastPlay: String?
        public var isRedZone: Bool
        public var fieldPosition: Double?
        public var kickoff: Date

        public init(game: Game) {
            awayScore = game.away.score ?? 0
            homeScore = game.home.score ?? 0
            state = game.status.state
            statusText = GameFormat.statusLine(game)
            period = game.status.period
            possession = game.possession
            downDistance = game.situation?.shortDownDistanceText ?? game.situation?.downDistanceText
            lastPlay = game.situation?.lastPlay
            isRedZone = game.situation?.isRedZone ?? false
            fieldPosition = game.situation?.fieldPosition
            kickoff = game.date
        }
    }

    public var gameID: String
    public var league: League
    public var away: TeamInfo
    public var home: TeamInfo

    public init(game: Game) {
        gameID = game.id
        league = game.league
        away = TeamInfo(game.away)
        home = TeamInfo(game.home)
    }

    public var deepLink: URL { DeepLink.game(league, gameID).url }
}

#if canImport(ActivityKit) && os(iOS)
extension GameActivityAttributes: ActivityAttributes {}

/// Starts, updates and ends game Live Activities.
///
/// Updates are pushed from the device itself (while FootMob is open, from background refresh,
/// and from widget refreshes) so no push server or paid Apple Developer membership is needed.
public enum GameActivityController {
    public static var isEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    public static var trackedGameIDs: Set<String> {
        Set(Activity<GameActivityAttributes>.activities.map(\.attributes.gameID))
    }

    @discardableResult
    public static func start(_ game: Game) throws -> Bool {
        guard !trackedGameIDs.contains(game.id) else { return false }
        let content = ActivityContent(
            state: GameActivityAttributes.ContentState(game: game),
            staleDate: staleDate(for: game),
            relevanceScore: game.status.isLive ? 100 : 50
        )
        _ = try Activity.request(attributes: GameActivityAttributes(game: game), content: content, pushType: nil)
        return true
    }

    public static func end(gameID: String) async {
        for activity in Activity<GameActivityAttributes>.activities where activity.attributes.gameID == gameID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Applies fresh game data to any matching activities and ends finished ones.
    public static func update(with games: [Game]) async {
        let byID = Dictionary(games.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for activity in Activity<GameActivityAttributes>.activities {
            guard let game = byID[activity.attributes.gameID] else { continue }
            let newState = GameActivityAttributes.ContentState(game: game)
            let oldState = activity.content.state
            let content = ActivityContent(
                state: newState,
                staleDate: staleDate(for: game),
                relevanceScore: game.status.isLive ? 100 : 50
            )
            if game.status.isFinal || game.status.state == .canceled {
                // Keep the final score on the Lock Screen for a while.
                await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(30 * 60)))
                continue
            }
            guard newState != oldState else { continue }
            let scored = newState.awayScore + newState.homeScore > oldState.awayScore + oldState.homeScore
            let alert = scored
                ? AlertConfiguration(
                    title: "Score!",
                    body: "\(activity.attributes.away.abbreviation) \(newState.awayScore) – \(newState.homeScore) \(activity.attributes.home.abbreviation)",
                    sound: .default
                )
                : nil
            await activity.update(content, alertConfiguration: alert)
        }
    }

    private static func staleDate(for game: Game) -> Date {
        game.status.isLive ? .now.addingTimeInterval(15 * 60) : max(game.date, .now).addingTimeInterval(15 * 60)
    }
}
#endif
