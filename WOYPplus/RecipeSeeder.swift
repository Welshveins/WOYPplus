import Foundation
import SwiftData

enum RecipeSeeder {

    // bump this whenever you change bundled recipes
    private static let seedKey = "woypplus.foundationRecipesSeeded.v6"

    static func seedIfNeeded(ctx: ModelContext) {
        print("Bundle resourceURL:", Bundle.main.resourceURL?.path ?? "nil");
        
        
    print("FoundationRecipes folderURL:", Bundle.main.url(forResource: "FoundationRecipes", withExtension: nil)?.path ?? "nil");       let defaults = UserDefaults.standard
        if defaults.bool(forKey: seedKey) {
            // already seeded for this version
            return
        }

        do {
            let count = try FoundationRecipeImport.importAllBundledRecipes(
                into: ctx,
                folderName: "FoundationRecipes"
            )

            // only mark seeded if we actually inserted something
            if count > 0 {
                defaults.set(true, forKey: seedKey)
            }

            print("Bundled recipe import complete. Inserted: \(count)")
        } catch {
            print("Recipe seeding failed: \(error)")
        }
    }
}
