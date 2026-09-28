import Foundation

/// Abstraction over a live-scores data source. `ESPNClient` is the default implementation;
/// swap in a licensed feed (Sportradar, SportsDataIO, …) by conforming to this protocol.
public protocol SportsDataProvider: Sendable {
    /// Scoreboard for a given week, or the current week when `week` is nil.
    func scoreboard(league: League, week: WeekSelection?) async throws -> Scoreboard
    func gameDetail(league: League, gameID: String) async throws -> GameDetail
    func standings(league: League) async throws -> [StandingsGroup]
    func news(league: League, teamID: String?, limit: Int) async throws -> [Article]
    func teams(league: League) async throws -> [Team]
    func schedule(for team: Team) async throws -> [Game]
}

public struct Scoreboard: Hashable, Sendable {
    public var league: League
    public var games: [Game]
    public var week: WeekSelection?
    public var calendar: [WeekSelection]

    public init(league: League, games: [Game], week: WeekSelection?, calendar: [WeekSelection]) {
        self.league = league
        self.games = games
        self.week = week
        self.calendar = calendar
    }
}

public struct WeekSelection: Codable, Hashable, Sendable, Identifiable {
    /// ESPN season type: 1 preseason, 2 regular season, 3 postseason, 4 off-season.
    public var seasonType: Int
    public var week: Int
    public var label: String
    public var startDate: Date?
    public var endDate: Date?

    public var id: String { "\(seasonType)-\(week)" }

    public init(seasonType: Int, week: Int, label: String, startDate: Date? = nil, endDate: Date? = nil) {
        self.seasonType = seasonType
        self.week = week
        self.label = label
        self.startDate = startDate
        self.endDate = endDate
    }
}

public enum SportsDataError: Error, LocalizedError {
    case badResponse(Int)
    case notFound
    case invalidInput
    case responseTooLarge

    public var errorDescription: String? {
        switch self {
        case .badResponse(let code): "The scores service returned an error (\(code))."
        case .notFound: "That game couldn't be found."
        case .invalidInput: "That link isn't valid."
        case .responseTooLarge: "The scores service sent an unexpected response."
        }
    }
}
