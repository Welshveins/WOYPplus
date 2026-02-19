import Foundation
import SwiftData

enum ExtrasSeeder {

    // Bump when seed structure materially changes
    private static let seedKey = "woypplus.extrasSeeded.v3"

    // UK-leaning starter catalogue (names + variants)
    static let seedCatalog: [(name: String, variants: [String])] = [
        // Chocolate bars
        ("KitKat", ["2-finger", "4-finger", "Chunky"]),
        ("Twix", ["Single", "Twin"]),
        ("Mars", ["Standard", "Duo"]),
        ("Snickers", ["Standard", "Duo"]),
        ("Cadbury Dairy Milk", ["Small", "Standard"]),
        ("Kinder Bueno", ["2-bar", "Single"]),

        // Crisps
        ("Walkers", ["Small", "Standard", "Large"]),
        ("McCoy's", ["Standard", "Large"]),
        ("Pringles", ["Small", "Standard"]),

        // Biscuits
        ("Digestives", ["2", "4"]),
        ("Hobnobs", ["2", "4"]),
        ("Oreos", ["2", "4", "6"]),

        // Ice cream
        ("Ice cream", ["Small bowl", "Standard bowl"])
    ]

    // Grams per variant (YOUR numbers)
    // Key format MUST be "Name/Variant" matching seedCatalog strings exactly.
    static let gramsMap: [String: Double] = [
        // KitKat
        "KitKat/2-finger": 20.7,
        "KitKat/4-finger": 41.5,
        "KitKat/Chunky": 40.0,

        // Twix
        "Twix/Single": 25.0,
        "Twix/Twin": 50.0,

        // Mars
        "Mars/Standard": 51.0,
        "Mars/Duo": 79.0,

        // Snickers
        "Snickers/Standard": 48.0,
        "Snickers/Duo": 83.4,

        // Cadbury Dairy Milk
        "Cadbury Dairy Milk/Small": 54.4,
        "Cadbury Dairy Milk/Standard": 105.0,

        // Kinder Bueno
        "Kinder Bueno/2-bar": 43.0,
        "Kinder Bueno/Single": 21.0,

        // Walkers
        "Walkers/Small": 0,
        "Walkers/Standard": 32.5,
        "Walkers/Large": 70.0,

        // McCoy's
        "McCoy's/Standard": 45.0,
        "McCoy's/Large": 47.5,

        // Pringles
        "Pringles/Small": 40.0,
        "Pringles/Standard": 165.0,

        // Digestives
        "Digestives/2": 29.4,
        "Digestives/4": 58.8,

        // Hobnobs
        "Hobnobs/2": 37.6,
        "Hobnobs/4": 75.2,

        // Oreos
        "Oreos/2": 22.0,
        "Oreos/4": 44.0,
        "Oreos/6": 66.0,

        // Ice cream bowls
        "Ice cream/Small bowl": 60.0,
        "Ice cream/Standard bowl": 80.0
    ]

    // Barcodes (YOUR screenshots + ice cream)
    // Key format MUST be "Name/Variant" exactly.
    static let barcodeMap: [String: String] = [
        // KitKat
        "KitKat/2-finger": "8445291524620",
        "KitKat/4-finger": "6009188002213",
        "KitKat/Chunky": "7613037051179",

        // Twix
        "Twix/Twin": "5000159559485",

        // ✅ Mars (FIX): use multipack barcode for BOTH variants, then scale by grams
        "Mars/Standard": "5000159551823",
        "Mars/Duo":      "5000159551823",

        // Snickers
        "Snickers/Standard": "5000159551915",

        // Cadbury Dairy Milk
        "Cadbury Dairy Milk/Small": "7622201461874",

        // Kinder Bueno
        "Kinder Bueno/2-bar": "8000500282373",

        // Walkers
        "Walkers/Standard": "5000328347790",
        "Walkers/Large": "5000328013961",

        // McCoy’s
        "McCoy's/Standard": "5000237138564",
        "McCoy's/Large": "5000237138564",

        // Pringles
        "Pringles/Small": "5053990107339",
        "Pringles/Standard": "5053990138722",

        // Digestives + Hobnobs
        "Digestives/2": "5000168036755",
        "Hobnobs/2": "5000168176833",

        // Ice cream (same tub barcode; we convert per 100g into bowl grams)
        "Ice cream/Small bowl": "50386600000974",
        "Ice cream/Standard bowl": "50386600000974"
    ]

    static func seedIfNeeded(ctx: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: seedKey) == false else { return }

        for item in seedCatalog {
            for v in item.variants {
                if fetchPreset(ctx: ctx, name: item.name, variant: v) != nil { continue }

                let key = "\(item.name)/\(v)"
                let grams = gramsMap[key] ?? 0
                let barcode = barcodeMap[key]

                let p = ExtrasPreset(
                    name: item.name,
                    variant: v,
                    gramsPerServing: grams,
                    offBarcode: barcode
                )
                ctx.insert(p)
            }
        }

        try? ctx.save()
        defaults.set(true, forKey: seedKey)
    }

    /// Seeds (if needed) and then tries to autofill from Open Food Facts for anything with a barcode.
    /// Safe to call repeatedly.
    @MainActor
    static func seedAndAutofillIfNeeded(ctx: ModelContext) async {
        seedIfNeeded(ctx: ctx)

        let all: [ExtrasPreset] = (try? ctx.fetch(FetchDescriptor<ExtrasPreset>())) ?? []
        guard !all.isEmpty else { return }

        for preset in all {
            guard !preset.isConfigured else { continue }
            guard let barcode = preset.offBarcode, !barcode.isEmpty else { continue }
            guard preset.gramsPerServing > 0 else { continue }

            do {
                if let product = try await OpenFoodFactsAPI.fetchByBarcode(barcode),
                   let n = product.nutriments,
                   n.hasUsableCore {

                    applyOFFPer100g(product: product, to: preset)
                    preset.updatedAt = Date()
                    try? ctx.save()
                }
            } catch {
                // ignore; manual entry remains available
            }
        }
    }

    private static func applyOFFPer100g(product: OFFProduct, to preset: ExtrasPreset) {
        guard let n = product.nutriments else { return }
        let g = preset.gramsPerServing
        guard g > 0 else { return }

        let factor = g / 100.0

        let kcal = (n.energyKcal_100g ?? 0) * factor
        let carbs = (n.carbohydrates_100g ?? 0) * factor
        let protein = (n.proteins_100g ?? 0) * factor
        let fat = (n.fat_100g ?? 0) * factor
        let fibre = (n.fiber_100g ?? 0) * factor

        if kcal == 0 && carbs == 0 && protein == 0 && fat == 0 && fibre == 0 { return }

        preset.caloriesKcal = kcal
        preset.carbsG = carbs
        preset.proteinG = protein
        preset.fatG = fat
        preset.fibreG = fibre

        preset.offProductName = product.product_name
        preset.offBrand = product.brands
        preset.offServingSize = product.serving_size
        preset.offLastFilledAt = Date()
    }

    private static func fetchPreset(ctx: ModelContext, name: String, variant: String) -> ExtrasPreset? {
        let desc = FetchDescriptor<ExtrasPreset>(
            predicate: #Predicate { $0.name == name && $0.variant == variant }
        )
        return (try? ctx.fetch(desc))?.first
    }
}
