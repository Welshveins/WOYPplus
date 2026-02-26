import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataBackupView: View {

    @Environment(\.modelContext) private var ctx

    // Single exporter state
    @State private var exportData: Data = Data()
    @State private var exportFilename: String = "WOYP_Backup"
    @State private var showingExporter = false

    // Import + alerts
    @State private var showingImporter = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {

        List {

            Section("Export") {

                Button {
                    exportRecipeLibrary()
                } label: {
                    actionRow(
                        systemImage: "square.and.arrow.up",
                        title: "Export Recipe Library"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    exportAllData()
                } label: {
                    actionRow(
                        systemImage: "square.and.arrow.up.fill",
                        title: "Export All Data"
                    )
                }
                .buttonStyle(.plain)
            }

            Section("Import") {

                Button {
                    showingImporter = true
                } label: {
                    actionRow(
                        systemImage: "square.and.arrow.down",
                        title: "Import Backup File"
                    )
                }
                .buttonStyle(.plain)
            }

            Section {
                Text("Export saves a backup file to Files, AirDrop or Messages. Import restores from a previous backup.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)

        // ✅ ONE exporter only (prevents SwiftUI state conflicts)
        .fileExporter(
            isPresented: $showingExporter,
            document: BackupDocument(data: exportData),
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            showingExporter = false
            if case .failure(let error) = result {
                show("Export failed", error.localizedDescription)
            }
        }

        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }

        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Export

    private func exportRecipeLibrary() {
        let recipes = (try? ctx.fetch(FetchDescriptor<Recipe>())) ?? []

        guard !recipes.isEmpty else {
            show("No recipes to export", "Your recipe library is empty.")
            return
        }

        let payload = recipes.map { BackupRecipeDTO(from: $0) }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)

            exportData = data
            exportFilename = "WOYP_RecipeLibrary"

            showingExporter = false
            DispatchQueue.main.async { showingExporter = true }
        } catch {
            show("Export failed", error.localizedDescription)
        }
    }

    private func exportAllData() {
        let days = (try? ctx.fetch(FetchDescriptor<Day>())) ?? []
        let entries = (try? ctx.fetch(FetchDescriptor<Entry>())) ?? []
        let recipes = (try? ctx.fetch(FetchDescriptor<Recipe>())) ?? []

        let payload = BackupAllDataDTO(
            days: days.map { BackupDayDTO(from: $0) },
            entries: entries.map { BackupEntryDTO(from: $0) },
            recipes: recipes.map { BackupRecipeDTO(from: $0) }
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)

            exportData = data
            exportFilename = "WOYP_AllData"

            showingExporter = false
            DispatchQueue.main.async { showingExporter = true }
        } catch {
            show("Export failed", "Could not encode All Data backup.")
        }
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            show("Import failed", error.localizedDescription)

        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let didStart = url.startAccessingSecurityScopedResource()
                defer { if didStart { url.stopAccessingSecurityScopedResource() } }

                let data = try Data(contentsOf: url)

                if let full = try? JSONDecoder().decode(BackupAllDataDTO.self, from: data) {
                    restoreAllData(full)
                    show("Restore complete", "All data restored.")
                    return
                }

                if let recipes = try? JSONDecoder().decode([BackupRecipeDTO].self, from: data) {
                    restoreRecipes(recipes)
                    show("Restore complete", "Recipes restored.")
                    return
                }

                show("Import failed", "File format not recognised.")
            } catch {
                show("Import failed", error.localizedDescription)
            }
        }
    }

    // MARK: - Restore (with de-dupe)

    private func restoreRecipes(_ dtos: [BackupRecipeDTO]) {

        // Build canonical fingerprints from existing recipes (robust against old UUID fingerprints)
        var existingCanonical = Set<String>()
        let existing = (try? ctx.fetch(FetchDescriptor<Recipe>())) ?? []
        existingCanonical.reserveCapacity(existing.count)

        var didMigrateAny = false
        for r in existing {
            let fp = RecipeFingerprint.fromRecipe(r)
            existingCanonical.insert(fp)
            if r.sourceFingerprint != fp {
                r.sourceFingerprint = fp
                didMigrateAny = true
            }
        }
        if didMigrateAny { try? ctx.save() }

        // Insert only new
        var inserted = 0
        for dto in dtos {
            let fp = RecipeFingerprint.make(
                title: dto.title,
                categoryRaw: dto.categoryRaw,
                caloriesKcal: dto.caloriesKcal,
                carbsG: dto.carbsG,
                proteinG: dto.proteinG,
                fatG: dto.fatG,
                fibreG: dto.fibreG
            )

            if existingCanonical.contains(fp) { continue }
            existingCanonical.insert(fp)

            ctx.insert(dto.toModel(fingerprint: fp))
            inserted += 1
        }

        try? ctx.save()

        if inserted == 0 {
            // optional: quiet UX; no alert here, caller already shows "Recipes restored."
        }
    }

    private func restoreAllData(_ dto: BackupAllDataDTO) {

        // Days/entries logic left as-is (your all-data restore works well)
        dto.days.forEach { ctx.insert($0.toModel()) }
        dto.entries.forEach { ctx.insert($0.toModel()) }

        // Recipes: de-dupe using canonical fingerprint
        restoreRecipes(dto.recipes)

        try? ctx.save()
    }

    private func show(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    // MARK: - UI

    private func actionRow(systemImage: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
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
}

// MARK: - FileDocument

private struct BackupDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - DTOs

private struct BackupRecipeDTO: Codable {
    var title: String
    var categoryRaw: String
    var caloriesKcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var fibreG: Double

    init(from r: Recipe) {
        title = r.title
        categoryRaw = r.categoryRaw
        caloriesKcal = r.caloriesKcal
        carbsG = r.carbsG
        proteinG = r.proteinG
        fatG = r.fatG
        fibreG = r.fibreG
    }

    func toModel(fingerprint: String) -> Recipe {
        Recipe(
            title: title,
            categoryRaw: categoryRaw,
            caloriesKcal: caloriesKcal,
            carbsG: carbsG,
            proteinG: proteinG,
            fatG: fatG,
            fibreG: fibreG,
            sourceFingerprint: fingerprint
        )
    }
}

private struct BackupEntryDTO: Codable {
    var title: String
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var fibreG: Double
    var caloriesKcal: Double
    var isEstimate: Bool
    var createdAt: Date

    init(from e: Entry) {
        title = e.title
        carbsG = e.carbsG
        proteinG = e.proteinG
        fatG = e.fatG
        fibreG = e.fibreG
        caloriesKcal = e.caloriesKcal
        isEstimate = e.isEstimate
        createdAt = e.createdAt
    }

    func toModel() -> Entry {
        Entry(
            title: title,
            mealSlot: .snacks,
            carbsG: carbsG,
            proteinG: proteinG,
            fatG: fatG,
            fibreG: fibreG,
            caloriesKcal: caloriesKcal,
            isEstimate: isEstimate,
            createdAt: createdAt
        )
    }
}

private struct BackupDayDTO: Codable {
    var date: Date

    init(from d: Day) {
        date = d.date
    }

    func toModel() -> Day {
        Day(date: date)
    }
}

private struct BackupAllDataDTO: Codable {
    var days: [BackupDayDTO]
    var entries: [BackupEntryDTO]
    var recipes: [BackupRecipeDTO]
}
