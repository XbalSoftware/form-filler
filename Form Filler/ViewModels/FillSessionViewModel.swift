//
//  FillSessionViewModel.swift
//  Form Filler
//
//  One fill session. Values are held ONLY in memory, keyed by field ID
//  (CLAUDE.md invariant #3): nothing here is ever written to disk, cached,
//  or restored. Leaving the screen discards everything; the only artifact
//  containing patient data is the exported PDF (Stage 6).
//

import Foundation
import Observation

@MainActor
@Observable
final class FillSessionViewModel {
    let template: Template
    let renderService: PDFRenderService?

    var values: [UUID: FieldValue] = [:]
    var focusedFieldID: UUID?
    var currentPageIndex = 0

    init(template: Template, store: TemplateStore) {
        self.template = template
        self.renderService = PDFRenderService(url: store.pdfURL(for: template))
    }

    /// Fields the user fills in, in fill order. Static text is rendered
    /// automatically and never appears in the form.
    var formFields: [FieldDefinition] {
        template.orderedFields.filter { $0.type != .staticText }
    }

    /// Fields the keyboard next/previous buttons cycle through.
    var keyboardNavigableFields: [FieldDefinition] {
        formFields.filter { $0.type == .singleLineText || $0.type == .multiLineText }
    }

    func fields(onPage index: Int) -> [FieldDefinition] {
        template.fields.filter { $0.pageIndex == index }
    }

    func displayText(for field: FieldDefinition) -> String? {
        FieldValueFormatting.displayText(for: field, value: values[field.id])
    }

    var hasAnyValues: Bool { !values.isEmpty }

    // MARK: - Focus

    func focusDidChange(to id: UUID?) {
        focusedFieldID = id
        if let id, let field = template.fields.first(where: { $0.id == id }) {
            currentPageIndex = field.pageIndex
        }
    }

    /// ID of the text field `offset` positions away in fill order
    /// (offset -1 = previous, +1 = next); nil when at either end.
    func textFieldID(adjacentTo id: UUID?, offset: Int) -> UUID? {
        let ids = keyboardNavigableFields.map(\.id)
        guard let id, let index = ids.firstIndex(of: id) else {
            return offset > 0 ? ids.first : ids.last
        }
        let target = index + offset
        return ids.indices.contains(target) ? ids[target] : nil
    }

    // MARK: - Value mutations

    func handleOverlayTap(_ field: FieldDefinition) {
        switch field.type {
        case .checkbox:
            toggleCheckbox(field)
        case .staticText:
            break
        case .singleLineText, .multiLineText, .date:
            focusDidChange(to: field.id)
        }
    }

    func toggleCheckbox(_ field: FieldDefinition) {
        if case .checkbox(true) = values[field.id] {
            values[field.id] = .checkbox(false)
        } else {
            values[field.id] = .checkbox(true)
        }
    }

    func clearValue(for id: UUID) {
        values[id] = nil
    }

    func clearAll() {
        values.removeAll()
    }
}
