import Foundation
import SwiftData

enum RecipeShareImport {

    static func importRecipe(from data: Data, into ctx: ModelContext) throws -> Bool {

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601

        // Only handles our share format
        let payload = try dec.decode(RecipeSharePayload.self, from: data)
        guard payload.schema == RecipeShareCodec.schema else {
            throw NSError(domain: "WOYPplus", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a WOYPplus recipe file."])
        }

        // De-dupe by fingerprint
        let fp = payload.sourceFingerprint
        let existing = try ctx.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.sourceFingerprint == fp }))
        if !existing.isEmpty {
            return false
        }

        let ingredients: [RecipeIngredient] = payload.ingredients.map {
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

        let photoData: Data? = payload.photoDataBase64.flatMap { Data(base64Encoded: $0) }

        let recipe = Recipe(
            title: payload.title,
            categoryRaw: payload.categoryRaw,
            caloriesKcal: payload.caloriesKcal,
            carbsG: payload.carbsG,
            proteinG: payload.proteinG,
            fatG: payload.fatG,
            fibreG: payload.fibreG,
            sourceFingerprint: payload.sourceFingerprint,
            photoData: photoData,
            ingredients: ingredients
        )

        ctx.insert(recipe)
        try ctx.save()
        return true
    }
}
