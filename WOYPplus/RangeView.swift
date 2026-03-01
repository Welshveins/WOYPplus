import SwiftUI
import SwiftData

struct RangeView: View {
    @Environment(\.colorScheme) private var colorScheme    // MARK: - Range Mode

    enum RangeMode: String, CaseIterable {
        case normal = "Normal"
        case holiday = "Holiday"
        case illness = "Illness"

        var margin: Double {
            switch self {
            case .normal: return 0.10
            case .holiday: return 0.20
            case .illness: return 0.20
            }
        }
    }

    // MARK: - Metric

    enum Metric: String, CaseIterable, Identifiable {
        case kcal = "kcal"
        case carbs = "Carbs"
        case protein = "Protein"
        case fat = "Fat"
        case fibre = "Fibre"

        var id: String { rawValue }

        var unit: String {
            switch self {
            case .kcal: return ""
            case .carbs, .protein, .fat, .fibre: return "g"
            }
        }

        var dotColor: Color {
            // Uses your existing palette if present; otherwise falls back safely
            switch self {
            case .kcal: return Color.secondary.opacity(0.65)
            case .carbs: return Color.woypSand
            case .protein: return Color.woypTeal
            case .fat: return Color.woypTerracotta
            case .fibre: return Color.secondary.opacity(0.75)
            }
        }

        var bandColor: Color {
            // Calm neutral band that works in light/dark
            Color.secondary.opacity(0.16)
        }

        var aimKey: String {
            "woyp.range.aim.\(id)"
        }
    }

    // MARK: - Data

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    // MARK: - UI State

    @State private var mode: RangeMode = .normal
    @State private var showingEdit = false

    // MARK: - Constants (your chosen defaults)

    private let bandHeight: CGFloat = 28

    var body: some View {

        ScrollView(showsIndicators: false) {

            VStack(alignment: .leading, spacing: 16) {

                header

                HStack {
                    Spacer()
                    Button {
                        showingEdit = true
                    } label: {
                        Text("Edit")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.woypSlate.opacity(0.25))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)

                Picker("", selection: $mode) {
                    ForEach(RangeMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 2)

                VStack(spacing: 14) {
                    rangeCard(for: .kcal)
                    rangeCard(for: .carbs)
                    rangeCard(for: .protein)
                    rangeCard(for: .fat)
                    rangeCard(for: .fibre)
                }
                .padding(.top, 6)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Range")
                    .font(.headline)
            }
        }
        .sheet(isPresented: $showingEdit) {
            RangeEditSheet(mode: $mode)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Range guide")
                .font(.system(size: 38, weight: .semibold))
                .tracking(-0.6)

            Text("A calm visual band around the aims you set. Nothing more.")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }

    // MARK: - Cards

    private func rangeCard(for metric: Metric) -> some View {

        let aim = RangeAimStore.value(forKey: metric.aimKey)
        let range = makeRange(aim: aim, margin: mode.margin)

        let points = recentDailyTotals(metric: metric, limit: 7)
        let values = points.map { $0.value }

        return VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text(metric.rawValue)
                    .font(.title3.bold())

                Spacer()

                Text(mode.rawValue)
                    .foregroundStyle(.secondary)
            }

            RangeBand(
                bandHeight: bandHeight,
                bandColor: metric.bandColor,
                range: range,
                values: values,
                dotColor: metric.dotColor
            )
            .frame(height: 92) // space above/below so distance is visible

            // Keep it simple: just show Aim (no low/high numbers)
            HStack {
                Text(metric.unit.isEmpty ? "Aim" : "Aim")
                    .foregroundStyle(.secondary)

                Spacer()

                if let aim {
                    Text(aimText(aim, unit: metric.unit, isKcal: metric == .kcal))
                        .font(.headline)
                } else {
                    Text("Set an aim in Edit")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.woypSlate.opacity(0.15))
        )
    }

    // MARK: - Calculations

    private func makeRange(aim: Double?, margin: Double) -> (low: Double, high: Double)? {
        guard let aim, aim > 0 else { return nil }
        let low = aim * (1.0 - margin)
        let high = aim * (1.0 + margin)
        return (low, high)
    }

    private func aimText(_ v: Double, unit: String, isKcal: Bool) -> String {
        if isKcal {
            return "\(Int(v.rounded()))"
        } else {
            return "\(Int(v.rounded()))\(unit)"
        }
    }

    /// Returns up to `limit` most recent days that have any entries, with totals for that metric.
    private func recentDailyTotals(metric: Metric, limit: Int) -> [(date: Date, value: Double)] {

        // Group entries by dayStart
        var byDay: [Date: [Entry]] = [:]
        for e in entries {
            guard let d = e.day else { continue }
            let start = Day.startOfDay(for: d.date)
            byDay[start, default: []].append(e)
        }

        // Sort dayStart descending
        let dayStarts = byDay.keys.sorted(by: >)

        var result: [(date: Date, value: Double)] = []
        for start in dayStarts {
            guard let es = byDay[start] else { continue }

            let total: Double
            switch metric {
            case .kcal:
                total = es.reduce(0) { $0 + $1.caloriesKcal }
            case .carbs:
                total = es.reduce(0) { $0 + $1.carbsG }
            case .protein:
                total = es.reduce(0) { $0 + $1.proteinG }
            case .fat:
                total = es.reduce(0) { $0 + $1.fatG }
            case .fibre:
                total = es.reduce(0) { $0 + $1.fibreG }
            }

            result.append((start, total))
            if result.count >= limit { break }
        }

        // Display left-to-right oldest -> newest
        return result.sorted(by: { $0.date < $1.date })
    }
}

// MARK: - RangeBand (self-contained, no ViewBuilder issues)

private struct RangeBand: View {

    let bandHeight: CGFloat
    let bandColor: Color
    let range: (low: Double, high: Double)?
    let values: [Double]
    let dotColor: Color

    var body: some View {

        GeometryReader { geo in

            let w = geo.size.width
            let h = geo.size.height

            // Determine vertical scale
            let minV: Double = {
                if let r = range {
                    let pad = max((r.high - r.low) * 0.6, 1)
                    return max(0, r.low - pad)
                } else {
                    let vMin = values.min() ?? 0
                    return max(0, vMin * 0.7)
                }
            }()

            let maxV: Double = {
                if let r = range {
                    let pad = max((r.high - r.low) * 0.6, 1)
                    return r.high + pad
                } else {
                    let vMax = values.max() ?? 1
                    return max(vMax * 1.3, 1)
                }
            }()

            ZStack {

                // Band
                if let r = range {

                    let yLow = positionY(value: r.low, minV: minV, maxV: maxV, height: h)
                    let yHigh = positionY(value: r.high, minV: minV, maxV: maxV, height: h)
                    let bandY = (yLow + yHigh) / 2

                    RoundedRectangle(cornerRadius: bandHeight / 2)
                        .fill(bandColor)
                        .frame(width: w, height: bandHeight)
                        .position(x: w / 2, y: bandY)

                } else {

                    RoundedRectangle(cornerRadius: bandHeight / 2)
                        .fill(bandColor.opacity(0.6))
                        .frame(width: w, height: bandHeight)
                        .position(x: w / 2, y: h / 2)
                }

                // Dots (only actual values; no ghost dots)
                ForEach(Array(values.enumerated()), id: \.offset) { idx, v in
                    Circle()
                        .fill(dotColor)
                        .frame(width: 12, height: 12)
                        .position(
                            x: xPosition(index: idx, count: values.count, width: w),
                            y: max(6, min(positionY(value: v, minV: minV, maxV: maxV, height: h), h - 6))
                            )
                }
            }
        }
    }

    private func positionY(value: Double, minV: Double, maxV: Double, height: CGFloat) -> CGFloat {
        let t = (value - minV) / max((maxV - minV), 0.0001)
        return (1 - CGFloat(t)) * (height - 1)
    }

    private func xPosition(index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        let leftPad: CGFloat = 6
        let rightPad: CGFloat = 6
        let usable = max(width - leftPad - rightPad, 1)
        let t = CGFloat(index) / CGFloat(count - 1)
        return leftPad + t * usable
    }
}

// MARK: - Edit Sheet (aim persistence)

private struct RangeEditSheet: View {

    @Binding var mode: RangeView.RangeMode
    @Environment(\.dismiss) private var dismiss

    @State private var kcal = RangeAimStore.value(forKey: RangeView.Metric.kcal.aimKey)
    @State private var carbs = RangeAimStore.value(forKey: RangeView.Metric.carbs.aimKey)
    @State private var protein = RangeAimStore.value(forKey: RangeView.Metric.protein.aimKey)
    @State private var fat = RangeAimStore.value(forKey: RangeView.Metric.fat.aimKey)
    @State private var fibre = RangeAimStore.value(forKey: RangeView.Metric.fibre.aimKey)

    var body: some View {

        NavigationStack {
            Form {

                Section("Aims") {
                    aimField("kcal", value: $kcal)
                    aimField("Carbs (g)", value: $carbs)
                    aimField("Protein (g)", value: $protein)
                    aimField("Fat (g)", value: $fat)
                    aimField("Fibre (g)", value: $fibre)
                }

                Section("Range mode") {
                    Picker("", selection: $mode) {
                        ForEach(RangeView.RangeMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Text("You set a single aim. WOYP shows a soft band around it (Normal ±10%, Holiday/Illness ±20%).")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit aims")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        RangeAimStore.set(kcal, forKey: RangeView.Metric.kcal.aimKey)
                        RangeAimStore.set(carbs, forKey: RangeView.Metric.carbs.aimKey)
                        RangeAimStore.set(protein, forKey: RangeView.Metric.protein.aimKey)
                        RangeAimStore.set(fat, forKey: RangeView.Metric.fat.aimKey)
                        RangeAimStore.set(fibre, forKey: RangeView.Metric.fibre.aimKey)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func aimField(_ title: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Aim", text: Binding(
                get: {
                    guard let v = value.wrappedValue else { return "" }
                    let i = Int(v.rounded())
                    return i == 0 ? "" : "\(i)"
                },
                set: { newText in
                    let cleaned = newText.replacingOccurrences(of: ",", with: "")
                    if let d = Double(cleaned), d > 0 {
                        value.wrappedValue = d
                    } else {
                        value.wrappedValue = nil
                    }
                }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 110)
        }
    }
}

// MARK: - Tiny persistence helper

private enum RangeAimStore {
    static func value(forKey key: String) -> Double? {
        let v = UserDefaults.standard.double(forKey: key)
        return v == 0 ? nil : v
    }

    static func set(_ value: Double?, forKey key: String) {
        if let value, value > 0 {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
