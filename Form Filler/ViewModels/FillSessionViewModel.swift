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
import CoreGraphics
import Observation
import UIKit

@MainActor
@Observable
final class FillSessionViewModel {
    let template: Template
    let renderService: PDFRenderService?
    let pdfURL: URL

    /// What a tap on the preview does: enter values, stamp a checkmark,
    /// draw a circle, or place a typed comment box.
    enum FillTool: Hashable {
        case entry, check, circle, comment
    }

    /// A comment box being created or edited; drives the editor sheet on
    /// the fill screen.
    struct CommentEditorState: Identifiable, Equatable {
        var mark: AdHocMark
        let isNew: Bool
        var id: UUID { mark.id }
    }

    var values: [UUID: FieldValue] = [:]
    /// Ad-hoc checkmarks/circles/comments — session data like `values`.
    var marks: [AdHocMark] = []
    var activeTool: FillTool = .entry
    var commentEditor: CommentEditorState?
    var focusedFieldID: UUID?
    var currentPageIndex = 0
    var errorMessage: String?

    private let draftStore: DraftStore
    /// Session state as of the last draft write — makes unchanged autosave ticks free.
    private var lastAutosavedValues: [UUID: FieldValue]?
    private var lastAutosavedMarks: [AdHocMark]?

    /// The signature stamped by signature fields: the selected profile's
    /// own signature, falling back to the legacy app-wide one
    /// (SignatureStore) so pre-profile setups keep working. Refreshed on
    /// profile selection.
    private(set) var signatureImage: UIImage?
    /// The pre-profile app-wide signature, if one was ever set up.
    private let legacySignatureImage: UIImage?

    /// Practitioner profiles available for auto-population, loaded once
    /// per session.
    let practitionerProfiles: [PractitionerProfile]
    private(set) var selectedProfileID: UUID?

    init(
        template: Template,
        store: TemplateStore,
        draftStore: DraftStore = DraftStore(),
        signatureStore: SignatureStore = SignatureStore(),
        practitionerStore: PractitionerStore = PractitionerStore()
    ) {
        self.template = template
        self.pdfURL = store.pdfURL(for: template)
        self.renderService = PDFRenderService(url: pdfURL)
        self.draftStore = draftStore
        self.legacySignatureImage = signatureStore.loadImage()
        self.practitionerProfiles = practitionerStore.load()
        self.selectedProfileID = practitionerProfiles.first?.id
        self.signatureImage = nil
        refreshSignature()
        applySelectedProfile()
    }

    // MARK: - Practitioner profiles

    /// True when this template has any auto-populated practitioner field.
    var hasPractitionerFields: Bool {
        template.fields.contains { $0.type.isPractitionerField }
    }

    /// The profile picker matters whenever the profile changes what gets
    /// printed — practitioner fields OR a profile-backed signature.
    var usesProfileSelection: Bool {
        template.fields.contains { $0.type.isPractitionerField || $0.type == .signature }
    }

    var selectedProfile: PractitionerProfile? {
        practitionerProfiles.first { $0.id == selectedProfileID }
    }

    func selectProfile(id: UUID?) {
        selectedProfileID = id
        refreshSignature()
        applySelectedProfile()
    }

    private func refreshSignature() {
        signatureImage = selectedProfile?.signatureImage ?? legacySignatureImage
    }

    /// Materializes the selected profile into the practitioner fields as
    /// ordinary `.text` values — so preview, export, draft, and the
    /// embedded payload all see them with zero special-casing. Patient
    /// entries are untouched.
    private func applySelectedProfile() {
        guard let profile = selectedProfile else { return }
        for field in template.fields where field.type.isPractitionerField {
            let text = profile.value(for: field.type) ?? ""
            values[field.id] = text.isEmpty ? nil : .text(text)
        }
    }

    /// True once anything would actually print (including static text,
    /// ad-hoc marks, and auto-stamped signatures).
    var hasExportableContent: Bool {
        !marks.isEmpty
            || template.fields.contains { displayText(for: $0) != nil }
            || (signatureImage != nil && template.fields.contains { $0.type == .signature })
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
            marks: marks,
            signature: signatureImage,
            sourceURL: pdfURL
        )
        let directory = PDFExportService.temporaryExportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: exportFileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Fields the user fills in, in fill order. Static text, practitioner
    /// fields, and signatures are rendered automatically and never appear
    /// in the form.
    var formFields: [FieldDefinition] {
        template.orderedFields.filter {
            $0.type != .staticText && $0.type != .signature && !$0.type.isPractitionerField
        }
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

    /// True when the USER has entered anything — auto-populated
    /// practitioner values don't count, so an untouched form neither
    /// autosaves a draft nor enables "Clear form".
    var hasAnyValues: Bool {
        if !marks.isEmpty { return true }
        let practitionerIDs = practitionerFieldIDs
        return values.keys.contains { !practitionerIDs.contains($0) }
    }

    private var practitionerFieldIDs: Set<UUID> {
        Set(template.fields.filter { $0.type.isPractitionerField }.map(\.id))
    }

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
        case .staticText, .signature,
             .doctorName, .officeAddress, .officeFax, .officePhone, .officeEmail, .practitionerID:
            break   // auto-populated; nothing to focus or toggle
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

    /// "Clear form": wipes the in-memory session AND this template's saved
    /// draft — the one deliberate way transient patient data is destroyed.
    /// Practitioner fields repopulate from the selected profile.
    func clearAll() {
        values.removeAll()
        marks.removeAll()
        lastAutosavedValues = nil
        lastAutosavedMarks = nil
        draftStore.clear(for: template.id)
        applySelectedProfile()
    }

    // MARK: - Ad-hoc marks

    func marks(onPage index: Int) -> [AdHocMark] {
        marks.filter { $0.pageIndex == index }
    }

    /// Handles a tap on the preview while a mark tool is active.
    /// Check/circle: removes a same-kind mark under the finger, otherwise
    /// places a default-size one. Comment: opens the editor for the
    /// comment under the finger, otherwise prompts for a new one — a tap
    /// with the wrong tool never deletes a typed comment.
    /// `pdfPoint` is in PDF space.
    func handleMarkTap(at pdfPoint: CGPoint, kind: AdHocMark.Kind) {
        if let hit = mark(at: pdfPoint, kind: kind) {
            if kind == .comment {
                commentEditor = CommentEditorState(mark: hit, isNew: false)
            } else {
                marks.removeAll { $0.id == hit.id }
            }
            return
        }
        let size = switch kind {
        case .check: AdHocMark.defaultCheckSize
        case .circle: AdHocMark.defaultCircleSize
        case .comment: AdHocMark.defaultCommentSize
        }
        let rect = CGRect(
            x: pdfPoint.x - size.width / 2,
            y: pdfPoint.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        if kind == .comment {
            promptComment(in: rect)
        } else {
            addMark(kind: kind, rect: rect)
        }
    }

    /// Commits a dragged-out circle. `pdfRect` is in PDF space.
    func addCircle(around pdfRect: CGRect) {
        addMark(kind: .circle, rect: pdfRect)
    }

    /// Opens the editor for a new comment box at `pdfRect`.
    func promptComment(in pdfRect: CGRect) {
        commentEditor = CommentEditorState(
            mark: AdHocMark(kind: .comment, pageIndex: currentPageIndex, rect: pdfRect, text: ""),
            isNew: true
        )
    }

    /// Saves the edited comment. Empty text deletes an existing comment
    /// and discards a new one.
    func commitComment(_ mark: AdHocMark) {
        commentEditor = nil
        var updated = mark
        updated.text = mark.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if updated.text?.isEmpty != false {
            marks.removeAll { $0.id == mark.id }
        } else if let index = marks.firstIndex(where: { $0.id == mark.id }) {
            marks[index] = updated
        } else {
            marks.append(updated)
        }
    }

    func deleteComment(id: UUID) {
        commentEditor = nil
        marks.removeAll { $0.id == id }
    }

    /// Commits a comment move/resize (Comment tool only). `pdfRect` is in
    /// PDF space.
    func setCommentRect(id: UUID, pdfRect: CGRect) {
        guard let index = marks.firstIndex(where: { $0.id == id }) else { return }
        marks[index].rect = pdfRect
    }

    func editComment(_ mark: AdHocMark) {
        commentEditor = CommentEditorState(mark: mark, isNew: false)
    }

    private func addMark(kind: AdHocMark.Kind, rect: CGRect) {
        marks.append(AdHocMark(kind: kind, pageIndex: currentPageIndex, rect: rect))
    }

    /// The topmost same-kind mark on the current page containing the
    /// point (with a little slop so small checkmarks are hittable).
    private func mark(at pdfPoint: CGPoint, kind: AdHocMark.Kind) -> AdHocMark? {
        marks(onPage: currentPageIndex).last {
            $0.kind == kind && $0.rect.insetBy(dx: -4, dy: -4).contains(pdfPoint)
        }
    }

    // MARK: - Draft vault

    /// This template's saved draft, if one is worth offering to resume.
    func availableDraft() -> FillSessionPayload? {
        guard let payload = draftStore.load(),
              payload.templateID == template.id,
              !(payload.values.isEmpty && payload.marks.isEmpty)
        else { return nil }
        return payload
    }

    func restoreDraft(_ payload: FillSessionPayload) {
        values = payload.fieldValues
        marks = payload.marks
        lastAutosavedValues = values
        lastAutosavedMarks = marks
    }

    /// Deletes the saved draft without touching the in-memory session
    /// (the "Start Fresh" choice in the resume prompt).
    func discardDraft() {
        draftStore.clear(for: template.id)
        lastAutosavedValues = nil
        lastAutosavedMarks = nil
    }

    /// Writes the current session to the encrypted vault. Cheap when
    /// nothing changed; never writes an empty session (so opening a form
    /// and backing straight out can't clobber another form's draft).
    /// Autosave failures are non-fatal and deliberately silent — the
    /// in-memory session is unaffected.
    func autosaveDraft() {
        guard hasAnyValues,
              values != lastAutosavedValues || marks != lastAutosavedMarks
        else { return }
        let payload = FillSessionPayload(
            templateID: template.id,
            templateName: template.name,
            values: values,
            marks: marks
        )
        do {
            try draftStore.save(payload)
            lastAutosavedValues = values
            lastAutosavedMarks = marks
        } catch {
            // Intentionally silent; the next tick retries.
        }
    }
}
