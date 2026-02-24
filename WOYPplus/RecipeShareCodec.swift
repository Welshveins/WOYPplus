import Foundation

struct RecipeSharePayload: Codable {
    let schema: String
    let exportedAt: Date

    let title: String
    let categoryRaw: String
    let caloriesKcal: Double
    let carbsG: Double
    let proteinG: Double
    let fatG: Double
    let fibreG: Double
    let sourceFingerprint: String

    let photoDataBase64: String?
    let ingredients: [Ingredient]

    struct Ingredient: Codable {
        let name: String
        let amountGrams: Double
        let kcalPer100g: Double
        let carbsPer100g: Double
        let proteinPer100g: Double
        let fatPer100g: Double
        let fibrePer100g: Double
    }
}

enum RecipeShareCodec {
    static let schema = "woypplus.recipe.v1"

    static func encode(recipe: Recipe) throws -> Data {
        let payload = RecipeSharePayload(
            schema: schema,
            exportedAt: Date(),
            title: recipe.title,
            categoryRaw: recipe.categoryRaw,
            caloriesKcal: recipe.caloriesKcal,
            carbsG: recipe.carbsG,
            proteinG: recipe.proteinG,
            fatG: recipe.fatG,
            fibreG: recipe.fibreG,
            sourceFingerprint: recipe.sourceFingerprint,
            photoDataBase64: recipe.photoData.map { $0.base64EncodedString() },
            ingredients: recipe.ingredients.map {
                .init(
                    name: $0.name,
                    amountGrams: $0.amountGrams,
                    kcalPer100g: $0.kcalPer100g,
                    carbsPer100g: $0.carbsPer100g,
                    proteinPer100g: $0.proteinPer100g,
                    fatPer100g: $0.fatPer100g,
                    fibrePer100g: $0.fibrePer100g
                )
            }
        )

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(payload)
    }

    static func safeFilename(for title: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title.components(separatedBy: bad).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "WOYPplus Recipe" : cleaned
    }

    static func writeTempShareFile(for recipe: Recipe) throws -> URL {
        let data = try encode(recipe: recipe)
        let name = safeFilename(for: recipe.title)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).woyprecipe.json")
        try data.write(to: url, options: .atomic)
        return url
    }
}
