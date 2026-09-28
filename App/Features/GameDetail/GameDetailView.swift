import SwiftUI
import Charts
import FootMobKit

@MainActor
@Observable
final class GameDetailViewModel {
    let route: GameRoute
    var state: LoadState<GameDetail>
    var standings: [StandingsGroup] = []

    init(route: GameRoute) {
        self.route = route
        state = route.preview.map { .loaded(GameDetail(game: $0)) } ?? .loading
    }

    var game: Game? { state.value?.game }

    func load(using model: AppModel) async {
        do {
            let detail = try await model.provider.gameDetail(league: route.league, gameID: route.gameID)
            state = .loaded(detail)
            if detail.game.status.isLive {
                await GameActivityController.update(with: [detail.game])
            }
        } catch is CancellationError {
        } catch {
            if state.value == nil { state = .failed(error.localizedDescription) }
        }
    }

    func loadStandings(using model: AppModel) async {
        guard standings.isEmpty, let game else { return }
        let groups = (try? await model.provider.standings(league: route.league)) ?? []
        standings = groups.filter { $0.contains(teamKey: game.home.team.id) || $0.contains(teamKey: game.away.team.id) }
    }
}

enum GameDetailTab: String, CaseIterable, Identifiable {
    case summary = "Summary", stats = "Stats", plays = "Plays", table = "Table"
    var id: String { rawValue }
}

struct GameDetailView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: GameDetailViewModel
    @State private var tab: GameDetailTab = .summary

    init(route: GameRoute) {
        _viewModel = State(initialValue: GameDetailViewModel(route: route))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ErrorStateView(message: message) { await viewModel.load(using: model) }
            case .loaded(let detail):
                content(detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let game = viewModel.game, !game.status.isFinal {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.toggleLiveActivity(for: game) }
                    } label: {
                        Label(model.isTracking(game) ? "Stop Live Activity" : "Start Live Activity",
                              systemImage: model.isTracking(game) ? "bell.slash.fill" : "bell.badge.fill")
                    }
                    .symbolEffect(.bounce, value: model.isTracking(game))
                }
            }
            if let game = viewModel.game {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: DeepLink.game(game.league, game.id).url,
                              subject: Text(game.shortName),
                              message: Text("\(game.away.team.abbreviation) \(game.away.score ?? 0) – \(game.home.score ?? 0) \(game.home.team.abbreviation) · \(GameFormat.statusLine(game))"))
                }
            }
        }
        .task {
            await viewModel.load(using: model)
            while !Task.isCancelled, viewModel.game?.status.isFinal == false {
                try? await Task.sleep(for: .seconds(viewModel.game?.status.isLive == true ? 15 : 90))
                await viewModel.load(using: model)
            }
        }
    }

    private func content(_ detail: GameDetail) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                GameHeaderView(game: detail.game)

                Picker("Section", selection: $tab) {
                    ForEach(GameDetailTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch tab {
                    case .summary: SummaryTab(detail: detail)
                    case .stats: TeamStatsView(detail: detail)
                    case .plays: DrivesView(detail: detail)
                    case .table:
                        StandingsList(groups: viewModel.standings,
                                      highlighted: [detail.game.home.team.id, detail.game.away.team.id])
                            .task { await viewModel.loadStandings(using: model) }
                    }
                }
                .padding(.horizontal)
                .animation(.default, value: tab)
            }
            .padding(.bottom, 32)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .sensoryFeedback(.selection, trigger: tab)
    }
}

// MARK: - Header

struct GameHeaderView: View {
    let game: Game

    var body: some View {
        VStack(spacing: 14) {
            if let headline = game.headline {
                Text(headline.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.8))
            }
            HStack(alignment: .center) {
                teamColumn(game.away, hasBall: game.possession == .away)
                VStack(spacing: 4) {
                    if game.status.isUpcoming {
                        Text(game.date, format: .dateTime.hour().minute())
                            .font(.title.bold())
                        Text(game.date, format: .dateTime.weekday(.wide).month().day())
                            .font(.caption)
                    } else {
                        Text("\(game.away.score ?? 0) - \(game.home.score ?? 0)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.snappy, value: game.away.score)
                            .animation(.snappy, value: game.home.score)
                        HStack(spacing: 4) {
                            if game.status.isLive { LiveDot() }
                            Text(GameFormat.statusLine(game)).font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(minWidth: 130)
                teamColumn(game.home, hasBall: game.possession == .home)
            }

            if game.status.isLive, let situation = game.situation {
                FieldPositionView(game: game, situation: situation)
            }

            if !game.status.isUpcoming, !game.away.linescores.isEmpty {
                LinescoreView(game: game)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background {
            TeamMeshBackground(leading: game.away.team.primaryColor, trailing: game.home.team.primaryColor)
                .clipShape(.rect(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
                .ignoresSafeArea(edges: .top)
        }
    }

    private func teamColumn(_ competitor: Competitor, hasBall: Bool) -> some View {
        NavigationLink(value: TeamRoute(competitor.team)) {
            VStack(spacing: 6) {
                TeamLogo(team: competitor.team, size: 56)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                HStack(spacing: 3) {
                    RankBadge(rank: competitor.rank)
                    Text(competitor.team.shortDisplayName).font(.subheadline.weight(.semibold))
                    if hasBall { Image(systemName: "football.fill").font(.caption2) }
                }
                if let record = competitor.record {
                    Text(record).font(.caption2).opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// A mini gridiron showing ball position, line to gain and down & distance.
struct FieldPositionView: View {
    let game: Game
    let situation: Situation

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(situation.downDistanceText ?? "")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if situation.isRedZone {
                    Label("Red Zone", systemImage: "flag.fill").font(.caption.bold()).foregroundStyle(.red)
                }
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                let endZone = width * 0.08
                let playing = width - endZone * 2
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(.green.gradient.opacity(0.85))
                    HStack(spacing: 0) {
                        Rectangle().fill(game.away.team.primaryColor).frame(width: endZone)
                        Spacer()
                        Rectangle().fill(game.home.team.primaryColor).frame(width: endZone)
                    }
                    .clipShape(.rect(cornerRadius: 8))
                    ForEach(1..<10) { yard in
                        Rectangle().fill(.white.opacity(0.35)).frame(width: 1)
                            .offset(x: endZone + playing * CGFloat(yard) / 10)
                    }
                    if let position = situation.fieldPosition {
                        let ballX = endZone + playing * position / 100
                        if let distance = situation.distance, let side = game.possession {
                            // Offense moves toward the opponent's end zone.
                            let target = side == .away ? position + Double(distance) : position - Double(distance)
                            Rectangle().fill(.yellow).frame(width: 2)
                                .offset(x: endZone + playing * min(max(target, 0), 100) / 100)
                        }
                        Rectangle().fill(.blue).frame(width: 2).offset(x: ballX)
                        Image(systemName: "football.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.brown)
                            .background(Circle().fill(.white).padding(-2))
                            .offset(x: ballX - 7)
                    }
                }
            }
            .frame(height: 36)
            if let lastPlay = situation.lastPlay {
                Text(lastPlay)
                    .font(.caption)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .glassEffect(.regular.tint(.black.opacity(0.2)), in: .rect(cornerRadius: 18))
        .animation(.smooth, value: situation.fieldPosition)
    }
}

struct LinescoreView: View {
    let game: Game

    var body: some View {
        let periods = max(game.away.linescores.count, game.home.linescores.count, 4)
        Grid(horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                Text("").gridColumnAlignment(.leading)
                ForEach(0..<periods, id: \.self) { index in
                    Text(index < 4 ? "\(index + 1)" : "OT")
                }
                Text("T").bold()
            }
            .font(.caption2).opacity(0.7)
            row(game.away)
            row(game.home)
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.white)
    }

    private func row(_ competitor: Competitor) -> some View {
        let periods = max(game.away.linescores.count, game.home.linescores.count, 4)
        return GridRow {
            Text(competitor.team.abbreviation).bold()
            ForEach(0..<periods, id: \.self) { index in
                Text(index < competitor.linescores.count ? "\(competitor.linescores[index])" : "-")
            }
            Text("\(competitor.score ?? 0)").bold()
        }
    }
}

// MARK: - Summary

struct SummaryTab: View {
    let detail: GameDetail

    var body: some View {
        VStack(spacing: 16) {
            if detail.winProbability.count > 1 {
                WinProbabilityCard(game: detail.game, points: detail.winProbability)
            }
            if !detail.scoringPlays.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scoring Summary").font(.headline)
                        ForEach(detail.scoringPlays) { play in
                            ScoringPlayRow(play: play, game: detail.game)
                        }
                    }
                }
            }
            if !detail.leaders.isEmpty {
                LeadersCard(game: detail.game, leaders: detail.leaders)
            }
            GameInfoCard(game: detail.game)
            if !detail.articles.isEmpty {
                VStack(spacing: 10) {
                    SectionHeader(title: "Related News", systemImage: "newspaper")
                    ForEach(detail.articles.prefix(4)) { ArticleRow(article: $0) }
                }
            }
        }
    }
}

struct ScoringPlayRow: View {
    let play: ScoringPlay
    let game: Game

    var body: some View {
        let team = [game.away.team, game.home.team].first { $0.id == play.teamKey }
        HStack(alignment: .top, spacing: 10) {
            if let team { TeamLogo(team: team, size: 24) }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(play.typeAbbreviation.isEmpty ? play.typeText : play.typeAbbreviation)
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(team?.primaryColor.opacity(0.2) ?? .gray.opacity(0.2), in: .capsule)
                    Text("Q\(play.period) · \(play.clock)").font(.caption).foregroundStyle(.secondary)
                }
                Text(play.text).font(.subheadline)
            }
            Spacer()
            Text("\(play.awayScore)-\(play.homeScore)").font(.subheadline.bold().monospacedDigit())
        }
    }
}

struct WinProbabilityCard: View {
    let game: Game
    let points: [WinProbabilityPoint]

    var body: some View {
        let latest = points.last?.homeWinProbability ?? 0.5
        let leader = latest >= 0.5 ? game.home.team : game.away.team
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Win Probability").font(.headline)
                    Spacer()
                    TeamLogo(team: leader, size: 18)
                    Text(max(latest, 1 - latest), format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline.bold().monospacedDigit())
                }
                Chart {
                    RuleMark(y: .value("Even", 0.5))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    ForEach(points) { point in
                        AreaMark(x: .value("Play", point.index), y: .value("Home", point.homeWinProbability))
                            .foregroundStyle(
                                LinearGradient(colors: [game.home.team.primaryColor.opacity(0.4),
                                                        game.away.team.primaryColor.opacity(0.4)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Play", point.index), y: .value("Home", point.homeWinProbability))
                            .foregroundStyle(.primary)
                            .interpolationMethod(.monotone)
                    }
                }
                .chartYScale(domain: 0...1)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v == 1 ? game.home.team.abbreviation : v == 0 ? game.away.team.abbreviation : "50%")
                            }
                        }
                    }
                }
                .frame(height: 140)
            }
        }
    }
}

struct LeadersCard: View {
    let game: Game
    let leaders: [LeaderCategory]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Game Leaders").font(.headline)
                ForEach(leaders) { category in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        HStack(alignment: .top) {
                            leaderView(category.away, team: game.away.team)
                            Divider()
                            leaderView(category.home, team: game.home.team)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func leaderView(_ leader: PlayerLeader?, team: Team) -> some View {
        if let leader {
            HStack(spacing: 8) {
                AsyncImage(url: leader.headshotURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Monogram(team: team)
                }
                .frame(width: 36, height: 36)
                .clipShape(.circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(leader.shortName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(leader.statLine).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("—").frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.secondary)
        }
    }
}

struct GameInfoCard: View {
    let game: Game

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Match Info").font(.headline)
                info("calendar", game.date.formatted(date: .complete, time: .shortened))
                if let venue = game.venue {
                    info("mappin.and.ellipse", [venue, game.city].compactMap { $0 }.joined(separator: " · "))
                }
                if let broadcast = game.broadcast { info("tv", broadcast) }
                if let odds = game.odds {
                    info("chart.line.uptrend.xyaxis",
                         game.overUnder.map { "\(odds) · O/U \($0.formatted())" } ?? odds)
                }
                if let week = game.week { info("number", "Week \(week)") }
            }
        }
    }

    private func info(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol).font(.subheadline)
    }
}

// MARK: - Stats

struct TeamStatsView: View {
    let detail: GameDetail

    var body: some View {
        if detail.teamStats.isEmpty {
            ContentUnavailableView("Stats appear at kickoff", systemImage: "chart.bar.xaxis")
        } else {
            GlassCard {
                VStack(spacing: 14) {
                    HStack {
                        TeamLogo(team: detail.game.away.team, size: 24)
                        Spacer()
                        Text("Team Stats").font(.headline)
                        Spacer()
                        TeamLogo(team: detail.game.home.team, size: 24)
                    }
                    ForEach(detail.teamStats) { line in
                        StatComparisonRow(line: line, away: detail.game.away.team, home: detail.game.home.team)
                    }
                }
            }
        }
    }
}

struct StatComparisonRow: View {
    let line: TeamStatLine
    let away: Team
    let home: Team

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(line.away).font(.subheadline.bold().monospacedDigit())
                Spacer()
                Text(line.label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(line.home).font(.subheadline.bold().monospacedDigit())
            }
            if let share = line.awayShare {
                let awayBetter = line.lowerIsBetter ? share < 0.5 : share > 0.5
                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        Capsule().fill(away.primaryColor.opacity(awayBetter ? 1 : 0.4))
                            .frame(width: max(4, (proxy.size.width - 3) * share))
                        Capsule().fill(home.primaryColor.opacity(awayBetter ? 0.4 : 1))
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

// MARK: - Plays

struct DrivesView: View {
    let detail: GameDetail
    @State private var expanded: Set<String> = []

    var body: some View {
        if detail.drives.isEmpty {
            ContentUnavailableView("No drives yet", systemImage: "list.bullet.rectangle")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(detail.drives) { drive in
                    driveCard(drive)
                }
            }
        }
    }

    private func driveCard(_ drive: Drive) -> some View {
        let team = [detail.game.away.team, detail.game.home.team].first { $0.id == drive.teamKey }
        let isExpanded = expanded.contains(drive.id) || drive.isCurrent
        return GlassCard(tint: drive.isScore ? team?.primaryColor : nil) {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.snappy) {
                        if expanded.contains(drive.id) { expanded.remove(drive.id) } else { expanded.insert(drive.id) }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if let team { TeamLogo(team: team, size: 26) }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(drive.result).font(.subheadline.weight(.bold))
                                if drive.isCurrent { LiveDot() }
                            }
                            Text(drive.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    ForEach(drive.plays.reversed()) { play in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                if let downDistance = play.downDistance {
                                    Text(downDistance).font(.caption.weight(.semibold))
                                }
                                Spacer()
                                Text("Q\(play.period) \(play.clock)").font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(play.text)
                                .font(.caption)
                                .fontWeight(play.isScoring ? .bold : .regular)
                        }
                        .padding(.leading, 36)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GameDetailView(route: GameRoute(SampleData.liveGame))
    }
    .environment(AppModel())
}
