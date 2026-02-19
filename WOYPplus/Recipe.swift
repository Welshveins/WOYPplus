import Foundation
import SwiftData

@Model
final class Recipe {

    var createdAt: Date
    var updatedAt: Date

    var title: String

    // Optional metadata (from Foundation export)
    var categoryRaw: String

    // Per serving (simple and consistent)
    var caloriesKcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var fibreG: Double

    // Optional recipe photo (decoded from base64 JPEG)
    @Attribute(.externalStorage) var photoData: Data?

    // Ingredients (imported from Foundation export)
    @Relationship(deleteRule: .cascade) var ingredients: [RecipeIngredient]

    // For de-duplication during import/share
    var sourceFingerprint: String

    init(
        title: String,
        categoryRaw: String = "",
        caloriesKcal: Double,
        carbsG: Double,
        proteinG: Double,
        fatG: Double,
        fibreG: Double,
        sourceFingerprint: String,
        photoData: Data? = nil,
        ingredients: [RecipeIngredient] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.categoryRaw = categoryRaw
        self.caloriesKcal = caloriesKcal
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
        self.fibreG = fibreG
        self.sourceFingerprint = sourceFingerprint
        self.photoData = photoData
        self.ingredients = ingredients
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Ingredient model (new)

@Model
final class RecipeIngredient {

    var name: String
    var amountGrams: Double

    var kcalPer100g: Double
    var carbsPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var fibrePer100g: Double

    init(
        name: String,
        amountGrams: Double,
        kcalPer100g: Double,
        carbsPer100g: Double,
        proteinPer100g: Double,
        fatPer100g: Double,
        fibrePer100g: Double
    ) {
        self.name = name
        self.amountGrams = amountGrams
        self.kcalPer100g = kcalPer100g
        self.carbsPer100g = carbsPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.fibrePer100g = fibrePer100g
    }

    // Convenience (for totals if needed later)
    var kcal: Double { kcalPer100g * amountGrams / 100.0 }
    var carbsG: Double { carbsPer100g * amountGrams / 100.0 }
    var proteinG: Double { proteinPer100g * amountGrams / 100.0 }
    var fatG: Double { fatPer100g * amountGrams / 100.0 }
    var fibreG: Double { fibrePer100g * amountGrams / 100.0 }
}
