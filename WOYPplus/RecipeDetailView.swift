import SwiftUI
import SwiftData
import UIKit

struct RecipeDetailView: View {

    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    let onEdit: (Recipe) -> Void
    let onDelete: (Recipe) -> Void

    @State private var shareURL: URL?

    // MARK: Portion toggle
    private enum MacroMode: String, CaseIterable, Identifiable {
        case fullRecipe = "Full recipe"
        case perPortion = "Per portion"
        var id: String { rawValue }
    }

    @State private var macroMode: MacroMode = .fullRecipe
    @State private var portions: Double = 1

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {

                if let data = recipe.photoData,
                   let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text(recipe.title)
                    .font(.system(size: 24, weight: .semibold))
                    .padding(.top, 2)

                if !recipe.categoryRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(recipe.categoryRaw)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // ✅ Visible toggle card (this is what you’re missing on-screen)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Macros")
                        .font(.headline)

                    Picker("Macro mode", selection: $macroMode) {
                        ForEach(MacroMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if macroMode == .perPortion {
                        HStack {
                            Text("Portions")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Stepper(value: $portions, in: 1...24, step: 1) {
                                Text("\(Int(portions))")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                            }
                            .labelsHidden()
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.woypSlate.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
                .padding(.top, 6)

                // Your macros line (kept exactly in your style)
                VStack(alignment: .leading, spacing: 6) {
                    Text(macroMode == .fullRecipe ? "Full recipe" : "Per portion")
                        .font(.headline)

                    Text(macroLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !recipe.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ingredients")
                            .font(.headline)

                        ForEach(recipe.ingredients) { ing in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(Int(ing.amountGrams.rounded())) g")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            Divider().opacity(0.3)
                        }
                    }
                    .padding(.top, 10)
                }

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
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
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        onEdit(recipe)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        onDelete(recipe)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .bottomBar) {
                HStack(spacing: 12) {

                    Button {
                        onEdit(recipe)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.woypSlate.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)

                    if let url = shareURL {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.woypTerracotta.opacity(0.14))
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            shareURL = try? WOYPRecipeShareManager.makeShareURL(for: recipe)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.woypTerracotta.opacity(0.14))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            shareURL = try? WOYPRecipeShareManager.makeShareURL(for: recipe)
        }
    }

    // MARK: - Macro formatting

    private var macroLine: String {
        let divisor = max(1, macroMode == .perPortion ? portions : 1)

        let kcal = recipe.caloriesKcal / divisor
        let c = recipe.carbsG / divisor
        let p = recipe.proteinG / divisor
        let f = recipe.fatG / divisor
        let fi = recipe.fibreG / divisor

        return "\(Int(kcal.rounded())) kcal • C \(Int(c.rounded()))g • P \(Int(p.rounded()))g • F \(Int(f.rounded()))g • Fibre \(Int(fi.rounded()))g"
    }
}
