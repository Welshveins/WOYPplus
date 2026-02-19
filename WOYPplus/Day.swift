import Foundation
import SwiftData

@Model
final class Day {

    var date: Date
    var hasEstimates: Bool

    @Relationship(deleteRule: .cascade)
    var entries: [Entry] = []

    init(date: Date) {
        self.date = date
        self.hasEstimates = false
    }

    static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
