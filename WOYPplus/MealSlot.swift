import Foundation

enum MealSlot: String, Codable, CaseIterable, Identifiable {

    case breakfast
    case lunch
    case dinner

    // IMPORTANT: keep raw value as "extras"
    // so previously saved entries still decode correctly
    case snacks = "extras"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        case .snacks:    return "Snacks"
        }
    }

    // MARK: - Default time-based assignment
    //
    // Breakfast 06:00–10:00
    // Lunch     11:30–14:30
    // Dinner    17:30–21:00
    // Snacks    anything else
    //
    // Windows are [start, end) — inclusive start, exclusive end

    static func defaultSlot(for date: Date, calendar: Calendar = .current) -> MealSlot {

        let minutes = minutesSinceMidnight(for: date, calendar: calendar)

        if inWindow(minutes, startH: 6,  startM: 0,  endH: 10, endM: 0)  { return .breakfast }
        if inWindow(minutes, startH: 11, startM: 30, endH: 14, endM: 30) { return .lunch }
        if inWindow(minutes, startH: 17, startM: 30, endH: 21, endM: 0)  { return .dinner }

        return .snacks
    }

    private static func minutesSinceMidnight(for date: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return (h * 60) + m
    }

    private static func inWindow(
        _ minutes: Int,
        startH: Int, startM: Int,
        endH: Int, endM: Int
    ) -> Bool {
        let start = startH * 60 + startM
        let end = endH * 60 + endM
        return minutes >= start && minutes < end
    }
}
