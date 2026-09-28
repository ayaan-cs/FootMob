import SwiftUI

public extension Color {
    /// Creates a color from an ESPN-style hex string such as `"002a5c"` or `"#002A5C"`.
    init?(hex: String?) {
        guard var hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

public extension Team {
    var primaryColor: Color { Color(hex: colorHex) ?? .gray }
    var secondaryColor: Color { Color(hex: alternateColorHex) ?? .secondary }

    /// The team color adjusted so it stays visible on the current background.
    ///
    /// Many team colors are near-black (Cowboys navy, Raiders black) and vanish in dark mode,
    /// while a few are near-white and vanish in light mode. In those cases the alternate color
    /// is used if it reads better, otherwise the primary is lightened or darkened.
    func color(for scheme: ColorScheme) -> Color {
        let primary = TeamColorContrast.luminance(hex: colorHex) ?? 0.3
        let alternate = TeamColorContrast.luminance(hex: alternateColorHex)
        switch scheme {
        case .dark where primary < TeamColorContrast.minimumOnDark:
            if let alternate, alternate >= TeamColorContrast.minimumOnDark { return secondaryColor }
            return primaryColor.mix(with: .white, by: 0.45)
        case .light where primary > TeamColorContrast.maximumOnLight:
            if let alternate, alternate <= TeamColorContrast.maximumOnLight { return secondaryColor }
            return primaryColor.mix(with: .black, by: 0.4)
        default:
            return primaryColor
        }
    }
}

public enum TeamColorContrast {
    /// Colors darker than this are hard to see on a dark background.
    public static let minimumOnDark = 0.1
    /// Colors lighter than this are hard to see on a light background.
    public static let maximumOnLight = 0.75

    /// WCAG relative luminance (0 = black, 1 = white) of a hex color.
    public static func luminance(hex: String?) -> Double? {
        guard var hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        func linear(_ channel: UInt64) -> Double {
            let c = Double(channel & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(value >> 16) + 0.7152 * linear(value >> 8) + 0.0722 * linear(value)
    }
}

public enum GameFormat {
    /// "1:00 PM" for today, "Sun 1:00 PM" this week, otherwise "Sep 28".
    public static func kickoff(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        if (0..<7).contains(days) {
            return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// Center-column text for a scoreboard row.
    public static func statusLine(_ game: Game) -> String {
        switch game.status.state {
        case .scheduled: kickoff(game.date)
        case .live: game.status.liveLabel
        case .final: game.status.isOvertime ? "Final/OT" : "Final"
        case .postponed: "Postponed"
        case .canceled: "Canceled"
        }
    }

    public static func dayHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
