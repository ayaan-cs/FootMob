import Foundation

/// Storage shared between the app and its widget extension through an App Group.
///
/// If the App Group isn't provisioned (for example a signing setup that drops the capability),
/// everything falls back to per-process storage. The app keeps working; widgets simply fetch
/// their own data and ask you to pick teams in their configuration instead of reading favorites.
public enum SharedStorage {
    /// Read from the `FootMobAppGroup` Info.plist key, which project.yml fills from `APP_GROUP_ID`.
    public static let appGroupID: String =
        Bundle.main.object(forInfoDictionaryKey: "FootMobAppGroup") as? String ?? "group.com.footmob.shared"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    public static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    public static var containerURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FootMob", isDirectory: true)
    }

    static func directory(_ name: String) -> URL {
        let url = containerURL.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// The user's followed teams, readable from the widget extension.
public enum FavoritesStorage {
    private static let key = "favoriteTeams.v1"

    public static func load() -> [Team] {
        guard let data = SharedStorage.defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Team].self, from: data)) ?? []
    }

    public static func save(_ teams: [Team]) {
        guard let data = try? JSONEncoder().encode(teams) else { return }
        SharedStorage.defaults.set(data, forKey: key)
    }

    public static var keys: Set<String> { Set(load().map(\.id)) }
}

/// JSON snapshots of the latest data so widgets have something to show offline.
public enum SnapshotStore {
    public enum Name: String, Sendable {
        case nflGames, cfbGames, news, nflTeams, cfbTeams

        public static func games(_ league: League) -> Name { league == .nfl ? .nflGames : .cfbGames }
        public static func teams(_ league: League) -> Name { league == .nfl ? .nflTeams : .cfbTeams }
    }

    private static func url(_ name: Name) -> URL {
        SharedStorage.directory("Snapshots").appendingPathComponent("\(name.rawValue).json")
    }

    public static func write<T: Encodable>(_ value: T, as name: Name) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        // Readable by widgets on the Lock Screen after first unlock, encrypted before that.
        try? data.write(to: url(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    public static func read<T: Decodable>(_ type: T.Type, _ name: Name) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

/// Deep links queued by App Intents (e.g. the Control Center button) for the app to pick up.
public enum DeepLinkInbox {
    private static let key = "pendingDeepLink"

    public static func post(_ url: URL) {
        SharedStorage.defaults.set(url.absoluteString, forKey: key)
    }

    public static func take() -> URL? {
        guard let string = SharedStorage.defaults.string(forKey: key) else { return nil }
        SharedStorage.defaults.removeObject(forKey: key)
        return URL(string: string)
    }
}

/// `footmob://` URLs used by widgets, Live Activities, controls and Spotlight.
public enum DeepLink: Hashable, Sendable {
    case live
    case game(League, String)
    case team(League, String)
    case article(URL)
    case news

    public static let scheme = "footmob"

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .live:
            components.host = "live"
        case .news:
            components.host = "news"
        case let .game(league, id):
            components.host = "game"
            components.path = "/\(league.rawValue)/\(id)"
        case let .team(league, id):
            components.host = "team"
            components.path = "/\(league.rawValue)/\(id)"
        case let .article(url):
            components.host = "article"
            components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        }
        return components.url!
    }

    public init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "live": self = .live
        case "news": self = .news
        case "game":
            guard parts.count == 2, let league = League(rawValue: parts[0]),
                  InputValidation.isValidIdentifier(parts[1]) else { return nil }
            self = .game(league, parts[1])
        case "team":
            guard parts.count == 2, let league = League(rawValue: parts[0]),
                  InputValidation.isValidIdentifier(parts[1]) else { return nil }
            self = .team(league, parts[1])
        case "article":
            let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "url" }?.value
            // Any app or web page can open a footmob:// link, so only trusted news hosts are allowed.
            guard let value, let target = URL(string: value), InputValidation.isTrustedArticle(target) else { return nil }
            self = .article(target)
        default:
            return nil
        }
    }
}
