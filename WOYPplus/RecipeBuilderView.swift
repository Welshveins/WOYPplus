import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import AVFoundation

struct RecipeBuilderView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let existingRecipe: Recipe?

    @State private var title: String = ""
    @State private var categoryRaw: String = "Dinner"
    @State private var servings: Double = 1
    @State private var draftIngredients: [DraftIngredient] = []

    // Photo
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uiImage: UIImage?
    @State private var photoData: Data?

    // Sheets
    private enum ActiveSheet: Identifiable {
        case addIngredientSource
        case scanBarcode
        case manualFood(prefillBarcode: String?)
        case pickBasics
        case pickMyFoods
        case pickAllFoods
        case portion(food: Food)

        var id: String {
            switch self {
            case .addIngredientSource: return "addIngredientSource"
            case .scanBarcode: return "scanBarcode"
            case .manualFood(let code): return "manualFood-\(code ?? "nil")"
            case .pickBasics: return "pickBasics"
            case .pickMyFoods: return "pickMyFoods"
            case .pickAllFoods: return "pickAllFoods"
            case .portion(let food): return "portion-\(food.persistentModelID)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet?

    // Alert
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    init(existingRecipe: Recipe? = nil, defaultCategoryRaw: String? = nil) {
        self.existingRecipe = existingRecipe
        self._categoryRaw = State(initialValue: defaultCategoryRaw ?? "Dinner")
    }

    var body: some View {
        NavigationStack {
            List {
                photoSection
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
                    // ✅ CHANGE:
                    // - New recipe: must have title + at least 1 ingredient
                    // - Edit recipe: title is enough (allows updating photo only)
                    .disabled(
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || (existingRecipe == nil && draftIngredients.isEmpty)
                    )
                }
            }
            .onAppear { hydrateFromExistingIfNeeded() }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {

                case .addIngredientSource:
                    NavigationStack {
                        AddIngredientSourceView(
                            onScanBarcode: { activeSheet = .scanBarcode },
                            onManual: { activeSheet = .manualFood(prefillBarcode: nil) },
                            onBasics: { activeSheet = .pickBasics },
                            onMyFoods: { activeSheet = .pickMyFoods },
                            onAllFoods: { activeSheet = .pickAllFoods },
                            onClose: { activeSheet = nil }
                        )
                    }

                case .scanBarcode:
                    NavigationStack {
                        RecipeBarcodeLookupView(
                            onPickedFood: { food in
                                activeSheet = .portion(food: food)
                            },
                            onCancel: { activeSheet = nil }
                        )
                    }

                case .manualFood(let prefill):
                    NavigationStack {
                        ManualFoodEntryView(prefillBarcode: prefill) { newFood in
                            activeSheet = .portion(food: newFood)
                        } onClose: {
                            activeSheet = nil
                        }
                    }

                case .pickBasics:
                    NavigationStack {
                        FoodPickerListView(mode: .basics) { food in
                            activeSheet = .portion(food: food)
                        } onClose: {
                            activeSheet = nil
                        }
                    }

                case .pickMyFoods:
                    NavigationStack {
                        FoodPickerListView(mode: .myFoods) { food in
                            activeSheet = .portion(food: food)
                        } onClose: {
                            activeSheet = nil
                        }
                    }

                case .pickAllFoods:
                    NavigationStack {
                        FoodPickerListView(mode: .allFoods) { food in
                            activeSheet = .portion(food: food)
                        } onClose: {
                            activeSheet = nil
                        }
                    }

                case .portion(let food):
                    FoodPortionSheet(
                        food: food,
                        initialGrams: food.defaultPortionGrams ?? 100
                    ) { grams in
                        let g = max(0, grams)
                        guard g > 0 else { return }

                        let pick = FoodPickResult(
                            foodName: food.name,
                            grams: g,
                            portionLabel: food.defaultPortionName,
                            kcal: food.kcalPer100g * g / 100.0,
                            carbsG: food.carbsPer100g * g / 100.0,
                            proteinG: food.proteinPer100g * g / 100.0,
                            fatG: food.fatPer100g * g / 100.0,
                            fibreG: food.fibrePer100g * g / 100.0
                        )

                        addDraftIngredient(from: pick)
                        activeSheet = nil
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker { image in
                    uiImage = image
                    photoData = image.jpegData(compressionQuality: 0.85)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                loadImage(newItem)
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section("Photo") {

            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.woypSlate.opacity(0.07))
                    .frame(height: 190)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("Add a photo (optional)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    )
            }

            HStack(spacing: 12) {
                Button { showingCamera = true } label: {
                    Label("Take photo", systemImage: "camera")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose photo", systemImage: "photo")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            if uiImage != nil {
                Button(role: .destructive) {
                    uiImage = nil
                    photoData = nil
                } label: {
                    Label("Remove photo", systemImage: "trash")
                }
            }
        }
    }

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
                activeSheet = .addIngredientSource
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

        if let data = r.photoData, let img = UIImage(data: data) {
            photoData = data
            uiImage = img
        } else {
            photoData = nil
            uiImage = nil
        }

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

    // MARK: - Photo loading

    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    uiImage = image
                    photoData = image.jpegData(compressionQuality: 0.85) ?? data
                }
            }
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
            r.photoData = photoData
            try? ctx.save()
            dismiss()
            return
        }

        let recipe = Recipe(
            title: trimmedTitle,
            categoryRaw: categoryRaw,
            servings: servings,
            caloriesKcal: perServingKcal,
            carbsG: perServingCarbs,
            proteinG: perServingProtein,
            fatG: perServingFat,
            fibreG: perServingFibre,
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

//////////////////////////////////////////////////////////////////
/// MARK: - Add ingredient source picker
//////////////////////////////////////////////////////////////////

private struct AddIngredientSourceView: View {

    let onScanBarcode: () -> Void
    let onManual: () -> Void
    let onBasics: () -> Void
    let onMyFoods: () -> Void
    let onAllFoods: () -> Void
    let onClose: () -> Void

    var body: some View {
        List {
            Section {
                Text("Choose the fastest way to add an ingredient.")
                    .foregroundStyle(.secondary)
            }

            Section("Add ingredient") {
                Button { onScanBarcode() } label: {
                    Label("Scan barcode", systemImage: "barcode.viewfinder")
                }

                Button { onManual() } label: {
                    Label("Manual entry", systemImage: "square.and.pencil")
                }

                Button { onBasics() } label: {
                    Label("Basics", systemImage: "list.bullet")
                }

                Button { onMyFoods() } label: {
                    Label("My foods", systemImage: "person.crop.circle")
                }

                Button { onAllFoods() } label: {
                    Label("Add ingredient (foods)", systemImage: "fork.knife")
                }
            }
        }
        .navigationTitle("Add ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onClose() }
            }
        }
    }
}

//////////////////////////////////////////////////////////////////
/// MARK: - Food picker list (Basics / My foods / All)
//////////////////////////////////////////////////////////////////

private struct FoodPickerListView: View {

    enum Mode {
        case basics
        case myFoods
        case allFoods

        var title: String {
            switch self {
            case .basics: return "Basics"
            case .myFoods: return "My foods"
            case .allFoods: return "Foods"
            }
        }
    }

    @Environment(\.modelContext) private var ctx
    @Query(sort: \Food.createdAt, order: .forward) private var foodsByCreatedAt: [Food]
    @Query(sort: \Food.name) private var foodsByName: [Food]

    let mode: Mode
    let onPick: (Food) -> Void
    let onClose: () -> Void

    @State private var queryText = ""

    var body: some View {
        List {
            Section {
                TextField("Search foods", text: $queryText)
            }

            if filtered.isEmpty {
                Section {
                    Text("No foods found.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(mode.title) {
                    ForEach(filtered) { f in
                        Button {
                            onPick(f)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.name)
                                    .font(.headline)

                                Text("\(Int(f.kcalPer100g.rounded())) kcal per 100g")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onClose() }
            }
        }
        .task {
            FoodSeeder.seedIfNeeded(into: ctx)
        }
    }

    private var baseList: [Food] {
        switch mode {
        case .allFoods:
            return foodsByName

        case .basics:
            let earliest = Array(foodsByCreatedAt.prefix(60))
            return earliest.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        case .myFoods:
            let latest = Array(foodsByCreatedAt.suffix(80))
            return latest.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private var filtered: [Food] {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return baseList }
        return baseList.filter { $0.name.lowercased().contains(q) }
    }
}

//////////////////////////////////////////////////////////////////
/// MARK: - Manual food entry (creates Food, then returns it)
//////////////////////////////////////////////////////////////////

private struct ManualFoodEntryView: View {

    @Environment(\.modelContext) private var ctx

    let prefillBarcode: String?
    let onSaved: (Food) -> Void
    let onClose: () -> Void

    @State private var name = ""
    @State private var barcode = ""

    @State private var kcalPer100g = ""
    @State private var carbsPer100g = ""
    @State private var proteinPer100g = ""
    @State private var fatPer100g = ""
    @State private var fibrePer100g = ""

    @State private var portionName = ""
    @State private var portionGrams = ""

    var body: some View {
        Form {

            if !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                Section {
                    Text(barcode)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)

                } header: {
                    Text("Barcode")

                } footer: {
                    Text("Barcode capture only (no lookup yet).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Food") {
                TextField("Name", text: $name)

                TextField("Barcode (optional)", text: $barcode)
                    .font(.footnote.monospaced())
            }

            Section("Macros per 100g") {
                numberField("kcal / 100g", text: $kcalPer100g)
                numberField("Carbs (g)", text: $carbsPer100g)
                numberField("Protein (g)", text: $proteinPer100g)
                numberField("Fat (g)", text: $fatPer100g)
                numberField("Fibre (g)", text: $fibrePer100g)
            }

            Section("Default portion (optional)") {
                TextField("Portion label (e.g. 1 egg)", text: $portionName)
                numberField("Portion grams (e.g. 60)", text: $portionGrams)
            }

            Button("Save food") {
                save()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("Manual food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onClose() }
            }
        }
        .onAppear {
            if let prefillBarcode, !prefillBarcode.isEmpty {
                barcode = prefillBarcode
            }
        }
    }

    private func numberField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .keyboardType(.decimalPad)
    }

    private func save() {
        let safeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty else { return }

        let food = Food(
            name: safeName,
            kcalPer100g: Double(kcalPer100g) ?? 0,
            carbsPer100g: Double(carbsPer100g) ?? 0,
            proteinPer100g: Double(proteinPer100g) ?? 0,
            fatPer100g: Double(fatPer100g) ?? 0,
            fibrePer100g: Double(fibrePer100g) ?? 0,
            defaultPortionName: portionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : portionName,
            defaultPortionGrams: Double(portionGrams)
        )

        ctx.insert(food)
        try? ctx.save()

        onSaved(food)
    }
}

//////////////////////////////////////////////////////////////////
/// MARK: - Barcode lookup (camera + OpenFoodFacts -> Food)
//////////////////////////////////////////////////////////////////

private struct RecipeBarcodeLookupView: View {

    @Environment(\.modelContext) private var ctx

    let onPickedFood: (Food) -> Void
    let onCancel: () -> Void

    @State private var last = ""
    @State private var scannedCode: String?
    @State private var product: OFFProduct?
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let product {
                foundProductView(product)
            } else {
                ZStack {
                    BarcodeScannerRepresentable(
                        onFound: { code in
                            guard !code.isEmpty else { return }
                            guard code != last else { return }
                            last = code
                            scannedCode = code
                            lookup(code)
                        },
                        onError: { err in
                            errorText = err.localizedDescription
                        }
                    )
                    .ignoresSafeArea()

                    overlay
                }
                .navigationTitle("Scan barcode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { onCancel() }
                    }
                }
            }
        }
    }

    private var overlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 10) {
                Text("Scan a barcode")
                    .font(.headline)

                if isLoading {
                    Text("Looking up…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Hold the barcode in the frame.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Cancel") { onCancel() }
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.55))
            )
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.bottom, 22)
        }
    }

    private func foundProductView(_ product: OFFProduct) -> some View {
        let n = product.nutriments

        return Form {
            Section("Product") {
                Text(product.displayName)
                if let b = product.brands, !b.isEmpty {
                    Text(b)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let c = product.code, !c.isEmpty {
                    Text("Barcode: \(c)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Per 100 g") {
                row("kcal", n?.energyKcal_100g)
                row("Carbs (g)", n?.carbohydrates_100g)
                row("Protein (g)", n?.proteins_100g)
                row("Fat (g)", n?.fat_100g)
                row("Fibre (g)", n?.fiber_100g)
            }

            Section {
                Button("Use as ingredient") {
                    createFood(from: product)
                }
                .disabled(!(n?.hasUsableCore ?? false))

                Button("Scan again") {
                    self.product = nil
                    self.scannedCode = nil
                    self.errorText = nil
                    self.isLoading = false
                    self.last = ""
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Barcode found")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onCancel() }
            }
        }
    }

    private func row(_ label: String, _ v: Double?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(v.map { "\(Int($0.rounded()))" } ?? "—")
                .foregroundStyle(.secondary)
        }
    }

    private func lookup(_ code: String) {
        Task {
            isLoading = true
            errorText = nil
            defer { isLoading = false }

            do {
                if let p = try await OpenFoodFactsAPI.fetchByBarcode(code) {
                    if let n = p.nutriments, n.hasUsableCore {
                        product = p
                    } else {
                        errorText = "No usable nutrition data found."
                    }
                } else {
                    errorText = "No product found."
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func createFood(from product: OFFProduct) {
        guard let n = product.nutriments, n.hasUsableCore else { return }

        let food = Food(
            name: product.displayName,
            kcalPer100g: n.energyKcal_100g ?? 0,
            carbsPer100g: n.carbohydrates_100g ?? 0,
            proteinPer100g: n.proteins_100g ?? 0,
            fatPer100g: n.fat_100g ?? 0,
            fibrePer100g: n.fiber_100g ?? 0,
            defaultPortionName: nil,
            defaultPortionGrams: nil
        )

        ctx.insert(food)
        try? ctx.save()

        onPickedFood(food)
    }
}

//////////////////////////////////////////////////////////////////
/// MARK: - Barcode capture (camera)
//////////////////////////////////////////////////////////////////

private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {

    let onFound: (String) -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onFound = onFound
        vc.onError = onError
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}

    final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

        var onFound: ((String) -> Void)?
        var onError: ((Error) -> Void)?

        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configure()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        private func configure() {
            do {
                guard let device = AVCaptureDevice.default(for: .video) else {
                    throw NSError(domain: "BarcodeScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "No camera available"])
                }

                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) { session.addInput(input) }

                let output = AVCaptureMetadataOutput()
                if session.canAddOutput(output) { session.addOutput(output) }

                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                output.metadataObjectTypes = [
                    .ean8, .ean13, .upce,
                    .code39, .code93, .code128,
                    .qr, .pdf417, .dataMatrix, .aztec
                ]

                let preview = AVCaptureVideoPreviewLayer(session: session)
                preview.videoGravity = .resizeAspectFill
                view.layer.addSublayer(preview)
                previewLayer = preview

                session.startRunning()

            } catch {
                onError?(error)
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = obj.stringValue else { return }
            onFound?(code)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning { session.stopRunning() }
        }
    }
}

//////////////////////////////////////////////////////////////////
/// MARK: - Camera (real device)
//////////////////////////////////////////////////////////////////

private struct CameraPicker: UIViewControllerRepresentable {

    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                onImage(img)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
