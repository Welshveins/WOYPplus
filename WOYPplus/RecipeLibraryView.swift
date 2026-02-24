import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct RecipeLibraryView: View {

    @Environment(\.modelContext) private var ctx

    @Query(sort: \Recipe.updatedAt, order: .reverse)
    private var recipes: [Recipe]

    let day: Day
    let mealSlot: MealSlot

    @State private var queryText = ""
    @State private var selectedRecipe: Recipe?
    @State private var showingBuilder = false
    @State private var editingRecipe: Recipe?
    @State private var showingImporter = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    // MARK: Filtering

    private var filtered: [Recipe] {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return recipes
            .filter { q.isEmpty || $0.title.lowercased().contains(q) }
            .sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    var body: some View {

        List {

            // Add new recipe
            Section {
                Button {
                    showingBuilder = true
                } label: {
                    actionRow(
                        systemImage: "plus.circle.fill",
                        title: "Add new recipe"
                    )
                }
                .buttonStyle(.plain)
            }

            // Import recipe
            Section {
                Button {
                    showingImporter = true
                } label: {
                    actionRow(
                        systemImage: "square.and.arrow.down",
                        title: "Import recipe (WOYP file)"
                    )
                }
                .buttonStyle(.plain)
            }

            // Search
            Section {
                TextField("Search recipes", text: $queryText)
            }

            // Recipes
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

                        Button(role: .destructive) {
                            delete(r)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            editingRecipe = r
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }

                if filtered.isEmpty {
                    Text("No recipes.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)

        // Import
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }

        // Log recipe
        .sheet(item: $selectedRecipe) { r in
            RecipeServingsSheet(recipe: r, day: day, mealSlot: mealSlot)
        }

        // New recipe
        .sheet(isPresented: $showingBuilder) {
            NavigationStack {
                RecipeBuilderView()
            }
        }

        // Edit recipe
        .sheet(item: $editingRecipe) { r in
            NavigationStack {
                RecipeBuilderView(existingRecipe: r)
            }
        }

        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: Import

    private func handleImport(_ result: Result<[URL], Error>) {

        switch result {

        case .failure(let error):
            alertTitle = "Import failed"
            alertMessage = error.localizedDescription
            showAlert = true

        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let didStart = url.startAccessingSecurityScopedResource()
                defer { if didStart { url.stopAccessingSecurityScopedResource() } }

                let data = try Data(contentsOf: url)

                let didImport: Bool
                do {
                    didImport = try RecipeShareImport.importRecipe(from: data, into: ctx)
                } catch {
                    didImport = try FoundationRecipeImport.importRecipe(from: data, into: ctx)
                }

                if didImport {
                    alertTitle = "Recipe added"
                    alertMessage = "Recipe successfully imported."
                } else {
                    alertTitle = "Already exists"
                    alertMessage = "This recipe is already in your library."
                }

                showAlert = true

            } catch {
                alertTitle = "Import failed"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    // MARK: Delete

    private func delete(_ recipe: Recipe) {
        ctx.delete(recipe)
        try? ctx.save()
    }

    // MARK: UI Helpers

    private func actionRow(systemImage: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 26)

            Text(title)
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
