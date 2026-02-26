import Foundation

enum EntryFingerprint {

    /// Canonical key for an Entry already in SwiftData
    static func fromEntry(_ e: Entry) -> String {
        make(
            title: e.title,
            mealSlotRaw: e.mealSlot.rawValue,
            carbsG: e.carbsG,
            proteinG: e.proteinG,
            fatG: e.fatG,
            fibreG: e.fibreG,
            caloriesKcal: e.caloriesKcal,
            isEstimate: e.isEstimate,
            createdAt: e.createdAt
        )
    }

    /// Canonical key for a backup/import DTO (pass raw values so this file does not depend on DTO visibility)
    static func fromBackupValues(
        title: String,
        mealSlotRaw: String,
        carbsG: Double,
        proteinG: Double,
        fatG: Double,
        fibreG: Double,
        caloriesKcal: Double,
        isEstimate: Bool,
        createdAt: Date
    ) -> String {
        make(
            title: title,
            mealSlotRaw: mealSlotRaw,
            carbsG: carbsG,
            proteinG: proteinG,
            fatG: fatG,
            fibreG: fibreG,
            caloriesKcal: caloriesKcal,
            isEstimate: isEstimate,
            createdAt: createdAt
        )
    }

    // MARK: - Core

    private static func make(
        title: String,
        mealSlotRaw: String,
        carbsG: Double,
        proteinG: Double,
        fatG: Double,
        fibreG: Double,
        caloriesKcal: Double,
        isEstimate: Bool,
        createdAt: Date
    ) -> String {

        func r(_ x: Double) -> Int { Int(x.rounded()) }

        let t = normalize(title)
        let slot = normalize(mealSlotRaw)
        let est = isEstimate ? "1" : "0"

        // Minute-level timestamp to reduce accidental duplicates while staying stable enough for imports
        let minute = Int(createdAt.timeIntervalSince1970 / 60.0)

        return "\(t)|\(slot)|\(r(caloriesKcal))|\(r(carbsG))|\(r(proteinG))|\(r(fatG))|\(r(fibreG))|\(est)|\(minute)"
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
