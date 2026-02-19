import SwiftUI
import SwiftData

struct TodayView: View {
    
    
    @Environment(\.modelContext) private var ctx

    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    @State private var showingPlateSheet = false
    @State private var showingExtrasSheet = false

    private var todayStart: Date { Day.startOfDay(for: Date()) }

    private var todayString: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE d MMM"
        return df.string(from: Date())
    }

    private var todayDay: Day? {
        days.first(where: { Day.startOfDay(for: $0.date) == todayStart })
    }

    private func ensureTodayDay() -> Day {
        if let d = todayDay { return d }
        let newDay = Day(date: todayStart)
        ctx.insert(newDay)
        try? ctx.save()
        return newDay
    }

    private func entriesForToday(slot: MealSlot) -> [Entry] {
        entries.filter { e in
            guard let d = e.day else { return false }
            return Day.startOfDay(for: d.date) == todayStart && e.mealSlot == slot
        }
    }

    private func totals() -> (kcal: Double, carbs: Double, protein: Double, fat: Double, fibre: Double) {
        let todays = entries.filter { e in
            guard let d = e.day else { return false }
            return Day.startOfDay(for: d.date) == todayStart
        }

        let kcal = todays.reduce(0) { $0 + $1.caloriesKcal }
        let c = todays.reduce(0) { $0 + $1.carbsG }
        let p = todays.reduce(0) { $0 + $1.proteinG }
        let f = todays.reduce(0) { $0 + $1.fatG }
        let fi = todays.reduce(0) { $0 + $1.fibreG }

        return (kcal, c, p, f, fi)
    }

    var body: some View {

        let day = ensureTodayDay()
        let t = totals()

        ScrollView(showsIndicators: false) {

            VStack(spacing: 18) {

                // Header
                VStack(spacing: 6) {
                    Text("Today")
                        .font(.system(size: 34, weight: .semibold))
                        .tracking(-0.5)

                    Text(todayString)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .task {
                    ExtrasSeeder.seedIfNeeded(ctx: ctx)
                }
                .padding(.top, 10)

                // Macro Ring
                NavigationLink {
                    TrendView()
                } label: {
                    GeometryReader { geo in
                        let size = min(geo.size.width * 0.72, 260)

                        ZStack {
                            MacroRingView(
                                carbs: t.carbs,
                                protein: t.protein,
                                fat: t.fat
                            )
                            .frame(width: size, height: size)

                            if day.hasEstimates {
                                Text("*")
                                    .font(.title2.bold())
                                    .foregroundStyle(.secondary)
                                    .offset(x: size * 0.28, y: -size * 0.28)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 300)
                }
                .buttonStyle(.plain)

                // Stats row
                MacroStatsRow(
                    kcal: t.kcal,
                    carbs: t.carbs,
                    protein: t.protein,
                    fat: t.fat,
                    fibre: t.fibre
                )
                .padding(.top, 2)

                // Range guide pill
                NavigationLink {
                    RangeView()
                } label: {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.woypSlate.opacity(0.58)) // your preferred TodayView pill opacity
                        .frame(height: 20)
                        .overlay(
                            Text("Range guide")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                // Meals
                VStack(spacing: 12) {

                    MealRow(
                        title: "Breakfast",
                        day: day,
                        mealSlot: .breakfast,
                        entries: entriesForToday(slot: .breakfast)
                    )

                    MealRow(
                        title: "Lunch",
                        day: day,
                        mealSlot: .lunch,
                        entries: entriesForToday(slot: .lunch)
                    )

                    MealRow(
                        title: "Dinner",
                        day: day,
                        mealSlot: .dinner,
                        entries: entriesForToday(slot: .dinner)
                    )

                    MealRow(
                        title: "Snacks",
                        day: day,
                        mealSlot: .snacks,
                        entries: entriesForToday(slot: .snacks)
                    )
                }
                .padding(.top, 4)

                // Actions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Actions")
                        .font(.headline)

                    HStack(spacing: 10) {

                        ActionTile(title: "Your plate", systemImage: "camera") {
                            showingPlateSheet = true
                        }

                        ActionTile(title: "Add recipe", systemImage: "plus") {
                            // placeholder for recipe create flow
                        }

                        // ✅ Extras lives here (packaged items quick log)
                        ActionTile(title: "Extras", systemImage: "cube") {
                            showingExtrasSheet = true
                        }
                    }
                }
                .padding(.top, 6)

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        // ✅ soft slate background for light mode too (instead of bright white)
        .background(Color.woypSlate.opacity(0.15))
        .sheet(isPresented: $showingPlateSheet) {
            AddPlateSheet(day: day)
        }
        .sheet(isPresented: $showingExtrasSheet) {
            // This assumes your existing sheet takes (day: Day).
            // If your ExtrasQuickLogSheet initializer is different, tell me what it is and I’ll adjust.
            ExtrasQuickLogSheet(day: day)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Import / Export entry point
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    DataBackupView()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.headline)
                        .padding(10)
                        .background(Circle().fill(Color.woypSlate.opacity(0.22)))
                        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

////////////////////////////////////////////////////////////
/// MARK: - Stats Row
////////////////////////////////////////////////////////////

private struct MacroStatsRow: View {

    let kcal: Double
    let carbs: Double
    let protein: Double
    let fat: Double
    let fibre: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {

            StatCell(label: "kcal", value: formatInt(kcal), valueColor: .secondary, showG: false)

            StatCell(label: "C", value: formatInt(carbs), valueColor: .woypSand, showG: true)
            StatCell(label: "P", value: formatInt(protein), valueColor: .woypTeal, showG: true)
            StatCell(label: "F", value: formatInt(fat), valueColor: .woypTerracotta, showG: true)

            StatCell(label: "Fibre", value: formatInt(fibre), valueColor: .secondary, showG: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatInt(_ x: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: x)) ?? "\(Int(x))"
    }
}

private struct StatCell: View {

    let label: String
    let value: String
    let valueColor: Color
    let showG: Bool

    var body: some View {
        VStack(spacing: 4) {

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(labelColor)

            Text(showG ? "\(value)g" : value)
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private var labelColor: Color {
        switch label {
        case "C": return .woypSand
        case "P": return .woypTeal
        case "F": return .woypTerracotta
        default:  return .secondary
        }
    }
}

////////////////////////////////////////////////////////////
/// MARK: - Meal Row
////////////////////////////////////////////////////////////

private struct MealRow: View {

    let title: String
    let day: Day
    let mealSlot: MealSlot
    let entries: [Entry]

    var body: some View {

        NavigationLink {
            MealDetailView(day: day, mealSlot: mealSlot, title: title)
        } label: {

            VStack(alignment: .leading, spacing: 6) {

                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if entries.isEmpty {
                    Text("Nothing logged yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries.prefix(2)) { entry in
                        HStack(spacing: 6) {
                            if entry.isEstimate {
                                Text("*").foregroundStyle(.secondary)
                            }
                            Text(entry.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.woypSlate.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}

////////////////////////////////////////////////////////////
/// MARK: - Action Tile
////////////////////////////////////////////////////////////

private struct ActionTile: View {

    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {

        Button(action: action) {

            VStack(spacing: 8) {

                Image(systemName: systemImage)
                    .font(.title2)

                Text(title)
                    .font(.subheadline).bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.woypSlate.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}
