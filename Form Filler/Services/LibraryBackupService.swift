//
//  LibraryBackupService.swift
//  Form Filler
//
//  Whole-library backup as ONE file: a JSON container holding every
//  template's metadata/fields plus its original PDF bytes (base64), so a
//  library can be reconstructed from nothing. JSON-with-base64 was chosen
//  over an archive format because the app is native-frameworks-only (no
//  zip API for reading) and the file stays debuggable in a text editor.
//
//  Templates hold no patient data (invariant #3), so a backup file is
//  safe to store anywhere.
//

import Foundation

nonisolated enum LibraryBackupError: LocalizedError {
    case unreadableBackup
    case emptyBackup

    var errorDescription: String? {
        switch self {
        case .unreadableBackup: "This file isn't a readable Form Filler library backup."
        case .emptyBackup: "There are no templates to back up."
        }
    }
}

/// The backup file's shape. Decoded defensively so future fields don't
/// break old app versions.
nonisolated struct LibraryBackup: Codable, Sendable {
    static let currentSchemaVersion = 1

    nonisolated struct Entry: Codable, Sendable {
        var template: Template
        var pdfBase64: String
    }

    var schemaVersion: Int
    var exportedAt: Date
    var entries: [Entry]

    init(schemaVersion: Int = LibraryBackup.currentSchemaVersion, exportedAt: Date = .now, entries: [Entry]) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.entries = entries
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? .now
        entries = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
    }
}

nonisolated struct LibraryBackupService: Sendable {
    let store: TemplateStore

    /// `Form Filler Library Backup <yyyy-MM-dd>.json`
    static func defaultFileName(on date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Form Filler Library Backup \(formatter.string(from: date)).json"
    }

    /// Serializes the whole library. Throws if there's nothing to back up
    /// (an empty backup is more likely a mistake than an intent).
    func exportBackup() throws -> Data {
        let templates = try store.loadAll()
        guard !templates.isEmpty else { throw LibraryBackupError.emptyBackup }
        let entries = try templates.map { template in
            LibraryBackup.Entry(
                template: template,
                pdfBase64: try Data(contentsOf: store.pdfURL(for: template)).base64EncodedString()
            )
        }
        return try TemplateStore.makeEncoder().encode(LibraryBackup(entries: entries))
    }

    nonisolated struct RestoreSummary: Equatable, Sendable {
        var imported = 0
        /// Templates whose ID already exists in the library — left untouched.
        var skipped = 0
    }

    /// Recreates templates from a backup file. Existing templates (same
    /// ID) are never overwritten — restore only ever adds. Thumbnails
    /// regenerate lazily on the next library load.
    func restore(from data: Data) throws -> RestoreSummary {
        guard let backup = try? TemplateStore.makeDecoder().decode(LibraryBackup.self, from: data),
              !backup.entries.isEmpty
        else { throw LibraryBackupError.unreadableBackup }

        var summary = RestoreSummary()
        for entry in backup.entries {
            guard let pdfData = Data(base64Encoded: entry.pdfBase64), !pdfData.isEmpty else {
                throw LibraryBackupError.unreadableBackup
            }
            do {
                try store.create(entry.template, pdfData: pdfData)
                summary.imported += 1
            } catch TemplateStoreError.templateAlreadyExists {
                summary.skipped += 1
            }
        }
        return summary
    }
}
