import Foundation
import SwiftData

@Model
final class Entry {

    var createdAt: Date

    var title: String
    var mealSlot: MealSlot

    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var fibreG: Double
    var caloriesKcal: Double

    var isEstimate: Bool

    // Relationships
    var day: Day?

    // ✅ NEW: Optional recipe link + servings
    var recipe: Recipe?
    var servings: Double?

    init(
        title: String,
        mealSlot: MealSlot,
        carbsG: Double,
        proteinG: Double,
        fatG: Double,
        fibreG: Double,
        caloriesKcal: Double,
        isEstimate: Bool,
        day: Day? = nil,
        recipe: Recipe? = nil,
        servings: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.title = title
        self.mealSlot = mealSlot
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
        self.fibreG = fibreG
        self.caloriesKcal = caloriesKcal
        self.isEstimate = isEstimate
        self.day = day
        self.recipe = recipe
        self.servings = servings
        self.createdAt = createdAt
    }
}
