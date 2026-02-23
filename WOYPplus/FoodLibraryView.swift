import SwiftUI
import SwiftData

/// Browse + search Foods, then pick one with a portion (grams or default portion).
/// Reusable: you pass in `onPick`, and it returns the chosen grams and computed macros.
struct FoodLibraryView: View {

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Food.name, order: .forward)
    private var foods: [Food]

    @State private var queryText = ""
    @State private var selectedFood: Food?

    let onPick: (FoodPickResult) -> Void

    private var filtered: [Food] {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return foods }
        return foods.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {

        NavigationStack {
            List {

                Section {
                    TextField("Search foods", text: $queryText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if foods.isEmpty {
                    Section {
                        Text("No foods yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {

                    Section("Foods") {
                        ForEach(filtered) { f in
                            Button {
                                selectedFood = f
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(f.name)
                                            .font(.headline)

                                        Text(summaryLine(for: f))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
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
            .sheet(item: $selectedFood) { f in
                FoodPortionSheet(food: f) { pick in
                    onPick(pick)
                    dismiss()
                }
            }
        }
    }

    private func summaryLine(for f: Food) -> String {
        // Keep it simple and calm
        // Shows per 100g so it matches your /100g mental model
        let kcal = Int(f.kcalPer100g.rounded())
        let c = Int(f.carbsPer100g.rounded())
        let p = Int(f.proteinPer100g.rounded())
        let fat = Int(f.fatPer100g.rounded())
        return "\(kcal) kcal /100g • C \(c) • P \(p) • F \(fat)"
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
