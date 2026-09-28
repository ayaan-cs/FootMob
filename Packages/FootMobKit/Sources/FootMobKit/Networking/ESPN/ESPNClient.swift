import Foundation

/// Free, key-less client for ESPN's public site API (the same JSON that powers espn.com).
///
/// The API is unofficial and undocumented: fine for a personal app, but check ESPN's terms
/// before distributing. Everything funnels through `SportsDataProvider`, so a different
/// source can be dropped in without touching the UI.
public struct ESPNClient: SportsDataProvider {
    private let session: URLSession
    private static let maxResponseBytes = 15 * 1_024 * 1_024
    private static let siteBase = URL(string: "https://site.api.espn.com/apis/site/v2/sports/")!
    private static let standingsBase = URL(string: "https://site.api.espn.com/apis/v2/sports/")!

    public init(session: URLSession = ESPNClient.sharedSession) {
        self.session = session
    }

    /// One shared session so widgets and intents don't create a new connection pool per request.
    public static let sharedSession = makeSession()

    /// A hardened, stateless session: no cookies, no credential storage, no disk cache,
    /// TLS 1.2+ only. FootMob never sends anything identifying to the data source.
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: configuration)
    }

    public func scoreboard(league: League, week: WeekSelection?) async throws -> Scoreboard {
        var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: "400")]
        if league == .cfb {
            // 80 = FBS. Without it ESPN only returns the Top 25 slate.
            query.append(URLQueryItem(name: "groups", value: "80"))
        }
        if let week {
            query.append(URLQueryItem(name: "seasontype", value: String(week.seasonType)))
            query.append(URLQueryItem(name: "week", value: String(week.week)))
        }
        let raw: ESPNScoreboard = try await get(url(league, "scoreboard", query: query))
        return raw.toScoreboard(league: league)
    }

    public func gameDetail(league: League, gameID: String) async throws -> GameDetail {
        guard InputValidation.isValidIdentifier(gameID) else { throw SportsDataError.invalidInput }
        let raw: ESPNSummary = try await get(url(league, "summary", query: [URLQueryItem(name: "event", value: gameID)]))
        guard let detail = raw.toDetail(league: league, gameID: gameID) else { throw SportsDataError.notFound }
        return detail
    }

    public func standings(league: League) async throws -> [StandingsGroup] {
        var components = URLComponents(
            url: Self.standingsBase.appendingPathComponent("\(league.espnPath)/standings"),
            resolvingAgainstBaseURL: false
        )!
        // NFL: level 3 returns divisions. College: group 80 returns FBS conferences.
        components.queryItems = league == .nfl
            ? [URLQueryItem(name: "level", value: "3")]
            : [URLQueryItem(name: "group", value: "80")]
        let raw: ESPNStandingsNode = try await get(components.url!)
        return raw.toGroups(league: league)
    }

    public func news(league: League, teamID: String?, limit: Int) async throws -> [Article] {
        if let teamID, !InputValidation.isValidIdentifier(teamID) { throw SportsDataError.invalidInput }
        var query = [URLQueryItem(name: "limit", value: String(min(max(limit, 1), 100)))]
        if let teamID { query.append(URLQueryItem(name: "team", value: teamID)) }
        let raw: ESPNNews = try await get(url(league, "news", query: query))
        return (raw.articles?.values ?? []).compactMap { $0.toArticle(league: league) }
    }

    public func teams(league: League) async throws -> [Team] {
        var query = [URLQueryItem(name: "limit", value: "1000")]
        if league == .cfb { query.append(URLQueryItem(name: "groups", value: "80")) }
        let raw: ESPNTeamsResponse = try await get(url(league, "teams", query: query))
        let teams = (raw.sports?.values ?? [])
            .flatMap { $0.leagues?.values ?? [] }
            .flatMap { $0.teams?.values ?? [] }
            .compactMap { $0.team?.toTeam(league: league) }
        return teams.sorted { $0.displayName < $1.displayName }
    }

    public func schedule(for team: Team) async throws -> [Game] {
        guard InputValidation.isValidIdentifier(team.espnID) else { throw SportsDataError.invalidInput }
        let raw: ESPNTeamSchedule = try await get(url(team.league, "teams/\(team.espnID)/schedule", query: []))
        return (raw.events?.values ?? []).compactMap { $0.toGame(league: team.league) }.sorted { $0.date < $1.date }
    }

    // MARK: - Plumbing

    private func url(_ league: League, _ path: String, query: [URLQueryItem]) -> URL {
        var components = URLComponents(
            url: Self.siteBase.appendingPathComponent("\(league.espnPath)/\(path)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query.isEmpty ? nil : query
        return components.url!
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SportsDataError.badResponse(0) }
        guard (200..<300).contains(http.statusCode) else { throw SportsDataError.badResponse(http.statusCode) }
        guard data.count <= Self.maxResponseBytes else { throw SportsDataError.responseTooLarge }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
