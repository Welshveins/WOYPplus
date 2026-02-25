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

    // Toggle: ON = use full image (better accuracy), OFF = centre crop
    @State private var useFullImage = true

    @State private var kcal: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var fibre: String = ""

    // Photos / Camera
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var uiImage: UIImage?

    @State private var showCamera = false

    // Vision
    @State private var isAnalysing = false
    @State private var analysisLabel: String?

    var body: some View {

        NavigationStack {
            Form {

                Section {

                    // Preview
                    if let image = uiImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.woypSlate.opacity(0.08))
                            .frame(height: 140)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text("Add a photo for best guess")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            )
                    }

                    // Actions
                    HStack(spacing: 12) {

                        Button {
                            showCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Choose photo", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Toggle("Use full image", isOn: $useFullImage)
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
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $uiImage)
                    .ignoresSafeArea()
            }
            .onChange(of: uiImage) { _, newImage in
                guard let newImage else { return }
                runVision(on: newImage)
            }
        }
    }

    // MARK: - Photos

    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                uiImage = image
            }
        }
    }

    // MARK: - Vision

    private func runVision(on image: UIImage) {

        let visionImage: UIImage = useFullImage ? image : image.centerSquareCrop()

        guard let cgImage = visionImage.cgImage else { return }

        isAnalysing = true
        analysisLabel = nil

        let request = VNClassifyImageRequest { request, _ in

            guard let results = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async { isAnalysing = false }
                return
            }

            let banned: Set<String> = [
                "structure", "pattern", "text", "font", "product",
                "table", "dish", "plate", "room", "floor", "screenshot"
            ]

            let foodHints = [
                "food","chocolate","bar","snack","pizza","burger","sandwich","wrap","burrito",
                "pasta","noodle","rice","bread","toast","cake","biscuit","cookie","fruit",
                "banana","apple","salad","yogurt","cheese","egg","chicken","beef","fish",
                "chips","fries","ice","cream","curry","soup","oats","porridge","cereal"
            ]

            let candidates = results.prefix(15)

            let bestFood = candidates.first(where: { obs in
                let id = obs.identifier.lowercased()
                if obs.confidence < 0.10 { return false }
                if banned.contains(id) { return false }
                return foodHints.contains(where: { id.contains($0) })
            })

            let bestFallback = candidates.first(where: { obs in
                let id = obs.identifier.lowercased()
                if obs.confidence < 0.15 { return false }
                if banned.contains(id) { return false }
                return true
            })

            let best = bestFood ?? bestFallback

            DispatchQueue.main.async {
                isAnalysing = false

                if let best {
                    analysisLabel = "\(best.identifier) (\(Int(best.confidence * 100))%)"
                    applyHeuristic(for: best.identifier)
                } else {
                    analysisLabel = "Unknown"
                }
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    // MARK: - Heuristic Mapping

    private func applyHeuristic(for label: String) {

        let lower = label.lowercased()

        if lower.contains("pizza") {
            fill(k: 800, c: 90, p: 35, f: 35)
        } else if lower.contains("salad") {
            fill(k: 350, c: 20, p: 15, f: 25)
        } else if lower.contains("burger") {
            fill(k: 750, c: 60, p: 40, f: 45)
        } else if lower.contains("pasta") {
            fill(k: 700, c: 100, p: 25, f: 20)
        } else if lower.contains("rice") {
            fill(k: 600, c: 110, p: 15, f: 10)
        } else if lower.contains("chocolate") || lower.contains("bar") {
            fill(k: 250, c: 28, p: 3, f: 12)
        } else {
            fill(k: 600, c: 60, p: 30, f: 25)
        }
    }

    private func fill(k: Double, c: Double, p: Double, f: Double) {
        kcal = "\(Int(k))"
        carbs = "\(Int(c))"
        protein = "\(Int(p))"
        fat = "\(Int(f))"
        fibre = "5"
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

        let descriptor = FetchDescriptor<Day>()
        let all = (try? ctx.fetch(descriptor)) ?? []

        if let existing = all.first(where: {
            Day.startOfDay(for: $0.date) == start
        }) {
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

// MARK: - Camera Picker

private struct CameraPicker: UIViewControllerRepresentable {

    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Simple centre crop helper

private extension UIImage {
    func centerSquareCrop() -> UIImage {
        guard let cg = cgImage else { return self }
        
        let w = size.width
        let h = size.height
        let side = min(w, h)
        let x = (w - side) / 2
        let y = (h - side) / 2
        let rect = CGRect(x: x, y: y, width: side, height: side)
        
        let scaleX = CGFloat(cg.width) / w
        let scaleY = CGFloat(cg.height) / h
        let scaledRect = rect.applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cropped = cg.cropping(to: scaledRect) else { return self }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
