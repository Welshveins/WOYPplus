import SwiftUI
import SwiftData

struct AddPlateSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    // We still accept the “current” day from TodayView, but the user can override via DatePicker.
    let day: Day

    @State private var title: String = ""
    @State private var when: Date = Date()

    @State private var mealSlot: MealSlot = MealSlot.defaultSlot(for: Date())
    @State private var userManuallyPickedSlot = false

    @State private var kcal: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var fibre: String = ""

    var body: some View {
        NavigationStack {
            Form {

                Section {
                    TextField("Description (optional)", text: $title)
                }

                Section("When?") {
                    DatePicker(
                        "Date & time",
                        selection: $when,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Where does this belong?") {
                    Picker("Meal", selection: $mealSlot) {
                        Text("Breakfast").tag(MealSlot.breakfast)
                        Text("Lunch").tag(MealSlot.lunch)
                        Text("Dinner").tag(MealSlot.dinner)
                        Text("Snacks").tag(MealSlot.snacks)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mealSlot) { _, _ in
                        userManuallyPickedSlot = true
                    }
                }

                Section("Best guess") {
                    numberField("kcal", text: $kcal)
                    numberField("Carbs (g)", text: $carbs)
                    numberField("Protein (g)", text: $protein)
                    numberField("Fat (g)", text: $fat)
                    numberField("Fibre (g)", text: $fibre)
                }

                Section {
                    Text("This entry is marked as an estimate. You can confirm or edit it later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Your plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                // Ensure initial default slot matches the initial "when"
                mealSlot = MealSlot.defaultSlot(for: when)
            }
            .onChange(of: when) { _, newValue in
                // Only auto-update the slot if the user hasn't manually overridden it
                guard !userManuallyPickedSlot else { return }
                mealSlot = MealSlot.defaultSlot(for: newValue)
            }
        }
    }

    private var canSave: Bool {
        let k = Double(kcal) ?? 0
        let c = Double(carbs) ?? 0
        let p = Double(protein) ?? 0
        let f = Double(fat) ?? 0
        return (k > 0) || (c + p + f > 0)
    }

    @ViewBuilder
    private func numberField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .keyboardType(.decimalPad)
    }

    private func ensureDay(for date: Date) -> Day {
        let start = Day.startOfDay(for: date)

        // Try to find an existing Day in the store first.
        do {
            let allDays = try ctx.fetch(FetchDescriptor<Day>())
            if let existing = allDays.first(where: { Day.startOfDay(for: $0.date) == start }) {
                return existing
            }
        } catch {
            // If fetch fails, we’ll still create a Day below.
        }

        let newDay = Day(date: start)
        ctx.insert(newDay)
        return newDay
    }

    private func save() {

        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = safeTitle.isEmpty ? "Your plate" : safeTitle

        let targetDay = ensureDay(for: when)

        let entry = Entry(
            title: finalTitle,
            mealSlot: mealSlot,
            carbsG: Double(carbs) ?? 0,
            proteinG: Double(protein) ?? 0,
            fatG: Double(fat) ?? 0,
            fibreG: Double(fibre) ?? 0,
            caloriesKcal: Double(kcal) ?? 0,
            isEstimate: true,
            day: targetDay
        )

        // Set createdAt to the chosen date/time (so Range/Trend match the day you picked)
        entry.createdAt = when

        ctx.insert(entry)

        // Mark the day so Today ring shows the subtle asterisk
        targetDay.hasEstimates = true

        do { try ctx.save() } catch { }

        dismiss()
    }
}
