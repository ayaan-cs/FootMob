import SwiftUI
import FootMobKit

struct LeaguesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(League.allCases) { league in
                    NavigationLink(value: league) {
                        GlassCard(tint: league == .nfl ? .blue : .orange) {
                            HStack(spacing: 14) {
                                Image(systemName: league.symbolName)
                                    .font(.title)
                                    .frame(width: 52, height: 52)
                                    .glassEffect(.regular.tint(league == .nfl ? .blue : .orange), in: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(league.displayName).font(.title3.bold())
                                    Text(league == .nfl ? "Standings, schedule & news" : "FBS conferences, Top 25 & news")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .appBackground()
        .navigationTitle("Leagues")
    }
}

enum LeagueTab: String, CaseIterable, Identifiable {
    case table = "Table", schedule = "Schedule", news = "News"
    var id: String { rawValue }
}

struct LeagueView: View {
    let league: League
    @Environment(AppModel.self) private var model
    @State private var tab: LeagueTab = .table
    @State private var standings: LoadState<[StandingsGroup]> = .loading
    @State private var news: [Article] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("Section", selection: $tab) {
                    ForEach(LeagueTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .table:
                    switch standings {
                    case .loading: ProgressView().padding(.top, 40)
                    case .failed(let message): ErrorStateView(message: message) { await loadStandings() }
                    case .loaded(let groups): StandingsList(groups: groups, highlighted: model.favoriteKeys)
                    }
                case .schedule:
                    LeagueScheduleView(league: league)
                case .news:
                    LazyVStack(spacing: 10) {
                        ForEach(news) { ArticleRow(article: $0) }
                    }
                    .task {
                        if news.isEmpty {
                            news = (try? await model.provider.news(league: league, teamID: nil, limit: 40)) ?? []
                        }
                    }
                }
            }
            .padding()
        }
        .appBackground()
        .navigationTitle(league.displayName)
        .task { await loadStandings() }
        .refreshable { await loadStandings() }
    }

    private func loadStandings() async {
        do {
            standings = .loaded(try await model.provider.standings(league: league))
        } catch {
            if standings.value == nil { standings = .failed(error.localizedDescription) }
        }
    }
}

/// Current-week schedule inside a league page.
struct LeagueScheduleView: View {
    let league: League
    @Environment(AppModel.self) private var model
    @State private var games: [Game] = []

    var body: some View {
        VStack(spacing: 12) {
            let grouped = Dictionary(grouping: games) { Calendar.current.startOfDay(for: $0.date) }
            ForEach(grouped.keys.sorted(), id: \.self) { day in
                SectionHeader(title: GameFormat.dayHeader(day))
                GameList(games: grouped[day] ?? [])
            }
        }
        .task {
            games = (try? await model.provider.scoreboard(league: league, week: nil).games) ?? []
        }
    }
}

/// FotMob-style league table. Highlighted rows are the user's teams (or the teams in a game).
struct StandingsList: View {
    let groups: [StandingsGroup]
    var highlighted: Set<String> = []
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if groups.isEmpty {
            ProgressView().padding(.top, 40)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(groups) { group in
                    VStack(spacing: 0) {
                        header(group)
                        ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                            NavigationLink(value: TeamRoute(entry.team)) {
                                row(entry, position: index + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
                }
            }
        }
    }

    private func header(_ group: StandingsGroup) -> some View {
        HStack {
            Text(group.name).font(.subheadline.bold())
            Spacer()
            statColumns(["W", "L", "PCT", "DIFF", "STRK"], bold: false)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func row(_ entry: StandingsEntry, position: Int) -> some View {
        let isHighlighted = highlighted.contains(entry.team.id)
        let pct = entry.winPercent.formatted(.number.precision(.fractionLength(3)))
        let diff = entry.pointDifferential.map { $0 > 0 ? "+\($0)" : "\($0)" } ?? "–"
        return HStack(spacing: 8) {
            Text("\(entry.playoffSeed ?? position)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18)
            TeamLogo(team: entry.team, size: 22)
            Text(entry.team.shortDisplayName)
                .font(.subheadline.weight(isHighlighted ? .bold : .regular))
                .lineLimit(1)
            if let clincher = entry.clincher {
                Text(clincher).font(.caption2.bold()).foregroundStyle(.green)
            }
            Spacer(minLength: 4)
            statColumns(["\(entry.wins)", "\(entry.losses)",
                         pct.hasPrefix("0") ? String(pct.dropFirst()) : pct,
                         diff, entry.streak ?? "–"], bold: isHighlighted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isHighlighted ? entry.team.color(for: scheme).opacity(0.22) : .clear)
        .contentShape(.rect)
    }

    private func statColumns(_ values: [String], bold: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.caption.monospacedDigit().weight(bold ? .bold : .regular))
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }
}
