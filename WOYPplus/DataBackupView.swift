import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataBackupView: View {

    @Environment(\.modelContext) private var ctx

    // Single exporter state
    @State private var exportData: Data = Data()
    @State private var exportFilename: String = "WOYP_Backup"
    @State private var showingExporter = false

    // Import flow
    @State private var showingImporter = false
    @State private var pendingImportData: Data?
    @State private var pendingImportSummary: ImportSummary?
    @State private var confirmImport = false

    // Alerts
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    // Trust indicators
    @AppStorage("backup_lastRecipeExportAt") private var lastRecipeExportAt: Double = 0
    @AppStorage("backup_lastAllDataExportAt") private var lastAllDataExportAt: Double = 0
    @AppStorage("backup_lastImportAt") private var lastImportAt: Double = 0

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

                VStack(alignment: .leading, spacing: 6) {
                    trustLine(label: "Last recipe export", timestamp: lastRecipeExportAt)
                    trustLine(label: "Last all-data export", timestamp: lastAllDataExportAt)
                }
                .padding(.vertical, 6)
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

                trustLine(label: "Last import", timestamp: lastImportAt)
                    .padding(.vertical, 6)
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

        // Pick a file
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handlePickedFile(result)
        }

        // Confirm after preview
        .confirmationDialog(
            "Import backup?",
            isPresented: $confirmImport,
            titleVisibility: .visible
        ) {
            Button("Import", role: .destructive) {
                performPendingImport()
            }
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
                pendingImportSummary = nil
            }
        } message: {
            if let s = pendingImportSummary {
                Text(s.message)
            }
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

        let payload = RecipeLibraryBackupV1(
            schema: BackupSchemas.recipeLibraryV1,
            exportedAt: Date(),
            recipes: recipes.map { BackupRecipeDTO(from: $0) }
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)

            exportData = data
            exportFilename = "WOYP_RecipeLibrary"
            lastRecipeExportAt = Date().timeIntervalSince1970

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

        let payload = AllDataBackupV1(
            schema: BackupSchemas.allDataV1,
            exportedAt: Date(),
            days: days.map { BackupDayDTO(from: $0) },
            entries: entries.map { BackupEntryDTO(from: $0) },
            recipes: recipes.map { BackupRecipeDTO(from: $0) }
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)

            exportData = data
            exportFilename = "WOYP_AllData"
            lastAllDataExportAt = Date().timeIntervalSince1970

            showingExporter = false
            DispatchQueue.main.async { showingExporter = true }
        } catch {
            show("Export failed", "Could not encode All Data backup.")
        }
    }

    // MARK: - Import (preview → confirm → import)

    private func handlePickedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            show("Import failed", error.localizedDescription)

        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                let didStart = url.startAccessingSecurityScopedResource()
                defer { if didStart { url.stopAccessingSecurityScopedResource() } }

                let data = try Data(contentsOf: url)

                // Preview / classify
                if let summary = makeSummary(for: data) {
                    pendingImportData = data
                    pendingImportSummary = summary
                    confirmImport = true
                } else {
                    show("Import failed", "File format not recognised.")
                }
            } catch {
                show("Import failed", error.localizedDescription)
            }
        }
    }

    private func performPendingImport() {
        guard let data = pendingImportData else { return }

        defer {
            pendingImportData = nil
            pendingImportSummary = nil
        }

        // 1) New all-data V1
        if let allV1 = tryDecode(AllDataBackupV1.self, from: data) {
            restoreAllData(days: allV1.days, recipes: allV1.recipes, entries: allV1.entries)
            lastImportAt = Date().timeIntervalSince1970
            show("Restore complete", "All data restored.")
            return
        }

        // 2) Old all-data (backwards compatible)
        if let oldAll = tryDecode(BackupAllDataDTO.self, from: data) {
            restoreAllData(days: oldAll.days, recipes: oldAll.recipes, entries: oldAll.entries)
            lastImportAt = Date().timeIntervalSince1970
            show("Restore complete", "All data restored.")
            return
        }

        // 3) New recipe-library V1
        if let libV1 = tryDecode(RecipeLibraryBackupV1.self, from: data) {
            restoreRecipes(libV1.recipes)
            lastImportAt = Date().timeIntervalSince1970
            show("Restore complete", "Recipes restored.")
            return
        }

        // 4) Old recipe-library array
        if let recipes = tryDecode([BackupRecipeDTO].self, from: data) {
            restoreRecipes(recipes)
            lastImportAt = Date().timeIntervalSince1970
            show("Restore complete", "Recipes restored.")
            return
        }

        show("Import failed", "File format not recognised.")
    }

    private func makeSummary(for data: Data) -> ImportSummary? {

        if let allV1 = tryDecode(AllDataBackupV1.self, from: data) {
            return ImportSummary(
                kind: "All Data",
                message: "This backup contains:\n• \(allV1.days.count) days\n• \(allV1.entries.count) entries\n• \(allV1.recipes.count) recipes\n\nImport will add missing items and skip duplicates."
            )
        }

        if let oldAll = tryDecode(BackupAllDataDTO.self, from: data) {
            return ImportSummary(
                kind: "All Data",
                message: "This backup contains:\n• \(oldAll.days.count) days\n• \(oldAll.entries.count) entries\n• \(oldAll.recipes.count) recipes\n\nImport will add missing items and skip duplicates."
            )
        }

        if let libV1 = tryDecode(RecipeLibraryBackupV1.self, from: data) {
            return ImportSummary(
                kind: "Recipe Library",
                message: "This file contains:\n• \(libV1.recipes.count) recipes\n\nImport will add missing recipes and skip duplicates."
            )
        }

        if let arr = tryDecode([BackupRecipeDTO].self, from: data) {
            return ImportSummary(
                kind: "Recipe Library",
                message: "This file contains:\n• \(arr.count) recipes\n\nImport will add missing recipes and skip duplicates."
            )
        }

        return nil
    }

    private func tryDecode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        do {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            return try dec.decode(type, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Restore (insert only if not already present)

    private func restoreRecipes(_ dtos: [BackupRecipeDTO]) {
        // Canonical fingerprint de-dupe
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
        // keep UX quiet; caller shows “Recipes restored.”
        _ = inserted
    }

    private func restoreAllData(days: [BackupDayDTO], recipes: [BackupRecipeDTO], entries: [BackupEntryDTO]) {
        // Days: de-dupe by start-of-day
        let existingDays = (try? ctx.fetch(FetchDescriptor<Day>())) ?? []
        var dayMap: [Date: Day] = [:]
        dayMap.reserveCapacity(existingDays.count)

        for d in existingDays {
            let key = Day.startOfDay(for: d.date)
            dayMap[key] = d
        }

        for dto in days {
            let key = Day.startOfDay(for: dto.date)
            if dayMap[key] != nil { continue }
            let newDay = dto.toModel()
            ctx.insert(newDay)
            dayMap[key] = newDay
        }

        // Recipes: reuse recipe restore logic
        restoreRecipes(recipes)

        // Entries: de-dupe by (createdAt + title + macros + mealSlot) approx
        let existingEntries = (try? ctx.fetch(FetchDescriptor<Entry>())) ?? []
        var existingEntryKeys = Set(existingEntries.map { EntryFingerprint.fromEntry($0) })

        for dto in entries {
            let key = EntryFingerprint.fromBackupValues(
                title: dto.title,
                mealSlotRaw: dto.mealSlotRaw,
                carbsG: dto.carbsG,
                proteinG: dto.proteinG,
                fatG: dto.fatG,
                fibreG: dto.fibreG,
                caloriesKcal: dto.caloriesKcal,
                isEstimate: dto.isEstimate,
                createdAt: dto.createdAt
            )
            if existingEntryKeys.contains(key) { continue }
            existingEntryKeys.insert(key)

            let entry = dto.toModel()
            // Attach to the correct day (if present); otherwise create it
            let dayKey = Day.startOfDay(for: dto.createdAt)
            let target = dayMap[dayKey] ?? {
                let newDay = Day(date: dayKey)
                ctx.insert(newDay)
                dayMap[dayKey] = newDay
                return newDay
            }()
            entry.day = target
            ctx.insert(entry)
        }

        try? ctx.save()
    }

    // MARK: - Trust UI

    private func trustLine(label: String, timestamp: Double) -> some View {
        let text: String
        if timestamp <= 0 {
            text = "—"
        } else {
            let d = Date(timeIntervalSince1970: timestamp)
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            text = df.string(from: d)
        }

        return HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Alerts

    private func show(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    // MARK: - UI row

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

// MARK: - Schemas / Headers

private enum BackupSchemas {
    static let recipeLibraryV1 = "woypplus.backup.recipeLibrary.v1"
    static let allDataV1 = "woypplus.backup.allData.v1"
}

private struct RecipeLibraryBackupV1: Codable {
    let schema: String
    let exportedAt: Date
    let recipes: [BackupRecipeDTO]
}

private struct AllDataBackupV1: Codable {
    let schema: String
    let exportedAt: Date
    let days: [BackupDayDTO]
    let entries: [BackupEntryDTO]
    let recipes: [BackupRecipeDTO]
}

private struct ImportSummary: Identifiable {
    let id = UUID()
    let kind: String
    let message: String
}

// MARK: - DTOs (kept stable)

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
    var mealSlotRaw: String
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var fibreG: Double
    var caloriesKcal: Double
    var isEstimate: Bool
    var createdAt: Date

    init(from e: Entry) {
        title = e.title
        mealSlotRaw = e.mealSlot.rawValue
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
            mealSlot: MealSlot(rawValue: mealSlotRaw) ?? .snacks,
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

// Old format (backwards compatibility)
private struct BackupAllDataDTO: Codable {
    var days: [BackupDayDTO]
    var entries: [BackupEntryDTO]
    var recipes: [BackupRecipeDTO]
}


