import SwiftUI

struct MacroEstimateBlock: View {

    let estimate: Macros

    var body: some View {
        VStack(spacing: 12) {

            HStack(spacing: 16) {
                macroItem(title: "Carbs", value: estimate.c, color: .woypSand)
                macroItem(title: "Protein", value: estimate.p, color: .woypTeal)
                macroItem(title: "Fat", value: estimate.f, color: .woypTerracotta)
            }

            HStack {
                Text("Estimated calories")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(estimate.k.rounded())) kcal")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.woypSlate.opacity(0.06))
        )
    }

    private func macroItem(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("\(Int(value.rounded()))g")
                .font(.headline.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}
