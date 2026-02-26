import Foundation
import SwiftData

enum RecipeShareImport {

    static func importRecipe(from data: Data, into ctx: ModelContext) throws -> Bool {

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601

        // Only handles our share format
        let payload = try dec.decode(RecipeSharePayload.self, from: data)
        guard payload.schema == RecipeShareCodec.schema else {
            throw NSError(
                domain: "WOYPplus",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Not a WOYPplus recipe file."]
            )
        }

        // Canonical fingerprint (do NOT trust the incoming fingerprint)
        let canonicalFP = RecipeFingerprint.make(
            title: payload.title,
            categoryRaw: payload.categoryRaw,
            caloriesKcal: payload.caloriesKcal,
            carbsG: payload.carbsG,
            proteinG: payload.proteinG,
            fatG: payload.fatG,
            fibreG: payload.fibreG
        )

        // Load existing recipes once and de-dupe robustly
        let existingRecipes = (try? ctx.fetch(FetchDescriptor<Recipe>())) ?? []

        // 1) Raw stored fingerprints (covers same-version imports)
        let rawFPs = Set(existingRecipes.map { $0.sourceFingerprint })

        // 2) Canonical fingerprints computed from what’s already in the DB
        var canonicalFPs = Set<String>()
        canonicalFPs.reserveCapacity(existingRecipes.count)

        var didMigrateAny = false
        for r in existingRecipes {
            let fp = RecipeFingerprint.fromRecipe(r)
            canonicalFPs.insert(fp)

            // Optional: migrate stored fingerprint to canonical if it’s different.
            // This improves future de-dupe across all import paths.
            if r.sourceFingerprint != fp {
                r.sourceFingerprint = fp
                didMigrateAny = true
            }
        }
        if didMigrateAny {
            try? ctx.save()
        }

        // De-dupe: block if it matches either style
        if rawFPs.contains(payload.sourceFingerprint) || canonicalFPs.contains(canonicalFP) {
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

        // IMPORTANT: store the CANONICAL fingerprint (not the incoming one)
        let recipe = Recipe(
            title: payload.title,
            categoryRaw: payload.categoryRaw,
            caloriesKcal: payload.caloriesKcal,
            carbsG: payload.carbsG,
            proteinG: payload.proteinG,
            fatG: payload.fatG,
            fibreG: payload.fibreG,
            sourceFingerprint: canonicalFP,
            photoData: photoData,
            ingredients: ingredients
        )

        ctx.insert(recipe)
        try ctx.save()
        return true
    }
}

// MARK: - Canonical fingerprint helper (lives in this file)

