import SwiftUI

struct RangeHistoryBandView: View {

    struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    let title: String
    let unit: String
    let color: Color
    let points: [Point]   // oldest -> newest
    let aim: Double
    let mode: RangeMode

    private let plotHeight: CGFloat = 78
    private let bandHeight: CGFloat = 28
    private let dotSize: CGFloat = 10
    private let todayDotSize: CGFloat = 12

    @Environment(\.colorScheme) private var scheme

    private var margin: Double { mode.marginFraction }
    private var low: Double { aim * (1.0 - margin) }
    private var high: Double { aim * (1.0 + margin) }

    private func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }

    private func y01(for value: Double) -> Double {
        let denom = max(high - low, 0.000_001)
        return clamp01((value - low) / denom)
    }

    private func format(_ x: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: x)) ?? "\(Int(x))"
    }

    private var bandFill: Color {
        scheme == .dark
        ? Color.woypSlate.opacity(0.26)
        : Color.woypSlate.opacity(0.14)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

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
                let h = geo.size.height

                let bandTop = (h - bandHeight) / 2
                let bandBottom = bandTop + bandHeight

                ZStack {

                    RoundedRectangle(cornerRadius: 18)
                        .fill(bandFill)
                        .frame(height: bandHeight)
                        .position(x: w/2, y: h/2)

                    if points.count == 1 {
                        dot(atX: w * 0.5,
                            plotH: h,
                            bandTop: bandTop,
                            bandBottom: bandBottom,
                            value: points[0].value,
                            isToday: true)
                    } else if points.count > 1 {
                        ForEach(Array(points.enumerated()), id: \.element.id) { idx, p in
                            let x = CGFloat(Double(idx) / Double(points.count - 1)) * w
                            let isToday = (idx == points.count - 1)

                            dot(atX: x,
                                plotH: h,
                                bandTop: bandTop,
                                bandBottom: bandBottom,
                                value: p.value,
                                isToday: isToday)
                        }
                    }
                }
            }
            .frame(height: plotHeight)

            // Simple bottom line: latest value + aim only
            if let latest = points.last?.value {
                HStack {
                    Text("\(format(latest))\(unit)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Aim \(format(aim))\(unit)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.woypSlate.opacity(0.06))
        )
    }

    @ViewBuilder
    private func dot(
        atX x: CGFloat,
        plotH h: CGFloat,
        bandTop: CGFloat,
        bandBottom: CGFloat,
        value: Double,
        isToday: Bool
    ) -> some View {

        let position = y01(for: value)
        let y = bandBottom - CGFloat(position) * bandHeight
        let size = isToday ? todayDotSize : dotSize

        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(isToday ? 0.18 : 0.10), lineWidth: 1)
            )
            .position(
                x: x,
                y: min(max(y, bandTop + size/2), bandBottom - size/2)
            )
    }
}
