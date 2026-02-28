import SwiftUI

struct RangeBandView: View {

    let title: String
    let unit: String
    let value: Double
    let aim: Double
    let mode: RangeMode

    var bandHeight: CGFloat = 16
    var dotSize: CGFloat = 10

    @Environment(\.colorScheme) private var colorScheme

    private var margin: Double { mode.marginFraction }

    private var low: Double { aim * (1.0 - margin) }
    private var high: Double { aim * (1.0 + margin) }

    private var position01: Double {
        let denom = max(high - low, 0.000_001)
        let raw = (value - low) / denom
        return min(max(raw, 0.0), 1.0)
    }

    private func format(_ x: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: x)) ?? "\(Int(x))"
    }

    // MARK: - Refined day/night tuning

    private var bandOpacity: Double {
        // Darker in day, lighter in night
        colorScheme == .light ? 0.65 : 0.60
    }

    private var cardFill: Color {
        colorScheme == .light
        ? Color.black.opacity(0.06)
        : Color.woypSlate.opacity(0.07)
    }

    private var dotFill: Color {
        colorScheme == .light
        ? Color.primary.opacity(0.95)
        : Color.primary.opacity(0.9)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Text(mode.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let w = geo.size.width
                let x = CGFloat(position01) * w

                ZStack(alignment: .leading) {

                    Capsule()
                        .fill(Color.woypSlate.opacity(colorScheme == .dark ? 0.60 : 0.65))
                        .frame(height: bandHeight)

                    Circle()
                        .fill(dotFill)
                        .frame(width: dotSize, height: dotSize)
                        .offset(x: max(0, min(x - dotSize/2, w - dotSize)))
                }
            }
            .frame(height: max(bandHeight, dotSize))

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
                .fill(cardFill)
        )
    }
}
