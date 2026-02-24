import SwiftUI
import SwiftData

struct MealDetailView: View {

    @Environment(\.modelContext) private var ctx

    let day: Day
    let mealSlot: MealSlot
    let title: String

    @Query(sort: \Entry.createdAt, order: .reverse) private var allEntries: [Entry]

    @State private var selectedEntry: Entry?

    @State private var showingAddChooser = false
    @State private var showingPlateSheet = false
    @State private var showingBasicsSheet = false
    @State private var showingRecipeLibrary = false
    @State private var showingDrinksSheet = false
    @State private var showingExtrasSheet = false

    // Stage 3: "Add new recipe" from meal screen
    @State private var showingRecipeBuilder = false

    private var entries: [Entry] {
        allEntries
            .filter { e in
                guard let d = e.day else { return false }
                return Day.startOfDay(for: d.date) == Day.startOfDay(for: day.date)
                && e.mealSlot == mealSlot
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {

        List {

            // Stage 3: in-body actions (replaces header +)
            Section {
                VStack(spacing: 10) {

                    Button {
                        showingAddChooser = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to \(title)")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.woypSlate.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingRecipeBuilder = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Add new recipe")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.woypSlate.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            // Entries
            if entries.isEmpty {
                Text("Nothing logged yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    Button {
                        selectedEntry = entry
                    } label: {
                        HStack(spacing: 10) {

                            if entry.isEstimate {
                                Text("*")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                HStack(spacing: 10) {
                                    Text("\(Int(entry.caloriesKcal.rounded())) kcal")
                                    Text("C \(Int(entry.carbsG.rounded()))g")
                                    Text("P \(Int(entry.proteinG.rounded()))g")
                                    Text("F \(Int(entry.fatG.rounded()))g")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)

        // Stage 3: remove header + (no toolbar add button)

        .confirmationDialog(
            "Add to \(title)",
            isPresented: $showingAddChooser,
            titleVisibility: .visible
        ) {
            Button("Recipe") { showingRecipeLibrary = true }
            Button("Your plate") { showingPlateSheet = true }
            Button("Basics") { showingBasicsSheet = true }
            Button("Drinks") { showingDrinksSheet = true }
            Button("Extras") { showingExtrasSheet = true }
            Button("Cancel", role: .cancel) { }
        }

        // Sheets
        .sheet(isPresented: $showingPlateSheet) {
            AddPlateSheet(day: day)
        }
        .sheet(isPresented: $showingBasicsSheet) {
            BasicsSheet(day: day, mealSlot: mealSlot)
        }
        .sheet(isPresented: $showingDrinksSheet) {
            DrinksSheet(day: day, mealSlot: mealSlot)
        }
        .sheet(isPresented: $showingExtrasSheet) {
            ExtrasSheet(day: day, mealSlot: mealSlot)
        }
        .sheet(isPresented: $showingRecipeLibrary) {
            NavigationStack {
                RecipeLibraryView(day: day, mealSlot: mealSlot)
            }
        }
        .sheet(item: $selectedEntry) { entry in
            EntryEditView(day: day, entry: entry)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingRecipeBuilder) {
            NavigationStack {
                RecipeBuilderView()
            }
        }
    }

    private func delete(_ entry: Entry) {
        ctx.delete(entry)
        try? ctx.save()
        refreshDayEstimateFlag()
    }

    private func refreshDayEstimateFlag() {
        let sameDayEntries = allEntries.filter { e in
            guard let d = e.day else { return false }
            return Day.startOfDay(for: d.date) == Day.startOfDay(for: day.date)
        }
        day.hasEstimates = sameDayEntries.contains(where: { $0.isEstimate })
        try? ctx.save()
    }
}
