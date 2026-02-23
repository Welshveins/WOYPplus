import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RecipeLibraryView: View {

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]

    let day: Day
    let mealSlot: MealSlot

    @State private var queryText = ""
    @State private var showingImporter = false
    @State private var selectedRecipe: Recipe?

    @State private var mealFilter: MealFilter = .all
    @State private var courseFilter: CourseFilter = .all

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    // MARK: - Filters

    private enum MealFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snacks = "Snacks"
        var id: String { rawValue }
    }

    private enum CourseFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case starter = "Starter"
        case main = "Main"
        case dessert = "Dessert"
        var id: String { rawValue }
    }

    private enum InferredMeal { case breakfast, lunch, dinner, snacks }
    private enum InferredCourse { case starter, main, dessert, none }

    private var searched: [Recipe] {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return recipes }
        return recipes.filter { $0.title.lowercased().contains(q) }
    }

    private var filtered: [Recipe] {
        searched.filter { r in
            matchesMeal(r) && matchesCourse(r)
        }
    }

    private func matchesMeal(_ r: Recipe) -> Bool {
        if mealFilter == .all { return true }
        let m = inferredMeal(from: r.categoryRaw)
        switch mealFilter {
        case .breakfast: return m == .breakfast
        case .lunch:     return m == .lunch
        case .dinner:    return m == .dinner
        case .snacks:    return m == .snacks
        case .all:       return true
        }
    }

    private func matchesCourse(_ r: Recipe) -> Bool {
        if courseFilter == .all { return true }
        let c = inferredCourse(from: r.categoryRaw)
        switch courseFilter {
        case .starter: return c == .starter
        case .main:    return c == .main
        case .dessert: return c == .dessert
        case .all:     return true
        }
    }

    private func inferredMeal(from categoryRaw: String) -> InferredMeal {
        let s = categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // your current JSON values (and safe fallbacks)
        if s.contains("breakfast") { return .breakfast }
        if s.contains("lunch") { return .lunch }
        if s.contains("dinner") { return .dinner }
        if s.contains("snack") { return .snacks }

        // common alt labels
        if s.contains("brunch") { return .lunch }

        // default (keeps list usable even with weird categories)
        return .dinner
    }

    private func inferredCourse(from categoryRaw: String) -> InferredCourse {
        let s = categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if s.contains("starter") { return .starter }
        if s.contains("main") { return .main }
        if s.contains("dessert") { return .dessert }

        // If a recipe is tagged as Breakfast/Lunch/Dinner/Snacks only, treat as "none"
        return .none
    }

    // MARK: - View

    var body: some View {

        List {

            Section {
                TextField("Search recipes", text: $queryText)

                Picker("Meal", selection: $mealFilter) {
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

                Section("Recipes") {
                    ForEach(filtered) { r in
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

                    if filtered.isEmpty {
                        Text("No matches.")
                            .foregroundStyle(.secondary)
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

                // Prefer your Foundation importer (handles ingredients + photo + fingerprint de-dupe)
                // If your importRecipe returns Bool (didImport), we’ll count properly.
                // If it returns Void, this still compiles if you change the next 3 lines accordingly.
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

        var parts: [String] = []
        parts.append("Imported \(imported)")
        if skipped > 0 { parts.append("Skipped \(skipped)") }
        if failed > 0 { parts.append("Failed \(failed)") }

        toast("Import complete", parts.joined(separator: " • "))
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
