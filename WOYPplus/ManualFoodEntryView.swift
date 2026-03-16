//
//  ManualFoodEntryView.swift
//  WOYPplus
//
//  Created by Chris Davies on 16/03/2026.
//

import SwiftUI
import SwiftData

struct ManualFoodEntryView: View {

    @Environment(\.modelContext) private var ctx

    let prefillBarcode: String?
    let onSaved: (Food) -> Void
    let onClose: () -> Void

    @State private var name = ""
    @State private var barcode = ""

    @State private var kcalPer100g = ""
    @State private var carbsPer100g = ""
    @State private var proteinPer100g = ""
    @State private var fatPer100g = ""
    @State private var fibrePer100g = ""

    @State private var portionName = ""
    @State private var portionGrams = ""

    var body: some View {
        Form {

            if !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                Section {
                    Text(barcode)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)

                } header: {
                    Text("Barcode")

                } footer: {
                    Text("Barcode capture only (no lookup yet).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Food") {
                TextField("Name", text: $name)

                TextField("Barcode (optional)", text: $barcode)
                    .font(.footnote.monospaced())
            }

            Section("Macros per 100g") {
                numberField("kcal / 100g", text: $kcalPer100g)
                numberField("Carbs (g)", text: $carbsPer100g)
                numberField("Protein (g)", text: $proteinPer100g)
                numberField("Fat (g)", text: $fatPer100g)
                numberField("Fibre (g)", text: $fibrePer100g)
            }

            Section("Default portion (optional)") {
                TextField("Portion label (e.g. 1 egg)", text: $portionName)
                numberField("Portion grams (e.g. 60)", text: $portionGrams)
            }

            Button("Save food") {
                save()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("Manual food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onClose() }
            }
        }
        .onAppear {
            if let prefillBarcode, !prefillBarcode.isEmpty {
                barcode = prefillBarcode
            }
        }
    }

    private func numberField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .keyboardType(.decimalPad)
    }

    private func save() {
        let safeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty else { return }

        let food = Food(
            name: safeName,
            kcalPer100g: Double(kcalPer100g) ?? 0,
            carbsPer100g: Double(carbsPer100g) ?? 0,
            proteinPer100g: Double(proteinPer100g) ?? 0,
            fatPer100g: Double(fatPer100g) ?? 0,
            fibrePer100g: Double(fibrePer100g) ?? 0,
            defaultPortionName: portionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : portionName,
            defaultPortionGrams: Double(portionGrams)
        )

        ctx.insert(food)
        try? ctx.save()

        onSaved(food)
    }
}
