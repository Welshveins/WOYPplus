import SwiftUI
import SwiftData

struct ExtrasQuickLogSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let day: Day

    @Query(sort: \ExtrasPreset.updatedAt, order: .reverse)
    private var presets: [ExtrasPreset]

    @State private var editingPreset: ExtrasPreset?
    @State private var pendingLog: (name: String, variant: String)?
    @State private var banner: String?

    // MUST match ExtrasSeeder.seedCatalog (same names/variants)
    private let catalog: [(name: String, variants: [String])] = ExtrasSeeder.seedCatalog

    var body: some View {
        NavigationStack {
            List {

                if let banner {
                    Section {
                        Text(banner)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Text("Quick log extras. First time you use a size, set its nutrition once — then it’s one-tap to log.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(catalog, id: \.name) { item in
                    VStack(alignment: .leading, spacing: 10) {

                        Text(item.name)
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(item.variants, id: \.self) { v in
                                    variantPill(name: item.name, variant: v)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Extras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                // Seed + best-effort autofill for everything with a barcode+grams
                await ExtrasSeeder.seedAndAutofillIfNeeded(ctx: ctx)
            }
            .sheet(item: $editingPreset) { preset in
                ExtrasPresetEditView(preset: preset) {
                    if let pending = pendingLog,
                       pending.name == preset.name,
                       pending.variant == preset.variant,
                       preset.isConfigured {
                        logPreset(preset)
                        pendingLog = nil
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func variantPill(name: String, variant: String) -> some View {
        let preset = presetFor(name: name, variant: variant)
        let configured = preset?.isConfigured ?? false

        return Button {
            Task { await handleTap(name: name, variant: variant) }
        } label: {
            HStack(spacing: 6) {
                Text(variant)
                    .font(.subheadline.weight(.semibold))

                if configured {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.woypSlate.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private func presetFor(name: String, variant: String) -> ExtrasPreset? {
        presets.first(where: { $0.name == name && $0.variant == variant })
    }

    private func ensurePreset(name: String, variant: String) -> ExtrasPreset {
        if let p = presetFor(name: name, variant: variant) { return p }

        // If it somehow wasn't seeded, create it now
        let key = "\(name)/\(variant)"
        let grams = ExtrasSeeder.gramsMap[key] ?? 0
        let barcode = ExtrasSeeder.barcodeMap[key]

        let p = ExtrasPreset(
            name: name,
            variant: variant,
            gramsPerServing: grams,
            offBarcode: barcode
        )
        ctx.insert(p)
        try? ctx.save()
        return p
    }

    @MainActor
    private func handleTap(name: String, variant: String) async {
        let preset = ensurePreset(name: name, variant: variant)

        // 1) Already configured -> log
        if preset.isConfigured {
            logPreset(preset)
            return
        }

        // 2) Try autofill if we have barcode + grams
        if let barcode = preset.offBarcode, !barcode.isEmpty, preset.gramsPerServing > 0 {
            banner = "Looking up nutrition…"
            do {
                if let product = try await OpenFoodFactsAPI.fetchByBarcode(barcode),
                   let n = product.nutriments,
                   n.hasUsableCore {

                    // Convert per-100g -> per-serving grams
                    let factor = preset.gramsPerServing / 100.0
                    let kcal = (n.energyKcal_100g ?? 0) * factor
                    let carbs = (n.carbohydrates_100g ?? 0) * factor
                    let protein = (n.proteins_100g ?? 0) * factor
                    let fat = (n.fat_100g ?? 0) * factor
                    let fibre = (n.fiber_100g ?? 0) * factor

                    if kcal != 0 || carbs != 0 || protein != 0 || fat != 0 || fibre != 0 {
                        preset.caloriesKcal = kcal
                        preset.carbsG = carbs
                        preset.proteinG = protein
                        preset.fatG = fat
                        preset.fibreG = fibre

                        preset.offProductName = product.product_name
                        preset.offBrand = product.brands
                        preset.offServingSize = product.serving_size
                        preset.offLastFilledAt = Date()

                        preset.updatedAt = Date()
                        try? ctx.save()
                    }
                }
            } catch {
                // ignore; manual fallback below
            }
            banner = nil
        }

        // 3) If now configured -> log, else manual sheet
        if preset.isConfigured {
            logPreset(preset)
        } else {
            banner = "Couldn't find nutrition for \(preset.name) (\(preset.variant)). Set it once and it’ll be one-tap next time."
            pendingLog = (name, variant)
            editingPreset = preset
        }
    }

    private func logPreset(_ preset: ExtrasPreset) {
        let entry = Entry(
            title: "\(preset.name) – \(preset.variant)",
            mealSlot: .snacks,
            carbsG: preset.carbsG,
            proteinG: preset.proteinG,
            fatG: preset.fatG,
            fibreG: preset.fibreG,
            caloriesKcal: preset.caloriesKcal,
            isEstimate: false,
            day: day
        )

        ctx.insert(entry)
        preset.updatedAt = Date()

        try? ctx.save()
        dismiss()
    }
}
