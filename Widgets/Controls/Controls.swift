import SwiftUI
import WidgetKit
import AppIntents

/// Control Center / Lock Screen / Action Button control that opens straight to live games.
struct LiveScoresControl: ControlWidget {
    static let kind = "com.footmob.control.livescores"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenLiveScoresIntent()) {
                Label("Live Scores", systemImage: "football.fill")
            }
        }
        .displayName("Live Scores")
        .description("Jump straight to games in progress.")
    }
}

/// The "live button": one tap puts your team's game on the Lock Screen and Dynamic Island.
struct TrackMyTeamControl: ControlWidget {
    static let kind = "com.footmob.control.trackteam"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: TrackMyTeamIntent()) {
                Label("Track My Team", systemImage: "dot.radiowaves.left.and.right")
            }
        }
        .displayName("Track My Team")
        .description("Start a Live Activity for your team's current or next game.")
    }
}
