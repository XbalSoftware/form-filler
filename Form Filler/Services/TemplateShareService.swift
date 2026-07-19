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

    /// A new PDF: the original's pages re-serialized through PDFKit with
    /// the template definition in Keywords. Verified readable before
    /// returning, so a colleague's import can't silently fail.
    static func pdfWithEmbeddedTemplate(_ template: Template, pdfData: Data) throws -> Data {
        guard let document = PDFDocument(data: pdfData) else {
            throw TemplateShareError.cannotEmbed
        }
        let payload = embeddedPrefix
            + (try TemplateStore.makeEncoder().encode(template)).base64EncodedString()
        var attributes = document.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.keywordsAttribute] = payload
        document.documentAttributes = attributes
        guard let data = document.dataRepresentation(),
              embeddedTemplate(in: data) != nil else {
            throw TemplateShareError.cannotEmbed
        }
        return data
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
