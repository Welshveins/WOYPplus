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

    // Imports a SINGLE recipe JSON blob (used for “shared file import” later)
    @discardableResult
    static func importRecipe(from data: Data, into ctx: ModelContext) throws -> Bool {
        var existingFingerprints = try loadExistingFingerprints(ctx: ctx)
        return try importRecipe(from: data, into: ctx, existingFingerprints: &existingFingerprints)
    }

    // Imports ALL bundled recipe JSON files.
    // If your JSON files are not actually inside a real bundle subfolder,
    // this will still find them because it falls back to scanning all .json in the bundle.
    @discardableResult
    static func importAllBundledRecipes(into ctx: ModelContext, folderName: String = "FoundationRecipes") throws -> Int {

        // 1) Try true bundle subfolder first
        var urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: folderName) ?? []

        // 2) Fallback: scan all bundled .json files (common when Xcode "groups" are used)
        if urls.isEmpty {
            urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        }

        if urls.isEmpty { return 0 }

        var existingFingerprints = try loadExistingFingerprints(ctx: ctx)

        var importedCount = 0
        for url in urls {
            // Only import JSONs that decode as FoundationRecipeDTO
            guard let data = try? Data(contentsOf: url) else { continue }
            let didImport = (try? importRecipe(from: data, into: ctx, existingFingerprints: &existingFingerprints)) ?? false
            if didImport { importedCount += 1 }
        }

        try? ctx.save()
        return importedCount
    }

    // MARK: - Internal helpers

    private static func importRecipe(
        from data: Data,
        into ctx: ModelContext,
        existingFingerprints: inout Set<String>
    ) throws -> Bool {

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

        // De-dupe quickly
        if existingFingerprints.contains(fingerprint) {
            return false
        }
        existingFingerprints.insert(fingerprint)

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
        return true
    }

    private static func loadExistingFingerprints(ctx: ModelContext) throws -> Set<String> {
        let existing = try ctx.fetch(FetchDescriptor<Recipe>())
        return Set(existing.compactMap { $0.sourceFingerprint })
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
