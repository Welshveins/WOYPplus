import SwiftUI
import SwiftData

@main
struct WOYPplusApp: App {

    var sharedModelContainer: ModelContainer = {
        try! ModelContainer(
            for:
                Day.self,
                Entry.self,
                Recipe.self,
                RecipeIngredient.self,
                ExtrasPreset.self,
                Food.self
        )
    }()

    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Seed core libraries (additive seeding)
                    FoodSeeder.seedIfNeeded(into: sharedModelContainer.mainContext)
                    ExtrasSeeder.seedIfNeeded(ctx: sharedModelContainer.mainContext)
                    RecipeSeeder.seedIfNeeded(ctx: sharedModelContainer.mainContext)
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
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Receive handler

    private func handleIncomingRecipe(_ url: URL) {

        guard url.pathExtension.contains("json") else { return }

        let ctx = sharedModelContainer.mainContext

        do {
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)

            // Use your existing importer (dedupe handled there)
            let didImport: Bool
            do {
                didImport = try RecipeShareImport.importRecipe(from: data, into: ctx)
            } catch {
                // Fallback: allow importing old Foundation recipe exports
                didImport = try FoundationRecipeImport.importRecipe(from: data, into: ctx)
            }

            if didImport {
                importAlertTitle = "Recipe added"
                importAlertMessage = "The recipe was successfully imported."
            } else {
                importAlertTitle = "Already exists"
                importAlertMessage = "This recipe is already in your library."
            }

            showImportAlert = true

        } catch {
            importAlertTitle = "Import failed"
            importAlertMessage = error.localizedDescription
            showImportAlert = true
        }
    }
}
