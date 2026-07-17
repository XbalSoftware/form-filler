//
//  TemplateStoreTests.swift
//  Form FillerTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Form_Filler

/// CRUD tests against a throwaway base directory, removed after each test.
final class TemplateStoreTests {
    private let baseURL: URL
    private let store: TemplateStore
    private let samplePDFData = Data("%PDF-1.4 fake sample bytes".utf8)

    init() {
        baseURL = FileManager.default.temporaryDirectory
            .appending(path: "TemplateStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = TemplateStore(baseDirectoryURL: baseURL)
    }

    deinit {
        try? FileManager.default.removeItem(at: baseURL)
    }

    private func makeTemplate(name: String = "Test Template") -> Template {
        Template(
            name: name,
            fields: [
                FieldDefinition(
                    name: "Patient Name",
                    rect: CGRect(x: 100, y: 640, width: 180, height: 24)
                ),
            ]
        )
    }

    // MARK: - Create / load

    @Test func createThenLoadRoundTrips() throws {
        let template = makeTemplate()
        try store.create(template, pdfData: samplePDFData)

        let loaded = try store.load(id: template.id)
        #expect(loaded.name == template.name)
        #expect(loaded.fields == template.fields)

        let storedPDF = try Data(contentsOf: store.pdfURL(for: template))
        #expect(storedPDF == samplePDFData)
    }

    @Test func storedPDFIsReadOnly() throws {
        let template = makeTemplate()
        try store.create(template, pdfData: samplePDFData)
        let pdfPath = store.pdfURL(for: template).path(percentEncoded: false)
        #expect(FileManager.default.isReadableFile(atPath: pdfPath))
        #expect(!FileManager.default.isWritableFile(atPath: pdfPath))
    }

    @Test func createExistingIDThrows() throws {
        let template = makeTemplate()
        try store.create(template, pdfData: samplePDFData)
        #expect(throws: TemplateStoreError.templateAlreadyExists(template.id)) {
            try self.store.create(template, pdfData: self.samplePDFData)
        }
    }

    @Test func loadMissingTemplateThrows() {
        let missing = UUID()
        #expect(throws: TemplateStoreError.templateNotFound(missing)) {
            _ = try self.store.load(id: missing)
        }
    }

    // MARK: - loadAll

    @Test func loadAllReturnsEmptyWhenDirectoryMissing() throws {
        #expect(try store.loadAll().isEmpty)
    }

    @Test func loadAllSortsByModifiedDateAndSkipsCorruptFolders() throws {
        var older = makeTemplate(name: "Older")
        older.modifiedAt = Date(timeIntervalSince1970: 1_000_000)
        var newer = makeTemplate(name: "Newer")
        newer.modifiedAt = Date(timeIntervalSince1970: 2_000_000)
        try store.create(older, pdfData: samplePDFData)
        try store.create(newer, pdfData: samplePDFData)

        // A folder with garbage JSON must be skipped, not sink the library.
        let corruptFolder = baseURL.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: corruptFolder, withIntermediateDirectories: true)
        try Data("not json at all".utf8).write(to: corruptFolder.appending(path: "template.json"))

        let loaded = try store.loadAll()
        #expect(loaded.map(\.name) == ["Newer", "Older"])
    }

    // MARK: - Save

    @Test func saveRewritesMetadata() throws {
        var template = makeTemplate()
        try store.create(template, pdfData: samplePDFData)

        template.name = "Renamed"
        template.fields.append(
            FieldDefinition(name: "Urgent", type: .checkbox, rect: CGRect(x: 60, y: 500, width: 16, height: 16), sortOrder: 1)
        )
        try store.save(template)

        let loaded = try store.load(id: template.id)
        #expect(loaded.name == "Renamed")
        #expect(loaded.fields.count == 2)
        // PDF untouched by save.
        #expect(try Data(contentsOf: store.pdfURL(for: template)) == samplePDFData)
    }

    @Test func saveMissingTemplateThrows() {
        let template = makeTemplate()
        #expect(throws: TemplateStoreError.templateNotFound(template.id)) {
            try self.store.save(template)
        }
    }

    // MARK: - Duplicate

    @Test func duplicateCreatesIndependentCopy() throws {
        let original = makeTemplate()
        try store.create(original, pdfData: samplePDFData)

        let copy = try store.duplicate(original)

        #expect(copy.id != original.id)
        #expect(copy.name == "Test Template Copy")
        #expect(copy.fields.count == original.fields.count)
        // Fresh field IDs, same geometry and styling.
        #expect(copy.fields[0].id != original.fields[0].id)
        #expect(copy.fields[0].rect == original.fields[0].rect)
        #expect(copy.fields[0].type == original.fields[0].type)

        // Both folders exist independently with identical PDF bytes.
        let reloadedOriginal = try store.load(id: original.id)
        let reloadedCopy = try store.load(id: copy.id)
        #expect(reloadedOriginal.name == "Test Template")
        #expect(reloadedCopy.name == "Test Template Copy")
        #expect(try Data(contentsOf: store.pdfURL(for: copy)) == samplePDFData)
    }

    // MARK: - Delete

    @Test func deleteRemovesFolder() throws {
        let template = makeTemplate()
        try store.create(template, pdfData: samplePDFData)
        try store.delete(template)

        let folderPath = store.folderURL(for: template.id).path(percentEncoded: false)
        #expect(!FileManager.default.fileExists(atPath: folderPath))
        #expect(throws: TemplateStoreError.templateNotFound(template.id)) {
            _ = try self.store.load(id: template.id)
        }
        #expect(throws: TemplateStoreError.templateNotFound(template.id)) {
            try self.store.delete(template)
        }
    }
}
