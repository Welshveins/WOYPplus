import SwiftUI
import SwiftData

struct RecipeBuilderView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let existingRecipe: Recipe?

    @State private var title: String = ""
    @State private var categoryRaw: String = "Dinner"

    // NEW: servings this recipe makes
    @State private var servings: Double = 1

    @State private var draftIngredients: [DraftIngredient] = []

    private enum ActiveSheet: Identifiable {
        case pickFood
        var id: String { "pickFood" }
    }

    @State private var activeSheet: ActiveSheet?

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    init(existingRecipe: Recipe? = nil) {
        self.existingRecipe = existingRecipe
    }

    var body: some View {
        NavigationStack {
            List {

                detailsSection
                ingredientsSection
                totalsSection
            }
            .navigationTitle(existingRecipe == nil ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingRecipe == nil ? "Save" : "Update") {
                        saveRecipe()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftIngredients.isEmpty)
                }
            }
            .onAppear { hydrateFromExistingIfNeeded() }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .pickFood:
                    NavigationStack {
                        FoodLibraryView { pick in
                            addDraftIngredient(from: pick)
                            activeSheet = nil
                        }
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section("Details") {

            TextField("Recipe name", text: $title)

            TextField("Category", text: $categoryRaw)
                .textInputAutocapitalization(.words)

            Stepper(value: $servings, in: 1...24, step: 1) {
                HStack {
                    Text("Servings this makes")
                    Spacer()
                    Text("\(Int(servings))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Text("Tip: categoryRaw drives filters (Breakfast/Lunch/Dinner/Snacks).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var ingredientsSection: some View {
        Section("Ingredients") {

            if draftIngredients.isEmpty {
                Text("No ingredients yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(draftIngredients) { d in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(d.name)
                                .font(.headline)

                            Text("\(Int(d.amountGrams.rounded())) g • \(Int(d.kcalPer100g.rounded())) kcal/100g")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            deleteDraft(d)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }

            Button {
                activeSheet = .pickFood
            } label: {
                Label("Add ingredient", systemImage: "plus")
            }
        }
    }

    private var totalsSection: some View {
        Group {
            Section("Totals (full recipe)") {
                TotalsRow(title: "Calories", value: "\(Int(totalKcal.rounded())) kcal")
                TotalsRow(title: "Carbs", value: "\(Int(totalCarbs.rounded())) g")
                TotalsRow(title: "Protein", value: "\(Int(totalProtein.rounded())) g")
                TotalsRow(title: "Fat", value: "\(Int(totalFat.rounded())) g")
                TotalsRow(title: "Fibre", value: "\(Int(totalFibre.rounded())) g")
            }

            Section("Per serving") {
                let s = max(servings, 1)
                TotalsRow(title: "Calories", value: "\(Int((totalKcal / s).rounded())) kcal")
                TotalsRow(title: "Carbs", value: "\(Int((totalCarbs / s).rounded())) g")
                TotalsRow(title: "Protein", value: "\(Int((totalProtein / s).rounded())) g")
                TotalsRow(title: "Fat", value: "\(Int((totalFat / s).rounded())) g")
                TotalsRow(title: "Fibre", value: "\(Int((totalFibre / s).rounded())) g")
            }
        }
    }

    // MARK: - Derived totals

    private var totalKcal: Double {
        draftIngredients.reduce(0) { $0 + ($1.kcalPer100g * $1.amountGrams / 100.0) }
    }

    private var totalCarbs: Double {
        draftIngredients.reduce(0) { $0 + ($1.carbsPer100g * $1.amountGrams / 100.0) }
    }

    private var totalProtein: Double {
        draftIngredients.reduce(0) { $0 + ($1.proteinPer100g * $1.amountGrams / 100.0) }
    }

    private var totalFat: Double {
        draftIngredients.reduce(0) { $0 + ($1.fatPer100g * $1.amountGrams / 100.0) }
    }

    private var totalFibre: Double {
        draftIngredients.reduce(0) { $0 + ($1.fibrePer100g * $1.amountGrams / 100.0) }
    }

    // MARK: - Hydration (edit mode)

    private func hydrateFromExistingIfNeeded() {
        guard let r = existingRecipe else { return }

        title = r.title
        categoryRaw = r.categoryRaw
        servings = r.servings

        draftIngredients = r.ingredients.map { ing in
            DraftIngredient(
                id: UUID(),
                name: ing.name,
                amountGrams: ing.amountGrams,
                kcalPer100g: ing.kcalPer100g,
                carbsPer100g: ing.carbsPer100g,
                proteinPer100g: ing.proteinPer100g,
                fatPer100g: ing.fatPer100g,
                fibrePer100g: ing.fibrePer100g
            )
        }
    }

    // MARK: - Draft ops

    private func addDraftIngredient(from pick: FoodPickResult) {
        let g = max(0.0, pick.grams)
        guard g > 0 else { return }

        draftIngredients.append(
            DraftIngredient(
                id: UUID(),
                name: pick.foodName,
                amountGrams: g,
                kcalPer100g: (pick.kcal / g) * 100.0,
                carbsPer100g: (pick.carbsG / g) * 100.0,
                proteinPer100g: (pick.proteinG / g) * 100.0,
                fatPer100g: (pick.fatG / g) * 100.0,
                fibrePer100g: (pick.fibreG / g) * 100.0
            )
        )
    }

    private func deleteDraft(_ d: DraftIngredient) {
        draftIngredients.removeAll { $0.id == d.id }
    }

    // MARK: - Save

    private func saveRecipe() {

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let recipeIngredients = draftIngredients.map { d in
            RecipeIngredient(
                name: d.name,
                amountGrams: d.amountGrams,
                kcalPer100g: d.kcalPer100g,
                carbsPer100g: d.carbsPer100g,
                proteinPer100g: d.proteinPer100g,
                fatPer100g: d.fatPer100g,
                fibrePer100g: d.fibrePer100g
            )
        }

        let perServingKcal = totalKcal / max(servings, 1)
        let perServingCarbs = totalCarbs / max(servings, 1)
        let perServingProtein = totalProtein / max(servings, 1)
        let perServingFat = totalFat / max(servings, 1)
        let perServingFibre = totalFibre / max(servings, 1)

        let fingerprint = makeFingerprint(
            name: trimmedTitle,
            totalKcal: totalKcal,
            totalCarbs: totalCarbs,
            totalProtein: totalProtein,
            totalFat: totalFat
        )

        if let r = existingRecipe {
            r.title = trimmedTitle
            r.categoryRaw = categoryRaw
            r.servings = servings
            r.caloriesKcal = perServingKcal
            r.carbsG = perServingCarbs
            r.proteinG = perServingProtein
            r.fatG = perServingFat
            r.fibreG = perServingFibre
            r.sourceFingerprint = fingerprint
            r.updatedAt = Date()
            r.ingredients = recipeIngredients
            try? ctx.save()
            dismiss()
            return
        }

        let recipe = Recipe(
            title: trimmedTitle,
            categoryRaw: categoryRaw,
            servings: servings,            caloriesKcal: perServingKcal,
            carbsG: perServingCarbs,
            proteinG: perServingProtein,
            fatG: perServingFat,
            fibreG: perServingFibre,
            sourceFingerprint: fingerprint,
            
            photoData: nil,
            ingredients: recipeIngredients
        )

        ctx.insert(recipe)
        try? ctx.save()
        dismiss()
    }

    private func makeFingerprint(
        name: String,
        totalKcal: Double,
        totalCarbs: Double,
        totalProtein: Double,
        totalFat: Double
    ) -> String {
        let n = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(n)|\(Int(totalKcal.rounded()))|\(Int(totalCarbs.rounded()))|\(Int(totalProtein.rounded()))|\(Int(totalFat.rounded()))"
    }
}

// MARK: - Draft ingredient

private struct DraftIngredient: Identifiable, Hashable {
    let id: UUID
    var name: String
    var amountGrams: Double
    var kcalPer100g: Double
    var carbsPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var fibrePer100g: Double
}

// MARK: - Totals row UI

private struct TotalsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
