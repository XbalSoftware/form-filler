//
//  FillSessionPayload.swift
//  Form Filler
//
//  A codable snapshot of one fill session. This is the ONLY sanctioned
//  serialization of fill values (amended invariant #3), used by exactly
//  two features the user explicitly requested:
//
//    1. DraftStore — the encrypted on-device draft vault.
//    2. PDFExportService — the payload embedded in every exported PDF so
//       a form can be reopened for re-editing later.
//
//  `FieldValue` itself stays non-Codable so nothing else can casually
//  persist patient data; `CodableFieldValue` is the explicit bridge.
//

import Foundation

nonisolated struct FillSessionPayload: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var templateID: UUID
    /// Purely informational (shown when the matching template is missing).
    var templateName: String
    var savedAt: Date
    var values: [UUID: CodableFieldValue]

    init(
        schemaVersion: Int = FillSessionPayload.currentSchemaVersion,
        templateID: UUID,
        templateName: String,
        savedAt: Date = .now,
        values: [UUID: FieldValue]
    ) {
        self.schemaVersion = schemaVersion
        self.templateID = templateID
        self.templateName = templateName
        self.savedAt = savedAt
        self.values = values.mapValues(CodableFieldValue.init)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        templateID = try container.decode(UUID.self, forKey: .templateID)
        templateName = try container.decodeIfPresent(String.self, forKey: .templateName) ?? ""
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? .now
        values = try container.decodeIfPresent([UUID: CodableFieldValue].self, forKey: .values) ?? [:]
    }

    /// The transient in-memory form the app actually works with.
    var fieldValues: [UUID: FieldValue] {
        values.mapValues(\.fieldValue)
    }

    // MARK: - Serialization

    /// Prefix identifying a Form Filler payload inside a PDF's Keywords
    /// Info key. Version-bump the prefix if the payload shape ever breaks
    /// compatibility.
    static let embeddedPrefix = "FormFiller1:"

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// `FormFiller1:<base64 JSON>` — the string embedded in exported PDFs.
    func embeddedString() throws -> String {
        Self.embeddedPrefix + (try Self.makeEncoder().encode(self)).base64EncodedString()
    }

    /// Parses an embedded string back into a payload; nil if the string
    /// isn't ours or doesn't decode.
    static func fromEmbeddedString(_ string: String) -> FillSessionPayload? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(embeddedPrefix),
              let data = Data(base64Encoded: String(trimmed.dropFirst(embeddedPrefix.count)))
        else { return nil }
        return try? makeDecoder().decode(FillSessionPayload.self, from: data)
    }
}

/// Explicit Codable mirror of `FieldValue`.
nonisolated enum CodableFieldValue: Codable, Equatable, Sendable {
    case text(String)
    case date(Date)
    case checkbox(Bool)

    init(_ value: FieldValue) {
        switch value {
        case .text(let string): self = .text(string)
        case .date(let date): self = .date(date)
        case .checkbox(let isOn): self = .checkbox(isOn)
        }
    }

    var fieldValue: FieldValue {
        switch self {
        case .text(let string): .text(string)
        case .date(let date): .date(date)
        case .checkbox(let isOn): .checkbox(isOn)
        }
    }
}
