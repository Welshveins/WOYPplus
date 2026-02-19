import SwiftUI
import SwiftData

struct ExtrasSheet: View {

    @Environment(\.dismiss) private var dismiss

    let day: Day
    let mealSlot: MealSlot

    struct ExtraItem: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let variants: [ExtraVariant]
    }

    struct ExtraVariant: Identifiable, Hashable {
        let id = UUID()
        let label: String
        let kcal: Double
        let carbs: Double
        let protein: Double
        let fat: Double
        let fibre: Double
    }

    // Starter set (we can expand once plumbing is proven)
    private let items: [ExtraItem] = [

        .init(
            name: "KitKat",
            variants: [
                .init(label: "2-finger", kcal: 106, carbs: 14, protein: 1.5, fat: 5.3, fibre: 0.8),
                .init(label: "4-finger", kcal: 212, carbs: 28, protein: 3.0, fat: 10.6, fibre: 1.6),
                .init(label: "Chunky",   kcal: 207, carbs: 25, protein: 3.4, fat: 10.2, fibre: 1.5)
            ]
        ),

        .init(
            name: "Crisps",
            variants: [
                .init(label: "Small bag",  kcal: 160, carbs: 15, protein: 2, fat: 10, fibre: 1),
                .init(label: "Grab bag",   kcal: 250, carbs: 24, protein: 3, fat: 16, fibre: 2)
            ]
        ),

        .init(
            name: "Ice cream",
            variants: [
                .init(label: "1 scoop", kcal: 137, carbs: 16, protein: 2.4, fat: 7.3, fibre: 0),
                .init(label: "2 scoops", kcal: 274, carbs: 32, protein: 4.8, fat: 14.6, fibre: 0)
            ]
        )
    ]

    @State private var selectedItem: ExtraItem?

    var body: some View {
        NavigationStack {
            List {

                Section {
                    Text("Quick log common extras without fuss. Sizes are simple and editable later.")
                        .foregroundStyle(.secondary)
                }

                Section("Extras") {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            HStack {
                                Text(item.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Extras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedItem) { item in
                ExtraSizeSheet(extra: item, day: day, mealSlot: mealSlot)
                    .presentationDetents([.medium])
            }
        }
    }
}
