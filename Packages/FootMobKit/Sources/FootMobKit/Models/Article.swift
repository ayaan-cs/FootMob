import Foundation

public struct Article: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var league: League
    public var headline: String
    public var summary: String
    public var published: Date?
    public var imageURL: URL?
    public var url: URL?
    public var byline: String?
    /// ESPN team IDs tagged on the story (scoped to `league`).
    public var teamIDs: [String]

    public init(id: String, league: League, headline: String, summary: String, published: Date?,
                imageURL: URL?, url: URL?, byline: String?, teamIDs: [String]) {
        self.id = id
        self.league = league
        self.headline = headline
        self.summary = summary
        self.published = published
        self.imageURL = imageURL
        self.url = url
        self.byline = byline
        self.teamIDs = teamIDs
    }

    public var teamKeys: [String] {
        teamIDs.map { Team.key(league: league, espnID: $0) }
    }
}
