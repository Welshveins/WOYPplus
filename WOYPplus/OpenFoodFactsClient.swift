import Foundation

enum OpenFoodFactsClient {

    // MARK: - API Models

    struct ProductResponse: Decodable {
        let product: Product?
        let status: Int?
    }

    struct Product: Decodable {
        let code: String?
        let product_name: String?
        let brands: String?
        let serving_size: String?
        let nutriments: Nutriments?

        var displayName: String {
            let n = product_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return n.isEmpty ? "Unnamed product" : n
        }
    }

    struct Nutriments: Decodable {

        // Per 100g keys
        let energyKcal_100g: Double?
        let proteins_100g: Double?
        let carbohydrates_100g: Double?
        let fat_100g: Double?
        let fiber_100g: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal_100g = "energy-kcal_100g"
            case proteins_100g
            case carbohydrates_100g
            case fat_100g
            case fiber_100g = "fiber_100g"
        }

        var hasUsableCore: Bool {
            (energyKcal_100g != nil) &&
            (proteins_100g != nil || carbohydrates_100g != nil || fat_100g != nil)
        }
    }

    // What the rest of the app needs (always per-100g, so we can scale by grams)
    struct Per100g {
        let kcal: Double
        let carbs: Double
        let protein: Double
        let fat: Double
        let fibre: Double

        let productName: String?
        let brand: String?
        let servingSize: String?
    }

    // MARK: - Fetch

    /// Returns per-100g nutrition (so caller can scale by grams).
    static func fetchPer100gByBarcode(_ barcode: String) async throws -> Per100g? {

        let trimmed = barcode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")

        guard !trimmed.isEmpty else { return nil }

        var comps = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json")!
        comps.queryItems = [
            URLQueryItem(name: "fields", value: "code,product_name,brands,serving_size,nutriments")
        ]
        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 15

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }

        let decoded = try JSONDecoder().decode(ProductResponse.self, from: data)
        guard let p = decoded.product,
              let n = p.nutriments,
              n.hasUsableCore
        else { return nil }

        let kcal = n.energyKcal_100g ?? 0
        let carbs = n.carbohydrates_100g ?? 0
        let protein = n.proteins_100g ?? 0
        let fat = n.fat_100g ?? 0
        let fibre = n.fiber_100g ?? 0

        if kcal == 0 && carbs == 0 && protein == 0 && fat == 0 && fibre == 0 { return nil }

        return Per100g(
            kcal: kcal,
            carbs: carbs,
            protein: protein,
            fat: fat,
            fibre: fibre,
            productName: p.product_name,
            brand: p.brands,
            servingSize: p.serving_size
        )
    }
}
