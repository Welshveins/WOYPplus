// AddPlateSheet.swift (FULL FILE REPLACEMENT)
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
    @AppStorage("addPlate_plateMix") private var plateMixRaw: String = PlateMix.balanced.rawValue

    // Keep simple state for segmented picker (prevents type-check blowups)
    @State private var plateMix: PlateMix = .balanced

    // Photo
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uiImage: UIImage?

    // Analysis
    @State private var isAnalysing = false
    @State private var analysisLabel: String?
    @State private var lastSuggestedMacros: Macros?

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
                plateMix = PlateMix(rawValue: plateMixRaw) ?? .balanced
            }
            .onChange(of: plateMix) { _, newValue in
                plateMixRaw = newValue.rawValue

                // If we already have a suggestion, re-apply it through the new mix (unless user locked)
                guard !userLockedMacros else { return }
                if let s = lastSuggestedMacros {
                    let adjusted = plateMix.apply(to: s)
                    fill(adjusted, markUnlocked: false)
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

            Picker("Plate mix", selection: $plateMix) {
                ForEach(PlateMix.allCases) { m in
                    Text(m.display).tag(m)
                }
            }
            .pickerStyle(.segmented)

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

            if lastSuggestedMacros != nil {
                Button {
                    userLockedMacros = false
                    if let s = lastSuggestedMacros {
                        let adjusted = plateMix.apply(to: s)
                        fill(adjusted, markUnlocked: true)
                    }
                } label: {
                    Label("Re-apply estimate", systemImage: "wand.and.stars")
                }
            }
        }
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
            lastSuggestedMacros = nil
        }

        let request = VNClassifyImageRequest { request, _ in
            guard let results = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async { isAnalysing = false }
                return
            }

            // Build a multi-label list for mixed-plate tagging
            let labels: [PlateMacroTagger.Label] = results
                .prefix(20)
                .map { PlateMacroTagger.Label(identifier: $0.identifier, confidence: Double($0.confidence)) }

            let estimate = PlateMacroTagger.estimate(from: labels)
            let base = Macros(
                k: estimate.macros.k,
                c: estimate.macros.c,
                p: estimate.macros.p,
                f: estimate.macros.f,
                fi: estimate.macros.fi
            )
            let adjusted = plateMix.apply(to: base)

            DispatchQueue.main.async {
                isAnalysing = false

                analysisLabel = estimate.detectedSummary
                lastSuggestedMacros = base

                guard !userLockedMacros else { return }
                fill(adjusted, markUnlocked: true)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try? handler.perform([request])
        }
    }

    private func fill(_ m: Macros, markUnlocked: Bool) {
        if markUnlocked { userLockedMacros = false }
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
        case .carbProtein:   return "Carb+Prot"
        case .mostlyCarb:    return "Mostly carb"
        case .mostlyProtein: return "Mostly prot"
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

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
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
