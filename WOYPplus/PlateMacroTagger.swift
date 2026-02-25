// PlateMacroTagger.swift
import Foundation

struct PlateMacroTagger {

    struct Label: Hashable {
        let identifier: String
        let confidence: Double   // 0.0–1.0
    }

    struct Macros: Equatable {
        var k: Double
        var c: Double
        var p: Double
        var f: Double
        var fi: Double
    }

    struct Estimate: Equatable {
        var macros: Macros
        var detectedSummary: String        // human-readable short list
        var primary: String?               // top label identifier
    }

    // MARK: - Public

    static func estimate(from rawLabels: [Label]) -> Estimate {

        // 1) Filter & sort
        let labels = rawLabels
            .filter { $0.confidence >= 0.08 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(12)
            .map { $0 }

        guard !labels.isEmpty else {
            return Estimate(
                macros: Macros(k: 600, c: 60, p: 30, f: 25, fi: 5),
                detectedSummary: "Unknown",
                primary: nil
            )
        }

        // 2) Build archetype weights from multiple labels (mixed plate support)
        var weights: [Archetype: Double] = [:]

        for l in labels {
            let id = l.identifier.lowercased()
            let w = l.confidence

            if isBanned(id) { continue }

            // Dessert / snack
            if containsAny(id, dessertWords) { add(.dessert, w * 1.1, to: &weights); continue }
            if containsAny(id, chocolateWords) { add(.chocolateBar, w * 1.15, to: &weights); continue }

            // Carb bases
            if containsAny(id, riceWords) { add(.rice, w * 1.15, to: &weights); continue }
            if containsAny(id, pastaWords) { add(.pasta, w * 1.10, to: &weights); continue }
            if containsAny(id, breadWords) { add(.sandwichWrap, w * 1.05, to: &weights); continue }
            if containsAny(id, chipsWords) { add(.chipsFries, w * 1.10, to: &weights); continue }

            // Mains
            if containsAny(id, curryWords) { add(.curry, w * 1.10, to: &weights); continue }
            if containsAny(id, burgerWords) { add(.burger, w * 1.10, to: &weights); continue }
            if containsAny(id, pizzaWords) { add(.pizza, w * 1.10, to: &weights); continue }
            if containsAny(id, saladWords) { add(.salad, w * 1.10, to: &weights); continue }

            // Proteins
            if containsAny(id, chickenWords) { add(.chicken, w * 1.05, to: &weights); continue }
            if containsAny(id, beefWords) { add(.beef, w * 1.05, to: &weights); continue }
            if containsAny(id, fishWords) { add(.fish, w * 1.05, to: &weights); continue }
            if containsAny(id, eggWords) { add(.eggs, w * 1.00, to: &weights); continue }

            // Fallback: treat unknown but non-banned as “generic meal”
            add(.genericMeal, w * 0.85, to: &weights)
        }

        // If everything got banned somehow, use generic
        if weights.isEmpty {
            weights[.genericMeal] = 1.0
        }

        // 3) Blend macros across archetypes
        let blended = blend(weights: weights)

        // 4) Human summary: up to 3 distinct “food-ish” tokens from top labels
        let summary = makeSummary(from: labels)

        return Estimate(
            macros: blended,
            detectedSummary: summary,
            primary: labels.first?.identifier
        )
    }

    // MARK: - Archetypes

    private enum Archetype: CaseIterable {
        case genericMeal
        case rice
        case pasta
        case sandwichWrap
        case curry
        case burger
        case pizza
        case salad
        case chipsFries
        case chicken
        case beef
        case fish
        case eggs
        case dessert
        case chocolateBar
    }

    private static func macros(for a: Archetype) -> Macros {
        switch a {
        case .genericMeal:   return Macros(k: 620, c: 65,  p: 30, f: 25, fi: 5)

        case .rice:          return Macros(k: 630, c: 110, p: 18, f: 10, fi: 3)
        case .pasta:         return Macros(k: 700, c: 100, p: 25, f: 20, fi: 5)
        case .sandwichWrap:  return Macros(k: 560, c: 55,  p: 25, f: 22, fi: 5)

        case .curry:         return Macros(k: 760, c: 80,  p: 35, f: 30, fi: 6)
        case .burger:        return Macros(k: 760, c: 60,  p: 40, f: 45, fi: 4)
        case .pizza:         return Macros(k: 820, c: 90,  p: 35, f: 35, fi: 5)
        case .salad:         return Macros(k: 360, c: 20,  p: 15, f: 25, fi: 6)
        case .chipsFries:    return Macros(k: 520, c: 60,  p: 6,  f: 24, fi: 5)

        case .chicken:       return Macros(k: 430, c: 10,  p: 45, f: 18, fi: 2)
        case .beef:          return Macros(k: 520, c: 10,  p: 40, f: 30, fi: 2)
        case .fish:          return Macros(k: 470, c: 8,   p: 38, f: 24, fi: 2)
        case .eggs:          return Macros(k: 420, c: 6,   p: 28, f: 30, fi: 1)

        case .dessert:       return Macros(k: 420, c: 55,  p: 6,  f: 18, fi: 2)
        case .chocolateBar:  return Macros(k: 260, c: 30,  p: 3,  f: 14, fi: 2)
        }
    }

    private static func blend(weights: [Archetype: Double]) -> Macros {
        let total = max(0.0001, weights.values.reduce(0, +))

        var out = Macros(k: 0, c: 0, p: 0, f: 0, fi: 0)
        for (a, w) in weights {
            let m = macros(for: a)
            let t = w / total
            out.k  += m.k  * t
            out.c  += m.c  * t
            out.p  += m.p  * t
            out.f  += m.f  * t
            out.fi += m.fi * t
        }

        // Keep within sensible guardrails (avoid silly outputs)
        out.k = clamp(out.k, 150, 1200)
        out.c = clamp(out.c, 0, 180)
        out.p = clamp(out.p, 0, 120)
        out.f = clamp(out.f, 0, 90)
        out.fi = clamp(out.fi, 0, 25)

        return out
    }

    // MARK: - Summary

    private static func makeSummary(from labels: [Label]) -> String {
        // Take top labels, convert to “food-ish” words, de-dupe, show up to 3
        var tokens: [String] = []
        for l in labels.prefix(8) {
            let raw = l.identifier.lowercased()
            if isBanned(raw) { continue }

            if let t = token(from: raw) {
                if !tokens.contains(t) {
                    tokens.append(t)
                }
            }
            if tokens.count >= 3 { break }
        }

        if tokens.isEmpty {
            let top = labels.first?.identifier.replacingOccurrences(of: "_", with: " ") ?? "Unknown"
            return top.capitalized
        }

        return tokens.map { $0.capitalized }.joined(separator: " • ")
    }

    private static func token(from id: String) -> String? {
        // Prefer meaningful meal components
        if containsAny(id, curryWords) { return "curry" }
        if containsAny(id, riceWords) { return "rice" }
        if containsAny(id, pastaWords) { return "pasta" }
        if containsAny(id, chickenWords) { return "chicken" }
        if containsAny(id, beefWords) { return "beef" }
        if containsAny(id, fishWords) { return "fish" }
        if containsAny(id, saladWords) { return "salad" }
        if containsAny(id, burgerWords) { return "burger" }
        if containsAny(id, pizzaWords) { return "pizza" }
        if containsAny(id, chocolateWords) { return "chocolate" }
        if containsAny(id, dessertWords) { return "dessert" }
        if containsAny(id, breadWords) { return "sandwich" }
        if containsAny(id, chipsWords) { return "chips" }

        // last resort: a cleaned identifier (but avoid overly generic)
        let cleaned = id
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count < 3 { return nil }
        if containsAny(cleaned, ["food", "meal", "dish"]) { return nil }
        return cleaned
    }

    // MARK: - Helpers

    private static func add(_ a: Archetype, _ w: Double, to dict: inout [Archetype: Double]) {
        dict[a, default: 0] += w
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains(where: { haystack.contains($0) })
    }

    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(x, lo), hi)
    }

    private static func isBanned(_ id: String) -> Bool {
        let lower = id.lowercased()
        return bannedWords.contains(where: { lower.contains($0) })
    }

    // MARK: - Keyword lists (keep short + practical)

    private static let bannedWords: [String] = [
        "structure","pattern","text","font",
        "table","floor","room","wood","product",
        "screenshot","shoe","shoes","person","human","clothing"
    ]

    private static let riceWords     = ["rice", "risotto", "pilaf", "biryani"]
    private static let pastaWords    = ["pasta", "noodle", "spaghetti", "macaroni", "ramen", "udon"]
    private static let breadWords    = ["sandwich", "wrap", "burrito", "taco", "bread", "toast", "bagel"]
    private static let curryWords    = ["curry", "stew", "chilli", "chili", "korma", "tikka", "masala", "dahl", "dal", "ragù", "ragu"]
    private static let burgerWords   = ["burger", "cheeseburger"]
    private static let pizzaWords    = ["pizza"]
    private static let saladWords    = ["salad"]
    private static let chipsWords    = ["chips", "fries"]

    private static let chickenWords  = ["chicken"]
    private static let beefWords     = ["beef", "steak"]
    private static let fishWords     = ["fish", "salmon", "tuna", "cod", "prawn", "shrimp"]
    private static let eggWords      = ["egg", "omelette", "omelet"]

    private static let dessertWords  = ["dessert", "cake", "brownie", "cookie", "biscuit", "ice cream", "pudding"]
    private static let chocolateWords = ["chocolate", "candy", "sweet", "bar"]
}
