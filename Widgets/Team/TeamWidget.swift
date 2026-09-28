import SwiftUI
import WidgetKit
import AppIntents
import FootMobKit

struct TeamEntry: TimelineEntry {
    let date: Date
    let team: Team?
    let game: Game?
    let record: String?
}

struct TeamTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TeamEntry {
        TeamEntry(date: .now, team: SampleData.chiefs, game: SampleData.liveGame, record: "2-1")
    }

    func snapshot(for configuration: TeamWidgetIntent, in context: Context) async -> TeamEntry {
        if context.isPreview { return placeholder(in: context) }
        return await entry(for: configuration)
    }

    func timeline(for configuration: TeamWidgetIntent, in context: Context) async -> Timeline<TeamEntry> {
        let entry = await entry(for: configuration)
        return Timeline(entries: [entry], policy: .after(WidgetData.nextRefresh(for: entry.game.map { [$0] } ?? [])))
    }

    private func entry(for configuration: TeamWidgetIntent) async -> TeamEntry {
        // Configured team, else the first followed team.
        let team: Team?
        if let parsed = configuration.team?.parsed {
            team = await TeamEntityQuery.allTeams().first { $0.league == parsed.league && $0.espnID == parsed.espnID }
        } else {
            team = FavoritesStorage.load().first
        }
        guard let team else { return TeamEntry(date: .now, team: nil, game: nil, record: nil) }

        var games = await WidgetData.games(for: [team.league])
        if !games.contains(where: { $0.involves(teamKey: team.id) }) {
            // Bye week or off-season: fall back to the full schedule.
            games = (try? await ESPNClient().schedule(for: team)) ?? []
        }
        let game = GamePrioritizer.featured(for: team.id, in: games)
        await ImageCache.shared.prefetchLogos(for: [team] + (game?.teams ?? []))
        let record = game.map { $0.home.team.id == team.id ? $0.home.record : $0.away.record } ?? nil
        return TeamEntry(date: .now, team: team, game: game, record: record)
    }
}

struct TeamWidget: Widget {
    static let kind = "com.footmob.widget.team"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: TeamWidgetIntent.self, provider: TeamTimelineProvider()) { entry in
            TeamWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    if let team = entry.team {
                        LinearGradient(colors: [team.primaryColor, team.primaryColor.opacity(0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    } else {
                        Color(.secondarySystemBackground)
                    }
                }
        }
        .configurationDisplayName("My Team")
        .description("Your team's live score, next kickoff or last result.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct TeamWidgetView: View {
    let entry: TeamEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let team = entry.team {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    if let game = entry.game, !game.status.isUpcoming {
                        Text("\(score(for: team, in: game))")
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                    } else {
                        WidgetTeamLogo(team: team, size: 30)
                    }
                }
            case .accessoryRectangular:
                if let game = entry.game { RectangularGameView(game: game) } else { Text(team.displayName) }
            case .systemMedium:
                medium(team)
            default:
                small(team)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "star.circle").font(.title)
                Text("Follow a team in FootMob, or long-press to pick one.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func small(_ team: Team) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                WidgetTeamLogo(team: team, size: 34)
                Spacer()
                if let record = entry.record {
                    Text(record).font(.caption.bold())
                }
            }
            Spacer(minLength: 0)
            if let game = entry.game {
                let opponent = game.home.team.id == team.id ? game.away.team : game.home.team
                Text(game.home.team.id == team.id ? "vs \(opponent.shortDisplayName)" : "@ \(opponent.shortDisplayName)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if game.status.isUpcoming {
                    Text(game.date, format: .dateTime.weekday().hour().minute())
                        .font(.headline)
                } else {
                    Text(score(for: team, in: game))
                        .font(.title2.bold().monospacedDigit())
                        .contentTransition(.numericText())
                }
                WidgetStatusText(game: game).font(.caption2.bold())
            } else {
                Text("No games scheduled").font(.caption)
            }
        }
        .foregroundStyle(.white)
        .widgetURL(DeepLink.team(team.league, team.espnID).url)
    }

    private func medium(_ team: Team) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetTeamLogo(team: team, size: 48)
                Text(team.shortDisplayName).font(.headline)
                if let record = entry.record { Text(record).font(.caption) }
            }
            if let game = entry.game {
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        WidgetTeamLogo(team: game.away.team, size: 30)
                        Text(game.status.isUpcoming ? "@" : game.widgetScore)
                            .font(.title2.bold().monospacedDigit())
                            .contentTransition(.numericText())
                        WidgetTeamLogo(team: game.home.team, size: 30)
                    }
                    WidgetStatusText(game: game).font(.caption.bold())
                    if let downDistance = game.situation?.downDistanceText {
                        Text(downDistance).font(.caption2)
                    }
                    if !game.status.isFinal {
                        Button(intent: StartGameLiveActivityIntent(game: game)) {
                            Label(GameActivityController.trackedGameIDs.contains(game.id) ? "Tracking" : "Go Live",
                                  systemImage: "dot.radiowaves.left.and.right")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .widgetURL(entry.game.map { DeepLink.game($0.league, $0.id).url } ?? DeepLink.team(team.league, team.espnID).url)
    }

    private func score(for team: Team, in game: Game) -> String {
        let isHome = game.home.team.id == team.id
        let mine = (isHome ? game.home.score : game.away.score) ?? 0
        let theirs = (isHome ? game.away.score : game.home.score) ?? 0
        return "\(mine)-\(theirs)"
    }
}
