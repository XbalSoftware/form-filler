//
//  FillFormListView.swift
//  Form Filler
//
//  The ordered entry form. Keyboard toolbar moves through text fields;
//  focusing a field jumps the preview to its page.
//

import SwiftUI

struct FillFormListView: View {
    let viewModel: FillSessionViewModel

    @FocusState private var focusedFieldID: UUID?

    var body: some View {
        List {
            practitionerSection
            Section {
                ForEach(viewModel.formFields) { field in
                    row(for: field)
                }
            } footer: {
                Text("Entries autosave to an encrypted draft that never leaves this iPad, so you can safely leave and come back. \"Clear form\" deletes the draft; only the exported PDF is shared.")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button {
                    focusedFieldID = viewModel.textFieldID(adjacentTo: focusedFieldID, offset: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(viewModel.textFieldID(adjacentTo: focusedFieldID, offset: -1) == nil)
                Button {
                    focusedFieldID = viewModel.textFieldID(adjacentTo: focusedFieldID, offset: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(viewModel.textFieldID(adjacentTo: focusedFieldID, offset: 1) == nil)
                Spacer()
                Button("Done") { focusedFieldID = nil }
            }
        }
        .onChange(of: focusedFieldID) { _, newValue in
            if viewModel.focusedFieldID != newValue {
                viewModel.focusDidChange(to: newValue)
            }
        }
        .onChange(of: viewModel.focusedFieldID) { _, newValue in
            if focusedFieldID != newValue {
                focusedFieldID = newValue
            }
        }
    }

    /// Shown when the profile choice affects the form (practitioner
    /// fields or a signature): a picker to choose the profile, or a hint
    /// when none exist.
    @ViewBuilder
    private var practitionerSection: some View {
        if viewModel.usesProfileSelection {
            if viewModel.practitionerProfiles.count > 1 {
                Section {
                    Picker("Practitioner", selection: profileBinding) {
                        ForEach(viewModel.practitionerProfiles) { profile in
                            Text(profile.displayLabel).tag(profile.id as UUID?)
                        }
                    }
                }
            } else if viewModel.practitionerProfiles.isEmpty {
                Section {
                    Text("This form uses practitioner details. Add a profile in Settings → Practitioner Profiles to fill them (and sign) automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var profileBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedProfileID },
            set: { viewModel.selectProfile(id: $0) }
        )
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(for field: FieldDefinition) -> some View {
        switch field.type {
        case .singleLineText, .patientName,
             .patientDateOfBirth, .patientHealthcareNumber, .patientPhone,
             .patientRefractionOD, .patientRefractionOS,
             .patientVisualAcuityOD, .patientVisualAcuityOS,
             .patientKeratometryOD, .patientKeratometryOS,
             .patientIntraocularPressureOD, .patientIntraocularPressureOS:
            labeled(field) {
                TextField("Enter \(field.name.lowercased())", text: textBinding(for: field))
                    .textInputAutocapitalization(.never)   // user decision: no forced capitals (breaks emails)
                    .focused($focusedFieldID, equals: field.id)
                    // Drive Tab through our own field order (see moveFocus).
                    // Without this, single-line fields fall back to the
                    // system's focus traversal, which fights the manual
                    // traversal used by multi-line fields below.
                    .onKeyPress(.tab, phases: .down) { press in
                        moveFocus(from: field, backward: press.modifiers.contains(.shift))
                    }
            }
        case .multiLineText, .patientAddress:
            labeled(field) {
                // TextEditor, not a vertical TextField: Return must insert
                // a carriage return inside the field, and Tab (intercepted
                // below) must move to the next field instead of indenting.
                TextEditor(text: textBinding(for: field))
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 88, maxHeight: 200)
                    .fixedSize(horizontal: false, vertical: true)
                    .focused($focusedFieldID, equals: field.id)
                    .onKeyPress(.tab, phases: .down) { press in
                        moveFocus(from: field, backward: press.modifiers.contains(.shift))
                    }
            }
        case .referralDate:
            labeled(field) {
                // Defaults to today (shown via the binding) but freely editable.
                TextField("Referral date", text: referralDateBinding(for: field))
                    .textInputAutocapitalization(.never)
                    .focused($focusedFieldID, equals: field.id)
                    .onKeyPress(.tab, phases: .down) { press in
                        moveFocus(from: field, backward: press.modifiers.contains(.shift))
                    }
            }
        case .staticText, .signature,
             .doctorName, .officeAddress, .officeFax, .officePhone, .officeEmail, .practitionerID:
            EmptyView()   // never in formFields (auto-populated)
        }
    }

    /// Tab / Shift-Tab inside a multi-line field: keep the tab-between-
    /// fields flow instead of inserting a tab character.
    private func moveFocus(from field: FieldDefinition, backward: Bool) -> KeyPress.Result {
        guard let target = viewModel.textFieldID(adjacentTo: field.id, offset: backward ? -1 : 1) else {
            return .handled   // at either end: swallow the tab, keep focus
        }
        focusedFieldID = target
        return .handled
    }

    private func labeled(_ field: FieldDefinition, @ViewBuilder control: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.name)
                .font(.caption)
                .foregroundStyle(.secondary)
            control()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Bindings

    private func textBinding(for field: FieldDefinition) -> Binding<String> {
        Binding(
            get: {
                if case .text(let string) = viewModel.values[field.id] { string } else { "" }
            },
            set: { newValue in
                // Patient phone auto-formats a bare 10-digit entry to
                // "(###) ###-####"; other input is stored verbatim.
                let stored = field.type == .patientPhone
                    ? PhoneFormatting.autoFormat(newValue)
                    : newValue
                viewModel.values[field.id] = stored.isEmpty ? nil : .text(stored)
            }
        )
    }

    /// Referral date shows the user's override if set, otherwise today's
    /// date (matching the preview/export). Clearing it reverts to today.
    private func referralDateBinding(for field: FieldDefinition) -> Binding<String> {
        Binding(
            get: {
                if case .text(let string) = viewModel.values[field.id], !string.isEmpty {
                    return string
                }
                return FieldValueFormatting.todayReferralDate()
            },
            set: { newValue in
                viewModel.values[field.id] = newValue.isEmpty ? nil : .text(newValue)
            }
        )
    }

}
