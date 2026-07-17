//
//  TemplateCodableTests.swift
//  Form FillerTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Form_Filler

private func isoDate(_ string: String) -> Date {
    ISO8601DateFormatter().date(from: string)!
}

/// A template exercising every field type, with whole-second dates so the
/// ISO-8601 round trip compares equal.
private func makeSampleTemplate() -> Template {
    Template(
        id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
        name: "Retinal Referral",
        category: "Hospital",
        createdAt: isoDate("2026-07-01T09:00:00Z"),
        modifiedAt: isoDate("2026-07-02T10:30:00Z"),
        fields: [
            FieldDefinition(
                name: "Patient Name",
                type: .singleLineText,
                pageIndex: 0,
                rect: CGRect(x: 100, y: 640, width: 180, height: 24),
                style: FieldStyle(fontName: "Helvetica", fontSize: 12, alignment: .leading, colorHex: "#000000"),
                sortOrder: 0
            ),
            FieldDefinition(
                name: "Notes",
                type: .multiLineText,
                pageIndex: 1,
                rect: CGRect(x: 40, y: 200, width: 500, height: 120),
                style: FieldStyle(fontName: "Helvetica", fontSize: 10, alignment: .leading, colorHex: "#222222"),
                sortOrder: 1
            ),
            FieldDefinition(
                name: "Referral Date",
                type: .date,
                pageIndex: 0,
                rect: CGRect(x: 400, y: 700, width: 120, height: 20),
                sortOrder: 2
            ),
            FieldDefinition(
                name: "Urgent",
                type: .checkbox,
                pageIndex: 0,
                rect: CGRect(x: 60, y: 500, width: 16, height: 16),
                sortOrder: 3
            ),
            FieldDefinition(
                name: "Clinic Header",
                type: .staticText,
                pageIndex: 0,
                rect: CGRect(x: 40, y: 750, width: 300, height: 20),
                style: FieldStyle(fontName: "Helvetica", fontSize: 14, alignment: .center, colorHex: "#003366"),
                sortOrder: 4
            ),
        ]
    )
}

struct TemplateCodableTests {

    @Test func roundTripPreservesEverything() throws {
        let original = makeSampleTemplate()
        let data = try TemplateStore.makeEncoder().encode(original)
        let decoded = try TemplateStore.makeDecoder().decode(Template.self, from: data)
        #expect(decoded == original)
    }

    @Test func encodedJSONIsHumanReadable() throws {
        let data = try TemplateStore.makeEncoder().encode(makeSampleTemplate())
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"name\" : \"Retinal Referral\""))
        #expect(json.contains("\"schemaVersion\" : 1"))
        #expect(json.contains("2026-07-01T09:00:00Z"))
    }

    /// A hand-written "old schema" file: no schemaVersion, no modifiedAt,
    /// no category, fields missing style/sortOrder, and one field whose
    /// type ("signature") this version has never heard of. Must decode
    /// with sensible defaults, not throw.
    @Test func oldSchemaJSONDecodesWithDefaults() throws {
        let json = """
        {
          "id" : "BBBBBBBB-0000-0000-0000-000000000002",
          "name" : "Legacy Template",
          "createdAt" : "2025-01-15T08:00:00Z",
          "pdfFileName" : "original.pdf",
          "fields" : [
            {
              "id" : "BBBBBBBB-0000-0000-0000-000000000003",
              "name" : "Patient",
              "type" : "signature",
              "pageIndex" : 0,
              "rect" : [[10, 20], [180, 24]]
            }
          ]
        }
        """
        let template = try TemplateStore.makeDecoder().decode(Template.self, from: Data(json.utf8))

        #expect(template.id == UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002"))
        #expect(template.schemaVersion == 1)
        #expect(template.name == "Legacy Template")
        #expect(template.category == nil)
        #expect(template.createdAt == isoDate("2025-01-15T08:00:00Z"))

        let field = try #require(template.fields.first)
        #expect(field.name == "Patient")
        #expect(field.type == .singleLineText)   // unknown "signature" falls back
        #expect(field.rect == CGRect(x: 10, y: 20, width: 180, height: 24))
        #expect(field.style == .default)
        #expect(field.sortOrder == 0)
    }

    @Test func nearlyEmptyJSONStillDecodes() throws {
        let template = try TemplateStore.makeDecoder().decode(Template.self, from: Data("{}".utf8))
        #expect(template.name == "Untitled")
        #expect(template.schemaVersion == 1)
        #expect(template.pdfFileName == "original.pdf")
        #expect(template.fields.isEmpty)
    }

    @Test func unknownAlignmentFallsBackToLeading() throws {
        let json = """
        { "fontName" : "Helvetica", "fontSize" : 12, "alignment" : "justified", "colorHex" : "#000000" }
        """
        let style = try TemplateStore.makeDecoder().decode(FieldStyle.self, from: Data(json.utf8))
        #expect(style.alignment == .leading)
    }

    @Test func orderedFieldsSortsBySortOrder() {
        var template = makeSampleTemplate()
        template.fields.reverse()
        #expect(template.orderedFields.map(\.sortOrder) == [0, 1, 2, 3, 4])
    }
}
