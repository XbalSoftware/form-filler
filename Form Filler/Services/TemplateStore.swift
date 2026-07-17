//
//  TemplateStore.swift
//  Form Filler
//

import Foundation
import os

nonisolated enum TemplateStoreError: LocalizedError, Equatable {
    case templateNotFound(UUID)
    case templateAlreadyExists(UUID)

    var errorDescription: String? {
        switch self {
        case .templateNotFound(let id):
            "No template folder exists for id \(id.uuidString)."
        case .templateAlreadyExists(let id):
            "A template folder already exists for id \(id.uuidString)."
        }
    }
}

/// Folder-per-template storage under Application Support:
///
/// ```
/// Templates/
///   <UUID>/
///     original.pdf      # imported bytes, byte-for-byte, read-only forever
///     template.json     # Template metadata + fields, pretty-printed
///     thumbnail.png     # cached library thumbnail
/// ```
///
/// All writes are atomic: JSON via write-to-temp-then-replace, and new
/// template folders are staged in a temporary directory and moved into
/// place in one step. The store never bumps dates — callers own
/// `modifiedAt`.
nonisolated struct TemplateStore: Sendable {
    static let pdfFileName = "original.pdf"
    static let jsonFileName = "template.json"
    static let thumbnailFileName = "thumbnail.png"

    let baseDirectoryURL: URL

    private static let logger = Logger(subsystem: "Xbal.Form-Filler", category: "TemplateStore")

    static var defaultBaseDirectoryURL: URL {
        URL.applicationSupportDirectory.appending(path: "Templates", directoryHint: .isDirectory)
    }

    init(baseDirectoryURL: URL = TemplateStore.defaultBaseDirectoryURL) {
        self.baseDirectoryURL = baseDirectoryURL
    }

    // MARK: - URLs

    func folderURL(for templateID: UUID) -> URL {
        baseDirectoryURL.appending(path: templateID.uuidString, directoryHint: .isDirectory)
    }

    func pdfURL(for template: Template) -> URL {
        folderURL(for: template.id).appending(path: template.pdfFileName)
    }

    func thumbnailURL(for templateID: UUID) -> URL {
        folderURL(for: templateID).appending(path: Self.thumbnailFileName)
    }

    // MARK: - Reading

    /// Loads every readable template, most recently modified first.
    /// Folders whose `template.json` is missing or undecodable are skipped
    /// (and logged) rather than failing the whole library.
    func loadAll() throws -> [Template] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: baseDirectoryURL.path(percentEncoded: false)) else {
            return []
        }
        let folders = try fileManager.contentsOfDirectory(
            at: baseDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var templates: [Template] = []
        for folder in folders {
            let isDirectory = (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { continue }
            do {
                templates.append(try loadTemplate(inFolder: folder))
            } catch {
                Self.logger.error("Skipping unreadable template folder \(folder.lastPathComponent): \(error)")
            }
        }
        return templates.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func load(id: UUID) throws -> Template {
        let folder = folderURL(for: id)
        guard FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) else {
            throw TemplateStoreError.templateNotFound(id)
        }
        return try loadTemplate(inFolder: folder)
    }

    private func loadTemplate(inFolder folder: URL) throws -> Template {
        let data = try Data(contentsOf: folder.appending(path: Self.jsonFileName))
        return try Self.makeDecoder().decode(Template.self, from: data)
    }

    // MARK: - Writing

    /// Creates a new template folder from imported PDF bytes. The folder is
    /// fully staged in a temporary location, then moved into place, so a
    /// half-written template can never appear in the library. The stored
    /// PDF is marked read-only (CLAUDE.md invariant #1).
    func create(_ template: Template, pdfData: Data) throws {
        let fileManager = FileManager.default
        let destination = folderURL(for: template.id)
        guard !fileManager.fileExists(atPath: destination.path(percentEncoded: false)) else {
            throw TemplateStoreError.templateAlreadyExists(template.id)
        }
        try ensureBaseDirectory()

        let staging = fileManager.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory
        )
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        let stagedPDF = staging.appending(path: template.pdfFileName)
        try pdfData.write(to: stagedPDF)
        try fileManager.setAttributes([.posixPermissions: 0o444], ofItemAtPath: stagedPDF.path(percentEncoded: false))
        try Self.makeEncoder().encode(template)
            .write(to: staging.appending(path: Self.jsonFileName))

        try fileManager.moveItem(at: staging, to: destination)
    }

    /// Rewrites `template.json` for an existing template. Only the JSON is
    /// touched — never the PDF.
    func save(_ template: Template) throws {
        let folder = folderURL(for: template.id)
        guard FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) else {
            throw TemplateStoreError.templateNotFound(template.id)
        }
        let data = try Self.makeEncoder().encode(template)
        try data.write(to: folder.appending(path: Self.jsonFileName), options: .atomic)
    }

    /// Copies a template's folder under a new UUID with fresh field IDs and
    /// dates. Returns the new template.
    func duplicate(_ template: Template) throws -> Template {
        let fileManager = FileManager.default
        let sourceFolder = folderURL(for: template.id)
        guard fileManager.fileExists(atPath: sourceFolder.path(percentEncoded: false)) else {
            throw TemplateStoreError.templateNotFound(template.id)
        }

        let copy = Template(
            name: template.name + " Copy",
            category: template.category,
            pdfFileName: template.pdfFileName,
            fields: template.fields.map { field in
                FieldDefinition(
                    name: field.name,
                    type: field.type,
                    pageIndex: field.pageIndex,
                    rect: field.rect,
                    style: field.style,
                    sortOrder: field.sortOrder
                )
            }
        )

        let staging = fileManager.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory
        )
        try fileManager.copyItem(at: sourceFolder, to: staging)
        defer { try? fileManager.removeItem(at: staging) }

        let stagedJSON = staging.appending(path: Self.jsonFileName)
        try? fileManager.removeItem(at: stagedJSON)
        try Self.makeEncoder().encode(copy).write(to: stagedJSON)

        try fileManager.moveItem(at: staging, to: folderURL(for: copy.id))
        return copy
    }

    func delete(_ template: Template) throws {
        try delete(id: template.id)
    }

    func delete(id: UUID) throws {
        let folder = folderURL(for: id)
        guard FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) else {
            throw TemplateStoreError.templateNotFound(id)
        }
        try FileManager.default.removeItem(at: folder)
    }

    // MARK: - Plumbing

    private func ensureBaseDirectory() throws {
        try FileManager.default.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
