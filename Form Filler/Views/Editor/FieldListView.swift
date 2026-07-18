//
//  FieldListView.swift
//  Form Filler
//
//  Inspector state when no field is selected: all fields in fill order,
//  tappable to select, reorderable (rewrites sortOrder), swipe-to-delete.
//

import SwiftUI

struct FieldListView: View {
    let viewModel: TemplateEditorViewModel

    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            Section {
                ForEach(viewModel.orderedFields) { field in
                    Button {
                        viewModel.select(field)
                    } label: {
                        row(for: field)
                    }
                    .foregroundStyle(.primary)
                }
                .onMove { viewModel.reorderFields(from: $0, to: $1) }
                .onDelete { viewModel.deleteFields(atOrderedOffsets: $0) }
            } header: {
                HStack {
                    Text("Fields — fill order")
                    Spacer()
                    if viewModel.orderedFields.count > 1 {
                        Button(editMode == .active ? "Done" : "Reorder") {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            } footer: {
                Text("Tap a field to edit it. Tap an empty spot on the page to add a new field.")
            }
        }
        .environment(\.editMode, $editMode)
    }

    private func row(for field: FieldDefinition) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon(for: field.type))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(field.name)
                .lineLimit(1)
            Spacer()
            Text("p\(field.pageIndex + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func icon(for type: FieldType) -> String {
        switch type {
        case .singleLineText: "textformat"
        case .multiLineText: "text.justify.leading"
        case .date: "calendar"
        case .checkbox: "checkmark.square"
        case .staticText: "text.quote"
        case .patientName: "person.text.rectangle"
        case .signature: "signature"
        case .doctorName: "stethoscope"
        case .officeAddress: "building.2"
        case .officeFax: "faxmachine"
        case .officePhone: "phone"
        case .officeEmail: "envelope"
        case .practitionerID: "number"
        }
    }
}
