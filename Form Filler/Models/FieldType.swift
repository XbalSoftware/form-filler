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
    /// Stamps the user's stored signature image (SignatureStore), toggled
    /// on/off during fill. Its session value reuses `.checkbox(Bool)` —
    /// "signed or not" — so FieldValue/CodableFieldValue stay unchanged.
    case signature
    // Practitioner fields: auto-populated as `.text` values from the
    // selected PractitionerProfile when a fill session starts (and when
    // the profile picker changes). Never shown in the fill form list.
    case doctorName
    case officeAddress
    case officeFax
    case officePhone
    case officeEmail
    case practitionerID

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
        case .signature: "Signature"
        case .doctorName: "Doctor Name"
        case .officeAddress: "Office Address"
        case .officeFax: "Office Fax"
        case .officePhone: "Office Phone"
        case .officeEmail: "Email"
        case .practitionerID: "Practitioner ID"
        }
    }

    /// Types auto-populated from the selected practitioner profile.
    var isPractitionerField: Bool {
        switch self {
        case .doctorName, .officeAddress, .officeFax, .officePhone, .officeEmail, .practitionerID:
            true
        default:
            false
        }
    }

    /// Types whose text wraps (and fits by height) rather than staying on
    /// one line. Drives TextFitting and the export/preview layout.
    var isMultiline: Bool {
        self == .multiLineText || self == .officeAddress
    }
}
