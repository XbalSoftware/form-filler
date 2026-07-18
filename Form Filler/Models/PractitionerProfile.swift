//
//  PractitionerProfile.swift
//  Form Filler
//
//  One practitioner's details, managed in Settings (multiple allowed) and
//  auto-populated into the practitioner field types when filling. The
//  user's own data, not PHI — stored as plain JSON and included in
//  library backups.
//

import Foundation
import UIKit

nonisolated struct PractitionerProfile: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    /// What the profile is CALLED in lists and the fill-screen picker —
    /// independent of the doctor name printed on forms, so one doctor can
    /// keep a profile per location ("Dr X — Downtown", "Dr X — Northside").
    /// Empty = fall back to the doctor name.
    var label: String
    var name: String            // doctor name (printed on forms)
    var officeAddress: String
    var officeFax: String
    var officePhone: String
    var email: String
    var practitionerID: String  // PracID
    /// This profile's signature image (PNG/JPEG bytes, base64) — stamped
    /// by signature fields when this profile is selected. Living inside
    /// the profile means it rides in library backups automatically.
    var signatureBase64: String?

    init(
        id: UUID = UUID(),
        label: String = "",
        name: String = "",
        officeAddress: String = "",
        officeFax: String = "",
        officePhone: String = "",
        email: String = "",
        practitionerID: String = "",
        signatureBase64: String? = nil
    ) {
        self.id = id
        self.label = label
        self.name = name
        self.officeAddress = officeAddress
        self.officeFax = officeFax
        self.officePhone = officePhone
        self.email = email
        self.practitionerID = practitionerID
        self.signatureBase64 = signatureBase64
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        officeAddress = try container.decodeIfPresent(String.self, forKey: .officeAddress) ?? ""
        officeFax = try container.decodeIfPresent(String.self, forKey: .officeFax) ?? ""
        officePhone = try container.decodeIfPresent(String.self, forKey: .officePhone) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        practitionerID = try container.decodeIfPresent(String.self, forKey: .practitionerID) ?? ""
        signatureBase64 = try container.decodeIfPresent(String.self, forKey: .signatureBase64)
    }

    /// Decoded signature image, or nil when none is attached.
    var signatureImage: UIImage? {
        guard let signatureBase64, let data = Data(base64Encoded: signatureBase64) else { return nil }
        return UIImage(data: data)
    }

    /// The profile value backing a practitioner field type; nil for
    /// non-practitioner types.
    func value(for type: FieldType) -> String? {
        switch type {
        case .doctorName: name
        case .officeAddress: officeAddress
        case .officeFax: officeFax
        case .officePhone: officePhone
        case .officeEmail: email
        case .practitionerID: practitionerID
        default: nil
        }
    }

    /// Label shown in lists and the fill screen's profile picker: the
    /// profile's own label, falling back to the doctor name.
    var displayLabel: String {
        if !label.isEmpty { return label }
        return name.isEmpty ? "Unnamed profile" : name
    }
}
