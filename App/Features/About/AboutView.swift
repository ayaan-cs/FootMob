import SwiftUI

/// About, credits and legal. FootMob exists because of FotMob — this screen says so.
struct AboutView: View {
    @Environment(\.openURL) private var openURL

    /// Opens the App Store's search for FotMob.
    private static let fotMobAppStore = URL(string: "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=FotMob")!
    private static let fotMobWebsite = URL(string: "https://www.fotmob.com")!

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                fotMobCredit
                otherCredits
                privacy
            }
            .padding()
        }
        .appBackground()
        .navigationTitle("About & Credits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(.rect(cornerRadius: 22))
                .shadow(radius: 8, y: 4)
                .accessibilityHidden(true)
            Text("FootMob").font(.title.bold())
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var fotMobCredit: some View {
        GlassCard(tint: .green) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Inspired by FotMob", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("""
                    FootMob is a fan-made tribute to **FotMob**, the brilliant football (soccer) app. \
                    The whole idea and much of the execution here come from them: the matchday-first \
                    layout, "your teams first" scores, the match centre with its stats and tables, \
                    league tables, following teams, and personalized news. FootMob only brings \
                    that approach to American football.
                    """)
                    .font(.subheadline)
                Text("If you follow soccer, go and get the real thing. It's one of the best sports apps there is.")
                    .font(.subheadline.weight(.semibold))
                HStack {
                    Button {
                        openURL(Self.fotMobAppStore)
                    } label: {
                        Label("Get FotMob", systemImage: "arrow.down.app.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.green)

                    Button {
                        openURL(Self.fotMobWebsite)
                    } label: {
                        Label("fotmob.com", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
                Text("FootMob is an independent project. It is not affiliated with, endorsed by or sponsored by FotMob. FotMob is a trademark of its owner.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var otherCredits: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Credits").font(.headline)
                credit("chart.bar.fill", "Scores, stats, standings and news", "Data from ESPN's public site API. FootMob is not affiliated with ESPN.")
                credit("shield.fill", "Teams and leagues", "Team names, logos and league marks belong to the NFL, the NCAA, their member schools and clubs.")
                credit("sparkles", "News briefings", "Written on-device by Apple Intelligence (Foundation Models).")
            }
        }
    }

    private var privacy: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Privacy & Security", systemImage: "lock.shield.fill").font(.headline)
                Text("No account, no ads, no tracking and no analytics. Your followed teams stay on your iPhone. FootMob only connects over HTTPS, sends no cookies or identifiers, and opens articles in Safari's secure viewer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func credit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(.tint)
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
}
