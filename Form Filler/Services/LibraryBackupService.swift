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
    /// The user's signature image (PNG/JPEG bytes), when one is set up.
    var signatureBase64: String?
    /// Practitioner profiles (the user's own details, no PHI).
    var practitioners: [PractitionerProfile]

    init(
        schemaVersion: Int = LibraryBackup.currentSchemaVersion,
        exportedAt: Date = .now,
        entries: [Entry],
        signatureBase64: String? = nil,
        practitioners: [PractitionerProfile] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.entries = entries
        self.signatureBase64 = signatureBase64
        self.practitioners = practitioners
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? .now
        entries = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        signatureBase64 = try container.decodeIfPresent(String.self, forKey: .signatureBase64)
        practitioners = try container.decodeIfPresent([PractitionerProfile].self, forKey: .practitioners) ?? []
    }
}

nonisolated struct LibraryBackupService: Sendable {
    let store: TemplateStore
    var signatureStore = SignatureStore()
    var practitionerStore = PractitionerStore()

    /// `Form Filler Library Backup <yyyy-MM-dd>.json`
    static func defaultFileName(on date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Form Filler Library Backup \(formatter.string(from: date)).json"
    }

    /// Serializes the whole library (plus the stored signature, if any).
    /// Throws if there's nothing to back up (an empty backup is more
    /// likely a mistake than an intent).
    func exportBackup() throws -> Data {
        let templates = try store.loadAll()
        guard !templates.isEmpty else { throw LibraryBackupError.emptyBackup }
        let entries = try templates.map { template in
            LibraryBackup.Entry(
                template: template,
                pdfBase64: try Data(contentsOf: store.pdfURL(for: template)).base64EncodedString()
            )
        }
        return try TemplateStore.makeEncoder().encode(LibraryBackup(
            entries: entries,
            signatureBase64: signatureStore.loadData()?.base64EncodedString(),
            practitioners: practitionerStore.load()
        ))
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

        // Add-only, like templates: the backup's signature is used only
        // when this device doesn't already have one.
        if !signatureStore.exists,
           let base64 = backup.signatureBase64,
           let data = Data(base64Encoded: base64) {
            try? signatureStore.save(data)
        }

        // Practitioner profiles merge add-only by ID too.
        if !backup.practitioners.isEmpty {
            var profiles = practitionerStore.load()
            let existingIDs = Set(profiles.map(\.id))
            let missing = backup.practitioners.filter { !existingIDs.contains($0.id) }
            if !missing.isEmpty {
                profiles.append(contentsOf: missing)
                try? practitionerStore.save(profiles)
            }
        }
        return summary
    }
}
