import SwiftUI
import SwiftData

struct RecipeBuilderView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    // Optional edit mode
    let existingRecipe: Recipe?

    @State private var title: String = ""
    @State private var categoryRaw: String = "Dinner"

    // Draft ingredients (built from Food library picks)
    @State private var draftIngredients: [DraftIngredient] = []

    // Sheet
    private enum ActiveSheet: Identifiable {
        case pickFood
        var id: String { "pickFood" }
    }
    @State private var activeSheet: ActiveSheet?

    // Alerts
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
                    Button(existingRecipe == nil ? "Save" : "Update") { saveRecipe() }
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
                Button("OK", role: .cancel) { }
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

            Text("Tip: categoryRaw drives filters (e.g. Breakfast/Lunch/Dinner/Snacks, Starter/Main/Dessert).")
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
        Section("Totals") {
            TotalsRow(title: "Calories", value: "\(Int(totalKcal.rounded())) kcal")
            TotalsRow(title: "Carbs", value: "\(Int(totalCarbs.rounded())) g")
            TotalsRow(title: "Protein", value: "\(Int(totalProtein.rounded())) g")
            TotalsRow(title: "Fat", value: "\(Int(totalFat.rounded())) g")
            TotalsRow(title: "Fibre", value: "\(Int(totalFibre.rounded())) g")
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
        // FoodPickResult gives totals for the chosen grams,
        // so convert back to /100g for storing as an ingredient.
        let g = max(0.0, pick.grams)
        guard g > 0 else { return }

        let kcalPer100 = (pick.kcal / g) * 100.0
        let carbsPer100 = (pick.carbsG / g) * 100.0
        let proteinPer100 = (pick.proteinG / g) * 100.0
        let fatPer100 = (pick.fatG / g) * 100.0
        let fibrePer100 = (pick.fibreG / g) * 100.0

        draftIngredients.append(
            DraftIngredient(
                id: UUID(),
                name: pick.foodName,
                amountGrams: g,
                kcalPer100g: kcalPer100,
                carbsPer100g: carbsPer100,
                proteinPer100g: proteinPer100,
                fatPer100g: fatPer100,
                fibrePer100g: fibrePer100
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

        let recipeIngredients: [RecipeIngredient] = draftIngredients.map { d in
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
            r.caloriesKcal = totalKcal
            r.carbsG = totalCarbs
            r.proteinG = totalProtein
            r.fatG = totalFat
            r.fibreG = totalFibre
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
            caloriesKcal: totalKcal,
            carbsG: totalCarbs,
            proteinG: totalProtein,
            fatG: totalFat,
            fibreG: totalFibre,
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

// MARK: - Small UI helpers

private struct TotalsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
