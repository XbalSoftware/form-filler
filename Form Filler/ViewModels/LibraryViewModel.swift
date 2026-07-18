//
//  LibraryViewModel.swift
//  Form Filler
//

import Foundation
import Observation
import PDFKit
import UIKit

/// A PDF picked via the file importer, validated and held in memory until
/// the user names it in the import sheet.
struct PendingImport: Identifiable {
    let id = UUID()
    let data: Data
    let suggestedName: String
}

@MainActor
@Observable
final class LibraryViewModel {
    private(set) var templates: [Template] = []
    private(set) var thumbnails: [UUID: UIImage] = [:]
    var errorMessage: String?
    /// Non-error outcome notices (e.g. a restore summary).
    var infoMessage: String?

    private let store: TemplateStore
    private let thumbnailService = ThumbnailService()
    private var thumbnailLoadsInFlight: Set<UUID> = []
    /// Session recovered from an exported PDF, waiting for the fill screen
    /// it was routed to; consumed by `makeFillSessionViewModel`.
    private var pendingFillRestore: (templateID: UUID, values: [UUID: FieldValue], marks: [AdHocMark])?

    init(store: TemplateStore = TemplateStore()) {
        self.store = store
    }

    /// Binding surface for the error alert.
    var isPresentingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    var isPresentingInfo: Bool {
        get { infoMessage != nil }
        set { if !newValue { infoMessage = nil } }
    }

    func onAppear() {
        #if DEBUG
        DebugSeeder.seedIfNeeded(using: store)
        #endif
        refresh()
    }

    func refresh() {
        do {
            templates = try store.loadAll()
        } catch {
            templates = []
            errorMessage = "Couldn't load templates: \(error.localizedDescription)"
        }
        loadMissingThumbnails()
    }

    func template(withID id: UUID) -> Template? {
        templates.first { $0.id == id }
    }

    func pdfURL(for template: Template) -> URL {
        store.pdfURL(for: template)
    }

    /// The editor persists through the same store; every save refreshes
    /// the library so field counts and dates stay current.
    func makeEditorViewModel(for template: Template) -> TemplateEditorViewModel {
        TemplateEditorViewModel(template: template, store: store) { [weak self] in
            self?.refresh()
        }
    }

    func makeFillSessionViewModel(for template: Template) -> FillSessionViewModel {
        let viewModel = FillSessionViewModel(template: template, store: store)
        if let pending = pendingFillRestore, pending.templateID == template.id {
            viewModel.values = pending.values
            viewModel.marks = pending.marks
            pendingFillRestore = nil
            // Vault the restored session immediately: even backing straight
            // out of the fill screen must not lose a reopened form.
            viewModel.autosaveDraft()
        }
        return viewModel
    }

    // MARK: - Backup & reopen

    /// Writes the whole-library backup file to a temp location for the
    /// save picker. Nil (with the error set) on failure.
    func exportBackupToTemporaryFile() -> URL? {
        do {
            let data = try LibraryBackupService(store: store).exportBackup()
            let directory = FileManager.default.temporaryDirectory
                .appending(path: "Backups", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: LibraryBackupService.defaultFileName())
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = "Backup failed: \(error.localizedDescription)"
            return nil
        }
    }

    func restoreBackup(from url: URL) {
        guard let data = readSecurityScoped(url) else { return }
        do {
            let summary = try LibraryBackupService(store: store).restore(from: data)
            refresh()
            var message = "Restored \(summary.imported) template\(summary.imported == 1 ? "" : "s")."
            if summary.skipped > 0 {
                message += " Skipped \(summary.skipped) already in the library."
            }
            infoMessage = message
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    /// Reads the fill payload embedded in a previously exported PDF and,
    /// if its template still exists, returns the fill route to push (the
    /// values are handed over when that route builds its view model).
    func prepareFillRestore(from url: URL) -> FillRoute? {
        guard let data = readSecurityScoped(url) else { return nil }
        guard let payload = PDFExportService.embeddedPayload(in: data) else {
            errorMessage = "\"\(url.lastPathComponent)\" doesn't contain re-editable Form Filler data. Only PDFs exported by this app (and not rewritten by another tool) can be reopened."
            return nil
        }
        guard template(withID: payload.templateID) != nil else {
            let name = payload.templateName.isEmpty ? "its template" : "\"\(payload.templateName)\""
            errorMessage = "This PDF was made with \(name), which is no longer in the library. Restore the template first, then reopen the PDF."
            return nil
        }
        pendingFillRestore = (payload.templateID, payload.fieldValues, payload.marks)
        return FillRoute(templateID: payload.templateID)
    }

    /// "Reset App": erases every template, the encrypted fill draft, the
    /// stored signature, and any staged temp exports. (In DEBUG builds
    /// the sample template reseeds on next launch.)
    func resetApp() {
        do {
            try store.deleteAll()
            thumbnails.removeAll()
            DraftStore().clear()
            SignatureStore().clear()
            PractitionerStore().clear()
            PDFExportService.purgeTemporaryExports()
            refresh()
            infoMessage = "All app data has been erased."
        } catch {
            errorMessage = "Reset failed: \(error.localizedDescription)"
        }
    }

    private func readSecurityScoped(_ url: URL) -> Data? {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Couldn't read the selected file."
            return nil
        }
        return data
    }

    // MARK: - Import

    /// Reads and validates a picked file. Returns nil (and sets the error
    /// message) if it isn't a readable PDF.
    func preparePendingImport(from url: URL) -> PendingImport? {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Couldn't read the selected file."
            return nil
        }
        guard PDFDocument(data: data) != nil else {
            errorMessage = "\"\(url.lastPathComponent)\" doesn't appear to be a valid PDF."
            return nil
        }
        return PendingImport(data: data, suggestedName: url.deletingPathExtension().lastPathComponent)
    }

    func importTemplate(_ pending: PendingImport, name: String, category: String) {
        let template = Template(
            name: normalized(name) ?? "Untitled",
            category: normalized(category)
        )
        do {
            try store.create(template, pdfData: pending.data)
            refresh()
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Template actions

    func updateDetails(of template: Template, name: String, category: String) {
        var updated = template
        updated.name = normalized(name) ?? template.name
        updated.category = normalized(category)
        updated.modifiedAt = .now
        do {
            try store.save(updated)
            refresh()
        } catch {
            errorMessage = "Couldn't save changes: \(error.localizedDescription)"
        }
    }

    func duplicate(_ template: Template) {
        do {
            _ = try store.duplicate(template)
            refresh()
        } catch {
            errorMessage = "Couldn't duplicate: \(error.localizedDescription)"
        }
    }

    func delete(_ template: Template) {
        do {
            try store.delete(template)
            thumbnails.removeValue(forKey: template.id)
            refresh()
        } catch {
            errorMessage = "Couldn't delete: \(error.localizedDescription)"
        }
    }

    // MARK: - Thumbnails

    private func loadMissingThumbnails() {
        for template in templates
        where thumbnails[template.id] == nil && !thumbnailLoadsInFlight.contains(template.id) {
            thumbnailLoadsInFlight.insert(template.id)
            Task {
                let image = await thumbnailService.thumbnail(for: template, in: store)
                thumbnailLoadsInFlight.remove(template.id)
                if let image {
                    thumbnails[template.id] = image
                }
            }
        }
    }

    private func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
