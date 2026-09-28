import SwiftUI
import FootMobKit

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        TabView(selection: $model.selectedTab) {
            Tab("Matches", systemImage: "football.fill", value: AppTab.matches) {
                NavigationStack(path: $model.matchesPath) {
                    ScoresView()
                        .withAppDestinations()
                }
            }
            Tab("Leagues", systemImage: "trophy.fill", value: AppTab.leagues) {
                NavigationStack {
                    LeaguesView()
                        .withAppDestinations()
                }
            }
            Tab("Following", systemImage: "star.fill", value: AppTab.following) {
                NavigationStack {
                    FollowingView()
                        .withAppDestinations()
                }
            }
            Tab("News", systemImage: "newspaper.fill", value: AppTab.news) {
                NavigationStack {
                    NewsView()
                        .withAppDestinations()
                }
            }
            Tab(value: AppTab.search, role: .search) {
                NavigationStack {
                    SearchView()
                        .withAppDestinations()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            LiveNowAccessory()
        }
        .sheet(item: $model.presentedArticle) { url in
            ArticleReaderView(url: url)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !model.hasOnboarded },
            set: { if !$0 { model.completeOnboarding() } }
        )) {
            OnboardingView()
        }
    }
}

extension View {
    /// Registers the shared navigation destinations on every tab's stack.
    func withAppDestinations() -> some View {
        navigationDestination(for: GameRoute.self) { route in
            GameDetailView(route: route)
        }
        .navigationDestination(for: TeamRoute.self) { route in
            TeamView(route: route)
        }
        .navigationDestination(for: League.self) { league in
            LeagueView(league: league)
        }
    }
}

/// Mini scoreboard that rides above the tab bar (iOS 26 bottom accessory), FotMob-style.
struct LiveNowAccessory: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if let game = model.accessoryGame {
            Button {
                model.handle(url: DeepLink.game(game.league, game.id).url)
            } label: {
                HStack(spacing: 10) {
                    if game.status.isLive { LiveDot() }
                    TeamLogo(team: game.away.team, size: 20)
                    Text(scoreText(game))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText())
                    TeamLogo(team: game.home.team, size: 20)
                    if placement != .inline {
                        Spacer(minLength: 0)
                        Text(GameFormat.statusLine(game))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(game.status.isLive ? .red : .secondary)
                    }
                }
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            .animation(.snappy, value: game.home.score)
            .animation(.snappy, value: game.away.score)
        } else {
            Label("No games right now", systemImage: "football")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func scoreText(_ game: Game) -> String {
        if game.status.isUpcoming {
            return "\(game.away.team.abbreviation) @ \(game.home.team.abbreviation)"
        }
        return "\(game.away.team.abbreviation) \(game.away.score ?? 0) – \(game.home.score ?? 0) \(game.home.team.abbreviation)"
    }
}
