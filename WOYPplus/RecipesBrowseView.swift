import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct RecipesBrowseView: View {

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    // Simple query; we sort A–Z in `filtered`.
    @Query private var recipes: [Recipe]

    @State private var queryText = ""

    @State private var selectedRecipe: Recipe?
    @State private var editingRecipe: Recipe?
    @State private var showingNewRecipeSheet = false

    @State private var showingImporter = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    // NEW: quick “Add to meal” from Recipes
    @State private var pendingLogRecipe: Recipe?
    @State private var logRecipe: Recipe?
    @State private var logMealSlot: MealSlot = MealSlot.defaultSlot(for: Date())
    @State private var showingMealPicker = false

    private var filtered: [Recipe] {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return recipes
            .filter { q.isEmpty || $0.title.lowercased().contains(q) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {

                // MARK: Actions
                Section {
                    Button {
                        showingNewRecipeSheet = true
                    } label: {
                        actionRow(systemImage: "plus.circle.fill", title: "Add new recipe")
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingImporter = true
                    } label: {
                        actionRow(systemImage: "square.and.arrow.down", title: "Import recipe file")
                    }
                    .buttonStyle(.plain)
                }

                // MARK: Search
                Section {
                    TextField("Search recipes", text: $queryText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                // MARK: Recipes list
                Section("Recipes") {
                    if filtered.isEmpty {
                        Text("No recipes.")
                            .foregroundStyle(.secondary)
                    } else {
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
                            .swipeActions(edge: .trailing) {

                                // NEW: Add to meal (does not constrain “type” — just a quick picker)
                                Button {
                                    pendingLogRecipe = r
                                    // default slot for now; user chooses next
                                    logMealSlot = MealSlot.defaultSlot(for: Date())
                                    showingMealPicker = true
                                } label: {
                                    Label("Add to meal", systemImage: "plus.circle")
                                }
                                .tint(.green)

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
                    }
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(10)
                            .background(Circle().fill(Color.woypSlate.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }

            // NEW: meal picker for “Add to meal”
            .confirmationDialog(
                "Add to meal",
                isPresented: $showingMealPicker,
                titleVisibility: .visible
            ) {
                Button("Breakfast") { startLog(.breakfast) }
                Button("Lunch") { startLog(.lunch) }
                Button("Dinner") { startLog(.dinner) }
                Button("Snacks") { startLog(.snacks) }
                Button("Cancel", role: .cancel) { pendingLogRecipe = nil }
            }

            // Import (WOYPPlus share format first, then Foundation)
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }

            // Browse/share detail screen (NOT logging)
            .sheet(item: $selectedRecipe) { r in
                NavigationStack {
                    BrowseRecipeDetailView(
                        recipe: r,
                        onEdit: { recipeToEdit in
                            selectedRecipe = nil
                            editingRecipe = recipeToEdit
                        },
                        onDelete: { recipeToDelete in
                            selectedRecipe = nil
                            delete(recipeToDelete)
                        }
                    )
                }
                .presentationDetents([.large])
            }

            // NEW: Log recipe (from recipes browse)
            .sheet(item: $logRecipe) { r in
                RecipeServingsSheet(
                    recipe: r,
                    day: ensureDay(for: Date()),
                    mealSlot: logMealSlot
                )
            }

            // Edit recipe
            .sheet(item: $editingRecipe) { r in
                NavigationStack {
                    RecipeBuilderView(existingRecipe: r)
                }
            }

            // New recipe
            .sheet(isPresented: $showingNewRecipeSheet) {
                NavigationStack {
                    RecipeBuilderView()
                }
            }

            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Add to meal helpers

    private func startLog(_ slot: MealSlot) {
        logMealSlot = slot
        logRecipe = pendingLogRecipe
        pendingLogRecipe = nil
    }

    private func ensureDay(for date: Date) -> Day {
        let start = Day.startOfDay(for: date)

        let all = (try? ctx.fetch(FetchDescriptor<Day>())) ?? []
        if let existing = all.first(where: { Day.startOfDay(for: $0.date) == start }) {
            return existing
        }

        let newDay = Day(date: start)
        ctx.insert(newDay)
        return newDay
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            show("Import failed", error.localizedDescription)

        case .success(let urls):
            guard let url = urls.first else { return }

            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)

                // 1) WOYP Plus share file
                if let didImport = try? RecipeShareImport.importRecipe(from: data, into: ctx) {
                    show(
                        didImport ? "Recipe added" : "Already exists",
                        didImport ? "Recipe successfully imported." : "This recipe is already in your library."
                    )
                    return
                }

                // 2) Foundation single recipe export fallback
                if let didImport = try? FoundationRecipeImport.importRecipe(from: data, into: ctx) {
                    show(
                        didImport ? "Recipe added" : "Already exists",
                        didImport ? "Recipe successfully imported." : "This recipe is already in your library."
                    )
                    return
                }

                show("Import failed", "File format not recognised.")
            } catch {
                show("Import failed", error.localizedDescription)
            }
        }
    }

    // MARK: - Delete

    private func delete(_ recipe: Recipe) {
        ctx.delete(recipe)
        try? ctx.save()
    }

    private func show(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    // MARK: - UI helpers

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
