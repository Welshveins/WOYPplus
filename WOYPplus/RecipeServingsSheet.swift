import SwiftUI
import SwiftData

struct RecipeServingsSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    let recipe: Recipe
    let day: Day
    let mealSlot: MealSlot

    @State private var servings: Double = 1.0

    @State private var showingShareExplainer = false
    @State private var shareURL: URL?
    @State private var showingShareSheet = false

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private let options: [Double] = [
        0.25, 0.5, 0.75,
        1.0,
        1.25, 1.5, 1.75,
        2.0
    ]

    var body: some View {

        NavigationStack {

            VStack(spacing: 16) {

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.title)
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(2)

                    Text(mealSlot.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                // Stage 4: Share (Option A style)
                Button {
                    showingShareExplainer = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 26)
                        Text("Share recipe")
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Servings")
                        .font(.headline)

                    LazyVGrid(columns: grid, spacing: 10) {
                        ForEach(options, id: \.self) { v in
                            Button {
                                servings = v
                            } label: {
                                Text(formatServing(v))
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.woypSlate.opacity(servings == v ? 0.32 : 0.12))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.white.opacity(servings == v ? 0.18 : 0.10), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("This entry")
                        .font(.headline)

                    Text(previewLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .navigationTitle("Log recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        .onAppear { servings = 1.0 }
        .confirmationDialog(
            "Share recipe",
            isPresented: $showingShareExplainer,
            titleVisibility: .visible
        ) {
            Button("Share…") { shareNow() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Shares a small recipe file you can send via AirDrop / WhatsApp / Messages.")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var grid: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    }

    private var previewLine: String {
        let kcal = recipe.caloriesKcal * servings
        let c = recipe.carbsG * servings
        let p = recipe.proteinG * servings
        let f = recipe.fatG * servings
        let fi = recipe.fibreG * servings

        return "\(Int(kcal.rounded())) kcal • C \(Int(c.rounded()))g • P \(Int(p.rounded()))g • F \(Int(f.rounded()))g • Fibre \(Int(fi.rounded()))g"
    }

    private func shareNow() {
        do {
            let url = try RecipeShareCodec.writeTempShareFile(for: recipe)
            shareURL = url
            showingShareSheet = true
        } catch {
            alertTitle = "Share failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func save() {

        let entry = Entry(
            title: recipe.title,
            mealSlot: mealSlot,
            carbsG: recipe.carbsG * servings,
            proteinG: recipe.proteinG * servings,
            fatG: recipe.fatG * servings,
            fibreG: recipe.fibreG * servings,
            caloriesKcal: recipe.caloriesKcal * servings,
            isEstimate: false,
            day: day,
            recipe: recipe,
            servings: servings
        )

        ctx.insert(entry)
        try? ctx.save()

        dismiss()
    }

    private func formatServing(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 { return "\(Int(v))" }
        return String(v)
    }
}
