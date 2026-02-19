import Foundation
import SwiftData

@Model
final class ExtrasPreset {

    // Identity
    var name: String
    var variant: String

    // Cached nutrition (for that size)
    var caloriesKcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var fibreG: Double

    // Weight for this variant (grams). Used to convert OFF per-100g values.
    var gramsPerServing: Double

    // Open Food Facts linkage (optional, but enables auto-fill)
    var offBarcode: String?
    var offProductName: String?
    var offBrand: String?
    var offServingSize: String?
    var offLastFilledAt: Date?

    var updatedAt: Date

    // Computed — DO NOT STORE
    var isConfigured: Bool {
        caloriesKcal > 0 ||
        carbsG > 0 ||
        proteinG > 0 ||
        fatG > 0 ||
        fibreG > 0
    }

    init(
        name: String,
        variant: String,
        caloriesKcal: Double = 0,
        carbsG: Double = 0,
        proteinG: Double = 0,
        fatG: Double = 0,
        fibreG: Double = 0,
        gramsPerServing: Double = 0,
        offBarcode: String? = nil,
        offProductName: String? = nil,
        offBrand: String? = nil,
        offServingSize: String? = nil,
        offLastFilledAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.name = name
        self.variant = variant
        self.caloriesKcal = caloriesKcal
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
        self.fibreG = fibreG
        self.gramsPerServing = gramsPerServing
        self.offBarcode = offBarcode
        self.offProductName = offProductName
        self.offBrand = offBrand
        self.offServingSize = offServingSize
        self.offLastFilledAt = offLastFilledAt
        self.updatedAt = updatedAt
    }
}
