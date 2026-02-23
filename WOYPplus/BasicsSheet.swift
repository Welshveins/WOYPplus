import SwiftUI
import SwiftData

struct BasicsSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @Query(sort: \Food.name) private var foods: [Food]

    let day: Day
    let mealSlot: MealSlot

    @State private var selectedFood: Food?
    @State private var amountGrams: Double = 100

    var body: some View {

        NavigationStack {

            List {

                if foods.isEmpty {
                    Section {
                        Text("No foods yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(foods) { food in
                            Button {
                                selectedFood = food
                                amountGrams = food.defaultPortionGrams ?? 100
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(food.name)
                                        .font(.headline)

                                    Text("\(Int(food.kcalPer100g.rounded())) kcal per 100g")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Basics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedFood) { food in
                FoodAmountSheet(
                    food: food,
                    day: day,
                    mealSlot: mealSlot
                )
            }
        }
    }
}

// MARK: - Amount + log sheet

private struct FoodAmountSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let food: Food
    let day: Day
    let mealSlot: MealSlot

    @State private var amountGrams: Double

    init(food: Food, day: Day, mealSlot: MealSlot) {
        self.food = food
        self.day = day
        self.mealSlot = mealSlot
        _amountGrams = State(initialValue: food.defaultPortionGrams ?? 100)
    }

    var body: some View {
        NavigationStack {
            Form {

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(food.name)
                            .font(.headline)

                        Text(subtitleLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Amount") {
                    if let label = food.defaultPortionName,
                       let grams = food.defaultPortionGrams {
                        Button {
                            amountGrams = grams
                        } label: {
                            HStack {
                                Text(label)
                                Spacer()
                                Text("\(Int(grams.rounded())) g")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack {
                        Text("Grams")
                        Spacer()
                        Text("\(Int(amountGrams.rounded())) g")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $amountGrams, in: 0...600, step: 5)
                }

                Section("This entry") {
                    Text(previewLine)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(amountGrams <= 0)
                }
            }
        }
    }

    private var subtitleLine: String {
        "\(Int(food.kcalPer100g.rounded())) kcal • C \(fmt(food.carbsPer100g)) • P \(fmt(food.proteinPer100g)) • F \(fmt(food.fatPer100g)) per 100g"
    }

    private var previewLine: String {
        let factor = amountGrams / 100.0
        let kcal = food.kcalPer100g * factor
        let c = food.carbsPer100g * factor
        let p = food.proteinPer100g * factor
        let f = food.fatPer100g * factor
        let fi = food.fibrePer100g * factor

        let portion = portionLabel

        return "\(portion) • \(Int(kcal.rounded())) kcal • C \(Int(c.rounded()))g • P \(Int(p.rounded()))g • F \(Int(f.rounded()))g • Fibre \(Int(fi.rounded()))g"
    }

    private var portionLabel: String {
        if let name = food.defaultPortionName,
           let grams = food.defaultPortionGrams,
           abs(grams - amountGrams) < 0.001 {
            return name
        }
        return "\(Int(amountGrams.rounded())) g"
    }

    private func save() {

        let factor = amountGrams / 100.0

        let kcal = food.kcalPer100g * factor
        let carbs = food.carbsPer100g * factor
        let protein = food.proteinPer100g * factor
        let fat = food.fatPer100g * factor
        let fibre = food.fibrePer100g * factor

        let titleParts = [
            food.name,
            portionLabel
        ]
        let title = titleParts.joined(separator: " • ")

        let entry = Entry(
            title: title,
            mealSlot: mealSlot,
            carbsG: carbs,
            proteinG: protein,
            fatG: fat,
            fibreG: fibre,
            caloriesKcal: kcal,
            isEstimate: false,
            day: day,
            recipe: nil,
            servings: 1.0
        )

        ctx.insert(entry)
        try? ctx.save()

        dismiss()
    }

    private func fmt(_ v: Double) -> String {
        "\(Int(v.rounded()))g"
    }
}
