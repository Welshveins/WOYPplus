import Foundation
import SwiftData

enum RecipeSeeder {

    private static let seedKey = "woypplus.foundationRecipesSeeded.v1"

    static func seedIfNeeded(ctx: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: seedKey) == false else { return }

        do {
            let count = try FoundationRecipeImport.importAllBundledRecipes(into: ctx, folderName: "FoundationRecipes")
            defaults.set(true, forKey: seedKey)
            print("Seeded foundation recipes: \(count)")
        } catch {
            print("Recipe seeding failed: \(error)")
        }
    }
}
