import SwiftUI
import SwiftData
import AVFoundation

struct RecipeBuilderView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let existingRecipe: Recipe?

    @State private var title: String = ""
    @State private var categoryRaw: String = "Dinner"

    // Servings this recipe makes
    @State private var servings: Double = 1

    @State private var draftIngredients: [DraftIngredient] = []

    // Add-ingredient flow
    private enum ActiveSheet: Identifiable {
        case pickFood
        case pickFoodMyFoods
        case scanBarcode
        case manualFood(prefillBarcode: String?)
        case portion(food: Food)

        var id: String {
            switch self {
            case .pickFood: return "pickFood"
            case .pickFoodMyFoods: return "pickFoodMyFoods"
            case .scanBarcode: return "scanBarcode"
            case .manualFood(let code): return "manualFood-\(code ?? "nil")"
            case .portion(let food): return "portion-\(food.persistentModelID)"
            }
        }
    }
    @State private var activeSheet: ActiveSheet?

    @State private var showingAddIngredientMenu = false

    // Alerts
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

            // Add ingredient chooser
            .confirmationDialog(
                "Add ingredient",
                isPresented: $showingAddIngredientMenu,
                titleVisibility: .visible
            ) {
                Button("Scan barcode") { activeSheet = .scanBarcode }
                Button("Manual entry") { activeSheet = .manualFood(prefillBarcode: nil) }
                Button("Basics") { activeSheet = .pickFood }
                Button("My foods") { activeSheet = .pickFoodMyFoods }
                Button("Cancel", role: .cancel) {}
            }

            // Sheets
            .sheet(item: $activeSheet) { sheet in
                switch sheet {

                case .pickFood:
                    NavigationStack {
                        FoodLibraryView { pick in
                            addDraftIngredient(from: pick)
                            activeSheet = nil
                        }
                    }

                case .pickFoodMyFoods:
                    // For now this uses the same Food library list.
                    // “My foods” are the ones you manually create (saved into Food).
                    NavigationStack {
                        FoodLibraryView { pick in
                            addDraftIngredient(from: pick)
                            activeSheet = nil
                        }
                        .navigationTitle("My foods")
                    }

                case .scanBarcode:
                    RecipeBarcodeScannerView(
                        onFound: { code in
                            // route to manual entry with prefilled code
                            activeSheet = .manualFood(prefillBarcode: code)
                        },
                        onError: { msg in
                            alertTitle = "Barcode scanner"
                            alertMessage = msg
                            showAlert = true
                            activeSheet = nil
                        }
                    )

                case .manualFood(let prefillBarcode):
                    NavigationStack {
                        ManualFoodEntryView(
                            prefillBarcode: prefillBarcode,
                            onSaved: { newFood in
                                // after saving a Food, go straight to portion selection
                                activeSheet = .portion(food: newFood)
                            }
                        )
                    }

                case .portion(let food):
                    FoodPortionSheet(
                        food: food,
                        initialGrams: food.defaultPortionGrams ?? 100
                    ) { grams in
                        let g = max(0, grams)
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
                showingAddIngredientMenu = true
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
            servings: servings,
            caloriesKcal: perServingKcal,
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

////////////////////////////////////////////////////////////////
// MARK: - Manual food entry (creates a Food, saved to “My foods”)
////////////////////////////////////////////////////////////////

private struct ManualFoodEntryView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let prefillBarcode: String?
    let onSaved: (Food) -> Void

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
                if prefillBarcode != nil {
                    TextField("Barcode (optional)", text: $barcode)
                        .font(.footnote.monospaced())
                } else {
                    TextField("Barcode (optional)", text: $barcode)
                        .font(.footnote.monospaced())
                }
            }

            Section("Macros per 100g") {
                numberField("kcal", text: $kcalPer100g)
                numberField("Carbs (g)", text: $carbsPer100g)
                numberField("Protein (g)", text: $proteinPer100g)
                numberField("Fat (g)", text: $fatPer100g)
                numberField("Fibre (g)", text: $fibrePer100g)
            }

            Section("Default portion (optional)") {
                TextField("Portion name (e.g. 1 pot)", text: $portionName)
                numberField("Portion grams", text: $portionGrams)
            }

            Button("Save food") { save() }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .navigationTitle("New food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
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
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }

        let food = Food(
            name: n,
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

///////////////////////////////////////////////////////////////
// MARK: - Barcode scanner (capture only) — UNIQUE NAMES
///////////////////////////////////////////////////////////////

private struct RecipeBarcodeScannerView: View {

    @Environment(\.dismiss) private var dismiss

    let onFound: (String) -> Void
    let onError: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                RecipeBarcodeScannerRepresentable(
                    onFound: { code in
                        onFound(code)
                    },
                    onError: { msg in
                        onError(msg)
                    }
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    Text("Scan a barcode")
                        .font(.headline)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct RecipeBarcodeScannerRepresentable: UIViewControllerRepresentable {

    let onFound: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .black

        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video) else {
            onError("No camera available.")
            return vc
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            onError("Camera input failed: \(error.localizedDescription)")
            return vc
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) { session.addOutput(output) }

        output.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
        output.metadataObjectTypes = [
            .ean8, .ean13, .upce,
            .code39, .code93, .code128,
            .qr, .dataMatrix, .pdf417, .aztec
        ]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = vc.view.bounds
        vc.view.layer.addSublayer(preview)

        context.coordinator.session = session
        context.coordinator.previewLayer = preview

        session.startRunning()
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.previewLayer?.frame = uiViewController.view.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFound: onFound, onError: onError)
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onFound: (String) -> Void
        let onError: (String) -> Void

        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?

        private var didEmit = false

        init(onFound: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onFound = onFound
            self.onError = onError
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {

            guard !didEmit else { return }

            if let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let code = obj.stringValue,
               !code.isEmpty {

                didEmit = true
                session?.stopRunning()
                onFound(code)
            }
        }
    }
}
