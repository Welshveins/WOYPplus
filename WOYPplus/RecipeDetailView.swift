import SwiftUI
import SwiftData

struct RecipeDetailView: View {

    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    let onEdit: (Recipe) -> Void
    let onDelete: (Recipe) -> Void

    @State private var shareURL: URL?

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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Per serving")
                        .font(.headline)

                    Text("\(Int(recipe.caloriesKcal.rounded())) kcal • C \(Int(recipe.carbsG.rounded()))g • P \(Int(recipe.proteinG.rounded()))g • F \(Int(recipe.fatG.rounded()))g • Fibre \(Int(recipe.fibreG.rounded()))g")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)

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
}
