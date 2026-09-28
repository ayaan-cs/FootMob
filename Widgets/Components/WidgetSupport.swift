import SwiftUI
import WidgetKit
import FootMobKit

/// Network-first data loading for widgets with snapshot fallback. Widgets fetch on their own,
/// so they work even before the app has been opened (or without a shared App Group).
enum WidgetData {
    static func games(for leagues: [League]) async -> [Game] {
        let client = ESPNClient()
        var games: [Game] = []
        for league in leagues {
            if let board = try? await client.scoreboard(league: league, week: nil) {
                games += board.games
                SnapshotStore.write(board.games, as: .games(league))
            } else {
                games += SnapshotStore.read([Game].self, .games(league)) ?? []
            }
        }
        // Widgets refreshing is also a good moment to nudge any running Live Activities.
        await GameActivityController.update(with: games)
        return games
    }

    /// Refresh often while games are live, otherwise wake up for the next kickoff.
    static func nextRefresh(for games: [Game], now: Date = .now) -> Date {
        if games.contains(where: \.status.isLive) {
            return now.addingTimeInterval(5 * 60)
        }
        let nextKickoff = games.filter(\.status.isUpcoming).map(\.date).filter { $0 > now }.min()
        let fallback = now.addingTimeInterval(60 * 60)
        guard let nextKickoff else { return fallback }
        return min(max(nextKickoff, now.addingTimeInterval(5 * 60)), fallback)
    }
}

/// Logo read from the shared image cache, with a team-colored monogram fallback.
struct WidgetTeamLogo: View {
    let team: Team
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let image = ImageCache.cachedImage(for: team.logoURL) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .scaledToFit()
            } else {
                Circle()
                    .fill(team.primaryColor.gradient)
                    .overlay {
                        Text(team.abbreviation)
                            .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
    }
}

extension Game {
    var widgetScore: String {
        "\(away.score ?? 0) – \(home.score ?? 0)"
    }
}

/// Compact status text; upcoming games get a live-updating countdown when kickoff is close.
struct WidgetStatusText: View {
    let game: Game

    var body: some View {
        switch game.status.state {
        case .live:
            Text(game.status.liveLabel).foregroundStyle(.red)
        case .scheduled where game.date.timeIntervalSinceNow < 3 * 3_600 && game.date > .now:
            Text(game.date, style: .timer).monospacedDigit()
        default:
            Text(GameFormat.statusLine(game))
        }
    }
}
