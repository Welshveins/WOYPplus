import SwiftUI
import SwiftData

@main
struct WOYPPlusApp: App {

    // Single shared container for the whole app
    private let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: Day.self,
                    Entry.self,
                    Recipe.self,
                    RecipeIngredient.self,
                    ExtrasPreset.self,
                    Food.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                // ✅ THIS is the critical line that fixes “no recipes”
                .modelContainer(sharedModelContainer)
                .task {
                    // Seed core libraries (additive seeding)
                    let ctx = sharedModelContainer.mainContext
                    FoodSeeder.seedIfNeeded(into: ctx)
                    ExtrasSeeder.seedIfNeeded(ctx: ctx)
                    RecipeSeeder.seedIfNeeded(ctx: ctx)
                }
                .onOpenURL { url in
                    handleIncomingRecipe(url)
                }
                .alert(importAlertTitle, isPresented: $showImportAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(importAlertMessage)
                }
        }
    }

    private func handleIncomingRecipe(_ url: URL) {
        // Uses the same importer as the bundled folder; tolerant DTO handles legacy "name"
        Task { @MainActor in
            let ctx = sharedModelContainer.mainContext

            do {
                let data = try Data(contentsOf: url)
                let didInsert = try FoundationRecipeImport.importRecipe(from: data, into: ctx)

                if didInsert {
                    importAlertTitle = "Imported"
                    importAlertMessage = "Recipe added."
                } else {
                    importAlertTitle = "Already in library"
                    importAlertMessage = "That recipe is already in your library."
                }
                showImportAlert = true

            } catch {
                importAlertTitle = "Import failed"
                importAlertMessage = error.localizedDescription
                showImportAlert = true
            }
        }
    }
}
