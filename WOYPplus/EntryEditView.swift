import SwiftUI
import SwiftData

struct EntryEditView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let day: Day
    let entry: Entry

    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]

    @State private var title: String = ""
    @State private var kcal: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var fibre: String = ""

    // Recipe-linked servings
    @State private var servings: Double = 1.0

    // Estimate state (editable)
    @State private var isEstimate: Bool = false

    private let servingOptions: [Double] = [
        0.25, 0.5, 0.75,
        1.0,
        1.25, 1.5, 1.75,
        2.0
    ]

    var body: some View {
        NavigationStack {
            Form {

                Section {
                    TextField("Title", text: $title)
                }

                // Estimate control
                Section {
                    Toggle("Estimate", isOn: $isEstimate)
                } footer: {
                    if isEstimate {
                        Text("This entry is marked as an estimate. You can confirm it later.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Marked as confirmed.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // Recipe-linked servings
                if let recipe = entry.recipe {
                    Section("Servings") {
                        Picker("Servings", selection: $servings) {
                            ForEach(servingOptions, id: \.self) { v in
                                Text(formatServing(v)).tag(v)
                            }
                        }
                        .onChange(of: servings) { _, newValue in
                            applyRecipe(recipe, servings: newValue)
                        }

                        Text("Based on recipe totals.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Nutrition") {
                    numberField("kcal", text: $kcal)
                    numberField("Carbs (g)", text: $carbs)
                    numberField("Protein (g)", text: $protein)
                    numberField("Fat (g)", text: $fat)
                    numberField("Fibre (g)", text: $fibre)
                }

                if entry.recipe != nil {
                    Section {
                        Text("If you edit macros manually, this entry will no longer match the recipe exactly.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { load() }
        }
    }

    private var canSave: Bool {
        let k = Double(kcal) ?? 0
        let c = Double(carbs) ?? 0
        let p = Double(protein) ?? 0
        let f = Double(fat) ?? 0
        return (k > 0) || (c + p + f > 0)
    }

    private func load() {
        title = entry.title
        kcal = format(entry.caloriesKcal)
        carbs = format(entry.carbsG)
        protein = format(entry.proteinG)
        fat = format(entry.fatG)
        fibre = format(entry.fibreG)

        isEstimate = entry.isEstimate

        if entry.recipe != nil {
            servings = entry.servings ?? 1.0
        }
    }

    @ViewBuilder
    private func numberField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .keyboardType(.decimalPad)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { entry.title = trimmed }

        entry.caloriesKcal = Double(kcal) ?? 0
        entry.carbsG = Double(carbs) ?? 0
        entry.proteinG = Double(protein) ?? 0
        entry.fatG = Double(fat) ?? 0
        entry.fibreG = Double(fibre) ?? 0

        entry.isEstimate = isEstimate

        if entry.recipe != nil {
            entry.servings = servings
        }

        try? ctx.save()
        refreshDayEstimateFlag()
        dismiss()
    }

    private func refreshDayEstimateFlag() {
        let sameDayEntries = allEntries.filter { e in
            guard let d = e.day else { return false }
            return Day.startOfDay(for: d.date) == Day.startOfDay(for: day.date)
        }
        day.hasEstimates = sameDayEntries.contains(where: { $0.isEstimate })
        try? ctx.save()
    }

    private func applyRecipe(_ recipe: Recipe, servings: Double) {
        kcal = format(recipe.caloriesKcal * servings)
        carbs = format(recipe.carbsG * servings)
        protein = format(recipe.proteinG * servings)
        fat = format(recipe.fatG * servings)
        fibre = format(recipe.fibreG * servings)
    }

    private func format(_ x: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: x)) ?? "\(Int(x.rounded()))"
    }

    private func formatServing(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(v))" }
        return String(v)
    }
}
