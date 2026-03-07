import Foundation
import SwiftData

// MARK: - Range Mode

enum RangeMode: String, CaseIterable, Codable {
    case normal = "Normal"
    case holiday = "Holiday"
    case illness = "Illness"

    /// Normal ±10%, Holiday/Illness ±20%
    var marginFraction: Double {
        switch self {
        case .normal:  return 0.25
        case .holiday: return 0.35
        case .illness: return 0.35
        }
    }
}

// MARK: - Range Profile (user aims)

@Model
final class RangeProfile {

    // Store mode as a raw string for SwiftData stability
    var modeRaw: String

    // Optional aims (user can set any subset)
    var aimKcal: Double?
    var aimCarbsG: Double?
    var aimProteinG: Double?
    var aimFatG: Double?
    var aimFibreG: Double?

    init(
        mode: RangeMode = .normal,
        aimKcal: Double? = nil,
        aimCarbsG: Double? = nil,
        aimProteinG: Double? = nil,
        aimFatG: Double? = nil,
        aimFibreG: Double? = nil
    ) {
        self.modeRaw = mode.rawValue
        self.aimKcal = aimKcal
        self.aimCarbsG = aimCarbsG
        self.aimProteinG = aimProteinG
        self.aimFatG = aimFatG
        self.aimFibreG = aimFibreG
    }

    var mode: RangeMode {
        get { RangeMode(rawValue: modeRaw) ?? .normal }
        set { modeRaw = newValue.rawValue }
    }

    // MARK: - Band helpers

    /// Returns (low, high) for an aim using the current mode’s margin.
    func band(for aim: Double) -> (low: Double, high: Double) {
        let m = mode.marginFraction
        let low = aim * (1.0 - m)
        let high = aim * (1.0 + m)
        return (low, high)
    }

    /// Converts a value to a 0...1 position within the band.
    /// If outside band, it clamps to 0 or 1 (calm, no judgement).
    func clampedPosition(value: Double, aim: Double) -> Double {
        let b = band(for: aim)
        let denom = max(b.high - b.low, 0.000_001)
        let raw = (value - b.low) / denom
        return min(max(raw, 0.0), 1.0)
    }
}
