import Foundation
import BackgroundTasks
import WidgetKit
import FootMobKit

/// Caches the full team list per league (in memory and in shared snapshots for widgets).
actor TeamDirectory {
    private let provider: any SportsDataProvider
    private var cache: [League: [Team]] = [:]

    init(provider: any SportsDataProvider) {
        self.provider = provider
    }

    func teams(for league: League) async -> [Team] {
        if let cached = cache[league] { return cached }
        if let fresh = try? await provider.teams(league: league), !fresh.isEmpty {
            cache[league] = fresh
            SnapshotStore.write(fresh, as: .teams(league))
            return fresh
        }
        let snapshot = SnapshotStore.read([Team].self, .teams(league)) ?? []
        cache[league] = snapshot
        return snapshot
    }
}

/// Keeps widgets current without burning their refresh budget.
enum WidgetSync {
    private static let key = "lastWidgetReload"

    static func reloadIfNeeded(minimumInterval: TimeInterval = 60) {
        let last = UserDefaults.standard.double(forKey: key)
        let now = Date.now.timeIntervalSince1970
        guard now - last >= minimumInterval else { return }
        UserDefaults.standard.set(now, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Opportunistic background refresh: updates snapshots, widgets and Live Activities.
///
/// iOS decides when this runs (typically every 15–60 minutes, more often for apps you use a lot).
/// For second-by-second updates while the phone is locked you'd need a push server, which
/// requires a paid developer account, so FootMob sticks to on-device updates.
enum BackgroundRefresh {
    static let identifier = "com.footmob.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        let hasLiveActivity = !GameActivityController.trackedGameIDs.isEmpty
        request.earliestBeginDate = .now.addingTimeInterval(hasLiveActivity ? 5 * 60 : 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run() async {
        schedule()
        let provider = ESPNClient()
        for league in League.allCases {
            guard let board = try? await provider.scoreboard(league: league, week: nil) else { continue }
            SnapshotStore.write(board.games, as: .games(league))
            await GameActivityController.update(with: board.games)
        }
        if let news = try? await provider.news(league: .nfl, teamID: nil, limit: 25) {
            let cfb = (try? await provider.news(league: .cfb, teamID: nil, limit: 25)) ?? []
            SnapshotStore.write(NewsRanker.rank(news + cfb, favorites: FavoritesStorage.keys), as: .news)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
