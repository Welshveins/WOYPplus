import SwiftUI
import SwiftData

@main
struct WOYPplusApp: App {

    var sharedModelContainer: ModelContainer = {
        try! ModelContainer(for:
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
                    seedFoodsIfNeeded()
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

            // Use your existing Foundation importer (dedupe handled there)
            let didImport: Bool
            do {
                didImport = try RecipeShareImport.importRecipe(from: data, into: ctx)
            } catch {
                // Fallback: still allow importing old Foundation recipe exports
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

    // MARK: - Seed foods

    private func seedFoodsIfNeeded() {

        let ctx = sharedModelContainer.mainContext

        let existing = try? ctx.fetch(FetchDescriptor<Food>())
        if let existing, !existing.isEmpty {
            return
        }

        let foods: [Food] = [

            Food(
                name: "White rice",
                kcalPer100g: 130,
                carbsPer100g: 28,
                proteinPer100g: 2.5,
                fatPer100g: 0.3,
                fibrePer100g: 0.4,
                defaultPortionName: "1 cup cooked",
                defaultPortionGrams: 180
            ),

            Food(
                name: "Chicken breast",
                kcalPer100g: 165,
                carbsPer100g: 0,
                proteinPer100g: 31,
                fatPer100g: 3.6,
                fibrePer100g: 0
            ),

            Food(
                name: "Broccoli",
                kcalPer100g: 35,
                carbsPer100g: 7,
                proteinPer100g: 2.8,
                fatPer100g: 0.4,
                fibrePer100g: 3,
                defaultPortionName: "80g serving",
                defaultPortionGrams: 80
            ),

            Food(
                name: "Potato",
                kcalPer100g: 77,
                carbsPer100g: 17,
                proteinPer100g: 2,
                fatPer100g: 0.1,
                fibrePer100g: 2.2,
                defaultPortionName: "1 medium",
                defaultPortionGrams: 180
            )
        ]

        foods.forEach { ctx.insert($0) }
        try? ctx.save()
    }
}
