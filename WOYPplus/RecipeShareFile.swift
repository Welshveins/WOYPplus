import Foundation
import SwiftData

// A simple, WOYPPlus-native share file format (single recipe).
// We share a .woyprecipe.json file via ShareLink, and import it back into the library.

struct WOYPRecipeShareFile: Codable {
    var version: Int
    var title: String
    var categoryRaw: String

    var caloriesKcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var fibreG: Double

    var sourceFingerprint: String

    // Optional image + ingredients
    var photoDataBase64: String?
    var ingredients: [WOYPRecipeShareIngredient]

    init(from recipe: Recipe) {
        version = 1
        title = recipe.title
        categoryRaw = recipe.categoryRaw
        caloriesKcal = recipe.caloriesKcal
        carbsG = recipe.carbsG
        proteinG = recipe.proteinG
        fatG = recipe.fatG
        fibreG = recipe.fibreG
        sourceFingerprint = recipe.sourceFingerprint

        if let data = recipe.photoData {
            photoDataBase64 = data.base64EncodedString()
        } else {
            photoDataBase64 = nil
        }

        ingredients = recipe.ingredients.map { ing in
            WOYPRecipeShareIngredient(
                name: ing.name,
                amountGrams: ing.amountGrams,
                kcalPer100g: ing.kcalPer100g,
                carbsPer100g: ing.carbsPer100g,
                proteinPer100g: ing.proteinPer100g,
                fatPer100g: ing.fatPer100g,
                fibrePer100g: ing.fibrePer100g
            )
        }
    }
}

struct WOYPRecipeShareIngredient: Codable {
    var name: String
    var amountGrams: Double
    var kcalPer100g: Double
    var carbsPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var fibrePer100g: Double
}

enum WOYPRecipeShareManager {

    static func makeShareURL(for recipe: Recipe) throws -> URL {
        let share = WOYPRecipeShareFile(from: recipe)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(share)

        let safeName = recipe.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        let filename = safeName.isEmpty ? "WOYPPlus_Recipe" : safeName
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filename).woyprecipe.json")

        try data.write(to: url, options: [.atomic])
        return url
    }

    /// Returns true if inserted, false if skipped (already exists by fingerprint)
    static func importRecipe(from data: Data, into ctx: ModelContext) throws -> Bool {
        let decoded = try JSONDecoder().decode(WOYPRecipeShareFile.self, from: data)

        // Deduplicate by fingerprint
        let existing = (try? ctx.fetch(FetchDescriptor<Recipe>())) ?? []
        if existing.contains(where: { $0.sourceFingerprint == decoded.sourceFingerprint }) {
            return false
        }

        let photoData: Data?
        if let b64 = decoded.photoDataBase64, let d = Data(base64Encoded: b64) {
            photoData = d
        } else {
            photoData = nil
        }

        let ingredients: [RecipeIngredient] = decoded.ingredients.map {
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

        let recipe = Recipe(
            title: decoded.title,
            categoryRaw: decoded.categoryRaw,
            caloriesKcal: decoded.caloriesKcal,
            carbsG: decoded.carbsG,
            proteinG: decoded.proteinG,
            fatG: decoded.fatG,
            fibreG: decoded.fibreG,
            sourceFingerprint: decoded.sourceFingerprint,
            photoData: photoData,
            ingredients: ingredients
        )

        ctx.insert(recipe)
        try ctx.save()
        return true
    }
}
