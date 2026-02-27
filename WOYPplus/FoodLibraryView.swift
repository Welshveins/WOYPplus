import SwiftUI
import SwiftData

struct FoodLibraryView: View {

    enum Mode {
        case all
        case basics
        case myFoods

        var title: String {
            switch self {
            case .all: return "Foods"
            case .basics: return "Basics"
            case .myFoods: return "My foods"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @Query(sort: \Food.name) private var foods: [Food]

    let mode: Mode
    /// Returns a fully specified pick (foodName + grams + totals)
    let onPick: (FoodPickResult) -> Void

    @State private var queryText = ""
    @State private var selectedFood: Food?

    init(mode: Mode = .all, onPick: @escaping (FoodPickResult) -> Void) {
        self.mode = mode
        self.onPick = onPick
    }

    var body: some View {
        List {

            Section {
                TextField("Search foods", text: $queryText)
            }

            if filteredFoods.isEmpty {
                Section {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(mode.title) {
                    ForEach(filteredFoods) { f in
                        Button {
                            selectedFood = f
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(f.name)
                                        .font(.headline)

                                    Spacer()

                                    if f.isUserCreated {
                                        Text("My food")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }

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
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            // Ensures library is populated even if TodayView wasn't opened first
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

    private var emptyMessage: String {
        switch mode {
        case .all: return "No foods yet."
        case .basics: return "No basics yet."
        case .myFoods: return "No saved foods yet."
        }
    }

    private var filteredFoods: [Food] {
        let base: [Food] = {
            switch mode {
            case .all:
                return foods
            case .basics:
                return foods.filter { !$0.isUserCreated }
            case .myFoods:
                return foods.filter { $0.isUserCreated }
            }
        }()

        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { $0.name.lowercased().contains(q) }
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
