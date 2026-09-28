import SwiftUI
import WidgetKit
import FootMobKit

struct NewsEntry: TimelineEntry {
    let date: Date
    let articles: [Article]
}

struct NewsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NewsEntry {
        NewsEntry(date: .now, articles: SampleData.articles)
    }

    func getSnapshot(in context: Context, completion: @escaping (NewsEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(NewsEntry(date: .now, articles: SnapshotStore.read([Article].self, .news) ?? SampleData.articles))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewsEntry>) -> Void) {
        Task {
            let articles = await Self.loadArticles()
            let entry = NewsEntry(date: .now, articles: articles)
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(45 * 60))))
        }
    }

    private static func loadArticles() async -> [Article] {
        let client = ESPNClient()
        let favorites = FavoritesStorage.load()
        var articles: [Article] = []
        for league in League.allCases {
            articles += (try? await client.news(league: league, teamID: nil, limit: 15)) ?? []
        }
        for team in favorites.prefix(3) {
            articles += (try? await client.news(league: team.league, teamID: team.espnID, limit: 5)) ?? []
        }
        guard !articles.isEmpty else { return SnapshotStore.read([Article].self, .news) ?? [] }
        let ranked = Array(NewsRanker.rank(articles, favorites: Set(favorites.map(\.id))).prefix(6))
        await ImageCache.shared.prefetch(ranked.compactMap(\.imageURL), maxPixel: 300)
        return ranked
    }
}

struct NewsWidget: Widget {
    static let kind = "com.footmob.widget.news"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NewsTimelineProvider()) { entry in
            NewsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Top Stories")
        .description("Headlines about your teams, then the rest of the league.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct NewsWidgetView: View {
    let entry: NewsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let hero = entry.articles.first {
            switch family {
            case .systemSmall:
                heroView(hero, lines: 4)
            case .systemMedium:
                list(Array(entry.articles.prefix(3)))
            default:
                VStack(spacing: 0) {
                    heroView(hero, lines: 2).frame(height: 150)
                    list(Array(entry.articles.dropFirst().prefix(3)))
                }
            }
        } else {
            Label("No news yet", systemImage: "newspaper").foregroundStyle(.secondary)
        }
    }

    private func heroView(_ article: Article, lines: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image = ImageCache.cachedImage(for: article.imageURL, maxPixel: 300) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            }
            Text(article.headline)
                .font(.caption.bold())
                .lineLimit(lines)
                .foregroundStyle(.white)
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .widgetURL(article.url.map { DeepLink.article($0).url })
    }

    private func list(_ articles: [Article]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(articles) { article in
                Link(destination: article.url.map { DeepLink.article($0).url } ?? DeepLink.news.url) {
                    HStack(spacing: 10) {
                        if let image = ImageCache.cachedImage(for: article.imageURL, maxPixel: 300) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(article.headline).font(.caption.weight(.semibold)).lineLimit(2)
                            Text(article.league.shortName).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
