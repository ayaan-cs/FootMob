import Foundation

/// The competitions FootMob covers.
public enum League: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case nfl
    case cfb

    public var id: String { rawValue }

    /// Path segment used by the ESPN site API.
    public var espnPath: String {
        switch self {
        case .nfl: "football/nfl"
        case .cfb: "football/college-football"
        }
    }

    public var displayName: String {
        switch self {
        case .nfl: "NFL"
        case .cfb: "College Football"
        }
    }

    public var shortName: String {
        switch self {
        case .nfl: "NFL"
        case .cfb: "NCAAF"
        }
    }

    public var symbolName: String {
        switch self {
        case .nfl: "football.fill"
        case .cfb: "graduationcap.fill"
        }
    }
}
