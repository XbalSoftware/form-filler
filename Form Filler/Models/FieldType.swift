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
    // Patient fields: ordinary fillable text/date fields that also carry a
    // fixed meaning, so an imported patient PDF can map its parsed values
    // onto them (and so the editor names them after their type). Unlike
    // practitioner fields, these appear in the fill form for manual entry.
    case patientAddress
    case patientDateOfBirth
    case patientHealthcareNumber
    case patientPhone
    // Patient exam findings (OD = right eye, OS = left eye), parsed from an
    // imported IRIS exam PDF; also user-fillable.
    case patientRefractionOD
    case patientRefractionOS
    case patientVisualAcuityOD
    case patientVisualAcuityOS
    case patientKeratometryOD
    case patientKeratometryOS
    case patientIntraocularPressureOD
    case patientIntraocularPressureOS
    /// Auto-fills with today's date (DD MON YYYY), computed at render time
    /// so it's always current; never stored and never shown in the form.
    case referralDate

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
        case .staticText: "Static Text"
        case .patientName: "Patient Name"
        case .signature: "Signature"
        case .doctorName: "Doctor Name"
        case .officeAddress: "Office Address"
        case .officeFax: "Office Fax"
        case .officePhone: "Office Phone"
        case .officeEmail: "Doctor Email"
        case .practitionerID: "Practitioner ID"
        case .patientAddress: "Patient Address"
        case .patientDateOfBirth: "Patient DOB"
        case .patientHealthcareNumber: "Healthcare #"
        case .patientPhone: "Patient Phone"
        case .patientRefractionOD: "Refraction OD"
        case .patientRefractionOS: "Refraction OS"
        case .patientVisualAcuityOD: "VA OD"
        case .patientVisualAcuityOS: "VA OS"
        case .patientKeratometryOD: "Keratometry OD"
        case .patientKeratometryOS: "Keratometry OS"
        case .patientIntraocularPressureOD: "IOP OD"
        case .patientIntraocularPressureOS: "IOP OS"
        case .referralDate: "Referral Date"
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

    /// Patient-detail types an imported patient PDF can populate. They are
    /// still user-fillable in the form (unlike practitioner fields).
    var isPatientField: Bool {
        switch self {
        case .patientName, .patientAddress, .patientDateOfBirth,
             .patientHealthcareNumber, .patientPhone,
             .patientRefractionOD, .patientRefractionOS,
             .patientVisualAcuityOD, .patientVisualAcuityOS,
             .patientKeratometryOD, .patientKeratometryOS,
             .patientIntraocularPressureOD, .patientIntraocularPressureOS:
            true
        default:
            false
        }
    }

    /// Types whose meaning is fixed by the type itself, so a separate field
    /// name would be redundant — the editor names them after their type and
    /// hides the name box. Generic text/date/checkbox/static still need a
    /// user-supplied name.
    var isSelfLabeling: Bool {
        switch self {
        case .singleLineText, .multiLineText, .staticText:
            false
        default:
            true   // patientName, signature, practitioner + patient fields
        }
    }

    /// Types whose text wraps (and fits by height) rather than staying on
    /// one line. Drives TextFitting and the export/preview layout.
    var isMultiline: Bool {
        self == .multiLineText || self == .officeAddress || self == .patientAddress
    }
}
