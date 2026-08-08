//
//  FieldValueFormatting.swift
//  Form Filler
//
//  Resolves a field + its (transient) value into the string that gets
//  drawn — shared by the fill-preview overlays and the PDF export so the
//  two can never disagree.
//

import Foundation

nonisolated enum FieldValueFormatting {
    /// The text to draw for a field, or nil if nothing should be drawn.
    static func displayText(for field: FieldDefinition, value: FieldValue?) -> String? {
        switch field.type {
        case .staticText:
            guard let text = field.staticText, !text.isEmpty else { return nil }
            return text
        case .referralDate:
            // Editable, defaulting to today: the user's typed override if
            // set, otherwise today's date (recomputed each render).
            if case .text(let string) = value, !string.isEmpty { return string }
            return todayReferralDate()
        case .singleLineText, .multiLineText, .patientName,
             .doctorName, .officeAddress, .officeFax, .officePhone, .officeEmail, .practitionerID,
             .patientAddress, .patientDateOfBirth, .patientHealthcareNumber, .patientPhone,
             .patientRefractionOD, .patientRefractionOS,
             .patientVisualAcuityOD, .patientVisualAcuityOS,
             .patientKeratometryOD, .patientKeratometryOS,
             .patientIntraocularPressureOD, .patientIntraocularPressureOS:
            // Practitioner fields hold ordinary `.text` values, materialized
            // from the selected profile by FillSessionViewModel. Patient
            // fields hold `.text` typed by the user or filled from an import.
            guard case .text(let string) = value, !string.isEmpty else { return nil }
            return string
        case .signature:
            return nil   // drawn as an image, never as text
        }
    }

    /// Today's date as "DD MON YYYY" (e.g. "03 AUG 2026"), month in caps —
    /// fixed en_US_POSIX so it never localizes. The default a Referral Date
    /// field shows until the user types an override; also used by the fill
    /// form's text binding so field and preview agree.
    static func todayReferralDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: Date()).uppercased()
    }
}
