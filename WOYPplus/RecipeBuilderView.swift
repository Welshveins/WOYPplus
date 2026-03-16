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

    // Ingredient editing
    @State private var editingIngredient: DraftIngredient?

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
            .sheet(item: $editingIngredient) { ingredient in
                NavigationStack {
                    EditDraftIngredientSheet(
                        ingredient: ingredient,
                        onSave: { updated in
                            updateDraftIngredient(updated)
                            editingIngredient = nil
                        },
                        onDelete: {
                            deleteDraft(ingredient)
                            editingIngredient = nil
                        },
                        onClose: {
                            editingIngredient = nil
                        }
                    )
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


    // MARK: - Main sections

    
    // MARK: - RecipeBuilder sections kept local for now

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
                    Button {
                        editingIngredient = d
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(d.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("\(Int(d.amountGrams.rounded())) g • \(Int(d.kcalPer100g.rounded())) kcal/100g")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteDraft(d)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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

    // MARK: - Totals

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

    // MARK: - Edit mode hydration

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

    // MARK: - Draft ingredient helpers

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

    private func updateDraftIngredient(_ updated: DraftIngredient) {
        guard let idx = draftIngredients.firstIndex(where: { $0.id == updated.id }) else { return }
        draftIngredients[idx] = updated
    }

    private func deleteDraft(_ d: DraftIngredient) {
        draftIngredients.removeAll { $0.id == d.id }
    }

    // MARK: - Save / update recipe

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


// MARK: - Builder support models
// MARK: - Draft ingredient

struct DraftIngredient: Identifiable, Hashable {
    let id: UUID
    var name: String
    var amountGrams: Double
    var kcalPer100g: Double
    var carbsPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var fibrePer100g: Double
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
