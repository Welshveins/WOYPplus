//
//  Macros.swift
//  WOYPplus
//
//  Created by Chris Davies on 17/03/2026.
//

import Foundation

struct Macros {
    var k: Double
    var c: Double
    var p: Double
    var f: Double
    var fi: Double

    func scaled(by factor: Double) -> Macros {
        Macros(
            k: k * factor,
            c: c * factor,
            p: p * factor,
            f: f * factor,
            fi: fi * factor
        )
    }
}
