import SwiftUI
import SwiftData

struct TrendView: View {

    enum Mode: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
    }

    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    @State private var mode: Mode = .daily
    @State private var showAsPercent = true

    var body: some View {

        ScrollView(showsIndicators: false) {

            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Macro rings")
                        .font(.system(size: 34, weight: .semibold))
                        .tracking(-0.4)

                    Text("Outer rings are more recent. Based on recorded days only.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)

                Picker("", selection: $mode) {
                    Text(Mode.daily.rawValue).tag(Mode.daily)
                    Text(Mode.weekly.rawValue).tag(Mode.weekly)
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
                .onChange(of: mode) { _, _ in
                    NotificationCenter.default.post(name: .trendRingsRestart, object: nil)
                }

                HStack {
                    Spacer()
                    Button {
                        showAsPercent.toggle()
                        NotificationCenter.default.post(name: .trendRingsRestart, object: nil)
                    } label: {
                        Text(showAsPercent ? "Show as g" : "Show as %")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.woypSlate.opacity(0.40))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, 2)

                ringCard
                    .padding(.top, 6)

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Color.woypSlate.opacity(0.15).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.woypSlate.opacity(0.15), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Trend")
                    .font(.headline)
            }
        }
    }

    private var ringCard: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width
            let ringSize = min(cardWidth - 44, 360)

            VStack(spacing: 2) {

                ConcentricTrendRings(
                    mode: mode,
                    showAsPercent: showAsPercent,
                    entries: entries
                )
                .frame(width: ringSize, height: ringSize)
                .padding(.top, 1)

                HStack(spacing: 18) {
                    legendDot(color: .woypTeal, text: "P")
                    legendDot(color: .woypSand, text: "C")
                    legendDot(color: .woypTerracotta, text: "F")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 16)
                .padding(.bottom, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.woypSlate.opacity(0.05))
            )
        }
        .frame(height: 470)
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }
}

private struct ConcentricTrendRings: View {

    let mode: TrendView.Mode
    let showAsPercent: Bool
    let entries: [Entry]

    private let ringsCountDaily = 14
    private let ringsCountWeekly = 12

    private let lineWidth: CGFloat = 10
    private let gapBetweenRings: CGFloat = 8
    private let segmentGap: Double = 0.0

    @State private var animateRings = false

    var body: some View {
        GeometryReader { geo in
            let baseSize = min(geo.size.width, geo.size.height)

            let series: [(carbs: Double, protein: Double, fat: Double)] =
                (mode == .daily)
                ? daySeries(limit: ringsCountDaily)
                : weekSeries(limit: ringsCountWeekly)

            ZStack {

                ForEach(series.indices, id: \.self) { idx in
                    let t = series[idx]

                    let inset = CGFloat(idx) * (lineWidth + gapBetweenRings)
                    let size = max(44, baseSize - inset)

                    let (c, p, f) = showAsPercent
                        ? fractionsByCalories(carbsG: t.carbs, proteinG: t.protein, fatG: t.fat)
                        : fractionsByGrams(carbsG: t.carbs, proteinG: t.protein, fatG: t.fat)

                    MacroRingView(
                        carbs: c,
                        protein: p,
                        fat: f,
                        isFractionInput: true,
                        lineWidth: lineWidth,
                        segmentGap: segmentGap,
                        backgroundOpacity: 0.12,
                        lineCap: .butt
                    )
                    .frame(width: size, height: size)
                    .opacity(animateRings ? 1 : 0)
                    .opacity(idx == 0 ? 1.0 : 0.83)                }

                Text(showAsPercent ? "Macros by % of calories" : "Macros by grams")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            animateRings = false
            withAnimation(.easeInOut(duration: 1.6)) {
                animateRings = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trendRingsRestart)) { _ in
            animateRings = false
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.6)) {
                    animateRings = true
                }
            }
        }
    }

    private func daySeries(limit: Int) -> [(carbs: Double, protein: Double, fat: Double)] {
        let groups = Dictionary(grouping: entries) { e in
            Day.startOfDay(for: e.day?.date ?? e.createdAt)
        }

        let sortedDayStarts = groups.keys.sorted(by: >).prefix(limit)

        return sortedDayStarts.map { start in
            let dayEntries = groups[start] ?? []
            let c = dayEntries.reduce(0) { $0 + $1.carbsG }
            let p = dayEntries.reduce(0) { $0 + $1.proteinG }
            let f = dayEntries.reduce(0) { $0 + $1.fatG }
            return (c, p, f)
        }
    }

    private func weekSeries(limit: Int) -> [(carbs: Double, protein: Double, fat: Double)] {
        let cal = Calendar.current

        let groups = Dictionary(grouping: entries) { e in
            let date = e.day?.date ?? e.createdAt
            return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? Day.startOfDay(for: date)
        }

        let sortedWeekStarts = groups.keys.sorted(by: >).prefix(limit)

        return sortedWeekStarts.map { start in
            let weekEntries = groups[start] ?? []
            let c = weekEntries.reduce(0) { $0 + $1.carbsG }
            let p = weekEntries.reduce(0) { $0 + $1.proteinG }
            let f = weekEntries.reduce(0) { $0 + $1.fatG }
            return (c, p, f)
        }
    }

    private func fractionsByCalories(carbsG: Double, proteinG: Double, fatG: Double) -> (Double, Double, Double) {
        let calsC = carbsG * 4
        let calsP = proteinG * 4
        let calsF = fatG * 9
        let total = max(calsC + calsP + calsF, 0.0001)
        return (calsC / total, calsP / total, calsF / total)
    }

    private func fractionsByGrams(carbsG: Double, proteinG: Double, fatG: Double) -> (Double, Double, Double) {
        let total = max(carbsG + proteinG + fatG, 0.0001)
        return (carbsG / total, proteinG / total, fatG / total)
    }
}

private extension Notification.Name {
    static let trendRingsRestart = Notification.Name("trendRingsRestart")
}
