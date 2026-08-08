//
//  FieldValue.swift
//  Form Filler
//

import Foundation

/// A value entered during a fill session, keyed by field ID in
/// `FillSessionViewModel`.
///
/// Deliberately NOT Codable so nothing can casually persist patient data
/// (CLAUDE.md invariant #3). The only sanctioned serialization is
/// `FillSessionPayload`/`CodableFieldValue`, used exclusively by the
/// encrypted draft vault and the payload embedded in exported PDFs — both
/// explicit user requests.
nonisolated enum FieldValue: Equatable, Sendable {
    case text(String)
    case date(Date)
    case checkbox(Bool)
}
