import Foundation
import Testing
@testable import FootMobKit

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Suite("ESPN decoding")
struct ESPNDecodingTests {
    @Test func scoreboardMapsLiveGame() throws {
        let raw = try JSONDecoder().decode(ESPNScoreboard.self, from: fixture("nfl_scoreboard"))
        let board = raw.toScoreboard(league: .nfl)

        #expect(board.games.count == 2)
        #expect(board.week?.week == 3)
        #expect(board.calendar.map(\.week) == [3, 4])

        let live = try #require(board.games.first { $0.id == "401773001" })
        #expect(live.status.state == .live)
        #expect(live.status.liveLabel == "Q3 8:21")
        #expect(live.away.team.abbreviation == "BUF")
        #expect(live.home.score == 20)
        #expect(live.home.linescores == [3, 10, 7])
        #expect(live.possession == .away)
        // "KC 34" with KC at home → 66 yards from the away goal line.
        #expect(live.situation?.fieldPosition == 66)
        #expect(live.broadcast == "CBS")
    }

    @Test func numericTeamIDsAndMalformedCompetitorsAreTolerated() throws {
        let raw = try JSONDecoder().decode(ESPNScoreboard.self, from: fixture("nfl_scoreboard"))
        let game = try #require(raw.toScoreboard(league: .nfl).games.first { $0.id == "401773002" })
        #expect(game.home.team.id == "nfl:21")
        #expect(game.status.isUpcoming)
    }

    @Test func standingsSortBySeed() throws {
        let raw = try JSONDecoder().decode(ESPNStandingsNode.self, from: fixture("nfl_standings"))
        let groups = raw.toGroups(league: .nfl)
        let west = try #require(groups.first)
        #expect(west.name == "AFC West")
        #expect(west.entries.first?.team.abbreviation == "KC")
        #expect(west.entries.first?.pointDifferential == 31)
        #expect(west.entries.first?.clincher == nil)
        #expect(west.entries.first?.conferenceRecord == "2-0")
    }

    @Test(arguments: [
        ("2026-09-27T17:00Z", true),
        ("2026-09-27T17:00:00Z", true),
        ("2026-09-27T17:00:00.000Z", true),
        ("not a date", false)
    ])
    func datesParse(raw: String, valid: Bool) {
        #expect((ESPNDate.parse(raw) != nil) == valid)
    }

    @Test func statParser() {
        #expect(StatValueParser.numeric("5-12") == 5.0 / 12.0)
        #expect(StatValueParser.numeric("31:30") == 1_890)
        #expect(StatValueParser.numeric("350") == 350)
    }

    @Test func deepLinksRoundTrip() {
        let links: [DeepLink] = [.live, .news, .game(.nfl, "401773001"), .team(.cfb, "61"),
                                 .article(URL(string: "https://www.espn.com/nfl/story?id=1")!)]
        for link in links {
            #expect(DeepLink(url: link.url) == link)
        }
    }
}

@Suite("Personalization")
struct PersonalizationTests {
    @Test func favoritesComeFirst() {
        let favorites: Set<String> = [SampleData.cowboys.id]
        let ordered = GamePrioritizer.prioritized(SampleData.games, favorites: favorites)
        #expect(ordered.first?.id == SampleData.upcomingGame.id)
    }

    @Test func liveBeatsFinalWithoutFavorites() {
        let ordered = GamePrioritizer.prioritized(SampleData.games, favorites: [])
        #expect(ordered.first?.status.isLive == true)
    }

    @Test func personalNewsRanksHigher() {
        let ranked = NewsRanker.rank(SampleData.articles, favorites: [SampleData.georgia.id])
        #expect(ranked.first?.id == "a2")
    }
}
