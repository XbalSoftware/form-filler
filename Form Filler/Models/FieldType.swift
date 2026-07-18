//
//  FieldType.swift
//  Form Filler
//

import Foundation

/// The kind of content a field holds.
///
/// Adding a case requires a switch arm in exactly two places: the overlay
/// view factory and the export renderer (see CLAUDE.md).
///
/// `nonisolated` opts out of the project's MainActor-by-default isolation:
/// models and storage must be usable from any concurrency context.
nonisolated enum FieldType: String, Codable, CaseIterable, Sendable {
    case singleLineText
    case multiLineText
    case date
    case checkbox
    case staticText
    /// Single-line text whose value also feeds the export filename.
    /// At most one per template (enforced by the editor inspector).
    case patientName

    /// Unknown raw values (from a newer schema) fall back to plain text
    /// rather than failing the whole template decode.
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FieldType(rawValue: raw) ?? .singleLineText
    }

    var displayName: String {
        switch self {
        case .singleLineText: "Single-line Text"
        case .multiLineText: "Multi-line Text"
        case .date: "Date"
        case .checkbox: "Checkbox"
        case .staticText: "Static Text"
        case .patientName: "Patient Name"
        }
    }
}
