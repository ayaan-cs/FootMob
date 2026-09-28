import Foundation

public struct GameDetail: Hashable, Sendable {
    public var game: Game
    public var teamStats: [TeamStatLine]
    public var scoringPlays: [ScoringPlay]
    public var drives: [Drive]
    public var leaders: [LeaderCategory]
    public var winProbability: [WinProbabilityPoint]
    public var articles: [Article]

    public init(game: Game, teamStats: [TeamStatLine] = [], scoringPlays: [ScoringPlay] = [],
                drives: [Drive] = [], leaders: [LeaderCategory] = [],
                winProbability: [WinProbabilityPoint] = [], articles: [Article] = []) {
        self.game = game
        self.teamStats = teamStats
        self.scoringPlays = scoringPlays
        self.drives = drives
        self.leaders = leaders
        self.winProbability = winProbability
        self.articles = articles
    }
}

/// One row of the side-by-side team stat comparison.
public struct TeamStatLine: Hashable, Sendable, Identifiable {
    public var id: String { key }
    public var key: String
    public var label: String
    public var away: String
    public var home: String

    public init(key: String, label: String, away: String, home: String) {
        self.key = key
        self.label = label
        self.away = away
        self.home = home
    }

    /// Share of the stat that belongs to the away team (0…1), used for comparison bars.
    /// `nil` when the values aren't numerically comparable.
    public var awayShare: Double? {
        guard let a = StatValueParser.numeric(away), let h = StatValueParser.numeric(home) else { return nil }
        let total = a + h
        guard total > 0 else { return 0.5 }
        return a / total
    }

    /// For stats like turnovers and penalties, a lower value is better.
    public var lowerIsBetter: Bool {
        ["turnovers", "totalPenaltiesYards", "fumblesLost", "interceptions", "sacksYardsLost"].contains(key)
    }
}

public enum StatValueParser {
    /// Parses ESPN display values: "350", "5-12" (efficiency), "31:22" (possession), "6.2".
    public static func numeric(_ raw: String) -> Double? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        if value.contains(":") {
            let parts = value.split(separator: ":").compactMap { Double($0) }
            guard parts.count == 2 else { return nil }
            return parts[0] * 60 + parts[1]
        }
        if let hyphen = value.firstIndex(of: "-"), hyphen != value.startIndex {
            let made = Double(value[..<hyphen])
            let attempts = Double(value[value.index(after: hyphen)...])
            guard let made, let attempts else { return nil }
            return attempts > 0 ? made / attempts : 0
        }
        return Double(value)
    }
}

public struct ScoringPlay: Hashable, Sendable, Identifiable {
    public var id: String
    public var teamKey: String?
    public var teamAbbreviation: String?
    public var typeAbbreviation: String
    public var typeText: String
    public var text: String
    public var period: Int
    public var clock: String
    public var awayScore: Int
    public var homeScore: Int

    public init(id: String, teamKey: String?, teamAbbreviation: String?, typeAbbreviation: String,
                typeText: String, text: String, period: Int, clock: String, awayScore: Int, homeScore: Int) {
        self.id = id
        self.teamKey = teamKey
        self.teamAbbreviation = teamAbbreviation
        self.typeAbbreviation = typeAbbreviation
        self.typeText = typeText
        self.text = text
        self.period = period
        self.clock = clock
        self.awayScore = awayScore
        self.homeScore = homeScore
    }
}

public struct Drive: Hashable, Sendable, Identifiable {
    public var id: String
    public var teamKey: String?
    public var teamAbbreviation: String?
    public var summary: String
    public var result: String
    public var isScore: Bool
    public var isCurrent: Bool
    public var plays: [Play]

    public init(id: String, teamKey: String?, teamAbbreviation: String?, summary: String,
                result: String, isScore: Bool, isCurrent: Bool, plays: [Play]) {
        self.id = id
        self.teamKey = teamKey
        self.teamAbbreviation = teamAbbreviation
        self.summary = summary
        self.result = result
        self.isScore = isScore
        self.isCurrent = isCurrent
        self.plays = plays
    }
}

public struct Play: Hashable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var downDistance: String?
    public var period: Int
    public var clock: String
    public var isScoring: Bool

    public init(id: String, text: String, downDistance: String?, period: Int, clock: String, isScoring: Bool) {
        self.id = id
        self.text = text
        self.downDistance = downDistance
        self.period = period
        self.clock = clock
        self.isScoring = isScoring
    }
}

public struct LeaderCategory: Hashable, Sendable, Identifiable {
    public var id: String { key }
    public var key: String
    public var title: String
    public var away: PlayerLeader?
    public var home: PlayerLeader?

    public init(key: String, title: String, away: PlayerLeader?, home: PlayerLeader?) {
        self.key = key
        self.title = title
        self.away = away
        self.home = home
    }
}

public struct PlayerLeader: Hashable, Sendable {
    public var name: String
    public var shortName: String
    public var position: String?
    public var headshotURL: URL?
    public var statLine: String

    public init(name: String, shortName: String, position: String?, headshotURL: URL?, statLine: String) {
        self.name = name
        self.shortName = shortName
        self.position = position
        self.headshotURL = headshotURL
        self.statLine = statLine
    }
}

public struct WinProbabilityPoint: Hashable, Sendable, Identifiable {
    public var id: Int { index }
    public var index: Int
    /// Home team win probability, 0…1.
    public var homeWinProbability: Double

    public init(index: Int, homeWinProbability: Double) {
        self.index = index
        self.homeWinProbability = homeWinProbability
    }
}
