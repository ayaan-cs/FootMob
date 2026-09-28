import Foundation

/// Static data for SwiftUI previews and widget placeholders.
public enum SampleData {
    public static let chiefs = Team(espnID: "12", league: .nfl, abbreviation: "KC", displayName: "Kansas City Chiefs",
                                    shortDisplayName: "Chiefs", location: "Kansas City", nickname: "Chiefs",
                                    colorHex: "e31837", alternateColorHex: "ffb612",
                                    logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/kc.png"))
    public static let bills = Team(espnID: "2", league: .nfl, abbreviation: "BUF", displayName: "Buffalo Bills",
                                   shortDisplayName: "Bills", location: "Buffalo", nickname: "Bills",
                                   colorHex: "00338d", alternateColorHex: "d50a0a",
                                   logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/buf.png"))
    public static let eagles = Team(espnID: "21", league: .nfl, abbreviation: "PHI", displayName: "Philadelphia Eagles",
                                    shortDisplayName: "Eagles", location: "Philadelphia", nickname: "Eagles",
                                    colorHex: "06424d", alternateColorHex: "a5acaf",
                                    logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/phi.png"))
    public static let cowboys = Team(espnID: "6", league: .nfl, abbreviation: "DAL", displayName: "Dallas Cowboys",
                                     shortDisplayName: "Cowboys", location: "Dallas", nickname: "Cowboys",
                                     colorHex: "002a5c", alternateColorHex: "b0b7bc",
                                     logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/dal.png"))
    public static let georgia = Team(espnID: "61", league: .cfb, abbreviation: "UGA", displayName: "Georgia Bulldogs",
                                     shortDisplayName: "Georgia", location: "Georgia", nickname: "Bulldogs",
                                     colorHex: "ba0c2f", alternateColorHex: "000000",
                                     logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/ncaa/500/61.png"))
    public static let texas = Team(espnID: "251", league: .cfb, abbreviation: "TEX", displayName: "Texas Longhorns",
                                   shortDisplayName: "Texas", location: "Texas", nickname: "Longhorns",
                                   colorHex: "bf5700", alternateColorHex: "ffffff",
                                   logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/ncaa/500/251.png"))

    public static let liveGame = Game(
        id: "sample-live", league: .nfl, date: .now.addingTimeInterval(-5_400), name: "Buffalo Bills at Kansas City Chiefs",
        shortName: "BUF @ KC", week: 4, seasonType: 2,
        away: Competitor(team: bills, score: 17, record: "3-0", linescores: [7, 3, 7]),
        home: Competitor(team: chiefs, score: 20, record: "2-1", linescores: [3, 10, 7]),
        status: GameStatus(state: .live, period: 3, displayClock: "8:21", detail: "8:21 - 3rd Quarter", shortDetail: "8:21 - 3rd"),
        situation: Situation(down: 2, distance: 7, downDistanceText: "2nd & 7 at KC 34", shortDownDistanceText: "2nd & 7",
                             possessionText: "KC 34", possessionTeamID: "2", isRedZone: false,
                             lastPlay: "J.Allen pass short right to K.Coleman for 9 yards.", fieldPosition: 66),
        venue: "GEHA Field at Arrowhead Stadium", city: "Kansas City, MO", broadcast: "CBS", odds: "KC -2.5", overUnder: 48.5
    )

    public static let upcomingGame = Game(
        id: "sample-next", league: .nfl, date: .now.addingTimeInterval(3 * 3_600), name: "Dallas Cowboys at Philadelphia Eagles",
        shortName: "DAL @ PHI", week: 4, seasonType: 2,
        away: Competitor(team: cowboys, record: "1-2"),
        home: Competitor(team: eagles, record: "3-0"),
        status: GameStatus(state: .scheduled, detail: "Sun 4:25 PM", shortDetail: "4:25 PM"),
        venue: "Lincoln Financial Field", city: "Philadelphia, PA", broadcast: "FOX", odds: "PHI -6.5", overUnder: 45.5
    )

    public static let finalGame = Game(
        id: "sample-final", league: .cfb, date: .now.addingTimeInterval(-26 * 3_600), name: "Texas Longhorns at Georgia Bulldogs",
        shortName: "TEX @ UGA", week: 5, seasonType: 2,
        away: Competitor(team: texas, score: 24, record: "4-1", rank: 3, linescores: [7, 7, 3, 7], isWinner: false),
        home: Competitor(team: georgia, score: 31, record: "5-0", rank: 2, linescores: [10, 7, 7, 7], isWinner: true),
        status: GameStatus(state: .final, period: 4, displayClock: "0:00", detail: "Final", shortDetail: "Final"),
        venue: "Sanford Stadium", city: "Athens, GA", broadcast: "ABC", headline: "SEC Showdown"
    )

    public static let games = [liveGame, upcomingGame, finalGame]

    public static let articles = [
        Article(id: "a1", league: .nfl, headline: "Chiefs' defense clamps down late to stay unbeaten at home",
                summary: "Kansas City forced two fourth-quarter turnovers to hold off Buffalo.", published: .now.addingTimeInterval(-3_600),
                imageURL: nil, url: URL(string: "https://www.espn.com/nfl/"), byline: "FootMob", teamIDs: ["12", "2"]),
        Article(id: "a2", league: .cfb, headline: "Georgia climbs to No. 2 after statement win over Texas",
                summary: "The Bulldogs' ground game piled up 240 yards in Athens.", published: .now.addingTimeInterval(-7_200),
                imageURL: nil, url: URL(string: "https://www.espn.com/college-football/"), byline: "FootMob", teamIDs: ["61"])
    ]

    public static let detail = GameDetail(
        game: liveGame,
        teamStats: [
            TeamStatLine(key: "totalYards", label: "Total Yards", away: "312", home: "287"),
            TeamStatLine(key: "firstDowns", label: "1st Downs", away: "18", home: "16"),
            TeamStatLine(key: "thirdDownEff", label: "3rd down efficiency", away: "5-11", home: "4-9"),
            TeamStatLine(key: "turnovers", label: "Turnovers", away: "1", home: "0"),
            TeamStatLine(key: "possessionTime", label: "Possession", away: "21:40", home: "20:59")
        ],
        scoringPlays: [
            ScoringPlay(id: "s1", teamKey: chiefs.id, teamAbbreviation: "KC", typeAbbreviation: "FG", typeText: "Field Goal",
                        text: "H.Butker 44 yd field goal", period: 1, clock: "6:12", awayScore: 0, homeScore: 3),
            ScoringPlay(id: "s2", teamKey: bills.id, teamAbbreviation: "BUF", typeAbbreviation: "TD", typeText: "Touchdown",
                        text: "J.Cook 12 yd run (T.Bass kick)", period: 1, clock: "1:40", awayScore: 7, homeScore: 3)
        ],
        leaders: [
            LeaderCategory(key: "passingYards", title: "Passing Yards",
                           away: PlayerLeader(name: "Josh Allen", shortName: "J. Allen", position: "QB", headshotURL: nil, statLine: "18/26, 211 YDS, 1 TD"),
                           home: PlayerLeader(name: "Patrick Mahomes", shortName: "P. Mahomes", position: "QB", headshotURL: nil, statLine: "20/29, 198 YDS, 2 TD"))
        ],
        winProbability: (0..<40).map { WinProbabilityPoint(index: $0, homeWinProbability: 0.5 + 0.2 * sin(Double($0) / 6)) }
    )
}
