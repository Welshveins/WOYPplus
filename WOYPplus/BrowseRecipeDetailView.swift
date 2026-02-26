import SwiftUI
import SwiftData
import UIKit

struct BrowseRecipeDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let recipe: Recipe
    let onEdit: (Recipe) -> Void
    let onDelete: (Recipe) -> Void

    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {

                header

                if let data = recipe.photoData,
                   let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                macrosCard

                if !recipe.ingredients.isEmpty {
                    ingredientsCard
                }

                actionsCard

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(Color.woypSlate.opacity(0.15).ignoresSafeArea())
        .navigationTitle("Recipe")
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
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - UI blocks

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.title)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.3)

            if !recipe.categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(recipe.categoryRaw)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Macros")
                .font(.headline)

            VStack(spacing: 8) {
                macroRow(label: "kcal", value: Int(recipe.caloriesKcal.rounded()), tint: .secondary, suffix: "")
                macroRow(label: "Carbs", value: Int(recipe.carbsG.rounded()), tint: .woypSand, suffix: "g")
                macroRow(label: "Protein", value: Int(recipe.proteinG.rounded()), tint: .woypTeal, suffix: "g")
                macroRow(label: "Fat", value: Int(recipe.fatG.rounded()), tint: .woypTerracotta, suffix: "g")
                macroRow(label: "Fibre", value: Int(recipe.fibreG.rounded()), tint: .secondary, suffix: "g")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.woypSlate.opacity(0.08))
        )
    }

    private func macroRow(label: String, value: Int, tint: Color, suffix: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(value)\(suffix)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients")
                .font(.headline)

            ForEach(recipe.ingredients, id: \.self) { ing in
                HStack(alignment: .firstTextBaseline) {
                    Text(ing.name)
                        .font(.subheadline)

                    Spacer()

                    Text("\(Int(ing.amountGrams.rounded())) g")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.woypSlate.opacity(0.08))
        )
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {

            Button {
                shareRecipe()
            } label: {
                actionRow(systemImage: "square.and.arrow.up", title: "Share recipe")
            }
            .buttonStyle(.plain)

            Button {
                onEdit(recipe)
            } label: {
                actionRow(systemImage: "pencil", title: "Edit recipe")
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onDelete(recipe)
            } label: {
                actionRow(systemImage: "trash", title: "Delete recipe", destructive: true)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.woypSlate.opacity(0.08))
        )
    }

    private func actionRow(systemImage: String, title: String, destructive: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 26)
                .foregroundStyle(destructive ? .red : .primary)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(destructive ? .red : .primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
        )
    }

    // MARK: - Share

    private func shareRecipe() {
        do {
            let url = try RecipeShareCodec.writeTempShareFile(for: recipe)
            shareItems = [url]
            showingShareSheet = true
        } catch {
            alertTitle = "Share failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - UIKit share sheet


