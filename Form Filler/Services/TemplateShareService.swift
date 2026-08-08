//
//  TemplateShareService.swift
//  Form Filler
//
//  Single-template sharing between colleagues running Form Filler: the
//  shared artifact is an ordinary, viewable PDF (a COPY of the template's
//  original — invariant #1 untouched) whose Keywords Info key carries the
//  template definition as "FormFillerTemplate1:" + base64 JSON. The normal
//  Import PDF flow detects the payload and offers to recreate the
//  template, fields and all.
//
//  Deliberately excludes practitioner profiles and signatures — those are
//  personal and never belong in a shared template.
//

import Foundation
import PDFKit

nonisolated enum TemplateShareError: LocalizedError {
    case cannotEmbed

    var errorDescription: String? {
        switch self {
        case .cannotEmbed: "Couldn't attach the template data to the PDF."
        }
    }
}

nonisolated enum TemplateShareService {
    /// Distinct from the fill payload's "FormFiller1:" prefix — both live
    /// in the Keywords key, the prefix says which kind of payload it is.
    static let embeddedPrefix = "FormFillerTemplate1:"

    /// `<TemplateName> – Form Filler Template.pdf`
    static func shareFileName(for template: Template) -> String {
        sanitized(template.name) + " – Form Filler Template.pdf"
    }

    /// `<TemplateName>.pdf` — for sharing the untouched blank original.
    static func blankFileName(for template: Template) -> String {
        sanitized(template.name) + ".pdf"
    }

    private static func sanitized(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
    }

    /// A new PDF carrying the template definition in Keywords, verified
    /// readable before returning so a colleague's import can't silently
    /// fail. Preferred path is PDFKit re-serialize (preserves the original's
    /// exact page geometry); if that doesn't take, it falls back to a clean
    /// Core Graphics re-render.
    ///
    /// The verification checks that THIS payload reads back — not merely that
    /// some template does. When the source PDF was itself a shared template
    /// (so it already carries embedded keywords), PDFKit's dataRepresentation
    /// can fail to overwrite them, leaving the OLD placement in place; a
    /// weaker "any template present" check would accept that stale result.
    /// The CG re-render draws fresh document info, so the old keywords are
    /// gone. Tagged PDFs whose structure tree defeats dataRepresentation take
    /// the same fallback.
    static func pdfWithEmbeddedTemplate(_ template: Template, pdfData: Data) throws -> Data {
        guard let document = PDFDocument(data: pdfData) else {
            throw TemplateShareError.cannotEmbed
        }
        let payload = embeddedPrefix
            + (try TemplateStore.makeEncoder().encode(template)).base64EncodedString()

        // 1. In place: fastest, preserves everything — but won't overwrite
        //    keywords a shared PDF already carries.
        var attributes = document.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.keywordsAttribute] = payload
        document.documentAttributes = attributes
        if let data = document.dataRepresentation(), embeds(payload, in: data) {
            return data
        }

        // 2. Fresh document with copied pages: no pre-existing keywords to
        //    fight (fixes re-sharing an imported template), and page copies
        //    keep each page's exact geometry.
        if let data = freshDocumentData(copyingPagesFrom: document, keywords: payload),
           embeds(payload, in: data) {
            return data
        }

        // 3. Core Graphics re-render: last resort for PDFs whose tag structure
        //    defeats PDFKit (may alter rotated-page geometry).
        let rerendered = PDFExportService().pdfCopy(ofSource: document, keywords: payload)
        guard embeds(payload, in: rerendered) else {
            throw TemplateShareError.cannotEmbed
        }
        return rerendered
    }

    /// Rebuilds the PDF from page copies in a brand-new document so the
    /// keywords write lands on clean document info (no stale template to
    /// overwrite). Page copies preserve mediaBox and rotation exactly.
    private static func freshDocumentData(copyingPagesFrom source: PDFDocument, keywords: String) -> Data? {
        let fresh = PDFDocument()
        for index in 0..<source.pageCount {
            guard let page = source.page(at: index)?.copy() as? PDFPage else { return nil }
            fresh.insert(page, at: fresh.pageCount)
        }
        guard fresh.pageCount > 0 else { return nil }
        fresh.documentAttributes = [PDFDocumentAttribute.keywordsAttribute: keywords]
        return fresh.dataRepresentation()
    }

    /// True only if `payload` itself is one of the PDF's keyword strings —
    /// so a stale, previously-embedded template can't pass verification.
    private static func embeds(_ payload: String, in data: Data) -> Bool {
        let target = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        return PDFExportService.keywordsCandidates(in: data)
            .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines) == target }
    }

    /// The template definition inside a shared PDF, or nil for ordinary
    /// PDFs (including our own fill exports, which use the other prefix).
    static func embeddedTemplate(in data: Data) -> Template? {
        for keywords in PDFExportService.keywordsCandidates(in: data) {
            let trimmed = keywords.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix(embeddedPrefix),
                  let decoded = Data(base64Encoded: String(trimmed.dropFirst(embeddedPrefix.count))),
                  let template = try? TemplateStore.makeDecoder().decode(Template.self, from: decoded)
            else { continue }
            return template
        }
        return nil
    }
}
