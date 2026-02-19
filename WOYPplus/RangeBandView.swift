import SwiftUI

struct RangeBandView: View {

    let title: String               // e.g. "kcal", "Carbs"
    let unit: String                // e.g. "", "g"
    let value: Double               // today’s value
    let aim: Double                 // user aim
    let mode: RangeMode             // normal / holiday / illness

    // visual style (calm)
    var bandHeight: CGFloat = 14
    var dotSize: CGFloat = 10

    private var margin: Double { mode.marginFraction }

    private var low: Double { aim * (1.0 - margin) }
    private var high: Double { aim * (1.0 + margin) }

    private var position01: Double {
        let denom = max(high - low, 0.000_001)
        let raw = (value - low) / denom
        return min(max(raw, 0.0), 1.0)   // clamp at edges (no judgement)
    }

    private func format(_ x: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: x)) ?? "\(Int(x))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                // subtle mode text (neutral)
                Text(mode.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let w = geo.size.width
                let x = CGFloat(position01) * w

                ZStack(alignment: .leading) {

                    // Soft band
                    Capsule()
                        .fill(Color.woypSlate.opacity(0.14))
                        .frame(height: bandHeight)

                    // Dot
                    Circle()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: dotSize, height: dotSize)
                        .offset(x: max(0, min(x - dotSize/2, w - dotSize)))
                }
            }
            .frame(height: max(bandHeight, dotSize))

            // end labels (subtle, no judgement)
            HStack {
                Text("\(format(low))\(unit)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(format(value))\(unit)")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()

                Spacer()

                Text("\(format(high))\(unit)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.woypSlate.opacity(0.06))
        )
    }
}

#Preview {
    RangeBandView(
        title: "Carbs",
        unit: "g",
        value: 220,
        aim: 200,
        mode: .normal
    )
    .padding()
}
