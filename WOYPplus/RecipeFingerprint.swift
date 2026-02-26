import Foundation

enum RecipeFingerprint {

    static func make(
        title: String,
        categoryRaw: String,
        caloriesKcal: Double,
        carbsG: Double,
        proteinG: Double,
        fatG: Double,
        fibreG: Double
    ) -> String {

        let t = normalize(title)
        let c = normalize(categoryRaw)

        func r(_ x: Double) -> Int { Int(x.rounded()) }

        return "\(t)|\(c)|\(r(caloriesKcal))|\(r(carbsG))|\(r(proteinG))|\(r(fatG))|\(r(fibreG))"
    }

    static func fromRecipe(_ r: Recipe) -> String {
        make(
            title: r.title,
            categoryRaw: r.categoryRaw,
            caloriesKcal: r.caloriesKcal,
            carbsG: r.carbsG,
            proteinG: r.proteinG,
            fatG: r.fatG,
            fibreG: r.fibreG
        )
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
