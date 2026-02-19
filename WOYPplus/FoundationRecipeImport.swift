import Foundation
import SwiftData

// MARK: - DTO matching Foundation export

struct FoundationRecipeDTO: Codable {
    var name: String
    var categoryRaw: String
    var ingredients: [FoundationIngredientDTO]
    var photoJPEGBase64: String?
}

struct FoundationIngredientDTO: Codable {
    var name: String
    var amountGrams: Double

    var kcalPer100g: Double
    var carbsPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var fibrePer100g: Double
}

enum FoundationRecipeImport {

    static func importRecipe(from data: Data, into ctx: ModelContext) throws {

        let decoder = JSONDecoder()
        let dto = try decoder.decode(FoundationRecipeDTO.self, from: data)

        // Build ingredients
        let ingredients = dto.ingredients.map {
            RecipeIngredient(
                name: $0.name,
                amountGrams: $0.amountGrams,
                kcalPer100g: $0.kcalPer100g,
                carbsPer100g: $0.carbsPer100g,
                proteinPer100g: $0.proteinPer100g,
                fatPer100g: $0.fatPer100g,
                fibrePer100g: $0.fibrePer100g
            )
        }

        // Compute WHOLE recipe totals
        let totalKcal = ingredients.reduce(0) { $0 + $1.kcal }
        let totalCarbs = ingredients.reduce(0) { $0 + $1.carbsG }
        let totalProtein = ingredients.reduce(0) { $0 + $1.proteinG }
        let totalFat = ingredients.reduce(0) { $0 + $1.fatG }
        let totalFibre = ingredients.reduce(0) { $0 + $1.fibreG }

        let photoData: Data?
        if let b64 = dto.photoJPEGBase64 {
            photoData = Data(base64Encoded: b64)
        } else {
            photoData = nil
        }

        // Stable fingerprint for de-duplication
        let fingerprint = makeFingerprint(
            name: dto.name,
            totalKcal: totalKcal,
            totalCarbs: totalCarbs,
            totalProtein: totalProtein,
            totalFat: totalFat
        )

        // Check duplicates
        let existing = try ctx.fetch(FetchDescriptor<Recipe>())
        if existing.contains(where: { $0.sourceFingerprint == fingerprint }) {
            return
        }

        let recipe = Recipe(
            title: dto.name,
            categoryRaw: dto.categoryRaw,
            caloriesKcal: totalKcal,
            carbsG: totalCarbs,
            proteinG: totalProtein,
            fatG: totalFat,
            fibreG: totalFibre,
            sourceFingerprint: fingerprint,
            photoData: photoData,
            ingredients: ingredients
        )

        ctx.insert(recipe)
        try ctx.save()
    }

    private static func makeFingerprint(
        name: String,
        totalKcal: Double,
        totalCarbs: Double,
        totalProtein: Double,
        totalFat: Double
    ) -> String {

        let n = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        return "\(n)|\(Int(totalKcal.rounded()))|\(Int(totalCarbs.rounded()))|\(Int(totalProtein.rounded()))|\(Int(totalFat.rounded()))"
    }
}
