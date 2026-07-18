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

    private let store: TemplateStore
    private let thumbnailService = ThumbnailService()
    private var thumbnailLoadsInFlight: Set<UUID> = []

    init(store: TemplateStore = TemplateStore()) {
        self.store = store
    }

    /// Binding surface for the error alert.
    var isPresentingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
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
        FillSessionViewModel(template: template, store: store)
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
