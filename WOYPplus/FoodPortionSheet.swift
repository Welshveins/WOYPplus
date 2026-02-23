import SwiftUI
import SwiftData

struct FoodPortionSheet: View {

    @Environment(\.dismiss) private var dismiss

    let food: Food
    let initialGrams: Double
    let onConfirm: (Double) -> Void

    @State private var grams: Double = 100

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(food.name)
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(2)

                    if let portionName = food.defaultPortionName,
                       let portionGrams = food.defaultPortionGrams,
                       portionGrams > 0 {
                        Text("Default: \(portionName) • \(Int(portionGrams.rounded())) g")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                // Slider card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Amount")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(grams.rounded())) g")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $grams, in: sliderRange, step: sliderStep)

                    HStack {
                        Text("\(Int(sliderRange.lowerBound)) g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(sliderRange.upperBound)) g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let portionName = food.defaultPortionName,
                       let portionGrams = food.defaultPortionGrams,
                       portionGrams > 0 {
                        Button {
                            grams = portionGrams
                        } label: {
                            HStack {
                                Image(systemName: "arrow.uturn.left")
                                Text("Use default portion")
                                Spacer()
                                Text("\(portionName)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.woypSlate.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

                // Macro preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("This ingredient")
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
            .navigationTitle("Add ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onConfirm(max(0, grams))
                        dismiss()
                    }
                    .disabled(grams <= 0)
                }
            }
        }
        .onAppear {
            let start = initialGrams > 0 ? initialGrams : (food.defaultPortionGrams ?? 100)
            grams = clamp(start, sliderRange.lowerBound, sliderRange.upperBound)
        }
    }

    // MARK: - Slider tuning

    private var sliderRange: ClosedRange<Double> {
        // Keep it practical + “fast”
        // (You can widen later if needed.)
        0...600
    }

    private var sliderStep: Double {
        // Nice feel: coarse enough to move quickly, fine enough to be useful.
        5
    }

    // MARK: - Preview

    private var previewLine: String {
        let g = max(0, grams)
        let kcal = food.kcalPer100g * g / 100.0
        let c = food.carbsPer100g * g / 100.0
        let p = food.proteinPer100g * g / 100.0
        let f = food.fatPer100g * g / 100.0
        let fi = food.fibrePer100g * g / 100.0

        return "\(Int(kcal.rounded())) kcal • C \(Int(c.rounded()))g • P \(Int(p.rounded()))g • F \(Int(f.rounded()))g • Fibre \(Int(fi.rounded()))g"
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}
