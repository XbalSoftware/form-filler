//
//  FillSessionViewModel.swift
//  Form Filler
//
//  One fill session. Values live in memory, keyed by field ID. The only
//  places they may touch disk (amended invariant #3, user request
//  2026-07-17): the exported PDF, its embedded reopen payload, and the
//  encrypted on-device draft vault (DraftStore) that lets a session
//  survive leaving the screen — e.g. to tweak the template mid-entry —
//  until the user clears the form.
//

import Foundation
import Observation

@MainActor
@Observable
final class FillSessionViewModel {
    let template: Template
    let renderService: PDFRenderService?
    let pdfURL: URL

    var values: [UUID: FieldValue] = [:]
    var focusedFieldID: UUID?
    var currentPageIndex = 0
    var errorMessage: String?

    private let draftStore: DraftStore
    /// Values as of the last draft write — makes unchanged autosave ticks free.
    private var lastAutosavedValues: [UUID: FieldValue]?

    init(template: Template, store: TemplateStore, draftStore: DraftStore = DraftStore()) {
        self.template = template
        self.pdfURL = store.pdfURL(for: template)
        self.renderService = PDFRenderService(url: pdfURL)
        self.draftStore = draftStore
    }

    /// True once anything would actually print (including static text).
    var hasExportableContent: Bool {
        template.fields.contains { displayText(for: $0) != nil }
    }

    /// Value of the template's patient-name field, if entered — it feeds
    /// the export filename (deliberate user decision, 2026-07-17).
    var patientNameText: String? {
        guard let field = template.patientNameField,
              case .text(let string) = values[field.id] else { return nil }
        return string
    }

    var exportFileName: String {
        PDFExportService.defaultFileName(for: template, patientName: patientNameText)
    }

    /// Renders the filled PDF and writes it to the temp export directory
    /// (purged on launch and when leaving this screen). Returns the file
    /// URL — the share sheet must be handed this URL directly, not a lazy
    /// file promise: the user's EMR software only accepts concrete URLs
    /// to PDF files.
    func exportToTemporaryFile() throws -> URL {
        let data = try PDFExportService().exportPDF(
            template: template,
            values: values,
            sourceURL: pdfURL
        )
        let directory = PDFExportService.temporaryExportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: exportFileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Fields the user fills in, in fill order. Static text is rendered
    /// automatically and never appears in the form.
    var formFields: [FieldDefinition] {
        template.orderedFields.filter { $0.type != .staticText }
    }

    /// Fields the keyboard next/previous buttons cycle through.
    var keyboardNavigableFields: [FieldDefinition] {
        formFields.filter {
            $0.type == .singleLineText || $0.type == .multiLineText || $0.type == .patientName
        }
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
        case .singleLineText, .multiLineText, .date, .patientName:
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

    /// "Clear form": wipes the in-memory values AND this template's saved
    /// draft — the one deliberate way transient patient data is destroyed.
    func clearAll() {
        values.removeAll()
        lastAutosavedValues = nil
        draftStore.clear(for: template.id)
    }

    // MARK: - Draft vault

    /// This template's saved draft, if one is worth offering to resume.
    func availableDraft() -> FillSessionPayload? {
        guard let payload = draftStore.load(),
              payload.templateID == template.id,
              !payload.values.isEmpty
        else { return nil }
        return payload
    }

    func restoreDraft(_ payload: FillSessionPayload) {
        values = payload.fieldValues
        lastAutosavedValues = values
    }

    /// Deletes the saved draft without touching the in-memory session
    /// (the "Start Fresh" choice in the resume prompt).
    func discardDraft() {
        draftStore.clear(for: template.id)
        lastAutosavedValues = nil
    }

    /// Writes the current values to the encrypted vault. Cheap when
    /// nothing changed; never writes an empty session (so opening a form
    /// and backing straight out can't clobber another form's draft).
    /// Autosave failures are non-fatal and deliberately silent — the
    /// in-memory session is unaffected.
    func autosaveDraft() {
        guard hasAnyValues, values != lastAutosavedValues else { return }
        let payload = FillSessionPayload(
            templateID: template.id,
            templateName: template.name,
            values: values
        )
        do {
            try draftStore.save(payload)
            lastAutosavedValues = values
        } catch {
            // Intentionally silent; the next tick retries.
        }
    }
}
