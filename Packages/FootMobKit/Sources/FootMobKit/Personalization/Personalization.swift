import Foundation

/// Orders games the way a fan scans a matchday: your teams first, then what's live,
/// then what's next, then what just finished.
public enum GamePrioritizer {
    public static func prioritized(_ games: [Game], favorites: Set<String>, now: Date = .now) -> [Game] {
        games.sorted { score($0, favorites: favorites, now: now) > score($1, favorites: favorites, now: now) }
    }

    static func score(_ game: Game, favorites: Set<String>, now: Date) -> Double {
        var score = 0.0
        if game.involves(anyOf: favorites) { score += 1_000 }
        switch game.status.state {
        case .live:
            score += 500
            // Close games in the 4th quarter matter most.
            if let away = game.away.score, let home = game.home.score,
               abs(away - home) <= 8, game.status.period >= 4 {
                score += 50
            }
        case .scheduled:
            let hours = game.date.timeIntervalSince(now) / 3_600
            score += max(0, 300 - hours * 2)
        case .final:
            let hours = now.timeIntervalSince(game.date) / 3_600
            score += max(0, 200 - hours * 4)
        case .postponed, .canceled:
            break
        }
        if let rank = [game.away.rank, game.home.rank].compactMap({ $0 }).min() {
            score += Double(26 - rank) * 2
        }
        return score
    }

    /// The single most relevant game, e.g. for the small widget or the tab bar accessory.
    public static func featured(_ games: [Game], favorites: Set<String>, now: Date = .now) -> Game? {
        prioritized(games, favorites: favorites, now: now).first
    }

    /// For a team: its live game, else its next game, else its most recent result.
    public static func featured(for teamKey: String, in games: [Game], now: Date = .now) -> Game? {
        let teamGames = games.filter { $0.involves(teamKey: teamKey) }
        if let live = teamGames.first(where: { $0.status.isLive }) { return live }
        if let next = teamGames.filter({ $0.status.isUpcoming && $0.date >= now.addingTimeInterval(-3 * 3_600) })
            .min(by: { $0.date < $1.date }) { return next }
        return teamGames.filter(\.status.isFinal).max { $0.date < $1.date }
    }
}

/// Ranks news for the "For You" feed: favorite-team stories first, weighted by recency.
public enum NewsRanker {
    public static func rank(_ articles: [Article], favorites: Set<String>, now: Date = .now) -> [Article] {
        var seen = Set<String>()
        let unique = articles.filter { seen.insert($0.url?.absoluteString ?? $0.id).inserted }
        return unique.sorted { score($0, favorites, now) > score($1, favorites, now) }
    }

    static func score(_ article: Article, _ favorites: Set<String>, _ now: Date) -> Double {
        let matches = article.teamKeys.filter(favorites.contains).count
        let ageHours = article.published.map { max(0, now.timeIntervalSince($0) / 3_600) } ?? 48
        // Recency halves roughly every 18 hours.
        let recency = 100 * pow(0.5, ageHours / 18)
        return Double(matches) * 120 + recency
    }

    public static func isPersonal(_ article: Article, favorites: Set<String>) -> Bool {
        article.teamKeys.contains(where: favorites.contains)
    }
}
