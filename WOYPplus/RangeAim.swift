import Foundation
import SwiftData

enum RangeMetric: String, CaseIterable, Codable {
    case kcal, carbs, protein, fat, fibre

    var title: String {
        switch self {
        case .kcal: return "kcal"
        case .carbs: return "Carbs"
        case .protein: return "Protein"
        case .fat: return "Fat"
        case .fibre: return "Fibre"
        }
    }

    var unit: String {
        switch self {
        case .kcal: return "kcal"
        default: return "g"
        }
    }
}

/// Stores a single aim value per metric.
/// Aims are optional: nil means “not set”.
@Model
final class RangeAim {
    @Attribute(.unique) var metricRaw: String
    var aimValue: Double?

    init(metric: RangeMetric, aimValue: Double? = nil) {
        self.metricRaw = metric.rawValue
        self.aimValue = aimValue
    }

    var metric: RangeMetric {
        RangeMetric(rawValue: metricRaw) ?? .kcal
    }
}
