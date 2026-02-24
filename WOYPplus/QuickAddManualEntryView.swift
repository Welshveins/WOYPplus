import SwiftUI
import SwiftData

struct QuickAddManualEntryView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let day: Day
    let mealSlot: MealSlot
    let useTimeBasedDefault: Bool

    @State private var title = ""
    @State private var kcal = ""
    @State private var carbs = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var fibre = ""

    var body: some View {

        Form {

            Section {
                TextField("Name", text: $title)
            }

            Section("Macros") {
                TextField("kcal", text: $kcal)
                    .keyboardType(.decimalPad)

                TextField("Carbs (g)", text: $carbs)
                    .keyboardType(.decimalPad)

                TextField("Protein (g)", text: $protein)
                    .keyboardType(.decimalPad)

                TextField("Fat (g)", text: $fat)
                    .keyboardType(.decimalPad)

                TextField("Fibre (g)", text: $fibre)
                    .keyboardType(.decimalPad)
            }

            Button("Log") {
                log()
            }
        }
        .navigationTitle("Quick add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func log() {

        let slotToUse = useTimeBasedDefault ? MealSlot.slot(for: Date()) : mealSlot

        let entry = Entry(
            title: title.isEmpty ? "Quick add" : title,
            mealSlot: slotToUse,
            carbsG: Double(carbs) ?? 0,
            proteinG: Double(protein) ?? 0,
            fatG: Double(fat) ?? 0,
            fibreG: Double(fibre) ?? 0,
            caloriesKcal: Double(kcal) ?? 0,
            isEstimate: false,
            day: day
        )

        ctx.insert(entry)
        try? ctx.save()

        dismiss()
    }
}
