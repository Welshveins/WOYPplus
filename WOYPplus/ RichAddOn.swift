//
//  RichAddOn.swift
//  WOYPplus
//
//  Created by Chris Davies on 17/03/2026.
//

import Foundation

enum RichAddOn: String, CaseIterable, Identifiable {
    case oily
    case creamy
    case cheeseHeavy
    case sauceHeavy

    var id: String { rawValue }

    var display: String {
        switch self {
        case .oily: return "Oily"
        case .creamy: return "Creamy"
        case .cheeseHeavy: return "Cheese-heavy"
        case .sauceHeavy: return "Sauce-heavy"
        }
    }

    var multiplier: Double {
        switch self {
        case .oily: return 1.12
        case .creamy: return 1.14
        case .cheeseHeavy: return 1.16
        case .sauceHeavy: return 1.10
        }
    }
}
