import Foundation
import SwiftData

// Minimal import DTO (we’ll adapt once you show the Foundation JSON)
struct RecipeDTO: Codable, Hashable {
    var title: String
    var caloriesKcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var fibreG: Double
}

enum RecipeImport {

    static func makeFingerprint(_ dto: RecipeDTO) -> String {
        // Stable-ish dedupe: title + macros (rounded)
        let t = dto.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        func r(_ x: Double) -> String { String(Int(x.rounded())) }
        return "\(t)|\(r(dto.caloriesKcal))|\(r(dto.carbsG))|\(r(dto.proteinG))|\(r(dto.fatG))|\(r(dto.fibreG))"
    }

    static func importJSON(data: Data, into ctx: ModelContext) throws -> Int {

        // Try to decode either [RecipeDTO] or { recipes: [RecipeDTO] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let dtos: [RecipeDTO]
        if let arr = try? decoder.decode([RecipeDTO].self, from: data) {
            dtos = arr
        } else {
            struct Wrapper: Codable { var recipes: [RecipeDTO] }
            dtos = try decoder.decode(Wrapper.self, from: data).recipes
        }

        let existing = try ctx.fetch(FetchDescriptor<Recipe>())
        let existingFingerprints = Set(existing.map { $0.sourceFingerprint })

        var inserted = 0

        for dto in dtos {
            let fp = makeFingerprint(dto)
            if existingFingerprints.contains(fp) { continue }

            let r = Recipe(
                title: dto.title,
                caloriesKcal: dto.caloriesKcal,
                carbsG: dto.carbsG,
                proteinG: dto.proteinG,
                fatG: dto.fatG,
                fibreG: dto.fibreG,
                sourceFingerprint: fp
            )

            ctx.insert(r)
            inserted += 1
        }

        try ctx.save()
        return inserted
    }
}
