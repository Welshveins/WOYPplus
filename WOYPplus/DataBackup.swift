import Foundation
import SwiftData

// MARK: - DTOs

struct WOYPBackupDTO: Codable {
    var version: Int
    var exportedAt: Date
    var days: [DayDTO]
    var entries: [EntryDTO]
}

struct DayDTO: Codable, Hashable {
    var date: Date
    var hasEstimates: Bool
}

struct EntryDTO: Codable, Hashable {
    var createdAt: Date

    var title: String
    var mealSlotRaw: String

    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var fibreG: Double
    var caloriesKcal: Double

    var isEstimate: Bool
    var dayStart: Date
}

// MARK: - Backup Engine

enum DataBackup {

    // MARK: Export

    static func makeBackup(days: [Day], entries: [Entry]) -> WOYPBackupDTO {

        let dayDTOs = days.map {
            DayDTO(
                date: Day.startOfDay(for: $0.date),
                hasEstimates: $0.hasEstimates
            )
        }

        let entryDTOs = entries.compactMap { e -> EntryDTO? in
            guard let d = e.day else { return nil }

            return EntryDTO(
                createdAt: e.createdAt,
                title: e.title,
                mealSlotRaw: e.mealSlot.rawValue,
                carbsG: e.carbsG,
                proteinG: e.proteinG,
                fatG: e.fatG,
                fibreG: e.fibreG,
                caloriesKcal: e.caloriesKcal,
                isEstimate: e.isEstimate,
                dayStart: Day.startOfDay(for: d.date)
            )
        }

        return WOYPBackupDTO(
            version: 1,
            exportedAt: Date(),
            days: dayDTOs,
            entries: entryDTOs
        )
    }

    static func restore(
        backup: WOYPBackupDTO,
        into ctx: ModelContext
    ) throws {

        let existingDays = try ctx.fetch(FetchDescriptor<Day>())
        let existingEntries = try ctx.fetch(FetchDescriptor<Entry>())

        var dayByStart: [Date: Day] = Dictionary(
            uniqueKeysWithValues: existingDays.map {
                (Day.startOfDay(for: $0.date), $0)
            }
        )

        // Build a fast lookup set of existing entry fingerprints
        var existingFingerprints: Set<String> = Set(
            existingEntries.map {
                "\($0.createdAt.timeIntervalSince1970)|\($0.title)|\($0.mealSlot.rawValue)"
            }
        )

        // Ensure days exist
        for d in backup.days {
            if let existing = dayByStart[d.date] {
                existing.hasEstimates = d.hasEstimates
            } else {
                let newDay = Day(date: d.date)
                newDay.hasEstimates = d.hasEstimates
                ctx.insert(newDay)
                dayByStart[d.date] = newDay
            }
        }

        // Restore entries (merge, never duplicate)
        for e in backup.entries {

            guard let day = dayByStart[e.dayStart] else { continue }

            let fingerprint =
            "\(e.createdAt.timeIntervalSince1970)|\(e.title)|\(e.mealSlotRaw)"

            if existingFingerprints.contains(fingerprint) {
                continue
            }

            let newEntry = Entry(
                title: e.title,
                mealSlot: MealSlot(rawValue: e.mealSlotRaw) ?? .dinner,
                carbsG: e.carbsG,
                proteinG: e.proteinG,
                fatG: e.fatG,
                fibreG: e.fibreG,
                caloriesKcal: e.caloriesKcal,
                isEstimate: e.isEstimate,
                day: day
            )

            ctx.insert(newEntry)

            existingFingerprints.insert(fingerprint)

            if e.isEstimate {
                day.hasEstimates = true
            }
        }

        try ctx.save()
    }
}
