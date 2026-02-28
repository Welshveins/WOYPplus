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

    private var rawPosition01: Double {
        let denom = max(high - low, 0.000_001)
        return (value - low) / denom
    }

    private var position01: Double {
        min(max(rawPosition01, 0.0), 1.0)   // clamp at edges (no judgement)
    }

    private var isOutOfRange: Bool {
        value < low || value > high
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
                let h = geo.size.height

                // X positioning
                let xRaw = CGFloat(position01) * w
                let xClamped = max(0, min(xRaw - dotSize / 2, w - dotSize))

                // Keep the capsule sitting at the bottom of the available height
                let capsuleY = max(0, h - bandHeight)

                // Y positioning:
                // - if out of range, dot sits on the bottom edge of the pill
                // - otherwise dot sits centred on the pill
                let centerOnPillY = capsuleY + (bandHeight - dotSize) / 2
                let bottomOfPillY = capsuleY + (bandHeight - dotSize)

                let y = isOutOfRange ? bottomOfPillY : centerOnPillY
                let yClamped = max(0, min(y, h - dotSize))

                ZStack(alignment: .topLeading) {

                    // Soft band (opacity +0.2)
                    Capsule()
                        .fill(Color.woypSlate.opacity(0.50))
                        .frame(height: bandHeight)
                        .offset(y: capsuleY)

                    // Dot
                    Circle()
                        .fill(Color.primary.opacity(0.85))
                        .frame(width: dotSize, height: dotSize)
                        .offset(x: xClamped, y: yClamped)
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
    VStack(spacing: 16) {
        RangeBandView(
            title: "Carbs",
            unit: "g",
            value: 220,
            aim: 200,
            mode: .normal
        )

        RangeBandView(
            title: "Carbs",
            unit: "g",
            value: 40,   // below range (dot should sit on bottom edge)
            aim: 200,
            mode: .normal
        )

        RangeBandView(
            title: "Carbs",
            unit: "g",
            value: 500,  // above range (dot should sit on bottom edge)
            aim: 200,
            mode: .normal
        )
    }
    .padding()
}
