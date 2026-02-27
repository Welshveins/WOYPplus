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

                header

                quickPortionCard

                sliderCard

                macroPreview

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

    // MARK: - Header

    private var header: some View {
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
            } else {
                Text("Choose an amount")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Quick portions

    private var quickPortionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick portions")
                .font(.headline)

            if hasDefaultPortion {
                defaultPortionChips
            } else {
                gramChips
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
    }

    private var defaultPortionChips: some View {
        let base = food.defaultPortionGrams ?? 100
        let label = food.defaultPortionName ?? "Default"

        return VStack(alignment: .leading, spacing: 10) {

            // Row 1: 1/2, 1x, 2x
            HStack(spacing: 10) {
                chip("½") { grams = base * 0.5 }
                chip("1×") { grams = base }
                chip("2×") { grams = base * 2.0 }
            }

            // Row 2: show what “1×” means in plain language
            HStack(spacing: 8) {
                Text("1× = \(label)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(base.rounded())) g")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var gramChips: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                chip("50g")  { grams = 50 }
                chip("100g") { grams = 100 }
                chip("150g") { grams = 150 }
                chip("200g") { grams = 200 }
            }
            Text("Tip: use the slider for fine adjustment.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            // Keep within slider limits
            grams = clamp(grams, sliderRange.lowerBound, sliderRange.upperBound)
        }) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.woypSlate.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var hasDefaultPortion: Bool {
        if let g = food.defaultPortionGrams, g > 0 { return true }
        return false
    }

    // MARK: - Slider (fine adjustment)

    private var sliderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Amount")
                    .font(.headline)
                Spacer()
                Text("\(Int(grams.rounded())) g")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
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
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.woypSlate.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var sliderRange: ClosedRange<Double> {
        0...600
    }

    private var sliderStep: Double {
        5
    }

    // MARK: - Preview

    private var macroPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This ingredient")
                .font(.headline)

            Text(previewLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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
