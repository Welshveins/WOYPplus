import Foundation

enum MacroDisplayMode {
    case gramsSplit
    case percentCalories
}

struct MacroFractions {
    let carb: Double
    let protein: Double
    let fat: Double
}

enum MacroMath {

    static func fractions(
        carbsG: Double,
        proteinG: Double,
        fatG: Double,
        mode: MacroDisplayMode
    ) -> MacroFractions {

        let c = max(0, carbsG)
        let p = max(0, proteinG)
        let f = max(0, fatG)

        switch mode {
        case .gramsSplit:
            let totalG = c + p + f
            guard totalG > 0 else { return .init(carb: 0, protein: 0, fat: 0) }
            return .init(carb: c / totalG, protein: p / totalG, fat: f / totalG)

        case .percentCalories:
            let carbKcal = c * 4.0
            let proteinKcal = p * 4.0
            let fatKcal = f * 9.0
            let totalKcal = carbKcal + proteinKcal + fatKcal
            guard totalKcal > 0 else { return .init(carb: 0, protein: 0, fat: 0) }
            return .init(carb: carbKcal / totalKcal, protein: proteinKcal / totalKcal, fat: fatKcal / totalKcal)
        }
    }
}
