import SwiftUI
import SwiftData

struct TodayView: View {

    @Environment(\.modelContext) private var ctx

    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    // Sheets / flows
    @State private var showingPlateSheet = false
    @State private var showingExtrasSheet = false

    @State private var showingRecipeSlotPicker = false
    @State private var recipeTargetSlot: MealSlot = .snacks
    @State private var showingRecipeLibrary = false

    @State private var showingQuickAddSlotPicker = false
    @State private var quickAddTargetSlot: MealSlot = .snacks
    @State private var showingQuickAddSheet = false

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

                // Explainer (Stage 1)
                Text("Outer ring = your most recent day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, -8)

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
                        .fill(Color.woypSlate.opacity(0.58))
                        .frame(height: 20)
                        .overlay(
                            Text("Range guide")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                // Actions grid (2 × 2)
                ActionsGrid(
                    onYourPlate: { showingPlateSheet = true },
                    onRecipe: {
                        recipeTargetSlot = .snacks
                        showingRecipeSlotPicker = true
                    },
                    onQuickAdd: {
                        quickAddTargetSlot = .snacks
                        showingQuickAddSlotPicker = true
                    },
                    onExtras: { showingExtrasSheet = true }
                )
                .padding(.top, 6)

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
                .padding(.top, 6)
                
                NavigationLink {
                    HelpInstructionsView()
                } label: {
                    Text("Help & instructions")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                Spacer(minLength: 18)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.woypSlate.opacity(0.15).ignoresSafeArea())
        .task {
            ExtrasSeeder.seedIfNeeded(ctx: ctx)
            RecipeSeeder.seedIfNeeded(ctx: ctx)
        }

        // Sheets (top-level)
        .sheet(isPresented: $showingPlateSheet) {
            AddPlateSheet(day: day)
        }
        .sheet(isPresented: $showingExtrasSheet) {
            ExtrasQuickLogSheet(day: day)
        }

        // Recipe: choose slot, then show library
        .confirmationDialog(
            "Log recipe to…",
            isPresented: $showingRecipeSlotPicker,
            titleVisibility: .visible
        ) {
            Button("Breakfast") { recipeTargetSlot = .breakfast; showingRecipeLibrary = true }
            Button("Lunch")     { recipeTargetSlot = .lunch;     showingRecipeLibrary = true }
            Button("Dinner")    { recipeTargetSlot = .dinner;    showingRecipeLibrary = true }
            Button("Snacks")    { recipeTargetSlot = .snacks;    showingRecipeLibrary = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingRecipeLibrary) {
            NavigationStack {
                RecipeLibraryView(day: day, mealSlot: recipeTargetSlot)
            }
        }

        // Quick Add: choose slot, then open quick add flow
        .confirmationDialog(
            "Quick add to…",
            isPresented: $showingQuickAddSlotPicker,
            titleVisibility: .visible
        ) {
            Button("Breakfast") { quickAddTargetSlot = .breakfast; showingQuickAddSheet = true }
            Button("Lunch")     { quickAddTargetSlot = .lunch;     showingQuickAddSheet = true }
            Button("Dinner")    { quickAddTargetSlot = .dinner;    showingQuickAddSheet = true }
            Button("Snacks")    { quickAddTargetSlot = .snacks;    showingQuickAddSheet = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingQuickAddSheet) {
            NavigationStack {
                QuickAddSheet(day: day, mealSlot: quickAddTargetSlot)
            }
        }

        .navigationBarTitleDisplayMode(.inline)
    
    }
}

////////////////////////////////////////////////////////////
/// MARK: - Actions Grid
////////////////////////////////////////////////////////////

private struct ActionsGrid: View {

    let onYourPlate: () -> Void
    let onRecipe: () -> Void
    let onQuickAdd: () -> Void
    let onExtras: () -> Void

    private let cols = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            ActionTileRow(title: "Your plate", systemImage: "camera", action: onYourPlate)
            ActionTileRow(title: "Recipe", systemImage: "fork.knife", action: onRecipe)
            ActionTileRow(title: "Quick add", systemImage: "barcode.viewfinder", action: onQuickAdd)
            ActionTileRow(title: "Extras", systemImage: "cube", action: onExtras)
        }
    }
}

private struct ActionTileRow: View {

    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {

                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 30)
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.60)
                    .allowsTightening(true)
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.woypSlate.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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
