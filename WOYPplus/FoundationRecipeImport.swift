import Foundation
import SwiftData

enum FoundationRecipeImport {

    // MARK: - Public API

    /// Import every recipe json inside the app bundle.
    /// Returns how many new recipes were inserted (not counting duplicates).
    static func importAllBundledRecipes(into ctx: ModelContext, folderName: String) throws -> Int {

        // DEBUG (keep for now)
        print("BOOT: seeding starting")
        print("Bundle resourceURL:")
        print(Bundle.main.resourceURL?.path ?? "nil")

        // Search the whole bundle for JSON (avoids folder-reference weirdness)
        let allJson = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []

        // Filter to your recipe JSONs
        let recipeFiles = allJson.filter { url in
            let name = url.lastPathComponent.lowercased()
            return name.hasSuffix(".woyprecipe.json") || name.hasPrefix("woyp recipe")
        }

        print("Bundle json count: \(allJson.count)")
        print("Recipe json count found: \(recipeFiles.count)")

        guard !recipeFiles.isEmpty else {
            throw ImportError.folderNotFound(folderName)
        }

        var inserted = 0

        for url in recipeFiles {
            do {
                let data = try Data(contentsOf: url)
                let didInsert = try importRecipe(from: data, into: ctx)
                if didInsert { inserted += 1 }
            } catch {
                // Keep going if one file fails
                print("Failed importing \(url.lastPathComponent): \(error)")
            }
        }

        try? ctx.save()
        print("BOOT: seeding finished. Inserted: \(inserted)")
        return inserted
    }

    /// Imports a single recipe json blob.
    /// Returns true if inserted, false if it already exists (dedupe).
    static func importRecipe(from data: Data, into ctx: ModelContext) throws -> Bool {

        let dto = try decodeDTO(from: data)

        let title = dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }

        // Build ingredients (full recipe amounts)
        let recipeIngredients: [RecipeIngredient] = dto.ingredients.map { ing in
            RecipeIngredient(
                name: ing.name,
                amountGrams: ing.amountGrams,
                kcalPer100g: ing.kcalPer100g,
                carbsPer100g: ing.carbsPer100g,
                proteinPer100g: ing.proteinPer100g,
                fatPer100g: ing.fatPer100g,
                fibrePer100g: ing.fibrePer100g
            )
        }

        // Determine fingerprint
        let total = totals(from: recipeIngredients)
        let fingerprint = makeFingerprint(
            name: title,
            totalKcal: total.kcal,
            totalCarbs: total.carbs,
            totalProtein: total.protein,
            totalFat: total.fat
        )

        // Dedupe: by fingerprint
        let existing = (try? ctx.fetch(FetchDescriptor<Recipe>())) ?? []
        if existing.contains(where: { ($0.sourceFingerprint ?? "") == fingerprint }) {
            return false
        }

        // Create recipe (stored per-serving in app model)
        let servings = max(dto.servings, 1)
        let perServing = Totals(
            kcal: total.kcal / servings,
            carbs: total.carbs / servings,
            protein: total.protein / servings,
            fat: total.fat / servings,
            fibre: total.fibre / servings
        )

        let recipe = Recipe(
            title: title,
            categoryRaw: dto.categoryRaw,
            servings: servings,
            caloriesKcal: perServing.kcal,
            carbsG: perServing.carbs,
            proteinG: perServing.protein,
            fatG: perServing.fat,
            fibreG: perServing.fibre,
            sourceFingerprint: fingerprint,
            photoData: dto.photoDataDecoded,   // ✅ now supports photoJPEGBase64
            ingredients: recipeIngredients
        )

        ctx.insert(recipe)
        try? ctx.save()
        return true
    }

    // MARK: - Decoding

    private static func decodeDTO(from data: Data) throws -> FoundationRecipeDTO {
        let decoder = JSONDecoder()
        return try decoder.decode(FoundationRecipeDTO.self, from: data)
    }

    // MARK: - Totals + fingerprint

    private struct Totals {
        let kcal: Double
        let carbs: Double
        let protein: Double
        let fat: Double
        let fibre: Double
    }

    private static func totals(from ingredients: [RecipeIngredient]) -> Totals {
        let kcal = ingredients.reduce(0) { $0 + ($1.kcalPer100g * $1.amountGrams / 100.0) }
        let carbs = ingredients.reduce(0) { $0 + ($1.carbsPer100g * $1.amountGrams / 100.0) }
        let protein = ingredients.reduce(0) { $0 + ($1.proteinPer100g * $1.amountGrams / 100.0) }
        let fat = ingredients.reduce(0) { $0 + ($1.fatPer100g * $1.amountGrams / 100.0) }
        let fibre = ingredients.reduce(0) { $0 + ($1.fibrePer100g * $1.amountGrams / 100.0) }
        return Totals(kcal: kcal, carbs: carbs, protein: protein, fat: fat, fibre: fibre)
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

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case folderNotFound(String)

        var errorDescription: String? {
            switch self {
            case .folderNotFound(let name):
                return "Bundled folder not found: \(name)"
            }
        }
    }
}

// MARK: - DTOs (uniquely named to avoid collisions)

private struct FoundationRecipeDTO: Decodable {

    // tolerate older exports that used "name" instead of "title"
    let title: String
    let categoryRaw: String
    let servings: Double

    // Photo support (your current files use photoJPEGBase64)
    let photoJPEGBase64: String?
    let photoDataBase64: String?

    // Full recipe ingredient amounts
    let ingredients: [FoundationIngredientDTO]

    var photoDataDecoded: Data? {
        // Prefer JPEG key (your uploaded example uses this)  [oai_citation:1‡WOYP Recipe - Banoffee Pie (1 portion).json](sediment://file_000000002a8071f486f4537fa9701dcd)
        if let s = photoJPEGBase64, !s.isEmpty, let d = Data(base64Encoded: s) {
            return d
        }
        // Support older key too
        if let s = photoDataBase64, !s.isEmpty {
            return Data(base64Encoded: s)
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case name                 // legacy
        case categoryRaw
        case servings
        case photoJPEGBase64      // ✅ current files
        case photoDataBase64      // ✅ legacy files
        case ingredients
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        if let t = try? c.decode(String.self, forKey: .title) {
            self.title = t
        } else if let n = try? c.decode(String.self, forKey: .name) {
            self.title = n
        } else {
            self.title = ""
        }

        self.categoryRaw = (try? c.decode(String.self, forKey: .categoryRaw)) ?? "Dinner"
        self.servings = (try? c.decode(Double.self, forKey: .servings)) ?? 1

        self.photoJPEGBase64 = try? c.decode(String.self, forKey: .photoJPEGBase64)
        self.photoDataBase64 = try? c.decode(String.self, forKey: .photoDataBase64)

        self.ingredients = (try? c.decode([FoundationIngredientDTO].self, forKey: .ingredients)) ?? []
    }
}

private struct FoundationIngredientDTO: Decodable {
    let name: String
    let amountGrams: Double
    let kcalPer100g: Double
    let carbsPer100g: Double
    let proteinPer100g: Double
    let fatPer100g: Double
    let fibrePer100g: Double
}
