import Foundation

// Raw ESPN site-API payloads. Everything is optional: the API is undocumented and shapes vary
// between the NFL and college feeds and between endpoints.

struct ESPNScoreboard: Decodable {
    var events: Lossy<ESPNEvent>?
    var week: ESPNWeek?
    var season: ESPNSeason?
    var leagues: Lossy<ESPNLeagueInfo>?
}

struct ESPNWeek: Decodable { var number: Int? }
struct ESPNSeason: Decodable { var year: Int?; var type: Int? }

struct ESPNLeagueInfo: Decodable {
    var calendar: [ESPNCalendarSection]?

    private enum CodingKeys: String, CodingKey { case calendar }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Football calendars are lists of sections; other sports send bare date strings.
        calendar = try? container.decode([ESPNCalendarSection].self, forKey: .calendar)
    }
}

struct ESPNCalendarSection: Decodable {
    var label: String?
    var value: FlexString?
    var entries: Lossy<ESPNCalendarEntry>?
}

struct ESPNCalendarEntry: Decodable {
    var label: String?
    var alternateLabel: String?
    var value: FlexString?
    var startDate: String?
    var endDate: String?
}

struct ESPNEvent: Decodable {
    var id: FlexString
    var date: String?
    var name: String?
    var shortName: String?
    var week: ESPNWeek?
    var season: ESPNSeason?
    var competitions: Lossy<ESPNCompetition>?
    var status: ESPNStatus?
}

struct ESPNCompetition: Decodable {
    var id: FlexString?
    var date: String?
    var venue: ESPNVenue?
    var competitors: Lossy<ESPNCompetitor>?
    var status: ESPNStatus?
    var situation: ESPNSituation?
    var broadcasts: Lossy<ESPNBroadcast>?
    var odds: Lossy<ESPNOdds>?
    var notes: Lossy<ESPNNote>?
}

struct ESPNVenue: Decodable {
    var fullName: String?
    var address: Address?
    struct Address: Decodable { var city: String?; var state: String? }
}

struct ESPNCompetitor: Decodable {
    var id: FlexString?
    var homeAway: String?
    var winner: Bool?
    var score: ESPNScore?
    var team: ESPNTeam?
    var records: Lossy<ESPNRecord>?
    var record: Lossy<ESPNRecord>?
    var linescores: Lossy<ESPNLinescore>?
    var curatedRank: Rank?

    struct Rank: Decodable { var current: Int? }
}

struct ESPNTeam: Decodable {
    var id: FlexString?
    var abbreviation: String?
    var displayName: String?
    var shortDisplayName: String?
    var name: String?
    var nickname: String?
    var location: String?
    var color: String?
    var alternateColor: String?
    var logo: String?
    var logos: Lossy<Logo>?

    struct Logo: Decodable { var href: String? }
}

struct ESPNRecord: Decodable {
    var name: String?
    var type: String?
    var summary: String?
    var displayValue: String?
}

struct ESPNLinescore: Decodable {
    var value: Double?
}

struct ESPNStatus: Decodable {
    var clock: Double?
    var displayClock: String?
    var period: Int?
    var type: StatusType?

    struct StatusType: Decodable {
        var name: String?
        var state: String?
        var completed: Bool?
        var description: String?
        var detail: String?
        var shortDetail: String?
    }
}

struct ESPNSituation: Decodable {
    var down: Int?
    var distance: Int?
    var yardLine: Int?
    var downDistanceText: String?
    var shortDownDistanceText: String?
    var possessionText: String?
    var possession: FlexString?
    var isRedZone: Bool?
    var homeTimeouts: Int?
    var awayTimeouts: Int?
    var lastPlay: LastPlay?

    struct LastPlay: Decodable { var text: String? }
}

struct ESPNBroadcast: Decodable {
    var market: String?
    var names: [String]?
    var media: Media?
    struct Media: Decodable { var shortName: String? }
}

struct ESPNOdds: Decodable {
    var details: String?
    var overUnder: Double?
}

struct ESPNNote: Decodable { var headline: String? }

// MARK: - Summary (game detail)

struct ESPNSummary: Decodable {
    var header: Header?
    var boxscore: Boxscore?
    var drives: Drives?
    var scoringPlays: Lossy<ESPNScoringPlay>?
    var winprobability: Lossy<ESPNWinProbability>?
    var leaders: Lossy<ESPNTeamLeaders>?
    var news: ESPNNews?
    var gameInfo: GameInfo?

    struct Header: Decodable {
        var id: FlexString?
        var season: ESPNSeason?
        var week: Int?
        var competitions: Lossy<ESPNCompetition>?
    }

    struct Boxscore: Decodable {
        var teams: Lossy<BoxTeam>?
    }

    struct BoxTeam: Decodable {
        var team: ESPNTeam?
        var homeAway: String?
        var statistics: Lossy<BoxStat>?
    }

    struct BoxStat: Decodable {
        var name: String?
        var label: String?
        var displayValue: String?
    }

    struct Drives: Decodable {
        var previous: Lossy<ESPNDrive>?
        var current: ESPNDrive?
    }

    struct GameInfo: Decodable { var venue: ESPNVenue? }
}

struct ESPNDrive: Decodable {
    var id: FlexString?
    var description: String?
    var team: ESPNTeam?
    var result: String?
    var displayResult: String?
    var isScore: Bool?
    var plays: Lossy<ESPNPlay>?
}

struct ESPNPlay: Decodable {
    var id: FlexString?
    var text: String?
    var clock: Clock?
    var period: Period?
    var scoringPlay: Bool?
    var start: Start?

    struct Clock: Decodable { var displayValue: String? }
    struct Period: Decodable { var number: Int? }
    struct Start: Decodable { var downDistanceText: String? }
}

struct ESPNScoringPlay: Decodable {
    var id: FlexString?
    var type: PlayType?
    var text: String?
    var awayScore: Int?
    var homeScore: Int?
    var period: ESPNPlay.Period?
    var clock: ESPNPlay.Clock?
    var team: ESPNTeam?

    struct PlayType: Decodable { var text: String?; var abbreviation: String? }
}

struct ESPNWinProbability: Decodable {
    var homeWinPercentage: Double?
}

struct ESPNTeamLeaders: Decodable {
    var team: ESPNTeam?
    var leaders: Lossy<Category>?

    struct Category: Decodable {
        var name: String?
        var displayName: String?
        var leaders: Lossy<Leader>?
    }

    struct Leader: Decodable {
        var displayValue: String?
        var athlete: Athlete?
    }

    struct Athlete: Decodable {
        var displayName: String?
        var shortName: String?
        var headshot: Headshot?
        var position: Position?
        struct Headshot: Decodable { var href: String? }
        struct Position: Decodable { var abbreviation: String? }
    }
}

// MARK: - News

struct ESPNNews: Decodable {
    var articles: Lossy<ESPNArticle>?
}

struct ESPNArticle: Decodable {
    var id: FlexString?
    var headline: String?
    var description: String?
    var published: String?
    var byline: String?
    var images: Lossy<Image>?
    var links: Links?
    var categories: Lossy<Category>?

    struct Image: Decodable { var url: String? }
    struct Links: Decodable {
        var web: Web?
        struct Web: Decodable { var href: String? }
    }
    struct Category: Decodable {
        var type: String?
        var teamId: FlexString?
        var team: CategoryTeam?
        struct CategoryTeam: Decodable { var id: FlexString? }
    }
}

// MARK: - Standings

struct ESPNStandingsNode: Decodable {
    var id: FlexString?
    var name: String?
    var abbreviation: String?
    var shortName: String?
    var children: Lossy<ESPNStandingsNode>?
    var standings: Standings?

    struct Standings: Decodable {
        var entries: Lossy<Entry>?
    }

    struct Entry: Decodable {
        var team: ESPNTeam?
        var stats: Lossy<Stat>?
    }

    struct Stat: Decodable {
        var name: String?
        var type: String?
        var value: Double?
        var displayValue: String?
        var summary: String?
    }
}

// MARK: - Teams & schedules

struct ESPNTeamsResponse: Decodable {
    var sports: Lossy<Sport>?

    struct Sport: Decodable { var leagues: Lossy<LeagueEntry>? }
    struct LeagueEntry: Decodable { var teams: Lossy<TeamWrapper>? }
    struct TeamWrapper: Decodable { var team: ESPNTeam? }
}

struct ESPNTeamSchedule: Decodable {
    var events: Lossy<ESPNEvent>?
}
