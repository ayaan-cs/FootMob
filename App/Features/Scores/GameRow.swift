import SwiftUI
import FootMobKit

/// FotMob-style row: away team on the left, score or kickoff in the middle, home team on the right.
struct GameRow: View {
    let game: Game

    var body: some View {
        HStack(spacing: 8) {
            side(game.away, alignment: .leading, hasBall: game.possession == .away)
            center.frame(width: 96)
            side(game.home, alignment: .trailing, hasBall: game.possession == .home)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func side(_ competitor: Competitor, alignment: HorizontalAlignment, hasBall: Bool) -> some View {
        let isLoser = game.status.isFinal && competitor.isWinner == false
        let logo = TeamLogo(team: competitor.team, size: 30)
        let name = VStack(alignment: alignment, spacing: 1) {
            HStack(spacing: 3) {
                if alignment == .trailing, hasBall { possessionIcon }
                RankBadge(rank: competitor.rank)
                Text(competitor.team.shortDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if alignment == .leading, hasBall { possessionIcon }
            }
            if let record = competitor.record {
                Text(record).font(.caption2).foregroundStyle(.secondary)
            }
        }
        return HStack(spacing: 8) {
            if alignment == .leading { logo; name } else { name; logo }
        }
        .opacity(isLoser ? 0.55 : 1)
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var possessionIcon: some View {
        Image(systemName: "football.fill")
            .font(.system(size: 8))
            .foregroundStyle(.brown)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var center: some View {
        VStack(spacing: 2) {
            if game.status.isUpcoming {
                Text(GameFormat.kickoff(game.date))
                    .font(.subheadline.weight(.semibold))
                if let broadcast = game.broadcast {
                    Text(broadcast).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Text("\(game.away.score ?? 0)  –  \(game.home.score ?? 0)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.snappy, value: game.away.score)
                    .animation(.snappy, value: game.home.score)
                HStack(spacing: 4) {
                    if game.status.isLive { LiveDot() }
                    Text(GameFormat.statusLine(game))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(game.status.isLive ? .red : .secondary)
                }
                if game.status.isLive, let redZone = game.situation?.isRedZone, redZone {
                    Text("RED ZONE").font(.system(size: 8, weight: .heavy)).foregroundStyle(.red)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: (game.away.score ?? 0) + (game.home.score ?? 0))
    }

    private var accessibilityText: String {
        let away = game.away.team.displayName, home = game.home.team.displayName
        switch game.status.state {
        case .scheduled:
            return "\(away) at \(home), \(GameFormat.kickoff(game.date))"
        default:
            return "\(away) \(game.away.score ?? 0), \(home) \(game.home.score ?? 0), \(GameFormat.statusLine(game))"
        }
    }
}

#Preview {
    VStack {
        ForEach(SampleData.games) { GameRow(game: $0) }
    }
    .padding()
}
