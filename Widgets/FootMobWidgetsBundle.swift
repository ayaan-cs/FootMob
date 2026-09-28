import SwiftUI
import WidgetKit

@main
struct FootMobWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ScoresWidget()
        TeamWidget()
        NewsWidget()
        GameLiveActivity()
        LiveScoresControl()
        TrackMyTeamControl()
    }
}
