//
//  PatientDemographics.swift
//  Form Filler
//
//  Patient details parsed from an imported EMR PDF — demographics plus
//  exam findings (VA, refraction, keratometry, IOP). Transient like all
//  fill-session data (CLAUDE.md invariant #3): never persisted on its own;
//  it feeds a fill session's patient fields only after the clinician
//  confirms the values in the review sheet.
//

import Foundation

nonisolated struct PatientDemographics: Equatable, Sendable {
    // Demographics
    var fullName: String?
    var address: String?            // address lines, comma-joined
    var dateOfBirth: String?        // reformatted "DD MON YYYY"
    var healthcareNumber: String?   // reformatted "#####-####"
    var phone: String?

    // Exam findings (per eye: OD = right, OS = left)
    var refractionOD: String?
    var refractionOS: String?
    var visualAcuityOD: String?
    var visualAcuityOS: String?
    var keratometryOD: String?
    var keratometryOS: String?
    var intraocularPressureOD: String?
    var intraocularPressureOS: String?

    var isEmpty: Bool { PatientDemographics.fieldMap.allSatisfy { self[keyPath: $0.value] == nil } }

    /// The parsed value for a patient field type, or nil if this type isn't
    /// a patient field or nothing was parsed for it.
    func value(for type: FieldType) -> String? {
        guard let keyPath = PatientDemographics.fieldMap[type] else { return nil }
        return self[keyPath: keyPath]
    }

    /// Keeps only the values whose field type is present in `types`, so the
    /// review sheet shows just what will actually populate the form.
    func limited(to types: Set<FieldType>) -> PatientDemographics {
        var copy = self
        for (type, keyPath) in PatientDemographics.fieldMap where !types.contains(type) {
            copy[keyPath: keyPath] = nil
        }
        return copy
    }

    /// The one place that maps each patient FieldType to its stored value —
    /// used by `value(for:)`, `limited(to:)`, and `isEmpty` so they can't
    /// drift out of sync. `nonisolated(unsafe)`: an immutable constant of
    /// key paths, safe to read from any context (WritableKeyPath just isn't
    /// marked Sendable).
    nonisolated(unsafe) private static let fieldMap: [FieldType: WritableKeyPath<PatientDemographics, String?>] = [
        .patientName: \.fullName,
        .patientAddress: \.address,
        .patientDateOfBirth: \.dateOfBirth,
        .patientHealthcareNumber: \.healthcareNumber,
        .patientPhone: \.phone,
        .patientRefractionOD: \.refractionOD,
        .patientRefractionOS: \.refractionOS,
        .patientVisualAcuityOD: \.visualAcuityOD,
        .patientVisualAcuityOS: \.visualAcuityOS,
        .patientKeratometryOD: \.keratometryOD,
        .patientKeratometryOS: \.keratometryOS,
        .patientIntraocularPressureOD: \.intraocularPressureOD,
        .patientIntraocularPressureOS: \.intraocularPressureOS,
    ]
}
