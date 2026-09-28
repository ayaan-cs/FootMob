import SwiftUI

/// The user's appearance choice. `system` follows the iPhone's Light/Dark setting.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    /// `nil` lets the system decide.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension Color {
    /// Soft grey in light mode, deep navy-black (from the app icon) in dark mode.
    static let appBackground = Color("AppBackground")
}

extension View {
    /// Puts the themed background behind a screen, including under `List`s and forms.
    func appBackground() -> some View {
        scrollContentBackground(.hidden)
            .background { Color.appBackground.ignoresSafeArea() }
    }
}
