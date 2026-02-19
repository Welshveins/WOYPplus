import SwiftUI
import SwiftData

struct ExtraSizeSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let extra: ExtrasSheet.ExtraItem
    let day: Day
    let mealSlot: MealSlot

    @State private var selected: ExtrasSheet.ExtraVariant?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                VStack(alignment: .leading, spacing: 6) {
                    Text(extra.name)
                        .font(.system(size: 22, weight: .semibold))

                    Text(mealSlot.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Size")
                        .font(.headline)

                    VStack(spacing: 10) {
                        ForEach(extra.variants) { v in
                            Button {
                                selected = v
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selected == v ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(selected == v ? Color.woypTeal : .secondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(v.label)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.primary)

                                        Text(summaryLine(for: v))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.woypSlate.opacity(selected == v ? 0.14 : 0.06))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .navigationTitle("Log extra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selected == nil)
                }
            }
        }
        .onAppear {
            selected = extra.variants.first
        }
    }

    private func summaryLine(for v: ExtrasSheet.ExtraVariant) -> String {
        "\(Int(v.kcal)) kcal • C \(Int(v.carbs))g • P \(Int(v.protein))g • F \(Int(v.fat))g"
    }

    private func save() {
        guard let v = selected else { return }

        let title = "\(extra.name) (\(v.label))"

        let entry = Entry(
            title: title,
            mealSlot: mealSlot,
            carbsG: v.carbs,
            proteinG: v.protein,
            fatG: v.fat,
            fibreG: v.fibre,
            caloriesKcal: v.kcal,
            isEstimate: false,
            day: day
        )

        ctx.insert(entry)
        try? ctx.save()
        dismiss()
    }
}
