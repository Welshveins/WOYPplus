import Foundation
import SwiftData

enum ExtrasBarcodeFlow {

    static func keyForBarcode(_ barcode: String) -> (name: String, variant: String)? {
        guard let key = ExtrasSeeder.barcodeMap[barcode] else { return nil }
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    static func presetFor(name: String, variant: String, in presets: [ExtrasPreset]) -> ExtrasPreset? {
        presets.first(where: { $0.name == name && $0.variant == variant })
    }

    static func ensurePreset(name: String, variant: String, ctx: ModelContext, presets: [ExtrasPreset]) -> ExtrasPreset {
        if let p = presetFor(name: name, variant: variant, in: presets) { return p }
        let p = ExtrasPreset(name: name, variant: variant)
        ctx.insert(p)
        try? ctx.save()
        return p
    }
}
