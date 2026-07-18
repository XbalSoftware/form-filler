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
            Section {
                ForEach(viewModel.formFields) { field in
                    row(for: field)
                }
            } footer: {
                Text("Entries are never saved — they exist only until you leave this screen. Only the exported PDF contains what you type.")
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

    // MARK: - Rows

    @ViewBuilder
    private func row(for field: FieldDefinition) -> some View {
        switch field.type {
        case .singleLineText:
            labeled(field) {
                TextField("Enter \(field.name.lowercased())", text: textBinding(for: field))
                    .focused($focusedFieldID, equals: field.id)
            }
        case .multiLineText:
            labeled(field) {
                TextField("Enter \(field.name.lowercased())", text: textBinding(for: field), axis: .vertical)
                    .lineLimit(3...8)
                    .focused($focusedFieldID, equals: field.id)
            }
        case .date:
            dateRow(for: field)
        case .checkbox:
            Toggle(field.name, isOn: checkboxBinding(for: field))
        case .staticText:
            EmptyView()   // never in formFields
        }
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
