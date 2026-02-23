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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    seedFoodsIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }

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
