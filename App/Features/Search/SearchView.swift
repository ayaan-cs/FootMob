import SwiftUI
import FootMobKit

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var allTeams: [Team] = []

    private var results: [Team] {
        guard !query.isEmpty else { return [] }
        return allTeams.filter {
            $0.displayName.localizedStandardContains(query)
                || $0.abbreviation.localizedStandardContains(query)
                || $0.location.localizedStandardContains(query)
        }
    }

    private var matchingGames: [Game] {
        guard !query.isEmpty else { return [] }
        return model.latestGames.values.flatMap { $0 }.filter {
            $0.name.localizedStandardContains(query) || $0.shortName.localizedStandardContains(query)
        }
    }

    var body: some View {
        List {
            if query.isEmpty {
                Section("Your Teams") {
                    ForEach(model.favorites) { teamRow($0) }
                }
            } else {
                if !matchingGames.isEmpty {
                    Section("This Week") {
                        ForEach(matchingGames) { game in
                            NavigationLink(value: GameRoute(game)) { GameRow(game: game) }
                        }
                    }
                }
                Section("Teams") {
                    ForEach(results.prefix(50)) { teamRow($0) }
                }
            }
        }
        .overlay {
            if !query.isEmpty && results.isEmpty && matchingGames.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .appBackground()
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Teams, games")
        .task {
            if allTeams.isEmpty {
                let nfl = await model.teams(for: .nfl)
                let cfb = await model.teams(for: .cfb)
                allTeams = nfl + cfb
            }
        }
    }

    private func teamRow(_ team: Team) -> some View {
        NavigationLink(value: TeamRoute(team)) {
            HStack {
                TeamLogo(team: team, size: 30)
                VStack(alignment: .leading) {
                    Text(team.displayName)
                    Text(team.league.displayName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.isFavorite(team) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }
            }
        }
    }
}
