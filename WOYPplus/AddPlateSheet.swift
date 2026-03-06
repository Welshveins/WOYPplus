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

    // Persisted settings
    @AppStorage("addPlate_cropToCentre") private var cropToCentre: Bool = true

    // Persisted nudges (B1)
    @AppStorage("addPlate_plateMix") private var plateMixRaw: String = ""        // empty = none selected
    @AppStorage("addPlate_vessel") private var vesselRaw: String = ""            // empty = none selected
    @AppStorage("addPlate_addOns") private var addOnsRaw: String = ""            // comma-separated raw values

    @State private var plateMix: PlateMix? = nil
    @State private var vessel: Vessel? = nil
    @State private var addOns: Set<RichAddOn> = []

    // Photo
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uiImage: UIImage?

    // Analysis
    @State private var isAnalysing = false
    @State private var analysisLabel: String?
    @State private var lastVisionIdentifier: String?

    // NEW: one-tap “about right” adjustment
    @State private var richnessAdjustment: Double = 1.0

    // Macros
    @State private var kcal: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var fibre: String = ""

    // Stop overwriting once user edits
    @State private var userLockedMacros = false

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                detailsSection
                whenSection
                mealSection
                macrosSection
                infoSection
            }
            .navigationTitle("Your plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear {
                mealSlot = MealSlot.defaultSlot(for: when)

                plateMix = plateMixRaw.isEmpty ? nil : PlateMix(rawValue: plateMixRaw)
                vessel = vesselRaw.isEmpty ? nil : Vessel(rawValue: vesselRaw)
                addOns = decodeAddOns(addOnsRaw)
                richnessAdjustment = 1.0
            }
            .onChange(of: plateMix) { _, newValue in
                plateMixRaw = newValue?.rawValue ?? ""
            }
            .onChange(of: vessel) { _, newValue in
                vesselRaw = newValue?.rawValue ?? ""
                if let id = lastVisionIdentifier {
                    userLockedMacros = false
                    applyHeuristic(for: id)
                }
            }
            .onChange(of: addOns) { _, newValue in
                addOnsRaw = encodeAddOns(newValue)
                if let id = lastVisionIdentifier {
                    userLockedMacros = false
                    applyHeuristic(for: id)
                }
            }
            .onChange(of: when) { _, newValue in
                guard !userManuallyPickedSlot else { return }
                mealSlot = MealSlot.defaultSlot(for: newValue)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                loadImage(newItem)
            }
            // Lock when user edits any macro field
            .onChange(of: kcal) { _, _ in userLockedMacros = true }
            .onChange(of: carbs) { _, _ in userLockedMacros = true }
            .onChange(of: protein) { _, _ in userLockedMacros = true }
            .onChange(of: fat) { _, _ in userLockedMacros = true }
            .onChange(of: fibre) { _, _ in userLockedMacros = true }
            .sheet(isPresented: $showingCamera) {
                CameraPicker { image in
                    uiImage = image
                    runVision(on: image)
                }
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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

            plateMixGrid

            vesselPicker

            addOnsGrid

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

    private var plateMixGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            ForEach(PlateMix.allCases) { mix in
                let isSelected = (plateMix == mix)

                Button {
                    plateMix = mix
                    if let id = lastVisionIdentifier {
                        userLockedMacros = false
                        applyHeuristic(for: id)
                    }
                } label: {
                    Text(mix.display)
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

    private var vesselPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vessel")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Vessel", selection: Binding<Vessel?>(
                get: { vessel },
                set: { vessel = $0 }
            )) {
                Text("None").tag(Vessel?.none)
                ForEach(Vessel.allCases) { v in
                    Text(v.display).tag(Optional(v))
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.top, 4)
    }

    private var addOnsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rich add-ons")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(RichAddOn.allCases) { a in
                    let isSelected = addOns.contains(a)

                    Button {
                        if isSelected {
                            addOns.remove(a)
                        } else {
                            addOns.insert(a)
                        }
                    } label: {
                        Text(a.display)
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
        .padding(.top, 2)
    }

    private var detailsSection: some View {
        Section {
            TextField("Description (optional)", text: $title)
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

    private var macrosSection: some View {
        Section("Best guess") {

            if userLockedMacros {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("Your edits are locked (Vision won’t overwrite).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            numberField("kcal", text: $kcal)
            numberField("Carbs (g)", text: $carbs)
            numberField("Protein (g)", text: $protein)
            numberField("Fat (g)", text: $fat)
            numberField("Fibre (g)", text: $fibre)

            if lastVisionIdentifier != nil {
                richnessAdjustmentRow
            }

            if let id = lastVisionIdentifier {
                Button {
                    userLockedMacros = false
                    applyHeuristic(for: id)
                } label: {
                    Label("Re-apply estimate", systemImage: "wand.and.stars")
                }
            }
        }
    }

    private var richnessAdjustmentRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Looks")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                richnessButton(title: "Lighter", value: 0.90)
                richnessButton(title: "About right", value: 1.0)
                richnessButton(title: "Richer", value: 1.10)
            }
        }
        .padding(.top, 4)
    }

    private func richnessButton(title: String, value: Double) -> some View {
        let isSelected = abs(richnessAdjustment - value) < 0.001

        return Button {
            guard let id = lastVisionIdentifier else { return }
            userLockedMacros = false
            richnessAdjustment = value
            applyHeuristic(for: id)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(1)
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

    private var infoSection: some View {
        Section {
            Text("This entry is marked as an estimate. You can confirm or edit it later.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
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
            richnessAdjustment = 1.0
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
                richnessAdjustment = 1.0

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
        let lower = label.lowercased()

        // Base guess (v1)
        var base = Macros(k: 600, c: 60, p: 30, f: 25, fi: 5)

        if lower.contains("chocolate") || lower.contains("candy") || lower.contains("sweet") {
            base = Macros(k: 260, c: 30, p: 3, f: 14, fi: 2)
        } else if lower.contains("pizza") {
            base = Macros(k: 800, c: 90, p: 35, f: 35, fi: 5)
        } else if lower.contains("burger") {
            base = Macros(k: 750, c: 60, p: 40, f: 45, fi: 4)
        } else if lower.contains("pasta") || lower.contains("noodle") {
            base = Macros(k: 700, c: 100, p: 25, f: 20, fi: 5)
        } else if lower.contains("rice") {
            base = Macros(k: 650, c: 105, p: 20, f: 15, fi: 4)
        } else if lower.contains("curry") || lower.contains("stew") || lower.contains("chilli") {
            base = Macros(k: 750, c: 80, p: 35, f: 30, fi: 6)
        } else if lower.contains("salad") {
            base = Macros(k: 350, c: 20, p: 15, f: 25, fi: 6)
        } else if lower.contains("sandwich") || lower.contains("wrap") {
            base = Macros(k: 550, c: 55, p: 25, f: 22, fi: 5)
        }

        // Apply Plate Mix (if selected)
        var adjusted = plateMix?.apply(to: base) ?? base

        // Apply Vessel (if selected)
        if let vessel {
            adjusted = adjusted.scaled(by: vessel.multiplier)
        }

        // Apply Add-ons (if any selected)
        if !addOns.isEmpty {
            let mul = addOns.reduce(1.0) { $0 * $1.multiplier }
            adjusted = adjusted.scaled(by: mul)
        }

        // NEW: apply lighter / about right / richer
        adjusted = adjusted.scaled(by: richnessAdjustment)

        fill(adjusted)
    }

    private func fill(_ m: Macros) {
        userLockedMacros = false
        kcal = "\(Int(m.k.rounded()))"
        carbs = "\(Int(m.c.rounded()))"
        protein = "\(Int(m.p.rounded()))"
        fat = "\(Int(m.f.rounded()))"
        fibre = "\(Int(m.fi.rounded()))"
    }

    // MARK: - Save

    private var canSave: Bool {
        let k = Double(kcal) ?? 0
        let c = Double(carbs) ?? 0
        let p = Double(protein) ?? 0
        let f = Double(fat) ?? 0
        return (k > 0) || (c + p + f > 0)
    }

    private func numberField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .keyboardType(.decimalPad)
    }

    private func ensureDay(for date: Date) -> Day {
        let start = Day.startOfDay(for: date)

        let all = (try? ctx.fetch(FetchDescriptor<Day>())) ?? []
        if let existing = all.first(where: { Day.startOfDay(for: $0.date) == start }) {
            return existing
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

        entry.createdAt = when
        ctx.insert(entry)

        targetDay.hasEstimates = true
        try? ctx.save()
        dismiss()
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

// MARK: - Vessel (B1 nudges)

private enum Vessel: String, CaseIterable, Identifiable {
    case smallPlate
    case largePlate
    case bowl

    var id: String { rawValue }

    var display: String {
        switch self {
        case .smallPlate: return "Small plate"
        case .largePlate: return "Large plate"
        case .bowl:       return "Bowl"
        }
    }

    /// Deterministic multiplier on the baseline estimate.
    var multiplier: Double {
        switch self {
        case .smallPlate: return 0.90
        case .largePlate: return 1.15
        case .bowl:       return 1.05
        }
    }
}

// MARK: - Rich add-ons (B1 nudges)

private enum RichAddOn: String, CaseIterable, Identifiable {
    case oil
    case cream
    case cheese
    case sauceHeavy
    case nuts

    var id: String { rawValue }

    var display: String {
        switch self {
        case .oil:        return "Oil"
        case .cream:      return "Cream"
        case .cheese:     return "Cheese"
        case .sauceHeavy: return "Sauce-heavy"
        case .nuts:       return "Nuts"
        }
    }

    /// Deterministic multipliers (applied cumulatively).
    var multiplier: Double {
        switch self {
        case .oil:        return 1.08
        case .cream:      return 1.07
        case .cheese:     return 1.06
        case .sauceHeavy: return 1.10
        case .nuts:       return 1.08
        }
    }
}

// MARK: - Plate mix

private enum PlateMix: String, CaseIterable, Identifiable {
    case balanced
    case carbProtein
    case mostlyCarb
    case mostlyProtein
    case dessertSnack

    var id: String { rawValue }

    var display: String {
        switch self {
        case .balanced:      return "Mixed"
        case .carbProtein:   return "Carb + Protein"
        case .mostlyCarb:    return "Mostly carb"
        case .mostlyProtein: return "Mostly protein"
        case .dessertSnack:  return "Dessert"
        }
    }

    func apply(to base: Macros) -> Macros {
        switch self {
        case .balanced:
            return base
        case .carbProtein:
            return Macros(
                k: base.k * 1.08,
                c: base.c * 1.02,
                p: base.p * 1.18,
                f: base.f * 1.05,
                fi: max(2, base.fi - 1)
            )
        case .mostlyCarb:
            return Macros(
                k: base.k * 1.05,
                c: base.c * 1.25,
                p: base.p * 0.80,
                f: base.f * 0.95,
                fi: base.fi
            )
        case .mostlyProtein:
            return Macros(
                k: base.k * 1.05,
                c: base.c * 0.70,
                p: base.p * 1.35,
                f: base.f * 1.10,
                fi: base.fi
            )
        case .dessertSnack:
            return Macros(
                k: base.k * 0.75,
                c: base.c * 1.10,
                p: max(2, base.p * 0.55),
                f: base.f * 1.10,
                fi: max(1, base.fi * 0.6)
            )
        }
    }
}

private struct Macros {
    var k: Double
    var c: Double
    var p: Double
    var f: Double
    var fi: Double

    func scaled(by m: Double) -> Macros {
        Macros(
            k: k * m,
            c: c * m,
            p: p * m,
            f: f * m,
            fi: max(0, fi * m)
        )
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
