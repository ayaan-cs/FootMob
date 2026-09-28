import Foundation

public struct Game: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var league: League
    public var date: Date
    public var name: String
    public var shortName: String
    public var week: Int?
    public var seasonType: Int?
    public var seasonYear: Int?
    public var away: Competitor
    public var home: Competitor
    public var status: GameStatus
    public var situation: Situation?
    public var venue: String?
    public var city: String?
    public var broadcast: String?
    public var odds: String?
    public var overUnder: Double?
    /// Special billing such as "Rose Bowl" or "Super Bowl LXI".
    public var headline: String?

    public init(
        id: String, league: League, date: Date, name: String, shortName: String,
        week: Int? = nil, seasonType: Int? = nil, seasonYear: Int? = nil,
        away: Competitor, home: Competitor, status: GameStatus, situation: Situation? = nil,
        venue: String? = nil, city: String? = nil, broadcast: String? = nil,
        odds: String? = nil, overUnder: Double? = nil, headline: String? = nil
    ) {
        self.id = id
        self.league = league
        self.date = date
        self.name = name
        self.shortName = shortName
        self.week = week
        self.seasonType = seasonType
        self.seasonYear = seasonYear
        self.away = away
        self.home = home
        self.status = status
        self.situation = situation
        self.venue = venue
        self.city = city
        self.broadcast = broadcast
        self.odds = odds
        self.overUnder = overUnder
        self.headline = headline
    }

    public var teams: [Team] { [away.team, home.team] }

    public func involves(teamKey: String) -> Bool {
        away.team.id == teamKey || home.team.id == teamKey
    }

    public func involves(anyOf keys: Set<String>) -> Bool {
        keys.contains(away.team.id) || keys.contains(home.team.id)
    }

    public func competitor(for side: Side) -> Competitor {
        side == .home ? home : away
    }

    /// Which side currently has the ball, if known.
    public var possession: Side? {
        guard status.state == .live, let id = situation?.possessionTeamID else { return nil }
        if id == home.team.espnID { return .home }
        if id == away.team.espnID { return .away }
        return nil
    }

    public var isRankedMatchup: Bool { away.rank != nil || home.rank != nil }
}

public enum Side: String, Codable, Sendable, Hashable {
    case away, home
}

public struct Competitor: Codable, Hashable, Sendable {
    public var team: Team
    public var score: Int?
    public var record: String?
    /// AP / CFP ranking for college teams.
    public var rank: Int?
    public var linescores: [Int]
    public var isWinner: Bool?

    public init(team: Team, score: Int? = nil, record: String? = nil, rank: Int? = nil,
                linescores: [Int] = [], isWinner: Bool? = nil) {
        self.team = team
        self.score = score
        self.record = record
        self.rank = rank
        self.linescores = linescores
        self.isWinner = isWinner
    }
}

public struct GameStatus: Codable, Hashable, Sendable {
    public enum State: String, Codable, Sendable {
        case scheduled, live, final, postponed, canceled
    }

    public var state: State
    public var period: Int
    public var displayClock: String
    public var detail: String
    public var shortDetail: String
    public var isHalftime: Bool
    public var isOvertime: Bool

    public init(state: State, period: Int = 0, displayClock: String = "0:00", detail: String = "",
                shortDetail: String = "", isHalftime: Bool = false, isOvertime: Bool = false) {
        self.state = state
        self.period = period
        self.displayClock = displayClock
        self.detail = detail
        self.shortDetail = shortDetail
        self.isHalftime = isHalftime
        self.isOvertime = isOvertime
    }

    public var isLive: Bool { state == .live }
    public var isFinal: Bool { state == .final }
    public var isUpcoming: Bool { state == .scheduled }

    /// "Q1", "Q4", "OT", "2OT".
    public var periodLabel: String {
        switch period {
        case ...0: ""
        case 1...4: "Q\(period)"
        case 5: "OT"
        default: "\(period - 4)OT"
        }
    }

    /// Compact live label, e.g. "Q3 8:21" or "Half".
    public var liveLabel: String {
        if isHalftime { return "Half" }
        if displayClock == "0:00" || displayClock.isEmpty { return "End \(periodLabel)" }
        return "\(periodLabel) \(displayClock)"
    }
}

public struct Situation: Codable, Hashable, Sendable {
    public var down: Int?
    public var distance: Int?
    public var downDistanceText: String?
    public var shortDownDistanceText: String?
    /// e.g. "DAL 25"
    public var possessionText: String?
    public var possessionTeamID: String?
    public var isRedZone: Bool
    public var homeTimeouts: Int?
    public var awayTimeouts: Int?
    public var lastPlay: String?
    /// Ball position measured in yards from the away team's goal line (0…100),
    /// i.e. left-to-right on a field drawn with the away end zone on the left.
    public var fieldPosition: Double?

    public init(down: Int? = nil, distance: Int? = nil, downDistanceText: String? = nil,
                shortDownDistanceText: String? = nil, possessionText: String? = nil,
                possessionTeamID: String? = nil, isRedZone: Bool = false, homeTimeouts: Int? = nil,
                awayTimeouts: Int? = nil, lastPlay: String? = nil, fieldPosition: Double? = nil) {
        self.down = down
        self.distance = distance
        self.downDistanceText = downDistanceText
        self.shortDownDistanceText = shortDownDistanceText
        self.possessionText = possessionText
        self.possessionTeamID = possessionTeamID
        self.isRedZone = isRedZone
        self.homeTimeouts = homeTimeouts
        self.awayTimeouts = awayTimeouts
        self.lastPlay = lastPlay
        self.fieldPosition = fieldPosition
    }
}
