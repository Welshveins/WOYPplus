import SwiftUI
import SwiftData

struct ExtrasPresetEditView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @Bindable var preset: ExtrasPreset
    var onSaved: () -> Void

    @State private var kcal: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var fibre: String = ""

    var body: some View {
        NavigationStack {
            Form {

                Section {
                    Text("\(preset.name) – \(preset.variant)")
                        .font(.headline)
                }

                Section("Nutrition (set once)") {
                    numberField("kcal", text: $kcal)
                    numberField("Carbs (g)", text: $carbs)
                    numberField("Protein (g)", text: $protein)
                    numberField("Fat (g)", text: $fat)
                    numberField("Fibre (g)", text: $fibre)
                }

                Section {
                    Text("Once saved, this size becomes one-tap to log.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Set values")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        kcal = asText(preset.caloriesKcal)
        carbs = asText(preset.carbsG)
        protein = asText(preset.proteinG)
        fat = asText(preset.fatG)
        fibre = asText(preset.fibreG)
    }

    private func save() {
        preset.caloriesKcal = Double(kcal.replacingOccurrences(of: ",", with: ".")) ?? 0
        preset.carbsG = Double(carbs.replacingOccurrences(of: ",", with: ".")) ?? 0
        preset.proteinG = Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0
        preset.fatG = Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0
        preset.fibreG = Double(fibre.replacingOccurrences(of: ",", with: ".")) ?? 0
        preset.updatedAt = Date()

        try? ctx.save()
        onSaved()
        dismiss()
    }

    @ViewBuilder
    private func numberField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .keyboardType(.decimalPad)
    }

    private func asText(_ v: Double) -> String {
        let i = Int(v.rounded())
        return i == 0 ? "" : "\(i)"
    }
}
