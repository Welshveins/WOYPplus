import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataBackupView: View {

    @Environment(\.modelContext) private var ctx

    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDoc: WOYPBackupDocument?

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        List {

            Section {
                Text("Backup your data to a file, then restore it later if you change phone or reinstall.")
                    .foregroundStyle(.secondary)
            }

            Section("Export") {
                Button {
                    doExport()
                } label: {
                    Label("Export backup file", systemImage: "square.and.arrow.up")
                }
            }

            Section("Import") {
                Button {
                    showingImporter = true
                } label: {
                    Label("Import backup file", systemImage: "square.and.arrow.down")
                }
            }

            Section("What this does") {
                Text("Import will merge: it won’t delete existing data. Duplicate entries are skipped.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Import / Export")
        .navigationBarTitleDisplayMode(.inline)

        // IMPORTANT:
        // Do NOT add a custom back button here.
        // If you do, you’ll see two back arrows (system + custom).

        .fileExporter(
            isPresented: $showingExporter,
            document: exportDoc,
            contentType: .json,
            defaultFilename: defaultFilename()
        ) { result in
            switch result {
            case .success:
                toast(title: "Exported", message: "Backup file created.")
            case .failure(let error):
                toast(title: "Export failed", message: error.localizedDescription)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                doImport(from: url)
            case .failure(let error):
                toast(title: "Import failed", message: error.localizedDescription)
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func defaultFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return "WOYPPlus-backup-\(df.string(from: Date()))"
    }

    private func doExport() {
        let dto = DataBackup.makeBackup(days: days, entries: entries)
        exportDoc = WOYPBackupDocument(dto: dto)
        showingExporter = true
    }

    private func doImport(from url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let backup: WOYPBackupDTO
            if let iso = try? decoder.decode(WOYPBackupDTO.self, from: data) {
                backup = iso
            } else {
                let fallback = JSONDecoder()
                fallback.dateDecodingStrategy = .deferredToDate
                backup = try fallback.decode(WOYPBackupDTO.self, from: data)
            }

            try DataBackup.restore(backup: backup, into: ctx)
            toast(title: "Imported", message: "Backup merged into your data.")
        } catch {
            toast(title: "Import failed", message: error.localizedDescription)
        }
    }

    private func toast(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - FileDocument wrapper

struct WOYPBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var dto: WOYPBackupDTO

    init(dto: WOYPBackupDTO) {
        self.dto = dto
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let iso = try? decoder.decode(WOYPBackupDTO.self, from: data) {
            self.dto = iso
        } else {
            let fallback = JSONDecoder()
            fallback.dateDecodingStrategy = .deferredToDate
            self.dto = try fallback.decode(WOYPBackupDTO.self, from: data)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        return FileWrapper(regularFileWithContents: data)
    }
}
