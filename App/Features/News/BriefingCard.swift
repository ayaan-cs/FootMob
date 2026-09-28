import SwiftUI
import FootMobKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// "Your Briefing": an on-device AI summary of news about the teams you follow.
///
/// Uses Apple's Foundation Models framework, which runs entirely on the iPhone — free,
/// private and offline. On devices without Apple Intelligence the card simply lists
/// the top personal headlines instead.
struct BriefingCard: View {
    let articles: [Article]
    @State private var summary: String?
    @State private var isGenerating = false

    var body: some View {
        if !articles.isEmpty {
            GlassCard(tint: .accentColor) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Your Briefing", systemImage: "sparkles")
                        .font(.headline)
                        .symbolEffect(.pulse, isActive: isGenerating)
                    if let summary {
                        Text(summary).font(.subheadline)
                    } else if isGenerating {
                        Text("Catching you up on your teams…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        ForEach(articles.prefix(3)) { article in
                            Label(article.headline, systemImage: "circle.fill")
                                .labelStyle(BulletLabelStyle())
                                .font(.subheadline)
                        }
                    }
                }
            }
            .task(id: articles.prefix(8).map(\.id)) { await generate() }
        }
    }

    private func generate() async {
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else { return }
        isGenerating = true
        defer { isGenerating = false }
        let headlines = articles.prefix(8)
            .map { "- \($0.headline): \($0.summary)" }
            .joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
            You write short, upbeat sports briefings for a football fan. Summarize the key \
            storylines in 2–3 sentences. Only use facts from the headlines provided. No lists, no emojis.
            """)
        if let response = try? await session.respond(to: "Today's headlines about my teams:\n\(headlines)") {
            withAnimation { summary = response.content }
        }
        #endif
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 5)).foregroundStyle(.tint)
            configuration.title
        }
    }
}
