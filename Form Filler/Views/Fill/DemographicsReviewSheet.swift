//
//  DemographicsReviewSheet.swift
//  Form Filler
//
//  Shows the patient details parsed from an imported PDF so the clinician
//  can verify (and correct) every value BEFORE it populates the form. This
//  confirmation step is deliberate: the parser is tuned to one EMR layout,
//  so a human check is what makes auto-fill safe for patient data.
//

import SwiftUI

struct DemographicsReviewSheet: View {
    @State private var draft: PatientDemographics
    private let demographicRows: [Row]
    private let examRows: [Row]
    private let onApply: (PatientDemographics) -> Void
    private let onCancel: () -> Void

    init(
        demographics: PatientDemographics,
        onApply: @escaping (PatientDemographics) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: demographics)
        // Row visibility is fixed at present-time from what was parsed, so a
        // row can't vanish if the user clears its text while editing.
        demographicRows = Row.demographics.filter { demographics[keyPath: $0.keyPath] != nil }
        examRows = Row.exam.filter { demographics[keyPath: $0.keyPath] != nil }
        self.onApply = onApply
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                if !demographicRows.isEmpty {
                    Section {
                        ForEach(demographicRows, id: \.self) { rowView($0) }
                    } header: {
                        Text("Patient")
                    } footer: {
                        Text("Check these against the source, then apply. They fill only the matching fields on this form — nothing is stored elsewhere, and only the exported PDF ever leaves this iPad.")
                    }
                }
                if !examRows.isEmpty {
                    Section("Exam Findings") {
                        ForEach(examRows, id: \.self) { rowView($0) }
                    }
                }
            }
            .navigationTitle("Patient Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply to Form") { onApply(draft) }
                }
            }
        }
    }

    private func rowView(_ row: Row) -> some View {
        labeled(row.label) {
            TextField(row.label, text: text(row.keyPath), axis: row == .address ? .vertical : .horizontal)
                .textInputAutocapitalization(row == .name || row == .address ? .words : .never)
                .lineLimit(row == .address ? 1...4 : 1...1)
        }
    }

    private func labeled(_ title: String, @ViewBuilder control: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            control()
        }
        .padding(.vertical, 2)
    }

    /// Bridges an optional stored value to a plain-text field binding
    /// (empty text clears it back to nil).
    private func text(_ keyPath: WritableKeyPath<PatientDemographics, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private enum Row: Hashable {
        case name, dateOfBirth, healthcareNumber, phone, address
        case refractionOD, refractionOS, visualAcuityOD, visualAcuityOS
        case keratometryOD, keratometryOS, iopOD, iopOS

        static let demographics: [Row] = [.name, .dateOfBirth, .healthcareNumber, .phone, .address]
        static let exam: [Row] = [
            .refractionOD, .refractionOS, .visualAcuityOD, .visualAcuityOS,
            .keratometryOD, .keratometryOS, .iopOD, .iopOS,
        ]

        var label: String {
            switch self {
            case .name: "Name"
            case .dateOfBirth: "Date of Birth"
            case .healthcareNumber: "Healthcare #"
            case .phone: "Phone"
            case .address: "Address"
            case .refractionOD: "Refraction OD"
            case .refractionOS: "Refraction OS"
            case .visualAcuityOD: "VA OD"
            case .visualAcuityOS: "VA OS"
            case .keratometryOD: "Keratometry OD"
            case .keratometryOS: "Keratometry OS"
            case .iopOD: "IOP OD"
            case .iopOS: "IOP OS"
            }
        }

        var keyPath: WritableKeyPath<PatientDemographics, String?> {
            switch self {
            case .name: \.fullName
            case .dateOfBirth: \.dateOfBirth
            case .healthcareNumber: \.healthcareNumber
            case .phone: \.phone
            case .address: \.address
            case .refractionOD: \.refractionOD
            case .refractionOS: \.refractionOS
            case .visualAcuityOD: \.visualAcuityOD
            case .visualAcuityOS: \.visualAcuityOS
            case .keratometryOD: \.keratometryOD
            case .keratometryOS: \.keratometryOS
            case .iopOD: \.intraocularPressureOD
            case .iopOS: \.intraocularPressureOS
            }
        }
    }
}
