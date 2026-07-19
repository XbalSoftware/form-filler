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
        case .singleLineText, .patientName:
            labeled(field) {
                TextField("Enter \(field.name.lowercased())", text: textBinding(for: field))
                    .textInputAutocapitalization(.never)   // user decision: no forced capitals (breaks emails)
                    .focused($focusedFieldID, equals: field.id)
            }
        case .multiLineText:
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
        case .date:
            dateRow(for: field)
        case .checkbox:
            Toggle(field.name, isOn: checkboxBinding(for: field))
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

    private func dateRow(for field: FieldDefinition) -> some View {
        HStack {
            if viewModel.values[field.id] != nil {
                DatePicker(field.name, selection: dateBinding(for: field), displayedComponents: .date)
                Button {
                    viewModel.clearValue(for: field.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text(field.name)
                Spacer()
                Button("Set Date") {
                    viewModel.values[field.id] = .date(.now)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Bindings

    private func textBinding(for field: FieldDefinition) -> Binding<String> {
        Binding(
            get: {
                if case .text(let string) = viewModel.values[field.id] { string } else { "" }
            },
            set: { newValue in
                viewModel.values[field.id] = newValue.isEmpty ? nil : .text(newValue)
            }
        )
    }

    private func dateBinding(for field: FieldDefinition) -> Binding<Date> {
        Binding(
            get: {
                if case .date(let date) = viewModel.values[field.id] { date } else { .now }
            },
            set: { viewModel.values[field.id] = .date($0) }
        )
    }

    private func checkboxBinding(for field: FieldDefinition) -> Binding<Bool> {
        Binding(
            get: {
                if case .checkbox(let isOn) = viewModel.values[field.id] { isOn } else { false }
            },
            set: { viewModel.values[field.id] = .checkbox($0) }
        )
    }
}
