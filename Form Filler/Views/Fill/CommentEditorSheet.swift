//
//  CommentEditorSheet.swift
//  Form Filler
//
//  Editor for an ad-hoc comment box: multi-line text plus its styling
//  (size, bold, black border, white background). Edits are local until
//  Save; Save with empty text deletes the comment.
//

import SwiftUI

struct CommentEditorSheet: View {
    @State private var mark: AdHocMark
    private let isNew: Bool
    private let onSave: (AdHocMark) -> Void
    private let onDelete: (UUID) -> Void
    private let onCancel: () -> Void

    @FocusState private var isTextFocused: Bool

    init(
        state: FillSessionViewModel.CommentEditorState,
        onSave: @escaping (AdHocMark) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _mark = State(initialValue: state.mark)
        self.isNew = state.isNew
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Comment") {
                    TextEditor(text: textBinding)
                        .textInputAutocapitalization(.never)
                        .frame(minHeight: 110, maxHeight: 220)
                        .focused($isTextFocused)
                }
                Section("Style") {
                    Stepper(
                        "Size: \(Int(mark.resolvedFontSize)) pt",
                        value: fontSizeBinding,
                        in: 6...36,
                        step: 1
                    )
                    Toggle("Bold", isOn: boolBinding(\.isBold))
                    Toggle("Black Border", isOn: boolBinding(\.showsBorder))
                    Toggle("White Background", isOn: boolBinding(\.whiteBackground))
                }
                if !isNew {
                    Section {
                        Button("Delete Comment", systemImage: "trash", role: .destructive) {
                            onDelete(mark.id)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Comment" : "Edit Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(mark) }
                        .disabled(isNew && (mark.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { isTextFocused = true }
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { mark.text ?? "" },
            set: { mark.text = $0 }
        )
    }

    private var fontSizeBinding: Binding<CGFloat> {
        Binding(
            get: { mark.resolvedFontSize },
            set: { mark.fontSize = $0 }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AdHocMark, Bool?>) -> Binding<Bool> {
        Binding(
            get: { mark[keyPath: keyPath] ?? false },
            set: { mark[keyPath: keyPath] = $0 }
        )
    }
}
