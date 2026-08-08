//
//  TemplateFormSheet.swift
//  Form Filler
//
//  Shared name/category form used by both the import flow and
//  "Edit Details".
//

import SwiftUI

struct TemplateFormSheet: View {
    let title: String
    let confirmLabel: String
    @State var name: String
    @State var category: String
    let onConfirm: (_ name: String, _ category: String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Category (optional)", text: $category)
                } footer: {
                    Text("Categories group related forms in the library, e.g. “Hospital” or “Cataract”.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel) {
                        onConfirm(name, category)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
