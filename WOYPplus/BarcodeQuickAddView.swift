import SwiftUI
import SwiftData

struct BarcodeQuickAddView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let day: Day
    let mealSlot: MealSlot

    @State private var scannedCode: String?
    @State private var product: OFFProduct?
    @State private var error: String?
    @State private var isLoading: Bool = false

    var body: some View {
        Group {
            if let product {
                BarcodeAmountAndLogView(
                    day: day,
                    product: product
                )
            } else {
                BarcodeScannerView { code in
                    scannedCode = code
                    lookup(code)
                } onError: { msg in
                    error = msg
                }
                .overlay(alignment: .top) {
                    headerOverlay
                }
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

private struct BarcodeAmountAndLogView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let day: Day
    let product: OFFProduct

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
        .navigationTitle("Quick add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Log") { log() }
                    .disabled(!(n?.hasUsableCore ?? false))
            }
        }
    }

    private func row(_ label: String, _ v: Double?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(v.map { format($0) } ?? "—")
                .foregroundStyle(.secondary)
        }
    }

    private func format(_ x: Double) -> String {
        "\(Int(x.rounded()))"
    }

    private func log() {
        guard let n = product.nutriments, n.hasUsableCore else { return }

        let grams = Double(gramsText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let g = max(0, grams)
        let factor = g / 100.0

        let kcal = (n.energyKcal_100g ?? 0) * factor
        let carbs = (n.carbohydrates_100g ?? 0) * factor
        let protein = (n.proteins_100g ?? 0) * factor
        let fat = (n.fat_100g ?? 0) * factor
        let fibre = (n.fiber_100g ?? 0) * factor

        let slot = MealSlot.slot(for: Date())

        let entry = Entry(
            title: product.displayName,
            mealSlot: slot,
            carbsG: carbs,
            proteinG: protein,
            fatG: fat,
            fibreG: fibre,
            caloriesKcal: kcal,
            isEstimate: false,
            day: day
        )

        ctx.insert(entry)
        try? ctx.save()
        dismiss()
    }
}
