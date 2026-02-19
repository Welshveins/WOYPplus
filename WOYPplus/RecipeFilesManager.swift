import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RecipesManagerView: View {

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]

    @State private var queryText = ""
    @State private var showingImporter = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var filtered: [Recipe] {
        let q = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return recipes }
        return recipes.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {

        NavigationStack {
            List {

                Section {
                    TextField("Search recipes", text: $queryText)
                }

                if recipes.isEmpty {
                    Section {
                        Text("No recipes yet. Import your Foundation exports to pre-populate WOYP Plus.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Recipes") {
                    ForEach(filtered) { r in
                        HStack(spacing: 12) {
                            thumbnail(for: r)

                            VStack(alignment: .leading, spacing: 4) {
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
                }

                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Foundation recipe .json files", systemImage: "square.and.arrow.down")
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
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(10)
                            .background(Circle().fill(Color.woypSlate.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    importFoundationRecipes(urls)
                case .failure(let error):
                    toast("Import failed", error.localizedDescription)
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func importFoundationRecipes(_ urls: [URL]) {

        var imported = 0
        var failed = 0

        for url in urls {
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)
                try FoundationRecipeImport.importRecipe(from: data, into: ctx)
                imported += 1
            } catch {
                failed += 1
            }
        }

        toast("Import complete", "Imported \(imported). Failed \(failed).")
    }

    private func toast(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
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
