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

    @State private var showingBuilder = false
    @State private var editingRecipe: Recipe?

    @State private var mealFilter: MealFilter = .all
    @State private var courseFilter: CourseFilter = .all

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    // MARK: Filters

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
        searched
            .filter { matchesMeal($0) && matchesCourse($0) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
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
        let s = categoryRaw.lowercased()
        if s.contains("breakfast") { return .breakfast }
        if s.contains("lunch") { return .lunch }
        if s.contains("dinner") { return .dinner }
        if s.contains("snack") { return .snacks }
        return .dinner
    }

    private func inferredCourse(from categoryRaw: String) -> InferredCourse {
        let s = categoryRaw.lowercased()
        if s.contains("starter") { return .starter }
        if s.contains("main") { return .main }
        if s.contains("dessert") { return .dessert }
        return .none
    }

    // MARK: View

    var body: some View {

        List {

            // Add new recipe (in body)
            Section {
                Button {
                    showingBuilder = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add new recipe")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.woypSlate.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }

            // Filters
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

            // Recipes list
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

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button {
                            editingRecipe = r
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }

                if filtered.isEmpty {
                    Text("No matches.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)

        .sheet(item: $selectedRecipe) { r in
            RecipeServingsSheet(recipe: r, day: day, mealSlot: mealSlot)
        }

        .sheet(isPresented: $showingBuilder) {
            NavigationStack {
                RecipeBuilderView()
            }
        }

        .sheet(item: $editingRecipe) { r in
            NavigationStack {
                RecipeBuilderView(existingRecipe: r)
            }
        }
    }

    // MARK: Thumbnail

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
