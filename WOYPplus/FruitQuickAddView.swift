import SwiftUI
import SwiftData

struct FruitQuickAddView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let day: Day
    let mealSlot: MealSlot

    @Query(sort: \Food.name) private var foods: [Food]

    @State private var selectedFood: Food?
    @State private var queryText: String = ""

    // Keep it explicit + stable (no guessing categories)
    private let allowedFruitNames: Set<String> = [
        "banana",
        "apple",
        "orange",
        "satsuma",
        "grapes",
        "kiwi",
        "mango"
    ]

    var body: some View {
        List {

            Section {
                TextField("Search fruit", text: $queryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section("Fruit") {
                let list = filteredFruit

                if list.isEmpty {
                    Text("No fruit found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(list) { food in
                        Button {
                            selectedFood = food
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(food.name)
                                    .font(.headline)

                                if let portionName = food.defaultPortionName,
                                   let portionGrams = food.defaultPortionGrams,
                                   portionGrams > 0 {
                                    Text("Default: \(portionName) • \(Int(portionGrams.rounded())) g")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(Int(food.kcalPer100g.rounded())) kcal per 100g")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Fruit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            // Make sure foods exist even if seeding didn't run yet
            FoodSeeder.seedIfNeeded(into: ctx)
        }
        .sheet(item: $selectedFood) { food in
            FoodPortionSheet(
                food: food,
                initialGrams: food.defaultPortionGrams ?? 100
            ) { grams in
                logFood(food, grams: grams)
                selectedFood = nil
                dismiss() // close FruitQuickAddView after logging
            }
        }
    }

    private var filteredFruit: [Food] {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let fruits = foods.filter { f in
            let key = f.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // match exact fruit names, but allow variants like "Banana - ripe" etc.
            // by checking "contains" for these basic seeds.
            let isFruit = allowedFruitNames.contains(key) || allowedFruitNames.contains(where: { key.contains($0) })
            if !isFruit { return false }

            if q.isEmpty { return true }
            return key.contains(q)
        }

        return fruits
    }

    private func logFood(_ food: Food, grams: Double) {
        let g = max(0, grams)

        let kcal = food.kcalPer100g * g / 100.0
        let carbs = food.carbsPer100g * g / 100.0
        let protein = food.proteinPer100g * g / 100.0
        let fat = food.fatPer100g * g / 100.0
        let fibre = food.fibrePer100g * g / 100.0

        let label = food.defaultPortionName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryTitle: String
        if let label, !label.isEmpty {
            entryTitle = "\(food.name) (\(label))"
        } else {
            entryTitle = food.name
        }

        let entry = Entry(
            title: entryTitle,
            mealSlot: mealSlot,
            carbsG: carbs,
            proteinG: protein,
            fatG: fat,
            fibreG: fibre,
            caloriesKcal: kcal,
            isEstimate: false,
            day: day
        )

        ctx.insert(entry)
        try? ctx.save()
    }
}
