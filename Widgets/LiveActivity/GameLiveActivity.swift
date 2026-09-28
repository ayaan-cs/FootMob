import SwiftUI
import WidgetKit
import ActivityKit
import FootMobKit

typealias GameContext = ActivityViewContext<GameActivityAttributes>

struct GameLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GameActivityAttributes.self) { context in
            LiveActivityLockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(context.attributes.deepLink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivityTeamColumn(team: context.attributes.away, score: context.state.awayScore,
                                       hasBall: context.state.possession == .away)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityTeamColumn(team: context.attributes.home, score: context.state.homeScore,
                                       hasBall: context.state.possession == .home)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        ActivityStatusText(state: context.state)
                            .font(.caption.bold())
                        if let downDistance = context.state.downDistance {
                            Text(downDistance).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        if let position = context.state.fieldPosition {
                            MiniField(position: position, attributes: context.attributes, state: context.state)
                        }
                        if let lastPlay = context.state.lastPlay {
                            Text(lastPlay)
                                .font(.caption2)
                                .lineLimit(2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    ActivityLogo(team: context.attributes.away, size: 18)
                    Text("\(context.state.awayScore)")
                        .font(.caption.bold().monospacedDigit())
                        .contentTransition(.numericText())
                }
            } compactTrailing: {
                HStack(spacing: 4) {
                    Text("\(context.state.homeScore)")
                        .font(.caption.bold().monospacedDigit())
                        .contentTransition(.numericText())
                    ActivityLogo(team: context.attributes.home, size: 18)
                }
            } minimal: {
                Text("\(context.state.awayScore)-\(context.state.homeScore)")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
            .widgetURL(context.attributes.deepLink)
            .keylineTint(Color(hex: context.attributes.home.colorHex) ?? .accentColor)
        }
        // Also shows in the Apple Watch Smart Stack and CarPlay.
        .supplementalActivityFamilies([.small, .medium])
    }
}

struct LiveActivityLockScreenView: View {
    let context: GameContext
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        switch activityFamily {
        case .small:
            compact
        default:
            full
        }
    }

    private var compact: some View {
        HStack {
            ActivityLogo(team: context.attributes.away, size: 22)
            Text("\(context.state.awayScore)-\(context.state.homeScore)")
                .font(.headline.monospacedDigit())
            ActivityLogo(team: context.attributes.home, size: 22)
            Spacer()
            ActivityStatusText(state: context.state).font(.caption2.bold())
        }
        .padding(8)
        .foregroundStyle(.white)
    }

    private var full: some View {
        VStack(spacing: 10) {
            HStack {
                ActivityTeamColumn(team: context.attributes.away, score: context.state.awayScore,
                                   hasBall: context.state.possession == .away)
                Spacer()
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        if context.state.state == .live {
                            Circle().fill(.red).frame(width: 6, height: 6)
                        }
                        ActivityStatusText(state: context.state).font(.subheadline.bold())
                    }
                    if let downDistance = context.state.downDistance {
                        Text(downDistance).font(.caption)
                    }
                    if context.state.isRedZone {
                        Text("RED ZONE").font(.caption2.weight(.heavy)).foregroundStyle(.red)
                    }
                }
                Spacer()
                ActivityTeamColumn(team: context.attributes.home, score: context.state.homeScore,
                                   hasBall: context.state.possession == .home)
            }
            if let position = context.state.fieldPosition {
                MiniField(position: position, attributes: context.attributes, state: context.state)
            }
            if let lastPlay = context.state.lastPlay {
                Text(lastPlay)
                    .font(.caption)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(0.85)
            }
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

struct ActivityTeamColumn: View {
    let team: GameActivityAttributes.TeamInfo
    let score: Int
    let hasBall: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 2) {
                ActivityLogo(team: team, size: 34)
                HStack(spacing: 2) {
                    if let rank = team.rank { Text("\(rank)").font(.caption2).opacity(0.7) }
                    Text(team.abbreviation).font(.caption.bold())
                    if hasBall { Image(systemName: "football.fill").font(.system(size: 8)) }
                }
            }
            Text("\(score)")
                .font(.system(size: 30, weight: .heavy, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
        }
    }
}

struct ActivityLogo: View {
    let team: GameActivityAttributes.TeamInfo
    let size: CGFloat

    var body: some View {
        Group {
            if let image = ImageCache.cachedImage(for: team.logoURL) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Circle()
                    .fill(Color(hex: team.colorHex) ?? .gray)
                    .overlay {
                        Text(team.abbreviation)
                            .font(.system(size: size * 0.32, weight: .heavy))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
    }
}

struct ActivityStatusText: View {
    let state: GameActivityAttributes.ContentState

    var body: some View {
        if state.state == .scheduled && state.kickoff > .now {
            Text(state.kickoff, style: .timer).monospacedDigit()
        } else {
            Text(state.statusText)
        }
    }
}

/// Field strip with end zones in team colors and the ball at the line of scrimmage.
struct MiniField: View {
    let position: Double
    let attributes: GameActivityAttributes
    let state: GameActivityAttributes.ContentState

    var body: some View {
        GeometryReader { proxy in
            let endZone = proxy.size.width * 0.08
            let playing = proxy.size.width - endZone * 2
            ZStack(alignment: .leading) {
                Capsule().fill(.green.opacity(0.55))
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: attributes.away.colorHex) ?? .gray).frame(width: endZone)
                    Spacer()
                    Rectangle().fill(Color(hex: attributes.home.colorHex) ?? .gray).frame(width: endZone)
                }
                .clipShape(.capsule)
                Image(systemName: "football.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.brown)
                    .background(Circle().fill(.white).padding(-2))
                    .offset(x: endZone + playing * position / 100 - 5)
            }
        }
        .frame(height: 12)
    }
}

#Preview("Lock Screen", as: .content, using: GameActivityAttributes(game: SampleData.liveGame)) {
    GameLiveActivity()
} contentStates: {
    GameActivityAttributes.ContentState(game: SampleData.liveGame)
}
