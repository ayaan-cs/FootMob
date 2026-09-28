import SwiftUI
import FootMobKit

struct FollowingView: View {
    @Environment(AppModel.self) private var model
    @State private var showingPicker = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            if model.favorites.isEmpty {
                ContentUnavailableView {
                    Label("Follow your teams", systemImage: "star")
                } description: {
                    Text("Get their games first on Matches, personalized news, and one-tap Live Activities.")
                } actions: {
                    Button("Choose Teams") { showingPicker = true }.buttonStyle(.glassProminent)
                }
                .padding(.top, 60)
            } else {
                GlassEffectContainer(spacing: 12) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(model.favorites) { team in
                            NavigationLink(value: TeamRoute(team)) {
                                FavoriteTeamTile(team: team)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Unfollow", systemImage: "star.slash", role: .destructive) {
                                    model.toggleFavorite(team)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Following")
        .toolbar {
            Button("Edit Teams", systemImage: "plus") { showingPicker = true }
        }
        .sheet(isPresented: $showingPicker) {
            TeamPickerView()
        }
    }
}

struct FavoriteTeamTile: View {
    let team: Team
    @Environment(AppModel.self) private var model

    var body: some View {
        let game = GamePrioritizer.featured(for: team.id, in: model.latestGames[team.league] ?? [])
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TeamLogo(team: team, size: 40)
                Spacer()
                Text(team.league.shortName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .glassEffect(.regular, in: .capsule)
            }
            Text(team.shortDisplayName).font(.headline).lineLimit(1)
            if let game {
                let opponent = game.home.team.id == team.id ? game.away.team : game.home.team
                HStack(spacing: 4) {
                    if game.status.isLive { LiveDot() }
                    Text(game.home.team.id == team.id ? "vs \(opponent.abbreviation)" : "@ \(opponent.abbreviation)")
                    Text("·")
                    Text(game.status.isUpcoming ? GameFormat.kickoff(game.date)
                         : "\(game.away.score ?? 0)-\(game.home.score ?? 0) \(GameFormat.statusLine(game))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            } else {
                Text(team.league.displayName).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(team.primaryColor.opacity(0.35)).interactive(), in: .rect(cornerRadius: 24))
    }
}

struct TeamPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var league: League = .nfl
    @State private var query = ""
    @State private var teams: [League: [Team]] = [:]

    var body: some View {
        NavigationStack {
            List {
                let filtered = (teams[league] ?? []).filter {
                    query.isEmpty || $0.displayName.localizedStandardContains(query)
                        || $0.abbreviation.localizedStandardContains(query)
                }
                ForEach(filtered) { team in
                    Button {
                        model.toggleFavorite(team)
                    } label: {
                        HStack {
                            TeamLogo(team: team, size: 30)
                            Text(team.displayName)
                            Spacer()
                            Image(systemName: model.isFavorite(team) ? "star.fill" : "star")
                                .foregroundStyle(model.isFavorite(team) ? .yellow : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .tint(.primary)
                }
                if teams[league] == nil {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .searchable(text: $query, prompt: "Search teams")
            .navigationTitle("Follow Teams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("League", selection: $league) {
                        ForEach(League.allCases) { Text($0.shortName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .task(id: league) {
                if teams[league] == nil { teams[league] = await model.teams(for: league) }
            }
            .sensoryFeedback(.success, trigger: model.favorites.count)
        }
    }
}

struct TeamView: View {
    let route: TeamRoute
    @Environment(AppModel.self) private var model
    @State private var team: Team?
    @State private var schedule: [Game] = []
    @State private var news: [Article] = []

    var body: some View {
        ScrollView {
            if let team {
                VStack(spacing: 16) {
                    header(team)
                    VStack(spacing: 16) {
                        if let featured = GamePrioritizer.featured(for: team.id, in: schedule) {
                            SectionHeader(title: featured.status.isLive ? "Live" : featured.status.isUpcoming ? "Next Game" : "Last Game")
                            GameList(games: [featured])
                        }
                        if !schedule.isEmpty {
                            SectionHeader(title: "Schedule", systemImage: "calendar")
                            GameList(games: schedule)
                        }
                        if !news.isEmpty {
                            SectionHeader(title: "News", systemImage: "newspaper")
                            ForEach(news.prefix(8)) { ArticleRow(article: $0) }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let team {
                Button(model.isFavorite(team) ? "Unfollow" : "Follow",
                       systemImage: model.isFavorite(team) ? "star.fill" : "star") {
                    model.toggleFavorite(team)
                }
                .symbolEffect(.bounce, value: model.isFavorite(team))
            }
        }
        .task { await load() }
    }

    private func header(_ team: Team) -> some View {
        VStack(spacing: 8) {
            TeamLogo(team: team, size: 84).shadow(radius: 8)
            Text(team.displayName).font(.title2.bold())
            Text(team.league.displayName).font(.subheadline).opacity(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background {
            TeamMeshBackground(leading: team.primaryColor, trailing: team.secondaryColor)
                .clipShape(.rect(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
                .ignoresSafeArea(edges: .top)
        }
    }

    private func load() async {
        if team == nil {
            team = route.preview
                ?? model.favorites.first { $0.league == route.league && $0.espnID == route.espnID }
            if team == nil {
                team = await model.teams(for: route.league).first { $0.espnID == route.espnID }
            }
        }
        guard let team else { return }
        let provider = model.provider
        async let scheduleTask = try? provider.schedule(for: team)
        async let newsTask = try? provider.news(league: team.league, teamID: team.espnID, limit: 20)
        schedule = await scheduleTask ?? []
        news = await newsTask ?? []
    }
}
