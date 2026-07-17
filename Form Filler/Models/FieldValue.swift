//
//  FieldValue.swift
//  Form Filler
//

import Foundation

/// A value entered during a fill session, keyed by field ID in
/// `FillSessionViewModel`.
///
/// Deliberately NOT Codable: fill values are in-memory only and must never
/// be persisted to disk (CLAUDE.md invariant #3). The only artifact that may
/// contain patient data is the exported PDF the user explicitly shares.
nonisolated enum FieldValue: Equatable, Sendable {
    case text(String)
    case date(Date)
    case checkbox(Bool)
}
