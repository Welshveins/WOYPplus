import SwiftUI
import SwiftData

struct FoodLibraryView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @Query(sort: \Food.name) private var foods: [Food]

    /// Returns a fully specified pick (foodName + grams + totals)
    let onPick: (FoodPickResult) -> Void

    @State private var queryText = ""
    @State private var selectedFood: Food?

    var body: some View {
        List {

            Section {
                TextField("Search foods", text: $queryText)
            }

            if foods.isEmpty {
                Section {
                    Text("No foods yet.")
                        .foregroundStyle(.secondary)
                }
            } else {

                Section("Foods") {
                    ForEach(filteredFoods) { f in
                        Button {
                            selectedFood = f
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.name)
                                    .font(.headline)

                                Text("\(Int(f.kcalPer100g.rounded())) kcal per 100g")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Foods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            // Ensures the library is populated even if you never opened TodayView first
            FoodSeeder.seedIfNeeded(into: ctx)
        }
        .sheet(item: $selectedFood) { food in
            FoodPortionSheet(
                food: food,
                initialGrams: food.defaultPortionGrams ?? 100
            ) { grams in
                let g = max(0, grams)

                let kcal = food.kcalPer100g * g / 100.0
                let carbs = food.carbsPer100g * g / 100.0
                let protein = food.proteinPer100g * g / 100.0
                let fat = food.fatPer100g * g / 100.0
                let fibre = food.fibrePer100g * g / 100.0

                let pick = FoodPickResult(
                    foodName: food.name,
                    grams: g,
                    portionLabel: food.defaultPortionName,
                    kcal: kcal,
                    carbsG: carbs,
                    proteinG: protein,
                    fatG: fat,
                    fibreG: fibre
                )

                onPick(pick)
                selectedFood = nil
            }
        }
    }

    private var filteredFoods: [Food] {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return foods }
        return foods.filter { $0.name.lowercased().contains(q) }
    }
}

/// What the picker returns (you can later use this in RecipeBuilder or to create an Entry).
struct FoodPickResult {
    let foodName: String
    let grams: Double
    let portionLabel: String?

    let kcal: Double
    let carbsG: Double
    let proteinG: Double
    let fatG: Double
    let fibreG: Double
}
