import SwiftUI
import WidgetKit
import AppIntents
import FootMobKit

struct ScoresEntry: TimelineEntry {
    let date: Date
    let games: [Game]
    let favorites: Set<String>
    let title: String
}

struct ScoresTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ScoresEntry {
        ScoresEntry(date: .now, games: SampleData.games, favorites: [], title: "Today")
    }

    func snapshot(for configuration: ScoresWidgetIntent, in context: Context) async -> ScoresEntry {
        if context.isPreview { return placeholder(in: context) }
        return await entry(for: configuration)
    }

    func timeline(for configuration: ScoresWidgetIntent, in context: Context) async -> Timeline<ScoresEntry> {
        let entry = await entry(for: configuration)
        return Timeline(entries: [entry], policy: .after(WidgetData.nextRefresh(for: entry.games)))
    }

    private func entry(for configuration: ScoresWidgetIntent) async -> ScoresEntry {
        let favorites = FavoritesStorage.keys
        var games = await WidgetData.games(for: configuration.league.leagues)
        if configuration.favoritesOnly {
            games = games.filter { $0.involves(anyOf: favorites) }
        }
        // Keep the widget about "today": live, next 36 hours, or finished in the last 18.
        let now = Date.now
        let relevant = games.filter { game in
            game.status.isLive
                || (game.status.isUpcoming && game.date < now.addingTimeInterval(36 * 3_600))
                || (game.status.isFinal && game.date > now.addingTimeInterval(-18 * 3_600))
        }
        let ordered = GamePrioritizer.prioritized(relevant.isEmpty ? games : relevant, favorites: favorites)
        let top = Array(ordered.prefix(8))
        await ImageCache.shared.prefetchLogos(for: top.flatMap(\.teams))

        let title = top.contains(where: \.status.isLive) ? "Live" : relevant.isEmpty ? "This Week" : "Today"
        return ScoresEntry(date: now, games: top, favorites: favorites, title: title)
    }
}

struct ScoresWidget: Widget {
    static let kind = "com.footmob.widget.scores"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: ScoresWidgetIntent.self, provider: ScoresTimelineProvider()) { entry in
            ScoresWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Scores")
        .description("Today's games with your teams first. Tap the bell to follow one live.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct ScoresWidgetView: View {
    let entry: ScoresEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            if let game = entry.games.first { SmallGameView(game: game) } else { empty }
        case .systemMedium:
            list(limit: 3)
        case .systemLarge:
            list(limit: 7)
        case .accessoryRectangular:
            if let game = entry.games.first { RectangularGameView(game: game) } else { Text("No games") }
        case .accessoryInline:
            if let game = entry.games.first { InlineGameView(game: game) } else { Text("FootMob") }
        case .accessoryCircular:
            if let game = entry.games.first { CircularGameView(game: game) } else { Image(systemName: "football.fill") }
        default:
            list(limit: 3)
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "football.fill").font(.title2)
            Text("No games today").font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private func list(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(entry.title, systemImage: entry.title == "Live" ? "dot.radiowaves.left.and.right" : "football.fill")
                    .font(.caption.bold())
                    .foregroundStyle(entry.title == "Live" ? .red : .secondary)
                    .widgetAccentable()
                Spacer()
                Text(entry.date, style: .time).font(.caption2).foregroundStyle(.secondary)
                Button(intent: RefreshScoresIntent()) {
                    Image(systemName: "arrow.clockwise").font(.caption.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
            if entry.games.isEmpty {
                Spacer()
                empty.frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.games.prefix(limit)) { game in
                    WidgetGameRow(game: game, isFavorite: game.involves(anyOf: entry.favorites))
                    if game.id != entry.games.prefix(limit).last?.id { Divider() }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct WidgetGameRow: View {
    let game: Game
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 6) {
            Link(destination: DeepLink.game(game.league, game.id).url) {
                HStack(spacing: 6) {
                    teamLine(game.away)
                    Text(game.status.isUpcoming ? "@" : game.widgetScore)
                        .font(.subheadline.bold().monospacedDigit())
                        .contentTransition(.numericText())
                        .widgetAccentable()
                    teamLine(game.home, trailing: true)
                    Spacer(minLength: 2)
                    WidgetStatusText(game: game)
                        .font(.caption2.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 58, alignment: .trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            if !game.status.isFinal {
                // One-tap "go live": starts a Live Activity for this game.
                Button(intent: StartGameLiveActivityIntent(game: game)) {
                    Image(systemName: GameActivityController.trackedGameIDs.contains(game.id) ? "bell.fill" : "bell")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
    }

    private func teamLine(_ competitor: Competitor, trailing: Bool = false) -> some View {
        HStack(spacing: 4) {
            if !trailing { WidgetTeamLogo(team: competitor.team, size: 18) }
            Text(competitor.team.abbreviation)
                .font(.caption.weight(isFavorite ? .heavy : .semibold))
            if trailing { WidgetTeamLogo(team: competitor.team, size: 18) }
        }
    }
}

struct SmallGameView: View {
    let game: Game

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                if game.status.isLive {
                    Circle().fill(.red).frame(width: 6, height: 6)
                }
                WidgetStatusText(game: game).font(.caption2.bold())
                Spacer()
                Text(game.league.shortName).font(.caption2).foregroundStyle(.secondary)
            }
            HStack {
                column(game.away)
                Spacer()
                column(game.home)
            }
            if game.status.isUpcoming {
                Text(game.date, format: .dateTime.weekday().hour().minute())
                    .font(.caption.bold())
            } else {
                Text(game.widgetScore)
                    .font(.title2.bold().monospacedDigit())
                    .contentTransition(.numericText())
                    .widgetAccentable()
            }
            if let downDistance = game.situation?.shortDownDistanceText {
                Text(downDistance).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .widgetURL(DeepLink.game(game.league, game.id).url)
    }

    private func column(_ competitor: Competitor) -> some View {
        VStack(spacing: 2) {
            WidgetTeamLogo(team: competitor.team, size: 36)
            Text(competitor.team.abbreviation).font(.caption2.bold())
        }
    }
}

struct RectangularGameView: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text("\(game.away.team.abbreviation) \(game.away.score.map(String.init) ?? "")")
                Spacer()
                Text("\(game.home.score.map(String.init) ?? "") \(game.home.team.abbreviation)")
            }
            .font(.headline.monospacedDigit())
            .widgetAccentable()
            WidgetStatusText(game: game).font(.caption)
            if let downDistance = game.situation?.downDistanceText {
                Text(downDistance).font(.caption2).lineLimit(1)
            }
        }
        .widgetURL(DeepLink.game(game.league, game.id).url)
    }
}

struct InlineGameView: View {
    let game: Game

    var body: some View {
        if game.status.isUpcoming {
            Text("\(game.away.team.abbreviation) @ \(game.home.team.abbreviation) \(GameFormat.kickoff(game.date))")
        } else {
            Text("\(game.away.team.abbreviation) \(game.away.score ?? 0)-\(game.home.score ?? 0) \(game.home.team.abbreviation) \(GameFormat.statusLine(game))")
        }
    }
}

struct CircularGameView: View {
    let game: Game

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(game.status.isUpcoming ? game.away.team.abbreviation : "\(game.away.score ?? 0)")
                Text(game.status.isUpcoming ? game.home.team.abbreviation : "\(game.home.score ?? 0)")
            }
            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
        }
        .widgetURL(DeepLink.game(game.league, game.id).url)
    }
}

#Preview(as: .systemMedium) {
    ScoresWidget()
} timeline: {
    ScoresEntry(date: .now, games: SampleData.games, favorites: [SampleData.chiefs.id], title: "Live")
}
