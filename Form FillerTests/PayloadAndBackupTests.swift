//
//  PayloadAndBackupTests.swift
//  Form FillerTests
//
//  Covers the 2026-07-17 additions: the codable fill payload (draft vault
//  + embedded PDF source), the payload embedded in exported PDFs, the
//  patient-name filename, and the whole-library backup round-trip.
//

import CoreGraphics
import Foundation
import PDFKit
import Testing
import UIKit
@testable import Form_Filler

struct FillSessionPayloadTests {
    private func makePayload() -> (FillSessionPayload, [UUID: FieldValue]) {
        let values: [UUID: FieldValue] = [
            UUID(): .text("jane@example.com"),
            UUID(): .date(Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 17))!),
            UUID(): .checkbox(true),
        ]
        let payload = FillSessionPayload(
            templateID: UUID(),
            templateName: "Round Trip",
            values: values,
            marks: [
                AdHocMark(kind: .check, pageIndex: 0, rect: CGRect(x: 50, y: 60, width: 16, height: 16)),
                AdHocMark(kind: .circle, pageIndex: 1, rect: CGRect(x: 100, y: 200, width: 80, height: 30)),
            ]
        )
        return (payload, values)
    }

    @Test func embeddedStringRoundTrip() throws {
        let (payload, values) = makePayload()
        let string = try payload.embeddedString()
        #expect(string.hasPrefix(FillSessionPayload.embeddedPrefix))

        let decoded = try #require(FillSessionPayload.fromEmbeddedString(string))
        #expect(decoded.templateID == payload.templateID)
        #expect(decoded.templateName == "Round Trip")
        #expect(decoded.fieldValues == values)
        #expect(decoded.marks == payload.marks)
    }

    @Test func rejectsForeignStrings() {
        #expect(FillSessionPayload.fromEmbeddedString("some ordinary keywords") == nil)
        #expect(FillSessionPayload.fromEmbeddedString("FormFiller1:not-base64!!!") == nil)
        #expect(FillSessionPayload.fromEmbeddedString("") == nil)
    }
}

struct ExportedPayloadTests {
    private func makeSourcePDF() throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let data = renderer.pdfData { context in
            context.beginPage()
            "SOURCE".draw(at: CGPoint(x: 40, y: 40), withAttributes: [
                .font: UIFont(name: "Helvetica", size: 14)!,
            ])
        }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "payload-test-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    @Test func exportedPDFCarriesReadablePayload() throws {
        let sourceURL = try makeSourcePDF()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let field = FieldDefinition(
            name: "Notes",
            type: .multiLineText,
            rect: CGRect(x: 40, y: 600, width: 300, height: 100)
        )
        let template = Template(name: "Embed Test", fields: [field])
        let values: [UUID: FieldValue] = [field.id: .text("line one\nline two")]

        let data = try PDFExportService().exportPDF(template: template, values: values, sourceURL: sourceURL)
        let payload = try #require(PDFExportService.embeddedPayload(in: data))
        #expect(payload.templateID == template.id)
        #expect(payload.fieldValues == values)

        // And the page content itself is still a valid PDF with the text.
        let reopened = try #require(PDFDocument(data: data))
        #expect(reopened.page(at: 0)?.string?.contains("SOURCE") == true)
    }

    @Test func foreignPDFHasNoPayload() throws {
        let sourceURL = try makeSourcePDF()
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        let plain = try Data(contentsOf: sourceURL)
        #expect(PDFExportService.embeddedPayload(in: plain) == nil)
    }

    @Test func fileNameIncludesPatientNameWhenPresent() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 17))!
        let template = Template(name: "Retinal Referral")
        #expect(
            PDFExportService.defaultFileName(for: template, patientName: "Jane Example", on: date)
                == "Jane Example – Retinal Referral – 2026-07-17.pdf"
        )
        // Empty/whitespace patient names fall back to the plain form.
        #expect(
            PDFExportService.defaultFileName(for: template, patientName: "   ", on: date)
                == "Retinal Referral – 2026-07-17.pdf"
        )
        // Path-hostile characters are sanitized out of the patient segment.
        let name = PDFExportService.defaultFileName(for: template, patientName: "A/B:C\\D", on: date)
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(!name.contains("\\"))
    }
}

struct LibraryBackupTests {
    private func makeStore() throws -> TemplateStore {
        let base = FileManager.default.temporaryDirectory
            .appending(path: "backup-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return TemplateStore(baseDirectoryURL: base.appending(path: "Templates", directoryHint: .isDirectory))
    }

    private func removeStore(_ store: TemplateStore) {
        try? FileManager.default.removeItem(at: store.baseDirectoryURL.deletingLastPathComponent())
    }

    private let pdfBytes = Data("%PDF-1.4 fake-but-stable-bytes".utf8)

    private func makeTemplate(name: String) -> Template {
        Template(
            name: name,
            category: "Backups",
            fields: [
                FieldDefinition(
                    name: "Patient Name",
                    type: .patientName,
                    rect: CGRect(x: 10, y: 20, width: 200, height: 24)
                ),
            ]
        )
    }

    @Test func backupRoundTripRebuildsLibrary() throws {
        let source = try makeStore()
        defer { removeStore(source) }
        let destination = try makeStore()
        defer { removeStore(destination) }

        let template = makeTemplate(name: "Backup Me")
        try source.create(template, pdfData: pdfBytes)

        let backupData = try LibraryBackupService(store: source).exportBackup()
        let summary = try LibraryBackupService(store: destination).restore(from: backupData)
        #expect(summary == LibraryBackupService.RestoreSummary(imported: 1, skipped: 0))

        let restored = try destination.load(id: template.id)
        #expect(restored == template)
        #expect(try Data(contentsOf: destination.pdfURL(for: restored)) == pdfBytes)
    }

    @Test func restoreSkipsExistingTemplates() throws {
        let store = try makeStore()
        defer { removeStore(store) }

        let template = makeTemplate(name: "Already Here")
        try store.create(template, pdfData: pdfBytes)

        let backupData = try LibraryBackupService(store: store).exportBackup()
        let summary = try LibraryBackupService(store: store).restore(from: backupData)
        #expect(summary == LibraryBackupService.RestoreSummary(imported: 0, skipped: 1))
        #expect(try store.loadAll().count == 1)
    }

    @Test func emptyLibraryRefusesToBackUp() throws {
        let store = try makeStore()
        defer { removeStore(store) }
        #expect(throws: LibraryBackupError.emptyBackup) {
            _ = try LibraryBackupService(store: store).exportBackup()
        }
    }

    @Test func backupCarriesPractitionerProfiles() throws {
        // The profile list travels in the backup JSON and merges add-only
        // by ID on restore. (Stores here use explicit temp files so the
        // test never touches real app data.)
        let profile = PractitionerProfile(
            label: "Dr. Test — Downtown",
            name: "Dr. Test",
            officeAddress: "1 Example St\nAnytown",
            officePhone: "555-0100",
            practitionerID: "PRAC123",
            signatureBase64: Data("fake-signature-bytes".utf8).base64EncodedString()
        )
        let backup = LibraryBackup(
            entries: [],
            practitioners: [profile]
        )
        let data = try TemplateStore.makeEncoder().encode(backup)
        let decoded = try TemplateStore.makeDecoder().decode(LibraryBackup.self, from: data)
        #expect(decoded.practitioners == [profile])
    }

    @Test func practitionerStoreRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "prac-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PractitionerStore(directoryURL: directory)

        #expect(store.load().isEmpty)
        let profiles = [
            PractitionerProfile(name: "Dr. A", practitionerID: "A1"),
            PractitionerProfile(name: "Dr. B", email: "b@example.com"),
        ]
        try store.save(profiles)
        #expect(store.load() == profiles)
    }

    @Test func garbageIsNotABackup() throws {
        let store = try makeStore()
        defer { removeStore(store) }
        #expect(throws: LibraryBackupError.unreadableBackup) {
            _ = try LibraryBackupService(store: store).restore(from: Data("nonsense".utf8))
        }
    }
}
