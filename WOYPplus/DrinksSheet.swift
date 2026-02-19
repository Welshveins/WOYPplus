import SwiftUI
import SwiftData

struct DrinksSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let day: Day
    let mealSlot: MealSlot

    struct DrinkItem: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let kcal: Double
        let carbs: Double
        let protein: Double
        let fat: Double
        let fibre: Double
    }

    // Starter curated list (calm + editable later in EntryEditView)
    private let items: [DrinkItem] = [
        .init(name: "Milk (semi-skimmed, 250ml)", kcal: 120, carbs: 12, protein: 8, fat: 4, fibre: 0),
        .init(name: "Milk (whole, 250ml)",        kcal: 160, carbs: 12, protein: 8, fat: 9, fibre: 0),

        .init(name: "Orange juice (250ml)",       kcal: 110, carbs: 26, protein: 2, fat: 0, fibre: 0),
        .init(name: "Coke (330ml can)",           kcal: 139, carbs: 35, protein: 0, fat: 0, fibre: 0),
        .init(name: "Diet coke (330ml can)",      kcal: 1,   carbs: 0,  protein: 0, fat: 0, fibre: 0),

        // Alcohol (simple approximations; calm and editable)
        .init(name: "Beer (pint)",                kcal: 215, carbs: 18, protein: 2, fat: 0, fibre: 0),
        .init(name: "Wine (175ml glass)",         kcal: 133, carbs: 4,  protein: 0, fat: 0, fibre: 0)
    ]

    @State private var selectedDrink: DrinkItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Tap a drink, then choose 0.5 / 1 / 1.5.")
                        .foregroundStyle(.secondary)
                }

                Section("Drinks") {
                    ForEach(items) { item in
                        Button {
                            selectedDrink = item
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .foregroundStyle(.primary)

                                Text(summaryLine(for: item))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Drinks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedDrink) { drink in
                DrinkPortionSheet(
                    drink: drink,
                    day: day,
                    mealSlot: mealSlot
                )
                .presentationDetents([.medium])
            }
        }
    }

    private func summaryLine(for item: DrinkItem) -> String {
        "\(Int(item.kcal)) kcal • C \(Int(item.carbs))g • P \(Int(item.protein))g • F \(Int(item.fat))g"
    }
}
