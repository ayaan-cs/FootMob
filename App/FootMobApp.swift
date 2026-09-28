import SwiftUI
import BackgroundTasks
import FootMobKit

@main
struct FootMobApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { model.handle(url: $0) }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    switch phase {
                    case .active:
                        if let url = DeepLinkInbox.take() { model.handle(url: url) }
                        Task { await model.refreshTrackedGames() }
                    case .background:
                        BackgroundRefresh.schedule()
                    default:
                        break
                    }
                }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.run()
        }
    }
}
