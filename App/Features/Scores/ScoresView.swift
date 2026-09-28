import SwiftUI
import FootMobKit

@MainActor
@Observable
final class ScoresViewModel {
    var league: League
    var state: LoadState<Scoreboard> = .loading
    var selectedWeek: WeekSelection?
    var topTwentyFiveOnly = false

    init(league: League = .nfl) {
        self.league = league
    }

    func reload(using model: AppModel) async {
        selectedWeek = nil
        state = .loading
        await load(using: model)
    }

    func select(_ week: WeekSelection, using model: AppModel) async {
        guard week != selectedWeek else { return }
        selectedWeek = week
        state = .loading
        await load(using: model)
    }

    func load(using model: AppModel) async {
        do {
            let board = try await model.provider.scoreboard(league: league, week: selectedWeek)
            state = .loaded(board)
            if selectedWeek == nil { selectedWeek = board.week }
            let isCurrentWeek = selectedWeek == nil || selectedWeek == board.week
            if isCurrentWeek || board.games.contains(where: \.status.isLive) {
                model.ingest(board.games, league: league)
            }
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            if state.value == nil { state = .failed(error.localizedDescription) }
        }
    }

    var hasLiveGames: Bool { state.value?.games.contains(where: \.status.isLive) ?? false }

    /// Sections: your teams, live now, then one per kickoff day.
    func sections(favorites: Set<String>) -> [GameSection] {
        guard var games = state.value?.games else { return [] }
        if league == .cfb && topTwentyFiveOnly { games = games.filter(\.isRankedMatchup) }

        var result: [GameSection] = []
        let mine = games.filter { $0.involves(anyOf: favorites) }
        if !mine.isEmpty { result.append(GameSection(title: "Your Teams", symbol: "star.fill", games: mine)) }

        let rest = games.filter { !$0.involves(anyOf: favorites) }
        let live = rest.filter(\.status.isLive)
        if !live.isEmpty {
            result.append(GameSection(title: "Live Now", symbol: "dot.radiowaves.left.and.right", games: live))
        }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: rest.filter { !$0.status.isLive }) { calendar.startOfDay(for: $0.date) }
        for day in grouped.keys.sorted() {
            let dayGames = grouped[day]!.sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return (lhs.home.rank ?? 99) < (rhs.home.rank ?? 99)
            }
            result.append(GameSection(title: GameFormat.dayHeader(day), symbol: nil, games: dayGames))
        }
        return result
    }
}

struct GameSection: Identifiable {
    var title: String
    var symbol: String?
    var games: [Game]
    var id: String { title }
}

struct ScoresView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = ScoresViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: []) {
                WeekPicker(viewModel: viewModel)

                if viewModel.league == .cfb {
                    Toggle("Top 25 only", isOn: $viewModel.topTwentyFiveOnly)
                        .toggleStyle(.button)
                        .buttonStyle(.glass)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                switch viewModel.state {
                case .loading:
                    ForEach(0..<6, id: \.self) { _ in
                        GameRow(game: SampleData.upcomingGame).redacted(reason: .placeholder)
                    }
                case .failed(let message):
                    ErrorStateView(message: message) { await viewModel.load(using: model) }
                case .loaded(let board) where board.games.isEmpty:
                    ContentUnavailableView("No games this week", systemImage: "calendar.badge.exclamationmark")
                case .loaded:
                    ForEach(viewModel.sections(favorites: model.favoriteKeys)) { section in
                        SectionHeader(title: section.title, systemImage: section.symbol)
                        GameList(games: section.games)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .appBackground()
        .navigationTitle("Matches")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("League", selection: $viewModel.league) {
                    ForEach(League.allCases) { Text($0.shortName).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .refreshable { await viewModel.load(using: model) }
        .task(id: viewModel.league) {
            await viewModel.reload(using: model)
            // Poll while games are live; back off otherwise.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(viewModel.hasLiveGames ? 20 : 120))
                guard !Task.isCancelled else { break }
                await viewModel.load(using: model)
            }
        }
    }
}

/// A glass card holding a run of FotMob-style game rows.
struct GameList: View {
    let games: [Game]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                NavigationLink(value: GameRoute(game)) {
                    GameRow(game: game)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if index < games.count - 1 {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}

struct WeekPicker: View {
    @Environment(AppModel.self) private var model
    @Bindable var viewModel: ScoresViewModel

    var body: some View {
        let calendar = viewModel.state.value?.calendar ?? []
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(calendar) { week in
                            let isSelected = week == viewModel.selectedWeek
                            Button {
                                Task { await viewModel.select(week, using: model) }
                            } label: {
                                Text(shortLabel(week))
                                    .font(.subheadline.weight(isSelected ? .bold : .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                                         in: .capsule)
                            .id(week.id)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.selectedWeek, initial: true) { _, week in
                guard let week else { return }
                withAnimation { proxy.scrollTo(week.id, anchor: .center) }
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedWeek)
    }

    private func shortLabel(_ week: WeekSelection) -> String {
        switch week.seasonType {
        case 1: "Pre \(week.week)"
        case 3: week.label.replacingOccurrences(of: "Round", with: "").trimmingCharacters(in: .whitespaces)
        default: week.label.replacingOccurrences(of: "Week ", with: "Wk ")
        }
    }
}
