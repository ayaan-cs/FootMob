import Foundation

public struct StandingsGroup: Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var shortName: String
    public var entries: [StandingsEntry]

    public init(id: String, name: String, shortName: String, entries: [StandingsEntry]) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.entries = entries
    }

    public func contains(teamKey: String) -> Bool {
        entries.contains { $0.team.id == teamKey }
    }
}

public struct StandingsEntry: Hashable, Sendable, Identifiable {
    public var id: String { team.id }
    public var team: Team
    public var wins: Int
    public var losses: Int
    public var ties: Int
    public var winPercent: Double
    public var pointsFor: Int?
    public var pointsAgainst: Int?
    public var streak: String?
    public var playoffSeed: Int?
    public var conferenceRecord: String?
    /// Clinch marker such as "x", "y", "z", "*", "e".
    public var clincher: String?

    public init(team: Team, wins: Int, losses: Int, ties: Int = 0, winPercent: Double,
                pointsFor: Int? = nil, pointsAgainst: Int? = nil, streak: String? = nil,
                playoffSeed: Int? = nil, conferenceRecord: String? = nil, clincher: String? = nil) {
        self.team = team
        self.wins = wins
        self.losses = losses
        self.ties = ties
        self.winPercent = winPercent
        self.pointsFor = pointsFor
        self.pointsAgainst = pointsAgainst
        self.streak = streak
        self.playoffSeed = playoffSeed
        self.conferenceRecord = conferenceRecord
        self.clincher = clincher
    }

    public var record: String {
        ties > 0 ? "\(wins)-\(losses)-\(ties)" : "\(wins)-\(losses)"
    }

    public var pointDifferential: Int? {
        guard let pointsFor, let pointsAgainst else { return nil }
        return pointsFor - pointsAgainst
    }
}
