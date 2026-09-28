import Foundation

public struct Team: Codable, Hashable, Sendable, Identifiable {
    /// ESPN's team identifier. Not unique across leagues (NFL and college IDs overlap).
    public var espnID: String
    public var league: League
    public var abbreviation: String
    public var displayName: String
    public var shortDisplayName: String
    public var location: String
    public var nickname: String
    public var colorHex: String?
    public var alternateColorHex: String?
    public var logoURL: URL?

    /// Globally unique key, e.g. `nfl:6`.
    public var id: String { Team.key(league: league, espnID: espnID) }

    public static func key(league: League, espnID: String) -> String {
        "\(league.rawValue):\(espnID)"
    }

    public init(
        espnID: String,
        league: League,
        abbreviation: String,
        displayName: String,
        shortDisplayName: String? = nil,
        location: String = "",
        nickname: String = "",
        colorHex: String? = nil,
        alternateColorHex: String? = nil,
        logoURL: URL? = nil
    ) {
        self.espnID = espnID
        self.league = league
        self.abbreviation = abbreviation
        self.displayName = displayName
        self.shortDisplayName = shortDisplayName ?? displayName
        self.location = location
        self.nickname = nickname
        self.colorHex = colorHex
        self.alternateColorHex = alternateColorHex
        self.logoURL = logoURL
    }
}
