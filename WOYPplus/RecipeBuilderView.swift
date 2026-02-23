import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Recipe Builder (Create + Edit)

struct RecipeBuilderView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    // If provided -> edit mode. If nil -> create mode.
    let recipeToEdit: Recipe?

    // Food library
    @Query(sort: \Food.name) private var foods: [Food]

    // Form
    @State private var title: String = ""
    @State private var categoryRaw: String = ""
    @State private var searchText: String = ""

    // Ingredients draft list
    @State private var draftIngredients: [DraftIngredient] = []
    @State private var selectedFood: Food?
    @State private var selectedIngredientIndex: Int?

    // Photo
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    // Alerts
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false

    init(recipeToEdit: Recipe? = nil) {
        self.recipeToEdit = recipeToEdit
    }

    var body: some View {
        NavigationStack {
            List {

                Section("Recipe") {
                    TextField("Name", text: $title)

                    TextField("Category (e.g. Breakfast / Dinner / Starter)", text: $categoryRaw)

                    HStack(spacing: 12) {
                        photoPreview
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Photo")
                                .font(.headline)
                            Text(photoData == nil ? "Optional" : "Selected")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }

                        Spacer()

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text(photoData == nil ? "Add" : "Change")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Ingredients") {

                    if draftIngredients.isEmpty {
                        Text("No ingredients yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(draftIngredients.enumerated()), id: \.element.id) { idx, ing in
                            Button {
                                selectedIngredientIndex = idx
                                selectedFood = ing.food
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(ing.food.name)
                                        .font(.headline)

                                    Text(ingredientLine(ing))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteIngredients)
                    }

                    // Add ingredient from Foods
                    TextField("Search foods", text: $searchText)

                    ForEach(filteredFoods) { food in
                        Button {
                            selectedFood = food
                            selectedIngredientIndex = nil
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(food.name)
                                    .font(.headline)
                                Text("\(Int(food.kcalPer100g.rounded())) kcal per 100g")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }

                    if foods.isEmpty {
                        Text("No foods found. (Food library is empty.)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Totals (whole recipe)") {
                    Text(totalsLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .navigationTitle(recipeToEdit == nil ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecipe() }
                        .disabled(!canSave)
                }
            }
            .onAppear { loadIfEditing() }
            .onChange(of: photoItem) { _, newValue in
                guard let newValue else { return }
                Task { await loadPhoto(from: newValue) }
            }
            .sheet(item: $selectedFood) { food in
                IngredientAmountSheet(
                    food: food,
                    existing: existingDraftForSelectedFood(),
                    onSave: { grams, portionName in
                        upsertIngredient(food: food, grams: grams, portionName: portionName)
                        selectedFood = nil
                        selectedIngredientIndex = nil
                    },
                    onCancel: {
                        selectedFood = nil
                        selectedIngredientIndex = nil
                    }
                )
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - UI helpers

    private var photoPreview: some View {
        Group {
            if let photoData, let ui = UIImage(data: photoData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.woypSlate.opacity(0.12))
                    .overlay(
                        Image(systemName: "camera")
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var filteredFoods: [Food] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return foods }
        return foods.filter { $0.name.lowercased().contains(q) }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draftIngredients.isEmpty
    }

    private func ingredientLine(_ ing: DraftIngredient) -> String {
        let grams = ing.amountGrams
        let kcal = ing.kcal
        let c = ing.carbsG
        let p = ing.proteinG
        let f = ing.fatG
        let fi = ing.fibreG

        if let portionName = ing.portionName, !portionName.isEmpty {
            return "\(portionName) • \(Int(grams.rounded()))g • \(Int(kcal.rounded())) kcal • C \(Int(c.rounded()))g • P \(Int(p.rounded()))g • F \(Int(f.rounded()))g • Fi \(Int(fi.rounded()))g"
        } else {
            return "\(Int(grams.rounded()))g • \(Int(kcal.rounded())) kcal • C \(Int(c.rounded()))g • P \(Int(p.rounded()))g • F \(Int(f.rounded()))g • Fi \(Int(fi.rounded()))g"
        }
    }

    private var totalsLine: String {
        let kcal = draftIngredients.reduce(0) { $0 + $1.kcal }
        let c = draftIngredients.reduce(0) { $0 + $1.carbsG }
        let p = draftIngredients.reduce(0) { $0 + $1.proteinG }
        let f = draftIngredients.reduce(0) { $0 + $1.fatG }
        let fi = draftIngredients.reduce(0) { $0 + $1.fibreG }

        return "\(Int(kcal.rounded())) kcal • C \(Int(c.rounded()))g • P \(Int(p.rounded()))g • F \(Int(f.rounded()))g • Fibre \(Int(fi.rounded()))g"
    }

    // MARK: - Load / Save

    private func loadIfEditing() {
        guard let r = recipeToEdit else {
            // create mode defaults
            title = ""
            categoryRaw = ""
            draftIngredients = []
            photoData = nil
            return
        }

        title = r.title
        categoryRaw = r.categoryRaw
        photoData = r.photoData

        // Convert existing RecipeIngredient -> DraftIngredient
        draftIngredients = r.ingredients.map { ri in
            let food = Food(
                name: ri.name,
                kcalPer100g: ri.kcalPer100g,
                carbsPer100g: ri.carbsPer100g,
                proteinPer100g: ri.proteinPer100g,
                fatPer100g: ri.fatPer100g,
                fibrePer100g: ri.fibrePer100g,
                defaultPortionName: nil,
                defaultPortionGrams: nil
            )
            return DraftIngredient(food: food, amountGrams: ri.amountGrams, portionName: nil)
        }
    }

    private func saveRecipe() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines)

        let totalKcal = draftIngredients.reduce(0) { $0 + $1.kcal }
        let totalCarbs = draftIngredients.reduce(0) { $0 + $1.carbsG }
        let totalProtein = draftIngredients.reduce(0) { $0 + $1.proteinG }
        let totalFat = draftIngredients.reduce(0) { $0 + $1.fatG }
        let totalFibre = draftIngredients.reduce(0) { $0 + $1.fibreG }

        // Convert DraftIngredient -> RecipeIngredient (stored on the recipe)
        let recipeIngredients: [RecipeIngredient] = draftIngredients.map { d in
            RecipeIngredient(
                name: d.food.name,
                amountGrams: d.amountGrams,
                kcalPer100g: d.food.kcalPer100g,
                carbsPer100g: d.food.carbsPer100g,
                proteinPer100g: d.food.proteinPer100g,
                fatPer100g: d.food.fatPer100g,
                fibrePer100g: d.food.fibrePer100g
            )
        }

        let fingerprint = makeFingerprint(
            name: cleanTitle,
            totalKcal: totalKcal,
            totalCarbs: totalCarbs,
            totalProtein: totalProtein,
            totalFat: totalFat
        )

        if let existing = recipeToEdit {
            // EDIT mode
            existing.title = cleanTitle
            existing.categoryRaw = cleanCategory
            existing.photoData = photoData

            existing.caloriesKcal = totalKcal
            existing.carbsG = totalCarbs
            existing.proteinG = totalProtein
            existing.fatG = totalFat
            existing.fibreG = totalFibre

            existing.sourceFingerprint = fingerprint
            existing.updatedAt = Date()

            // Replace ingredients cleanly
            existing.ingredients.removeAll()
            existing.ingredients = recipeIngredients

            try? ctx.save()
            dismiss()
            return
        }

        // CREATE mode: de-dupe by fingerprint
        do {
            let existing = try ctx.fetch(FetchDescriptor<Recipe>())
            if existing.contains(where: { $0.sourceFingerprint == fingerprint }) {
                alertTitle = "Duplicate"
                alertMessage = "A recipe with the same name and totals already exists."
                showAlert = true
                return
            }
        } catch { }

        let recipe = Recipe(
            title: cleanTitle,
            categoryRaw: cleanCategory,
            caloriesKcal: totalKcal,
            carbsG: totalCarbs,
            proteinG: totalProtein,
            fatG: totalFat,
            fibreG: totalFibre,
            sourceFingerprint: fingerprint,
            photoData: photoData,
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

    // MARK: - Ingredient upsert / delete

    private func existingDraftForSelectedFood() -> DraftIngredient? {
        if let idx = selectedIngredientIndex, idx < draftIngredients.count {
            return draftIngredients[idx]
        }
        return nil
    }

    private func upsertIngredient(food: Food, grams: Double, portionName: String?) {
        let g = max(0, grams)

        if let idx = selectedIngredientIndex, idx < draftIngredients.count {
            // Editing an existing ingredient row
            draftIngredients[idx] = DraftIngredient(food: food, amountGrams: g, portionName: portionName)
            return
        }

        // If adding: if same food name exists already, replace it (keeps it simple)
        if let existingIdx = draftIngredients.firstIndex(where: { $0.food.name == food.name }) {
            draftIngredients[existingIdx] = DraftIngredient(food: food, amountGrams: g, portionName: portionName)
        } else {
            draftIngredients.append(DraftIngredient(food: food, amountGrams: g, portionName: portionName))
        }
    }

    private func deleteIngredients(at offsets: IndexSet) {
        draftIngredients.remove(atOffsets: offsets)
    }

    // MARK: - Photo loading

    private func loadPhoto(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.photoData = data
                }
            }
        } catch {
            await MainActor.run {
                alertTitle = "Photo failed"
                alertMessage = "Couldn’t load that image."
                showAlert = true
            }
        }
    }
}

// MARK: - DraftIngredient (local builder type)

private struct DraftIngredient: Identifiable {
    let id = UUID()
    var food: Food
    var amountGrams: Double
    var portionName: String?

    var kcal: Double { food.kcalPer100g * amountGrams / 100.0 }
    var carbsG: Double { food.carbsPer100g * amountGrams / 100.0 }
    var proteinG: Double { food.proteinPer100g * amountGrams / 100.0 }
    var fatG: Double { food.fatPer100g * amountGrams / 100.0 }
    var fibreG: Double { food.fibrePer100g * amountGrams / 100.0 }
}

// MARK: - Ingredient Amount Sheet

private struct IngredientAmountSheet: View {

    let food: Food
    let existing: DraftIngredient?
    let onSave: (_ grams: Double, _ portionName: String?) -> Void
    let onCancel: () -> Void

    @State private var grams: Double = 100
    @State private var usePortion: Bool = true
    @State private var portionName: String = ""
    @State private var portionGrams: Double = 100

    var body: some View {
        NavigationStack {
            Form {
                Section(food.name) {
                    Text("\(Int(food.kcalPer100g.rounded())) kcal per 100g • C \(Int(food.carbsPer100g.rounded()))g • P \(Int(food.proteinPer100g.rounded()))g • F \(Int(food.fatPer100g.rounded()))g • Fi \(Int(food.fibrePer100g.rounded()))g")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                Section("Amount") {
                    Toggle("Use portion (e.g. 1 medium)", isOn: $usePortion)

                    if usePortion {
                        TextField("Portion label", text: $portionName)

                        HStack {
                            Text("Portion grams")
                            Spacer()
                            TextField("", value: $portionGrams, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 90)
                        }

                        Button("Set grams from portion") {
                            grams = portionGrams
                        }
                    }

                    HStack {
                        Text("Grams used")
                        Spacer()
                        TextField("", value: $grams, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                    }
                }

                Section("This ingredient") {
                    Text(previewLine)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .navigationTitle(existing == nil ? "Add ingredient" : "Edit ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let label = usePortion ? portionName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
                        onSave(grams, label.isEmpty ? nil : label)
                    }
                }
            }
            .onAppear { seedDefaults() }
        }
    }

    private func seedDefaults() {
        if let existing {
            grams = existing.amountGrams
            if let pn = existing.portionName, !pn.isEmpty {
                usePortion = true
                portionName = pn
                portionGrams = existing.amountGrams
            } else {
                usePortion = false
                portionName = food.defaultPortionName ?? ""
                portionGrams = food.defaultPortionGrams ?? 100
            }
            return
        }

        // New ingredient default
        portionName = food.defaultPortionName ?? ""
        portionGrams = food.defaultPortionGrams ?? 100
        usePortion = (food.defaultPortionGrams != nil) || !(food.defaultPortionName ?? "").isEmpty
        grams = food.defaultPortionGrams ?? 100
    }

    private var previewLine: String {
        let g = max(0, grams)
        let kcal = food.kcalPer100g * g / 100.0
        let c = food.carbsPer100g * g / 100.0
        let p = food.proteinPer100g * g / 100.0
        let f = food.fatPer100g * g / 100.0
        let fi = food.fibrePer100g * g / 100.0

        return "\(Int(kcal.rounded())) kcal • C \(Int(c.rounded()))g • P \(Int(p.rounded()))g • F \(Int(f.rounded()))g • Fibre \(Int(fi.rounded()))g"
    }
}
