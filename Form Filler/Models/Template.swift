//
//  Template.swift
//  Form Filler
//

import Foundation

/// Metadata and field layout for one imported PDF, persisted as
/// `template.json` inside the template's folder. The imported PDF itself
/// (`pdfFileName`) is read-only forever (CLAUDE.md invariant #1).
nonisolated struct Template: Codable, Identifiable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let id: UUID
    var schemaVersion: Int
    var name: String
    var category: String?
    var createdAt: Date
    var modifiedAt: Date
    var pdfFileName: String          // relative to the template's folder
    var fields: [FieldDefinition]

    init(
        id: UUID = UUID(),
        schemaVersion: Int = Template.currentSchemaVersion,
        name: String,
        category: String? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        pdfFileName: String = "original.pdf",
        fields: [FieldDefinition] = []
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.category = category
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.pdfFileName = pdfFileName
        self.fields = fields
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        category = try container.decodeIfPresent(String.self, forKey: .category)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .now
        pdfFileName = try container.decodeIfPresent(String.self, forKey: .pdfFileName) ?? "original.pdf"
        fields = try container.decodeIfPresent([FieldDefinition].self, forKey: .fields) ?? []
    }

    /// Fields in fill-form order.
    var orderedFields: [FieldDefinition] {
        fields.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }
}
