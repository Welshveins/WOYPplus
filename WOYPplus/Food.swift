import Foundation
import SwiftData

@Model
final class Food {

    var name: String

    // Macros per 100g (core WOYP philosophy)
    var kcalPer100g: Double
    var carbsPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var fibrePer100g: Double

    // Optional portion system (Phase 1 simple)
    var defaultPortionName: String?      // e.g. "1 medium potato"
    var defaultPortionGrams: Double?     // e.g. 180g

    var createdAt: Date

    init(
        name: String,
        kcalPer100g: Double,
        carbsPer100g: Double,
        proteinPer100g: Double,
        fatPer100g: Double,
        fibrePer100g: Double,
        defaultPortionName: String? = nil,
        defaultPortionGrams: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.kcalPer100g = kcalPer100g
        self.carbsPer100g = carbsPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.fibrePer100g = fibrePer100g
        self.defaultPortionName = defaultPortionName
        self.defaultPortionGrams = defaultPortionGrams
        self.createdAt = createdAt
    }
}
