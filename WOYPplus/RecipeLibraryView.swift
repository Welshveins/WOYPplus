import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct RecipeLibraryView: View {

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]

    let day: Day
    let mealSlot: MealSlot

    @State private var queryText = ""
    @State private var showingImporter = false
    @State private var selectedRecipe: Recipe?

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    // Filters
    @State private var mealFilter: MealFilter = .all
    @State private var courseFilter: CourseFilter = .all

    enum MealFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snacks = "Snacks"

        var id: String { rawValue }
    }

    enum CourseFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case starter = "Starter"
        case main = "Main"
        case dessert = "Dessert"

        var id: String { rawValue }
    }

    private var searched: [Recipe] {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return recipes }
        return recipes.filter { $0.title.lowercased().contains(q) }
    }

    private var filtered: [Recipe] {
        searched.filter { r in
            // meal filter
            if mealFilter != .all {
                let m = inferredMeal(from: r.categoryRaw)
                if mealFilter == .breakfast, m != .breakfast { return false }
                if mealFilter == .lunch, m != .lunch { return false }
                if mealFilter == .dinner, m != .dinner { return false }
                if mealFilter == .snacks, m != .snacks { return false }
            }

            // course filter
            if courseFilter != .all {
                let c = inferredCourse(from: r.categoryRaw)
                if courseFilter == .starter, c != .starter { return false }
                if courseFilter == .main, c != .main { return false }
                if courseFilter == .dessert, c != .dessert { return false }
            }

            return true
        }
    }

    var body: some View {

        List {

            Section {
                TextField("Search recipes", text: $queryText)
            }

            if !recipes.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("When", selection: $mealFilter) {
                            ForEach(MealFilter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Course", selection: $courseFilter) {
                            ForEach(CourseFilter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 2)
                }
            }

            if recipes.isEmpty {
                Section {
                    Text("No recipes yet.")
                        .foregroundStyle(.secondary)

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import recipes (JSON)", systemImage: "square.and.arrow.down")
                    }
                }
            } else {

                // Grouping logic:
                // - If mealFilter is All -> sections by meal (Breakfast/Lunch/Dinner/Snacks/Other)
                // - If mealFilter is specific -> sections by course (Starter/Main/Dessert/Other)
                let groups = makeGroups(from: filtered)

                ForEach(groups, id: \.title) { group in
                    if !group.items.isEmpty {
                        Section(group.title) {
                            ForEach(group.items) { r in
                                Button {
                                    selectedRecipe = r
                                } label: {
                                    HStack(spacing: 12) {
                                        thumbnail(for: r)

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(r.title)
                                                .font(.headline)

                                            Text("\(Int(r.caloriesKcal.rounded())) kcal • C \(Int(r.carbsG.rounded()))g • P \(Int(r.proteinG.rounded()))g • F \(Int(r.fatG.rounded()))g")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import recipes (JSON)", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                importFrom(urls)
            case .failure(let error):
                toast("Import failed", error.localizedDescription)
            }
        }
        .sheet(item: $selectedRecipe) { r in
            RecipeServingsSheet(recipe: r, day: day, mealSlot: mealSlot)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Grouping

    private struct GroupBlock {
        let title: String
        let items: [Recipe]
    }

    private func makeGroups(from list: [Recipe]) -> [GroupBlock] {

        // If user chose a specific meal, group by course
        if mealFilter != .all {
            let starters = list.filter { inferredCourse(from: $0.categoryRaw) == .starter }
            let mains = list.filter { inferredCourse(from: $0.categoryRaw) == .main }
            let desserts = list.filter { inferredCourse(from: $0.categoryRaw) == .dessert }
            let other = list.filter { inferredCourse(from: $0.categoryRaw) == .other }

            return [
                .init(title: "Starter", items: starters),
                .init(title: "Main", items: mains),
                .init(title: "Dessert", items: desserts),
                .init(title: "Other", items: other)
            ]
        }

        // Otherwise group by meal
        let breakfast = list.filter { inferredMeal(from: $0.categoryRaw) == .breakfast }
        let lunch = list.filter { inferredMeal(from: $0.categoryRaw) == .lunch }
        let dinner = list.filter { inferredMeal(from: $0.categoryRaw) == .dinner }
        let snacks = list.filter { inferredMeal(from: $0.categoryRaw) == .snacks }
        let other = list.filter { inferredMeal(from: $0.categoryRaw) == .other }

        return [
            .init(title: "Breakfast", items: breakfast),
            .init(title: "Lunch", items: lunch),
            .init(title: "Dinner", items: dinner),
            .init(title: "Snacks", items: snacks),
            .init(title: "Other", items: other)
        ]
    }

    private enum InferredMeal {
        case breakfast, lunch, dinner, snacks, other
    }

    private func inferredMeal(from raw: String?) -> InferredMeal {
        let s = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if s.contains("breakfast") { return .breakfast }
        if s.contains("lunch") { return .lunch }
        if s.contains("dinner") { return .dinner }
        if s.contains("snack") || s.contains("snacks") { return .snacks }

        // Common Foundation categories that should behave like snacks/desserts:
        if s.contains("dessert") || s.contains("pudding") { return .snacks }

        return .other
    }

    private enum InferredCourse {
        case starter, main, dessert, other
    }

    private func inferredCourse(from raw: String?) -> InferredCourse {
        let s = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if s.contains("starter") || s.contains("appetizer") || s.contains("appetiser") { return .starter }
        if s.contains("main") || s.contains("entrée") || s.contains("entree") { return .main }
        if s.contains("dessert") || s.contains("pudding") || s.contains("sweet") { return .dessert }

        return .other
    }

    // MARK: - Import

    private func importFrom(_ urls: [URL]) {
        var imported = 0
        var skipped = 0
        var failed = 0

        for url in urls {
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)

                // If your importer returns Bool (true=imported, false=duplicate/skip)
                let didImport = try FoundationRecipeImport.importRecipe(from: data, into: ctx)
                if didImport {
                    imported += 1
                } else {
                    skipped += 1
                }
            } catch {
                failed += 1
            }
        }

        toast("Import complete", "Imported \(imported). Skipped \(skipped). Failed \(failed).")
    }

    private func toast(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private func thumbnail(for recipe: Recipe) -> some View {
        if let data = recipe.photoData,
           let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.woypSlate.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.secondary)
                )
        }
    }
}
