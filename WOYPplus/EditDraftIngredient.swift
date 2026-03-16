import SwiftUI

struct EditDraftIngredientSheet: View {

    @State private var working: DraftIngredient

    let onSave: (DraftIngredient) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    init(
        ingredient: DraftIngredient,
        onSave: @escaping (DraftIngredient) -> Void,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._working = State(initialValue: ingredient)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
    }

    var body: some View {
        Form {
            Section("Ingredient") {
                Text(working.name)
                    .font(.headline)
                Text("\(Int(working.kcalPer100g.rounded())) kcal per 100g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Amount") {
                TextField(
                    "Grams",
                    value: $working.amountGrams,
                    format: .number.precision(.fractionLength(0...1))
                )
                .keyboardType(.decimalPad)

                Stepper(value: $working.amountGrams, in: 1...5000, step: 5) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("\(Int(working.amountGrams.rounded())) g")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            Section {
                Button("Save changes") {
                    working.amountGrams = max(1, working.amountGrams)
                    onSave(working)
                }

                Button("Delete ingredient", role: .destructive) {
                    onDelete()
                }
            }
        }
        .navigationTitle("Edit ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onClose() }
            }
        }
    }
}
