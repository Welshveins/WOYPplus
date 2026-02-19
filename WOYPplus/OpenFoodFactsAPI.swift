import Foundation

// MARK: - Models

struct OFFProductResponse: Decodable {
    let product: OFFProduct?
    let status: Int?
}

struct OFFProduct: Decodable {
    let code: String?
    let product_name: String?
    let brands: String?
    let serving_size: String?
    let nutriments: OFFNutriments?

    var displayName: String {
        let n = product_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? "Unnamed product" : n
    }
}

struct OFFNutriments: Decodable {
    // Per 100g (Open Food Facts has multiple possible keys)
    let energyKcal_100g: Double?       // "energy-kcal_100g"
    let energyKj_100g: Double?         // "energy-kj_100g"
    let energy_100g: Double?           // often kJ in v2 ("energy_100g")

    let proteins_100g: Double?
    let carbohydrates_100g: Double?
    let fat_100g: Double?

    let fiber_100g: Double?            // US spelling
    let fibres_100g: Double?           // UK spelling

    enum CodingKeys: String, CodingKey {
        case energyKcal_100g = "energy-kcal_100g"
        case energyKj_100g   = "energy-kj_100g"
        case energy_100g     = "energy_100g"
        case proteins_100g
        case carbohydrates_100g
        case fat_100g
        case fiber_100g
        case fibres_100g
    }

    /// Return kcal per 100g, converting from kJ if needed.
    var energyKcalPer100g: Double? {
        if let kcal = energyKcal_100g { return kcal }
        if let kj = energyKj_100g { return kj / 4.184 }
        if let kj = energy_100g { return kj / 4.184 }
        return nil
    }

    var fibrePer100g: Double? {
        fiber_100g ?? fibres_100g
    }

    var hasUsableCore: Bool {
        // require kcal (or convertible kJ) + at least one macro
        (energyKcalPer100g != nil) && (proteins_100g != nil || carbohydrates_100g != nil || fat_100g != nil)
    }
}

// MARK: - API

enum OpenFoodFactsAPI {
    static func fetchByBarcode(_ raw: String) async throws -> OFFProduct? {
        let code = normalizeBarcode(raw)
        guard !code.isEmpty else { return nil }

        var comps = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json")!
        comps.queryItems = [
            URLQueryItem(name: "fields", value: "code,product_name,brands,serving_size,nutriments")
        ]

        guard let url = comps.url else { return nil }

        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        // status==1 is "found" on OFF; but product can still be nil sometimes
        return decoded.product
    }

    /// Keep digits only; handle GTIN-14 -> EAN-13; trim leading 0s safely.
    static func normalizeBarcode(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }

        guard !digits.isEmpty else { return "" }

        // If GTIN-14, often just leading 0 + EAN-13
        if digits.count == 14 {
            // Prefer dropping leading 0 if present, else take last 13
            if digits.first == "0" {
                return String(digits.dropFirst())
            } else {
                return String(digits.suffix(13))
            }
        }

        // If longer than 13, take last 13 (rare but safe)
        if digits.count > 13 {
            return String(digits.suffix(13))
        }

        // If 13 or less, return as-is
        return digits
    }
}
