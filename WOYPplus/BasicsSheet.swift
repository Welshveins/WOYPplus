import SwiftUI
import SwiftData

struct BasicsSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let day: Day
    let mealSlot: MealSlot

    // Very small starter library (we can expand once the plumbing is proven)
    struct BasicItem: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let kcal: Double
        let carbs: Double
        let protein: Double
        let fat: Double
        let fibre: Double
    }

    // Default “fast logging” set (can expand to your full Basics/Add-ons library later)
    private let items: [BasicItem] = [
        // Carby staples (typical portions, editable later in EntryEditView if needed)
        .init(name: "Rice (cooked)",        kcal: 260, carbs: 57, protein: 5,  fat: 1,  fibre: 1),
        .init(name: "Bread (2 slices)",     kcal: 190, carbs: 36, protein: 7,  fat: 2,  fibre: 3),
        .init(name: "Wrap",                 kcal: 220, carbs: 36, protein: 6,  fat: 5,  fibre: 2),
        .init(name: "Potatoes (boiled)",    kcal: 210, carbs: 47, protein: 5,  fat: 0,  fibre: 4),

        // Vegetables default 80g servings (rough, calm, editable)
        .init(name: "Carrots (80g)",        kcal: 33,  carbs: 8,  protein: 1,  fat: 0,  fibre: 2),
        .init(name: "Broccoli (80g)",       kcal: 28,  carbs: 6,  protein: 2,  fat: 0,  fibre: 2),
        .init(name: "Green beans (80g)",    kcal: 25,  carbs: 5,  protein: 2,  fat: 0,  fibre: 2),
        .init(name: "Mixed veg (80g)",      kcal: 35,  carbs: 7,  protein: 2,  fat: 0,  fibre: 3),
        .init(name: "Salad (80g)",          kcal: 18,  carbs: 3,  protein: 1,  fat: 0,  fibre: 2)
    ]

    @State private var selected: Set<BasicItem> = []
    @State private var title: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Description (optional)", text: $title)
                }

                Section("Pick a few basics") {
                    ForEach(items) { item in
                        Button {
                            toggle(item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected.contains(item) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(item) ? Color.woypTeal : .secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .foregroundStyle(.primary)

                                    Text(summaryLine(for: item))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    HStack {
                        Text("Total")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(totalSummary)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Basics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selected.isEmpty)
                }
            }
        }
    }

    private func toggle(_ item: BasicItem) {
        if selected.contains(item) {
            selected.remove(item)
        } else {
            selected.insert(item)
        }
    }

    private func summaryLine(for item: BasicItem) -> String {
        "\(Int(item.kcal)) kcal • C \(Int(item.carbs))g • P \(Int(item.protein))g • F \(Int(item.fat))g"
    }

    private var totals: (kcal: Double, carbs: Double, protein: Double, fat: Double, fibre: Double) {
        let all = Array(selected)
        return (
            all.reduce(0) { $0 + $1.kcal },
            all.reduce(0) { $0 + $1.carbs },
            all.reduce(0) { $0 + $1.protein },
            all.reduce(0) { $0 + $1.fat },
            all.reduce(0) { $0 + $1.fibre }
        )
    }

    private var totalSummary: String {
        let t = totals
        return "\(Int(t.kcal.rounded())) kcal • C \(Int(t.carbs.rounded()))g • P \(Int(t.protein.rounded()))g • F \(Int(t.fat.rounded()))g"
    }

    private func save() {
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // If the user didn’t type a description, use the selected item names.
        // Keep it short so it looks good on TodayView.
        let pickedNames = selected
            .map { $0.name }
            .sorted()

        let autoTitle: String = {
            if pickedNames.isEmpty { return "Basics" } // should never happen (Save disabled), but safe.
            if pickedNames.count == 1 { return pickedNames[0] }
            if pickedNames.count == 2 { return "\(pickedNames[0]) + \(pickedNames[1])" }
            return "\(pickedNames[0]) + \(pickedNames[1]) + \(pickedNames.count - 2) more"
        }()

        let finalTitle = safeTitle.isEmpty ? autoTitle : safeTitle

        let t = totals

        let entry = Entry(
            title: finalTitle,
            mealSlot: mealSlot,
            carbsG: t.carbs,
            proteinG: t.protein,
            fatG: t.fat,
            fibreG: t.fibre,
            caloriesKcal: t.kcal,
            isEstimate: false,
            day: day
        )

        ctx.insert(entry)
        try? ctx.save()
        dismiss()
    }
}
