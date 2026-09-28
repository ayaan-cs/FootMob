import AppIntents

/// Siri, Spotlight and Action Button shortcuts — available with zero setup.
struct FootMobShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenLiveScoresIntent(),
            phrases: [
                "Show live scores in \(.applicationName)",
                "Open \(.applicationName) live games"
            ],
            shortTitle: "Live Scores",
            systemImageName: "football.fill"
        )
        AppShortcut(
            intent: TrackMyTeamIntent(),
            phrases: [
                "Track my team in \(.applicationName)",
                "Follow my game live with \(.applicationName)"
            ],
            shortTitle: "Track My Team",
            systemImageName: "dot.radiowaves.left.and.right"
        )
    }
}
