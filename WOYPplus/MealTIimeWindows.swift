import Foundation

// Centralised meal-time rules (Stage 10)
enum MealTimeWindows {

    // Breakfast 06:00–10:00
    // Lunch     11:30–14:30
    // Dinner    17:30–21:00
    // Snacks    otherwise

    static func slot(for date: Date, calendar: Calendar = .current) -> MealSlot {
        let minutes = minutesSinceMidnight(for: date, calendar: calendar)

        if minutes >= (6 * 60) && minutes < (10 * 60) {
            return .breakfast
        }

        if minutes >= (11 * 60 + 30) && minutes < (14 * 60 + 30) {
            return .lunch
        }

        if minutes >= (17 * 60 + 30) && minutes < (21 * 60) {
            return .dinner
        }

        return .snacks
    }

    static func currentSlot(calendar: Calendar = .current) -> MealSlot {
        slot(for: Date(), calendar: calendar)
    }

    private static func minutesSinceMidnight(for date: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return (h * 60) + m
    }
}
