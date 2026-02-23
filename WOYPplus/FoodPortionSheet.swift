import SwiftUI

/// Choose grams OR default portion if the Food provides one.
struct FoodPortionSheet: View {

    @Environment(\.dismiss) private var dismiss

    let food: Food
    let onPick: (FoodPickResult) -> Void

    @State private var useDefaultPortion = false
    @State private var gramsText = "100"

    private var hasDefaultPortion: Bool {
        guard let g = food.defaultPortionGrams else { return false }
        return g > 0
    }

    private var chosenGrams: Double {
        if useDefaultPortion, let g = food.defaultPortionGrams, g > 0 {
            return g
        }
        return Double(gramsText) ?? 0
    }

    var body: some View {

        NavigationStack {
            VStack(spacing: 16) {

                VStack(alignment: .leading, spacing: 6) {
                    Text(food.name)
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(2)

                    Text("Choose portion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                if hasDefaultPortion {
                    Toggle(isOn: $useDefaultPortion) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use default portion")
                                .font(.headline)
                            Text(defaultPortionSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.woypTeal)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.woypSlate.opacity(0.06))
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Grams")
                        .font(.headline)

                    HStack(spacing: 10) {
                        TextField("e.g. 180", text: $gramsText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .disabled(useDefaultPortion && hasDefaultPortion)

                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    Text("Tip: /100g macros are your base. This just scales them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.woypSlate.opacity(0.06))
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("This portion")
                        .font(.headline)

                    Text(previewLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(chosenGrams <= 0)
                }
            }
        }
        .onAppear {
            // sensible defaults
            gramsText = hasDefaultPortion ? "\(Int(food.defaultPortionGrams ?? 100))" : "100"
            useDefaultPortion = hasDefaultPortion // start on default if it exists
        }
    }

    private var defaultPortionSubtitle: String {
        let name = (food.defaultPortionName ?? "Default portion")
        let g = Int((food.defaultPortionGrams ?? 0).rounded())
        return "\(name) • \(g)g"
    }

    private var previewLine: String {
        let g = chosenGrams
        let kcal = food.kcalPer100g * g / 100.0
        let c = food.carbsPer100g * g / 100.0
        let p = food.proteinPer100g * g / 100.0
        let f = food.fatPer100g * g / 100.0
        let fi = food.fibrePer100g * g / 100.0

        return "\(Int(kcal.rounded())) kcal • C \(Int(c.rounded()))g • P \(Int(p.rounded()))g • F \(Int(f.rounded()))g • Fibre \(Int(fi.rounded()))g"
    }

    private func add() {
        let g = chosenGrams

        let kcal = food.kcalPer100g * g / 100.0
        let c = food.carbsPer100g * g / 100.0
        let p = food.proteinPer100g * g / 100.0
        let f = food.fatPer100g * g / 100.0
        let fi = food.fibrePer100g * g / 100.0

        let label: String?
        if useDefaultPortion, let name = food.defaultPortionName, !name.isEmpty {
            label = name
        } else {
            label = "\(Int(g.rounded()))g"
        }

        onPick(
            FoodPickResult(
                foodName: food.name,
                grams: g,
                portionLabel: label,
                kcal: kcal,
                carbsG: c,
                proteinG: p,
                fatG: f,
                fibreG: fi
            )
        )
    }
}
