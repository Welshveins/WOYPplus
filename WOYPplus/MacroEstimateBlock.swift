import SwiftUI

struct MacroEstimateBlock: View {
    let userLockedMacros: Bool
    let lastVisionIdentifier: String?
    @Binding var kcal: String
    @Binding var carbs: String
    @Binding var protein: String
    @Binding var fat: String
    @Binding var fibre: String
    let macroRefreshPulse: Bool
    let onReapply: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if userLockedMacros {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("Your edits are locked (Vision won’t overwrite).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            macroRow(title: "Calories", value: displayValue(kcal, suffix: "kcal"), accent: .woypTeal)
            macroRow(title: "Carbs", value: displayValue(carbs, suffix: "g"), accent: .woypSand)
            macroRow(title: "Protein", value: displayValue(protein, suffix: "g"), accent: .woypTeal)
            macroRow(title: "Fat", value: displayValue(fat, suffix: "g"), accent: .orange)
            macroRow(title: "Fibre", value: displayValue(fibre, suffix: "g"), accent: .secondary)

            if lastVisionIdentifier != nil {
                Button(action: onReapply) {
                    Label("Re-apply estimate", systemImage: "wand.and.stars")
                }
            }
        }
        .opacity(macroRefreshPulse ? 0.72 : 1.0)
        .scaleEffect(macroRefreshPulse ? 0.992 : 1.0)
        .animation(.easeInOut(duration: 0.16), value: macroRefreshPulse)
    }

    private func macroRow(title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(accent.opacity(0.12))
                )
        }
    }

    private func displayValue(_ raw: String, suffix: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "0 \(suffix)" }
        return "\(trimmed) \(suffix)"
    }
}
