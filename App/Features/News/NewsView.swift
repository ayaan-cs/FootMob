import SwiftUI
import WebKit
import FootMobKit

enum NewsFeed: String, CaseIterable, Identifiable {
    case forYou = "For You", nfl = "NFL", college = "College"
    var id: String { rawValue }
}

@MainActor
@Observable
final class NewsViewModel {
    var feed: NewsFeed = .forYou
    var articles: [NewsFeed: [Article]] = [:]
    var isLoading = false

    func load(using model: AppModel) async {
        isLoading = true
        defer { isLoading = false }
        let provider = model.provider
        let favorites = Array(model.favorites.prefix(6))
        async let nfl = try? provider.news(league: .nfl, teamID: nil, limit: 40)
        async let cfb = try? provider.news(league: .cfb, teamID: nil, limit: 40)
        let nflArticles = await nfl ?? []
        let cfbArticles = await cfb ?? []

        // Pull team-specific stories for followed teams so "For You" is actually personal.
        var teamArticles: [Article] = []
        await withTaskGroup(of: [Article].self) { group in
            for team in favorites {
                group.addTask {
                    (try? await provider.news(league: team.league, teamID: team.espnID, limit: 10)) ?? []
                }
            }
            for await batch in group { teamArticles += batch }
        }

        articles[.nfl] = nflArticles
        articles[.college] = cfbArticles
        let forYou = NewsRanker.rank(teamArticles + nflArticles + cfbArticles, favorites: model.favoriteKeys)
        articles[.forYou] = forYou
        SnapshotStore.write(Array(forYou.prefix(20)), as: .news)
    }
}

struct NewsView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = NewsViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                Picker("Feed", selection: $viewModel.feed) {
                    ForEach(NewsFeed.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                let articles = viewModel.articles[viewModel.feed] ?? []
                if viewModel.feed == .forYou, !model.favorites.isEmpty, !articles.isEmpty {
                    BriefingCard(articles: articles.filter { NewsRanker.isPersonal($0, favorites: model.favoriteKeys) })
                }
                if let hero = articles.first {
                    HeroArticleCard(article: hero)
                }
                ForEach(articles.dropFirst()) { ArticleRow(article: $0) }

                if articles.isEmpty && viewModel.isLoading {
                    ProgressView().padding(.top, 60)
                }
            }
            .padding()
        }
        .navigationTitle("News")
        .task { if viewModel.articles.isEmpty { await viewModel.load(using: model) } }
        .refreshable { await viewModel.load(using: model) }
    }
}

struct HeroArticleCard: View {
    let article: Article
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.presentedArticle = article.url
        } label: {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: article.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
                .frame(height: 230)
                .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    Text(article.league.shortName).font(.caption.bold()).foregroundStyle(.secondary)
                    Text(article.headline).font(.title3.bold()).lineLimit(3)
                    if let published = article.published {
                        Text(published, style: .relative).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
                .padding(10)
            }
            .clipShape(.rect(cornerRadius: 26))
        }
        .buttonStyle(.plain)
    }
}

struct ArticleRow: View {
    let article: Article
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.presentedArticle = article.url
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.headline).font(.subheadline.weight(.semibold)).lineLimit(3)
                    if !article.summary.isEmpty {
                        Text(article.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    HStack(spacing: 4) {
                        if NewsRanker.isPersonal(article, favorites: model.favoriteKeys) {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                        }
                        Text(article.league.shortName)
                        if let published = article.published {
                            Text("·")
                            Text(published, style: .relative)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                AsyncImage(url: article.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .frame(width: 84, height: 64)
                .clipShape(.rect(cornerRadius: 12))
            }
            .padding(12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(article.url == nil)
    }
}

/// In-app reader using the SwiftUI-native WebView (iOS 26).
struct ArticleReaderView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            WebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        ShareLink(item: url)
                        Button("Open in Safari", systemImage: "safari") { openURL(url) }
                    }
                }
        }
    }
}
