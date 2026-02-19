import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupView: View {

    @Environment(\.modelContext) private var ctx

    @Query(sort: \Day.date, order: .reverse) private var days: [Day]
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]

    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var statusText: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {

                Text("Backup")
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(-0.4)

                Text("Export a file you can keep anywhere. Import it later if you change phone.")
                    .foregroundStyle(.secondary)

                // Export / Import buttons (Option A: icon + label)
                VStack(spacing: 10) {

                    // EXPORT
                    if let url = exportURL {
                        ShareLink(item: url) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share backup file")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.woypSlate.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            createBackupFile()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Create backup file")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.woypSlate.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // IMPORT
                    Button {
                        showImporter = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "tray.and.arrow.down")
                            Text("Import backup file")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.woypSlate.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)

                    // Lightweight guidance copy (your locked requirement)
                    Text("Import adds anything missing. It won’t delete your current data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .padding(.top, 6)

                if let statusText {
                    Text(statusText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importBackup(from: url)
            case .failure(let error):
                statusText = "Import failed: \(error.localizedDescription)"
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Backup").font(.headline)
            }
        }
    }

    private func createBackupFile() {
        do {
            let dto = DataBackup.makeBackup(days: days, entries: entries)
            let data = try JSONEncoder.pretty.encode(dto)

            let filename = "WOYPPlus_Backup_\(Date().backupStamp).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            try data.write(to: url, options: [.atomic])
            exportURL = url
            statusText = "Backup file created."
        } catch {
            statusText = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importBackup(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let backup = try JSONDecoder().decode(WOYPBackupDTO.self, from: data)

            try DataBackup.restore(backup: backup, into: ctx)

            statusText = "Import complete."
        } catch {
            statusText = "Import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helpers

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

private extension JSONDecoder {
    convenience init() {
        self.init()
        self.dateDecodingStrategy = .iso8601
    }
}

private extension Date {
    static var backupStampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmm"
        return df
    }()

    var backupStamp: String { Date.backupStampFormatter.string(from: self) }
}
