//
//  PDFExportServiceTests.swift
//  Form FillerTests
//
//  Exports are verified by re-parsing the output PDF: page count and
//  size survive, and drawn values are real (extractable) PDF text.
//

import CoreGraphics
import Foundation
import PDFKit
import Testing
import UIKit
@testable import Form_Filler

struct PDFExportServiceTests {
    private let pageSize = CGSize(width: 612, height: 792)

    /// A two-page vector source PDF written to a temp file.
    private func makeSourcePDF() throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let data = renderer.pdfData { context in
            context.beginPage()
            "SOURCE PAGE ONE".draw(at: CGPoint(x: 40, y: 40), withAttributes: [
                .font: UIFont(name: "Helvetica", size: 14)!,
            ])
            context.beginPage()
            "SOURCE PAGE TWO".draw(at: CGPoint(x: 40, y: 40), withAttributes: [
                .font: UIFont(name: "Helvetica", size: 14)!,
            ])
        }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "export-test-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }

    private func makeTemplate() -> Template {
        Template(
            name: "Export Test",
            fields: [
                FieldDefinition(
                    name: "Patient Name",
                    type: .singleLineText,
                    pageIndex: 0,
                    rect: CGRect(x: 100, y: 640, width: 300, height: 24),
                    sortOrder: 0
                ),
                FieldDefinition(
                    name: "Urgent",
                    type: .checkbox,
                    pageIndex: 0,
                    rect: CGRect(x: 60, y: 500, width: 16, height: 16),
                    sortOrder: 1
                ),
                FieldDefinition(
                    name: "Referral Date",
                    type: .date,
                    pageIndex: 0,
                    rect: CGRect(x: 400, y: 700, width: 120, height: 20),
                    sortOrder: 2,
                    dateFormat: "yyyy-MM-dd"
                ),
                FieldDefinition(
                    name: "Clinic",
                    type: .staticText,
                    pageIndex: 1,
                    rect: CGRect(x: 40, y: 700, width: 300, height: 20),
                    sortOrder: 3,
                    staticText: "ANYTOWN EYE CLINIC"
                ),
            ]
        )
    }

    @Test func exportContainsPagesValuesAndStaticText() throws {
        let sourceURL = try makeSourcePDF()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let template = makeTemplate()
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 17))!
        let values: [UUID: FieldValue] = [
            template.fields[0].id: .text("JANE EXAMPLE"),
            template.fields[1].id: .checkbox(true),
            template.fields[2].id: .date(date),
        ]

        let data = try PDFExportService().exportPDF(template: template, values: values, sourceURL: sourceURL)
        let exported = try #require(PDFDocument(data: data))

        #expect(exported.pageCount == 2)

        let pageOne = try #require(exported.page(at: 0)?.string)
        #expect(pageOne.contains("SOURCE PAGE ONE"))     // original content survived
        #expect(pageOne.contains("JANE EXAMPLE"))
        #expect(pageOne.contains("X"))                   // checked checkbox
        #expect(pageOne.contains("2026-07-17"))          // per-field date format

        let pageTwo = try #require(exported.page(at: 1)?.string)
        #expect(pageTwo.contains("SOURCE PAGE TWO"))
        #expect(pageTwo.contains("ANYTOWN EYE CLINIC"))  // static text, no value needed
        #expect(!pageTwo.contains("JANE EXAMPLE"))       // page-0 value stays on page 0
    }

    @Test func exportPreservesPageSize() throws {
        let sourceURL = try makeSourcePDF()
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let data = try PDFExportService().exportPDF(template: makeTemplate(), values: [:], sourceURL: sourceURL)
        let exported = try #require(PDFDocument(data: data))
        let bounds = try #require(exported.page(at: 0)).bounds(for: .mediaBox)
        #expect(bounds.size == pageSize)
    }

    @Test func exportNeverTouchesSourceFile() throws {
        // Invariant #1: exporting reads the original; bytes must be identical after.
        let sourceURL = try makeSourcePDF()
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        let before = try Data(contentsOf: sourceURL)
        _ = try PDFExportService().exportPDF(template: makeTemplate(), values: [:], sourceURL: sourceURL)
        let after = try Data(contentsOf: sourceURL)
        #expect(before == after)
    }

    @Test func missingSourceThrows() {
        let bogus = FileManager.default.temporaryDirectory.appending(path: "nope-\(UUID().uuidString).pdf")
        #expect(throws: PDFExportError.cannotOpenSource) {
            _ = try PDFExportService().exportPDF(template: makeTemplate(), values: [:], sourceURL: bogus)
        }
    }

    @Test func defaultFileNameFormat() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 17))!
        let template = Template(name: "Retinal Referral")
        #expect(PDFExportService.defaultFileName(for: template, on: date) == "Retinal Referral – 2026-07-17.pdf")

        let sneaky = Template(name: "A/B: C\\D")
        let name = PDFExportService.defaultFileName(for: sneaky, on: date)
        #expect(!name.contains("/"))
        #expect(!name.contains(":"))
        #expect(!name.contains("\\"))
    }
}
