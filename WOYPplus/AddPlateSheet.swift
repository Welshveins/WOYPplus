import SwiftUI
import SwiftData
import Vision
import PhotosUI
import UIKit

struct AddPlateSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let day: Day

    @State private var title: String = ""
    @State private var when: Date = Date()

    @State private var mealSlot: MealSlot = MealSlot.defaultSlot(for: Date())
    @State private var userManuallyPickedSlot = false

    @AppStorage("addPlate_cropToCentre") private var cropToCentre: Bool = true
    @AppStorage("addPlate_addOns") private var addOnsRaw: String = ""

    @State private var addOns: Set<RichAddOn> = []

    // New Your Plate flow state
    @State private var suggestedMealName: String = ""
    @State private var portionSize: PortionSize = .standardPlate
    @State private var carbType: CarbType = .rice
    @State private var proteinType: ProteinType = .chicken
    @State private var vegType: VegType = .mixedVeg
    @State private var carbPercent: Double = 40
    @State private var proteinPercent: Double = 30
    @State private var vegPercent: Double = 30
    @State private var estimateAdjustment: EstimateAdjustment = .aboutRight

    // Photo
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uiImage: UIImage?

    // Analysis
    @State private var isAnalysing = false
    @State private var analysisLabel: String?
    @State private var lastVisionIdentifier: String?


    // Macros
    @State private var kcal: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var fibre: String = ""

    // Stop overwriting once user edits
    @State private var userLockedMacros = false
    @State private var isProgrammaticMacroFill = false
    @State private var macroRefreshPulse = false
    @State private var savePulse = false
    
    // MARK: - New Your Plate enums

    private enum PortionSize: String, CaseIterable, Identifiable, CustomStringConvertible {
        case smallPlate
        case standardPlate
        case largePlate
        case bowl
        case largeBowl

        var id: String { rawValue }

        var display: String {
            switch self {
            case .smallPlate: return "Small plate"
            case .standardPlate: return "Standard plate"
            case .largePlate: return "Large plate"
            case .bowl: return "Bowl"
            case .largeBowl: return "Large bowl"
            }
        }

        var description: String { display }

        var multiplier: Double {
            switch self {
            case .smallPlate: return 0.80
            case .standardPlate: return 1.00
            case .largePlate: return 1.25
            case .bowl: return 1.10
            case .largeBowl: return 1.35
            }
        }
    }
    private enum CarbType: String, CaseIterable, Identifiable, CustomStringConvertible {
        case rice
        case pasta
        case bread
        case potatoes
        case noodles
        case other
        var id: String { rawValue }
        var display: String {
            switch self {
            case .rice: return "Rice"
            case .pasta: return "Pasta"
            case .bread: return "Bread"
            case .potatoes: return "Potatoes"
            case .noodles: return "Noodles"
            case .other: return "Other"
            }
        }
        var description: String { display }
    }
    private enum ProteinType: String, CaseIterable, Identifiable, CustomStringConvertible {
        case chicken
        case fish
        case beef
        case pork
        case eggs
        case beansTofu
        case other
        var id: String { rawValue }
        var display: String {
            switch self {
            case .chicken: return "Chicken"
            case .fish: return "Fish"
            case .beef: return "Beef"
            case .pork: return "Pork"
            case .eggs: return "Eggs"
            case .beansTofu: return "Beans / tofu"
            case .other: return "Other"
            }
        }
        var description: String { display }
    }
    private enum VegType: String, CaseIterable, Identifiable, CustomStringConvertible {
        case mixedVeg
        case leafyVeg
        case rootVeg
        case salad
        case none
        case other
        var id: String { rawValue }
        var display: String {
            switch self {
            case .mixedVeg: return "Mixed veg"
            case .leafyVeg: return "Leafy veg"
            case .rootVeg: return "Root veg"
            case .salad: return "Salad"
            case .none: return "None"
            case .other: return "Other"
            }
        }
        var description: String { display }
    }
    private enum EstimateAdjustment: String, CaseIterable, Identifiable, CustomStringConvertible {
        case tooLow
        case aboutRight
        case tooHigh

        var id: String { rawValue }

        var display: String {
            switch self {
            case .tooLow: return "Too low"
            case .aboutRight: return "About right"
            case .tooHigh: return "Too high"
            }
        }

        var description: String { display }

        var multiplier: Double {
            switch self {
            case .tooLow: return 1.10
            case .aboutRight: return 1.00
            case .tooHigh: return 0.90
            }
        }
    }

    private func lightTapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    var body: some View {
        observedContent
    }

    private var observedContent: some View {
        baseView
    }

    private var baseView: some View {
        observedMacroView
    }

    private var navigationBaseView: some View {
        NavigationStack {
            presentedContent
        }
    }

    private var observedPrimaryView: some View {
        navigationBaseView
            .onAppear {
                mealSlot = MealSlot.defaultSlot(for: when)
                addOns = decodeAddOns(addOnsRaw)
                if suggestedMealName.isEmpty {
                    suggestedMealName = title
                }
            }
            .onChange(of: addOns) { _, newValue in
                addOnsRaw = encodeAddOns(newValue)
                guard !userLockedMacros else { return }
                reapplyEstimateFromCurrentSelections()
            }
            .onChange(of: portionSize) { _, _ in
                guard !userLockedMacros else { return }
                reapplyEstimateFromCurrentSelections()
            }
            .onChange(of: carbType) { _, _ in
                guard !userLockedMacros else { return }
                reapplyEstimateFromCurrentSelections()
            }
            .onChange(of: proteinType) { _, _ in
                guard !userLockedMacros else { return }
                reapplyEstimateFromCurrentSelections()
            }
            .onChange(of: vegType) { _, _ in
                guard !userLockedMacros else { return }
                reapplyEstimateFromCurrentSelections()
            }
            .onChange(of: carbPercent) { _, _ in
                balanceComposition(changed: .carb)
                guard !userLockedMacros else { return }
                reapplyEstimateFromCurrentSelections()
            }
            .onChange(of: proteinPercent) { _, _ in
                balanceComposition(changed: .protein)
                guard !userLockedMacros else { return }
                reapplyEstimateFromCurrentSelections()
            }
            .onChange(of: vegPercent) { _, _ in
                balanceComposition(changed: .veg)
                guard !userLockedMacros else { return }
                reapplyEstimateFromCurrentSelections()
            }
            .onChange(of: estimateAdjustment) { _, _ in
                guard !userLockedMacros else { return }
                reapplyEstimateFromCurrentSelections()
            }
            .onChange(of: when) { _, newValue in
                guard !userManuallyPickedSlot else { return }
                mealSlot = MealSlot.defaultSlot(for: newValue)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                loadImage(newItem)
            }
    }

    private var observedMacroView: some View {
        observedPrimaryView
            .onChange(of: kcal) { _, _ in if !isProgrammaticMacroFill { userLockedMacros = true } }
            .onChange(of: carbs) { _, _ in if !isProgrammaticMacroFill { userLockedMacros = true } }
            .onChange(of: protein) { _, _ in if !isProgrammaticMacroFill { userLockedMacros = true } }
            .onChange(of: fat) { _, _ in if !isProgrammaticMacroFill { userLockedMacros = true } }
            .onChange(of: fibre) { _, _ in if !isProgrammaticMacroFill { userLockedMacros = true } }
            .onChange(of: canSave) { _, newValue in
                guard newValue else { return }
                savePulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    savePulse = false
                }
            }
    }

    private var presentedContent: some View {
        contentForm
            .navigationTitle("Your plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingCamera) {
                CameraPicker { image in
                    uiImage = image
                    runVision(on: image)
                }
            }
    }
    private var contentForm: some View {
        Form {
            photoSection
            suggestedMealSection
            foodTypeSection
            compositionSection
            portionSizeSection
            whenSection
            mealSection
            modifiersSection
            estimateAdjustmentSection
            macrosSection
            infoSection
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
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

            Toggle("Focus on centre", isOn: $cropToCentre)
                .font(.footnote)

            if isAnalysing {
                HStack {
                    ProgressView()
                    Text("Analysing…")
                        .foregroundStyle(.secondary)
                }
            }

            if let analysisLabel {
                Text("Detected: \(analysisLabel)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }


    // New locked flow UI sections
    private var suggestedMealSection: some View {
        Section("Meal") {
            TextField("Meal name", text: mealNameBinding)

            if let analysisLabel {
                Text("Suggested from photo. You can edit this.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var portionSizeSection: some View {
        Section("Plate or bowl size") {
            horizontalPickerRow(title: "Size", options: PortionSize.allCases, selection: $portionSize)
        }
    }

    private var foodTypeSection: some View {
        Section("What is on the plate?") {
            horizontalPickerRow(title: "Carb", options: CarbType.allCases, selection: $carbType)
            horizontalPickerRow(title: "Protein", options: ProteinType.allCases, selection: $proteinType)
            horizontalPickerRow(title: "Veg", options: VegType.allCases, selection: $vegType)
        }
    }

    private var compositionSection: some View {
        Section("Plate composition") {
            percentageRow(title: "Carb", value: $carbPercent)
            percentageRow(title: "Protein", value: $proteinPercent)
            percentageRow(title: "Veg", value: $vegPercent)
        }
    }

    private var modifiersSection: some View {
        Section("Optional richness") {
            modifiersGrid
        }
    }

    private var estimateAdjustmentSection: some View {
        Section("Estimate") {
            Picker("Estimate", selection: $estimateAdjustment) {
                ForEach(EstimateAdjustment.allCases) { item in
                    Text(item.display).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var whenSection: some View {
        Section("When?") {
            DatePicker(
                "Date & time",
                selection: $when,
                displayedComponents: [.date, .hourAndMinute]
            )
        }
    }

    private var mealSection: some View {
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
    }

    // MARK: - Locked flow helpers

    private var mealNameBinding: Binding<String> {
        Binding(
            get: { suggestedMealName.isEmpty ? title : suggestedMealName },
            set: {
                suggestedMealName = $0
                title = $0
            }
        )
    }

    private var modifiersGrid: some View {
        ModifierChipGrid(
            addOns: $addOns,
            onTap: lightTapHaptic
        )
    }

    private func horizontalPickerRow<Option: Identifiable & CaseIterable & Hashable>(
        title: String,
        options: Option.AllCases,
        selection: Binding<Option>
    ) -> some View where Option: CustomStringConvertible {
        PickerChipRow(
            title: title,
            options: Array(options),
            selection: selection,
            onTap: lightTapHaptic
        )
    }

    private func percentageRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: 0...100, step: 5)
        }
    }

    private var macrosSection: some View {
        Section("Best guess") {
            MacroEstimateBlock(
                userLockedMacros: userLockedMacros,
                lastVisionIdentifier: lastVisionIdentifier,
                kcal: $kcal,
                carbs: $carbs,
                protein: $protein,
                fat: $fat,
                fibre: $fibre,
                macroRefreshPulse: macroRefreshPulse,
                onReapply: {
                    if let id = lastVisionIdentifier {
                        userLockedMacros = false
                        applyHeuristic(for: id)
                    }
                }
            )
        }
    }

    private var infoSection: some View {
        Section {
            Text("This entry is marked as an estimate. You can confirm or edit it later.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func save() {
        let entry = Entry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            mealSlot: mealSlot,
            carbsG: Double(carbs) ?? 0,
            proteinG: Double(protein) ?? 0,
            fatG: Double(fat) ?? 0,
            fibreG: Double(fibre) ?? 0,
            caloriesKcal: Double(kcal) ?? 0,
            isEstimate: true,
            day: day,
            recipe: nil,
            servings: 1,
            createdAt: when
        )

        ctx.insert(entry)
        try? ctx.save()
        dismiss()
    }

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? (savePulse ? 0.7 : 1.0) : 0.4)
                    .animation(.easeInOut(duration: 0.2), value: savePulse)
            }
        }
    }

    // MARK: - Vision

    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run { uiImage = image }
                runVision(on: image)
            }
        }
    }

    private func runVision(on image: UIImage) {
        let input = cropToCentre ? image.centerSquareCropped() : image
        guard let cg = input.cgImage else { return }

        DispatchQueue.main.async {
            isAnalysing = true
            analysisLabel = nil
            lastVisionIdentifier = nil
        }

        let request = VNClassifyImageRequest { request, _ in
            guard let results = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async { isAnalysing = false }
                return
            }

            let keywords = [
                "salad", "pizza", "burger", "pasta", "noodle", "spaghetti", "rice",
                "curry", "stew", "chili", "chilli", "sandwich", "wrap",
                "chocolate", "candy", "sweet"
            ]

            let best = results.first(where: { obs in
                let id = obs.identifier.lowercased()
                return obs.confidence > 0.10 && keywords.contains(where: { id.contains($0) })
            }) ?? results.first(where: { $0.confidence > 0.15 }) ?? results.first

            DispatchQueue.main.async {
                isAnalysing = false

                guard let best else {
                    analysisLabel = "Unknown"
                    return
                }

                analysisLabel = "\(best.identifier) (\(Int(best.confidence * 100))%)"
                lastVisionIdentifier = best.identifier

                let suggestion = suggestedMeal(from: best.identifier)
                suggestedMealName = suggestion
                title = suggestion

                guard !userLockedMacros else { return }
                applyHeuristic(for: best.identifier)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Heuristic mapping

    private func applyHeuristic(for label: String) {
        let _ = label.lowercased()
        reapplyEstimateFromCurrentSelections()
    }

    private enum ChangedComposition {
        case carb
        case protein
        case veg
    }

    private func balanceComposition(changed: ChangedComposition) {
        let total = carbPercent + proteinPercent + vegPercent
        guard total != 100 else { return }

        switch changed {
        case .carb:
            let remaining = max(0, 100 - carbPercent)
            let otherTotal = max(1, proteinPercent + vegPercent)
            proteinPercent = (proteinPercent / otherTotal) * remaining
            vegPercent = 100 - carbPercent - proteinPercent

        case .protein:
            let remaining = max(0, 100 - proteinPercent)
            let otherTotal = max(1, carbPercent + vegPercent)
            carbPercent = (carbPercent / otherTotal) * remaining
            vegPercent = 100 - proteinPercent - carbPercent

        case .veg:
            let remaining = max(0, 100 - vegPercent)
            let otherTotal = max(1, carbPercent + proteinPercent)
            carbPercent = (carbPercent / otherTotal) * remaining
            proteinPercent = 100 - vegPercent - carbPercent
        }

        carbPercent = (carbPercent / 5).rounded() * 5
        proteinPercent = (proteinPercent / 5).rounded() * 5
        vegPercent = max(0, 100 - carbPercent - proteinPercent)
    }

    private func reapplyEstimateFromCurrentSelections() {
        let carbWeight = max(0, carbPercent) / 100.0
        let proteinWeight = max(0, proteinPercent) / 100.0
        let vegWeight = max(0, vegPercent) / 100.0

        let carbBase = carbComponentMacros(for: carbType)
        let proteinBase = proteinComponentMacros(for: proteinType)
        let vegBase = vegComponentMacros(for: vegType)

        var adjusted = Macros(
            k: 0,
            c: (carbBase.c * carbWeight) + (proteinBase.c * proteinWeight) + (vegBase.c * vegWeight),
            p: (carbBase.p * carbWeight) + (proteinBase.p * proteinWeight) + (vegBase.p * vegWeight),
            f: (carbBase.f * carbWeight) + (proteinBase.f * proteinWeight) + (vegBase.f * vegWeight),
            fi: (carbBase.fi * carbWeight) + (proteinBase.fi * proteinWeight) + (vegBase.fi * vegWeight)
        )

        adjusted = adjusted.scaled(by: portionSize.multiplier)

        if !addOns.isEmpty {
            let addOnMultiplier = addOns.reduce(1.0) { $0 * $1.multiplier }
            adjusted = adjusted.scaled(by: addOnMultiplier)
        }

        adjusted = adjusted.scaled(by: estimateAdjustment.multiplier)
        adjusted.k = (adjusted.c * 4) + (adjusted.p * 4) + (adjusted.f * 9)

        fill(adjusted)
    }

    private func suggestedMeal(from label: String) -> String {
        let lower = label.lowercased()

        if lower.contains("pizza") { return "Pizza" }
        if lower.contains("burger") { return "Burger and fries" }
        if lower.contains("pasta") || lower.contains("spaghetti") { return "Pasta dish" }
        if lower.contains("noodle") { return "Noodle dish" }
        if lower.contains("rice") { return "Rice dish" }
        if lower.contains("curry") { return "Curry and rice" }
        if lower.contains("salad") { return "Salad bowl" }
        if lower.contains("sandwich") || lower.contains("wrap") { return "Sandwich or wrap" }
        if lower.contains("stew") || lower.contains("chilli") || lower.contains("chili") { return "Stew or chilli" }
        return "Your plate"
    }

    private func carbComponentMacros(for type: CarbType) -> Macros {
        switch type {
        case .rice:
            return Macros(k: 0, c: 90, p: 8, f: 2, fi: 3)
        case .pasta:
            return Macros(k: 0, c: 95, p: 14, f: 3, fi: 5)
        case .bread:
            return Macros(k: 0, c: 85, p: 16, f: 5, fi: 6)
        case .potatoes:
            return Macros(k: 0, c: 70, p: 8, f: 1, fi: 8)
        case .noodles:
            return Macros(k: 0, c: 90, p: 12, f: 4, fi: 4)
        case .other:
            return Macros(k: 0, c: 80, p: 10, f: 3, fi: 5)
        }
    }

    private func proteinComponentMacros(for type: ProteinType) -> Macros {
        switch type {
        case .chicken:
            return Macros(k: 0, c: 0, p: 55, f: 12, fi: 0)
        case .fish:
            return Macros(k: 0, c: 0, p: 45, f: 14, fi: 0)
        case .beef:
            return Macros(k: 0, c: 0, p: 45, f: 22, fi: 0)
        case .pork:
            return Macros(k: 0, c: 0, p: 42, f: 24, fi: 0)
        case .eggs:
            return Macros(k: 0, c: 3, p: 30, f: 24, fi: 0)
        case .beansTofu:
            return Macros(k: 0, c: 20, p: 30, f: 14, fi: 10)
        case .other:
            return Macros(k: 0, c: 5, p: 35, f: 16, fi: 3)
        }
    }

    private func vegComponentMacros(for type: VegType) -> Macros {
        switch type {
        case .mixedVeg:
            return Macros(k: 0, c: 18, p: 6, f: 1, fi: 8)
        case .leafyVeg:
            return Macros(k: 0, c: 10, p: 6, f: 1, fi: 7)
        case .rootVeg:
            return Macros(k: 0, c: 28, p: 5, f: 1, fi: 10)
        case .salad:
            return Macros(k: 0, c: 8, p: 4, f: 1, fi: 5)
        case .none:
            return Macros(k: 0, c: 0, p: 0, f: 0, fi: 0)
        case .other:
            return Macros(k: 0, c: 15, p: 5, f: 1, fi: 7)
        }
    }
    private func fill(_ m: Macros) {
        isProgrammaticMacroFill = true
        userLockedMacros = false

        withAnimation(.easeInOut(duration: 0.16)) {
            macroRefreshPulse = true
            kcal = "\(Int(m.k.rounded()))"
            carbs = "\(Int(m.c.rounded()))"
            protein = "\(Int(m.p.rounded()))"
            fat = "\(Int(m.f.rounded()))"
            fibre = "\(Int(m.fi.rounded()))"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            macroRefreshPulse = false
            isProgrammaticMacroFill = false
        }
    }

    


    private struct ModifierChipGrid: View {
        @Binding var addOns: Set<RichAddOn>
        let onTap: () -> Void

        var body: some View {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(RichAddOn.allCases) { addOn in
                    let isSelected = addOns.contains(addOn)

                    Button {
                        onTap()
                        if isSelected {
                            addOns.remove(addOn)
                        } else {
                            addOns.insert(addOn)
                        }
                    } label: {
                        Text(addOn.display)
                            .font(.system(size: 13, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .foregroundStyle(isSelected ? Color.woypTeal : Color.primary)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected
                                          ? Color.woypTeal.opacity(0.12)
                                          : Color.woypSlate.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(isSelected ? 0.18 : 0.10), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private struct PickerChipRow<Option: Identifiable & Hashable & CustomStringConvertible>: View {
        let title: String
        let options: [Option]
        @Binding var selection: Option
        let onTap: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options, id: \.id) { option in
                            let isSelected = selection == option

                            Button {
                                onTap()
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selection = option
                                }
                            } label: {
                                Text(option.description)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isSelected ? Color.woypTeal : Color.primary)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .fill(isSelected
                                                  ? Color.woypTeal.opacity(0.16)
                                                  : Color.woypSlate.opacity(0.07))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(isSelected ? 0.22 : 0.10), lineWidth: 1)
                                    )
                                    .scaleEffect(isSelected ? 1.04 : 1.0)
                                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private struct MacroEstimateBlock: View {
        let userLockedMacros: Bool
        let lastVisionIdentifier: String?
        @Binding var kcal: String
        @Binding var carbs: String
        @Binding var protein: String
        @Binding var fat: String
        @Binding var fibre: String
        let macroRefreshPulse: Bool
        let onReapply: () -> Void

        var body: some View {
            VStack(spacing: 12) {
                if userLockedMacros {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                        Text("Your edits are locked (Vision won’t overwrite).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                macroField("kcal", text: $kcal)
                macroField("Carbs (g)", text: $carbs)
                macroField("Protein (g)", text: $protein)
                macroField("Fat (g)", text: $fat)
                macroField("Fibre (g)", text: $fibre)

                if lastVisionIdentifier != nil {
                    Button(action: onReapply) {
                        Label("Re-apply estimate", systemImage: "wand.and.stars")
                    }
                }
            }
            .opacity(macroRefreshPulse ? 0.72 : 1.0)
            .scaleEffect(macroRefreshPulse ? 0.992 : 1.0)
            .animation(.easeInOut(duration: 0.16), value: macroRefreshPulse)
        }

        private func macroField(_ label: String, text: Binding<String>) -> some View {
            TextField(label, text: text)
                .keyboardType(.decimalPad)
        }
    }

        // MARK: - Persistence helpers (Add-ons)

    private func decodeAddOns(_ raw: String) -> Set<RichAddOn> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let parts = trimmed.split(separator: ",").map { String($0) }
        return Set(parts.compactMap { RichAddOn(rawValue: $0) })
    }

    private func encodeAddOns(_ set: Set<RichAddOn>) -> String {
        set.map(\.rawValue).sorted().joined(separator: ",")
    }
}



// MARK: - Camera (real device)

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

// MARK: - Centre crop (orientation-safe)

private extension UIImage {
    func centerSquareCropped() -> UIImage {
        let w = size.width
        let h = size.height
        let side = min(w, h)
        let originX = (w - side) / 2.0
        let originY = (h - side) / 2.0

        let cropRect = CGRect(x: originX, y: originY, width: side, height: side)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
    }
}
