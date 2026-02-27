import SwiftUI

struct BarcodeIngredientPickerView: View {

    @Environment(\.dismiss) private var dismiss

    /// Return a FoodPickResult back to RecipeBuilder (so it can become a DraftIngredient)
    let onPick: (FoodPickResult) -> Void

    @State private var scannedCode: String?
    @State private var product: OFFProduct?
    @State private var error: String?
    @State private var isLoading: Bool = false

    var body: some View {
        Group {
            if let product {
                BarcodeAmountAndPickView(product: product) { pick in
                    onPick(pick)
                    dismiss()
                }
            } else {
                BarcodeScannerView { code in
                    scannedCode = code
                    lookup(code)
                } onError: { msg in
                    error = msg
                }
                .overlay(alignment: .top) { headerOverlay }
                .ignoresSafeArea()
            }
        }
    }

    private var headerOverlay: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Scan barcode")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button("Close") { dismiss() }
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.top, 14)

            if isLoading {
                Text("Looking up…")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal)
            }

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    private func lookup(_ code: String) {
        Task {
            isLoading = true
            error = nil
            defer { isLoading = false }

            do {
                if let p = try await OpenFoodFactsAPI.fetchByBarcode(code) {
                    if let n = p.nutriments, n.hasUsableCore {
                        product = p
                    } else {
                        error = "No usable nutrition data found."
                    }
                } else {
                    error = "No product found."
                }
            } catch let e {
                error = e.localizedDescription
            }
        }
    }
}

private struct BarcodeAmountAndPickView: View {

    let product: OFFProduct
    let onPick: (FoodPickResult) -> Void

    @State private var gramsText: String = "100"

    var body: some View {
        let n = product.nutriments

        Form {
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

            Section("Amount") {
                TextField("g / ml", text: $gramsText)
                    .keyboardType(.decimalPad)

                Text("Assumes 1 ml = 1 g")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Per 100 g") {
                row("kcal", n?.energyKcal_100g)
                row("Carbs (g)", n?.carbohydrates_100g)
                row("Protein (g)", n?.proteins_100g)
                row("Fat (g)", n?.fat_100g)
                row("Fibre (g)", n?.fiber_100g)
            }
        }
        .navigationTitle("Add ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { pick() }
                    .disabled(!(n?.hasUsableCore ?? false))
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

    private func pick() {
        guard let n = product.nutriments, n.hasUsableCore else { return }

        let grams = Double(gramsText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let g = max(0, grams)
        guard g > 0 else { return }

        let kcal = (n.energyKcal_100g ?? 0) * g / 100.0
        let carbs = (n.carbohydrates_100g ?? 0) * g / 100.0
        let protein = (n.proteins_100g ?? 0) * g / 100.0
        let fat = (n.fat_100g ?? 0) * g / 100.0
        let fibre = (n.fiber_100g ?? 0) * g / 100.0

        let pick = FoodPickResult(
            foodName: product.displayName,
            grams: g,
            portionLabel: "Barcode",
            kcal: kcal,
            carbsG: carbs,
            proteinG: protein,
            fatG: fat,
            fibreG: fibre
        )

        onPick(pick)
    }
}
