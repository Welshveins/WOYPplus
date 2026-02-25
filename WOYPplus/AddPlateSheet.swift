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

    // Photo
    @State private var cropToCentre = true
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uiImage: UIImage?

    // Analysis
    @State private var isAnalysing = false
    @State private var analysisLabel: String?

    // Macros
    @State private var kcal: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var fibre: String = ""

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Photo
                Section {

                    if let image = uiImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    HStack(spacing: 12) {
                        Button {
                            showingCamera = true
                        } label: {
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

                // MARK: Details
                Section {
                    TextField("Description (optional)", text: $title)
                }

                Section("When?") {
                    DatePicker(
                        "Date & time",
                        selection: $when,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

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

                // MARK: Best guess
                Section("Best guess") {
                    numberField("kcal", text: $kcal)
                    numberField("Carbs (g)", text: $carbs)
                    numberField("Protein (g)", text: $protein)
                    numberField("Fat (g)", text: $fat)
                    numberField("Fibre (g)", text: $fibre)
                }

                Section {
                    Text("This entry is marked as an estimate. You can confirm or edit it later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Your plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                mealSlot = MealSlot.defaultSlot(for: when)
            }
            .onChange(of: when) { _, newValue in
                guard !userManuallyPickedSlot else { return }
                mealSlot = MealSlot.defaultSlot(for: newValue)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                loadImage(newItem)
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker { image in
                    uiImage = image
                    runVision(on: image)
                }
            }
        }
    }

    // MARK: - Vision

    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    uiImage = image
                }
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
        }

        let request = VNClassifyImageRequest { request, _ in
            guard let results = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async { isAnalysing = false }
                return
            }

            let bannedWords = [
                "structure", "pattern", "text", "font",
                "table", "floor", "room", "wood", "product"
            ]

            let foodHints = [
                "food","chocolate","bar","snack","pizza","burger","sandwich","wrap","burrito",
                "pasta","noodle","rice","bread","toast","cake","biscuit","cookie","fruit",
                "banana","apple","salad","yogurt","yoghurt","cheese","egg","chicken","beef","fish",
                "chips","fries","ice cream","curry","soup","oats","porridge","cereal"
            ]

            let candidates = Array(results.prefix(20))

            func isBanned(_ id: String) -> Bool {
                let lower = id.lowercased()
                return bannedWords.contains(where: { lower.contains($0) })
            }

            // Prefer anything that looks food-ish, otherwise take best non-banned label.
            let bestFood = candidates.first(where: { obs in
                let id = obs.identifier
                if obs.confidence < 0.10 { return false }
                if isBanned(id) { return false }
                let lower = id.lowercased()
                return foodHints.contains(where: { lower.contains($0) })
            })

            let bestFallback = candidates.first(where: { obs in
                let id = obs.identifier
                if obs.confidence < 0.15 { return false }
                if isBanned(id) { return false }
                return true
            })

            let best = bestFood ?? bestFallback

            DispatchQueue.main.async {
                isAnalysing = false

                guard let best else {
                    analysisLabel = "Unknown"
                    return
                }

                analysisLabel = "\(best.identifier) (\(Int(best.confidence * 100))%)"
                applyHeuristic(for: best.identifier)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Heuristic mapping (simple v1)

    private func applyHeuristic(for label: String) {
        // Don’t overwrite if user has already typed values.
        let alreadyHasNumbers =
            (Double(kcal) ?? 0) > 0 ||
            (Double(carbs) ?? 0) > 0 ||
            (Double(protein) ?? 0) > 0 ||
            (Double(fat) ?? 0) > 0

        guard !alreadyHasNumbers else { return }

        let lower = label.lowercased()

        if lower.contains("chocolate") || lower.contains("candy") || lower.contains("sweet") {
            fill(k: 260, c: 30, p: 3, f: 14, fi: 2)
            return
        }

        if lower.contains("pizza") {
            fill(k: 800, c: 90, p: 35, f: 35, fi: 5)
        } else if lower.contains("salad") {
            fill(k: 350, c: 20, p: 15, f: 25, fi: 6)
        } else if lower.contains("burger") {
            fill(k: 750, c: 60, p: 40, f: 45, fi: 4)
        } else if lower.contains("pasta") || lower.contains("noodle") {
            fill(k: 700, c: 100, p: 25, f: 20, fi: 5)
        } else if lower.contains("rice") {
            fill(k: 600, c: 110, p: 15, f: 10, fi: 3)
        } else if lower.contains("sandwich") || lower.contains("wrap") {
            fill(k: 550, c: 55, p: 25, f: 22, fi: 5)
        } else {
            // Generic meal prior
            fill(k: 600, c: 60, p: 30, f: 25, fi: 5)
        }
    }

    private func fill(k: Double, c: Double, p: Double, f: Double, fi: Double) {
        kcal = "\(Int(k.rounded()))"
        carbs = "\(Int(c.rounded()))"
        protein = "\(Int(p.rounded()))"
        fat = "\(Int(f.rounded()))"
        fibre = "\(Int(fi.rounded()))"
    }

    // MARK: - Save

    private var canSave: Bool {
        let k = Double(kcal) ?? 0
        let c = Double(carbs) ?? 0
        let p = Double(protein) ?? 0
        let f = Double(fat) ?? 0
        return (k > 0) || (c + p + f > 0)
    }

    @ViewBuilder
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

        // Make it land in the chosen time/day
        entry.createdAt = when

        ctx.insert(entry)

        // Asterisk on macro wheel day
        targetDay.hasEstimates = true

        try? ctx.save()
        dismiss()
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

// MARK: - Simple centre crop (orientation-safe)

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
