import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataBackupView: View {

    @Environment(\.modelContext) private var ctx

    @State private var exportData: Data?
    @State private var showingRecipeExporter = false
    @State private var showingAllDataExporter = false
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

        // Exporters
        .fileExporter(
            isPresented: $showingRecipeExporter,
            document: BackupDocument(data: exportData ?? Data()),
            contentType: .json,
            defaultFilename: "WOYP_RecipeLibrary"
        ) { _ in }

        .fileExporter(
            isPresented: $showingAllDataExporter,
            document: BackupDocument(data: exportData ?? Data()),
            contentType: .json,
            defaultFilename: "WOYP_AllData"
        ) { _ in }

        // Importer
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

    // MARK: Export

    private func exportRecipeLibrary() {

        let recipes = (try? ctx.fetch(FetchDescriptor<Recipe>())) ?? []
        let payload = recipes.map { BackupRecipeDTO(from: $0) }

        if let data = try? JSONEncoder().encode(payload) {
            exportData = data
            showingRecipeExporter = true
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

        if let data = try? JSONEncoder().encode(payload) {
            exportData = data
            showingAllDataExporter = true
        }
    }

    // MARK: Import

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

                // Try full restore first
                if let full = try? JSONDecoder().decode(BackupAllDataDTO.self, from: data) {
                    restoreAllData(full)
                    show("Restore complete", "All data restored.")
                    return
                }

                // Try recipe-only restore
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

    // MARK: Restore

    private func restoreRecipes(_ dtos: [BackupRecipeDTO]) {
        for dto in dtos {
            ctx.insert(dto.toModel())
        }
        try? ctx.save()
    }

    private func restoreAllData(_ dto: BackupAllDataDTO) {
        dto.days.forEach { ctx.insert($0.toModel()) }
        dto.recipes.forEach { ctx.insert($0.toModel()) }
        dto.entries.forEach { ctx.insert($0.toModel()) }
        try? ctx.save()
    }

    private func show(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    // MARK: UI

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

    // MARK: DTOs

    struct BackupRecipeDTO: Codable {
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

        func toModel() -> Recipe {
            Recipe(
                title: title,
                categoryRaw: categoryRaw,
                caloriesKcal: caloriesKcal,
                carbsG: carbsG,
                proteinG: proteinG,
                fatG: fatG,
                fibreG: fibreG,
                sourceFingerprint: UUID().uuidString
            )
        }
    }

    struct BackupEntryDTO: Codable {
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
                mealSlot: .snacks, // note: backup currently doesn’t restore original slot
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

    struct BackupDayDTO: Codable {
        var date: Date

        init(from d: Day) { date = d.date }

        func toModel() -> Day { Day(date: date) }
    }

    struct BackupAllDataDTO: Codable {
        var days: [BackupDayDTO]
        var entries: [BackupEntryDTO]
        var recipes: [BackupRecipeDTO]
    }
}

// MARK: FileDocument (MUST be outside body modifier chain)

struct BackupDocument: FileDocument {

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
