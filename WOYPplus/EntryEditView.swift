import SwiftUI
import SwiftData

struct EntryEditView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let day: Day
    let entry: Entry

    @State private var title: String = ""
    @State private var kcal: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var fibre: String = ""

    // Recipe-linked servings
    @State private var servings: Double = 1.0

    // Fractions you asked for
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

                // ✅ If this entry came from a recipe, show servings control
                if let recipe = entry.recipe {
                    Section("Servings") {
                        Picker("Servings", selection: $servings) {
                            ForEach(servingOptions, id: \.self) { v in
                                Text(formatServing(v)).tag(v)
                            }
                        }
                        .onChange(of: servings) { _, newValue in
                            // Recalculate from whole-recipe totals
                            applyRecipe(recipe, servings: newValue)
                        }

                        Text("Based on whole recipe totals.")
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

                if entry.isEstimate {
                    Section {
                        Text("This entry is marked as an estimate.")
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
            .onAppear {
                load()
            }
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

        // If linked, load servings (default 1)
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
        entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? entry.title : title

        entry.caloriesKcal = Double(kcal) ?? 0
        entry.carbsG = Double(carbs) ?? 0
        entry.proteinG = Double(protein) ?? 0
        entry.fatG = Double(fat) ?? 0
        entry.fibreG = Double(fibre) ?? 0

        // If recipe-linked, persist servings too
        if entry.recipe != nil {
            entry.servings = servings
        }

        try? ctx.save()
        dismiss()
    }

    private func applyRecipe(_ recipe: Recipe, servings: Double) {
        // This assumes Recipe macros are whole-recipe totals (your chosen architecture)
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
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(v))"
        }
        return String(v)
    }
}
