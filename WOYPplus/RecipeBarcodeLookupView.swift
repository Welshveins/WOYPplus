//
//  RecipeBarcodeLookupView.swift
//  WOYPplus
//
//  Created by Chris Davies on 16/03/2026.
//

import SwiftUI
import SwiftData

struct RecipeBarcodeLookupView: View {

    @Environment(\.modelContext) private var ctx

    let onPickedFood: (Food) -> Void
    let onCancel: () -> Void

    @State private var last = ""
    @State private var scannedCode: String?
    @State private var product: OFFProduct?
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let product {
                foundProductView(product)
            } else {
                ZStack {
                    BarcodeScannerRepresentable(
                        onFound: { code in
                            guard !code.isEmpty else { return }
                            guard code != last else { return }
                            last = code
                            scannedCode = code
                            lookup(code)
                        },
                        onError: { err in
                            errorText = err.localizedDescription
                        }
                    )
                    .ignoresSafeArea()

                    overlay
                }
                .navigationTitle("Scan barcode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { onCancel() }
                    }
                }
            }
        }
    }

    private var overlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 10) {
                Text("Scan a barcode")
                    .font(.headline)

                if isLoading {
                    Text("Looking up…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Hold the barcode in the frame.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Cancel") { onCancel() }
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.55))
            )
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
    }

    private func foundProductView(_ product: OFFProduct) -> some View {
        let n = product.nutriments

        return Form {
            Section("Product") {
                Text(product.displayName)
                if let b = product.brands, !b.isEmpty {
                    Text(b)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let c = product.code, !c.isEmpty {
                    Text("Barcode: \(c)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Per 100 g") {
                row("kcal", n?.energyKcal_100g)
                row("Carbs (g)", n?.carbohydrates_100g)
                row("Protein (g)", n?.proteins_100g)
                row("Fat (g)", n?.fat_100g)
                row("Fibre (g)", n?.fiber_100g)
            }

            Section {
                Button("Use as ingredient") {
                    createFood(from: product)
                }
                .disabled(!(n?.hasUsableCore ?? false))

                Button("Scan again") {
                    self.product = nil
                    self.scannedCode = nil
                    self.errorText = nil
                    self.isLoading = false
                    self.last = ""
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Barcode found")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onCancel() }
            }
        }
    }

    private func row(_ label: String, _ v: Double?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(v.map { "\(Int($0.rounded()))" } ?? "—")
                .foregroundStyle(.secondary)
        }
    }

    private func lookup(_ code: String) {
        Task {
            isLoading = true
            errorText = nil
            defer { isLoading = false }

            do {
                if let p = try await OpenFoodFactsAPI.fetchByBarcode(code) {
                    if let n = p.nutriments, n.hasUsableCore {
                        product = p
                    } else {
                        errorText = "No usable nutrition data found."
                    }
                } else {
                    errorText = "No product found."
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func createFood(from product: OFFProduct) {
        guard let n = product.nutriments, n.hasUsableCore else { return }

        let food = Food(
            name: product.displayName,
            kcalPer100g: n.energyKcal_100g ?? 0,
            carbsPer100g: n.carbohydrates_100g ?? 0,
            proteinPer100g: n.proteins_100g ?? 0,
            fatPer100g: n.fat_100g ?? 0,
            fibrePer100g: n.fiber_100g ?? 0,
            defaultPortionName: nil,
            defaultPortionGrams: nil
        )

        ctx.insert(food)
        try? ctx.save()

        onPickedFood(food)
    }
}
