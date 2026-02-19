import SwiftUI
import SwiftData

struct DrinkPortionSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let drink: DrinksSheet.DrinkItem
    let day: Day
    let mealSlot: MealSlot

    @State private var portion: Double = 1.0

    private let options: [Double] = [0.5, 1.0, 1.5]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                VStack(alignment: .leading, spacing: 6) {
                    Text(drink.name)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(2)

                    Text(mealSlot.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Portion")
                        .font(.headline)

                    HStack(spacing: 10) {
                        ForEach(options, id: \.self) { v in
                            Button {
                                portion = v
                            } label: {
                                Text(formatPortion(v))
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.woypSlate.opacity(portion == v ? 0.32 : 0.12))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(portion == v ? 0.18 : 0.10), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("This entry")
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
            .navigationTitle("Log drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private var previewLine: String {
        let kcal = drink.kcal * portion
        let c = drink.carbs * portion
        let p = drink.protein * portion
        let f = drink.fat * portion
        let fi = drink.fibre * portion

        return "\(Int(kcal.rounded())) kcal • C \(Int(c.rounded()))g • P \(Int(p.rounded()))g • F \(Int(f.rounded()))g • Fibre \(Int(fi.rounded()))g"
    }

    private func save() {

        let entry = Entry(
            title: portion == 1.0 ? drink.name : "\(drink.name) x\(formatPortion(portion))",
            mealSlot: mealSlot,
            carbsG: drink.carbs * portion,
            proteinG: drink.protein * portion,
            fatG: drink.fat * portion,
            fibreG: drink.fibre * portion,
            caloriesKcal: drink.kcal * portion,
            isEstimate: false,
            day: day
        )

        ctx.insert(entry)
        try? ctx.save()
        dismiss()
    }

    private func formatPortion(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(v))" }
        return String(v)
    }
}
