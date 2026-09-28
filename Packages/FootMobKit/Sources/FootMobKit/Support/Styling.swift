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
