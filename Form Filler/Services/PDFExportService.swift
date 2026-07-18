//
//  PDFExportService.swift
//  Form Filler
//
//  Core Graphics re-render export (CLAUDE.md invariant #5): each output
//  page is drawn from scratch — original page content first (vector, via
//  CGPDFPage with the documented rotation-aware drawing transform), then
//  field values as attributed strings in display space. No PDFAnnotation
//  flattening, and the source PDF is only ever read (invariant #1).
//
//  Font fitting and value formatting use the exact same Support functions
//  as the fill preview, so the export matches what the user saw.
//

import UIKit
import PDFKit

nonisolated enum PDFExportError: LocalizedError {
    case cannotOpenSource
    case emptyDocument

    var errorDescription: String? {
        switch self {
        case .cannotOpenSource: "The template's PDF file couldn't be read."
        case .emptyDocument: "The template's PDF has no pages."
        }
    }
}

nonisolated struct PDFExportService: Sendable {

    // MARK: - Filename & temp files

    /// `<TemplateName> – <PatientName> – <yyyy-MM-dd>.pdf`, or without the
    /// patient segment when no patient-name field is filled. Including the
    /// patient name is a deliberate user decision (2026-07-17) that
    /// supersedes the original never-in-filename rule; it only ever comes
    /// from a field the user explicitly typed into.
    static func defaultFileName(
        for template: Template,
        patientName: String? = nil,
        on date: Date = .now
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var parts = [sanitized(template.name)]
        if let patientName, let safePatient = nonEmpty(sanitized(patientName)) {
            parts.append(safePatient)
        }
        parts.append(formatter.string(from: date))
        return parts.joined(separator: " – ") + ".pdf"
    }

    private static func sanitized(_ name: String) -> String {
        name.components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Exported files are staged here for the share sheet, then purged on
    /// app launch and when leaving the fill screen.
    static var temporaryExportDirectory: URL {
        FileManager.default.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory)
    }

    static func purgeTemporaryExports() {
        try? FileManager.default.removeItem(at: temporaryExportDirectory)
    }

    // MARK: - Export

    func exportPDF(
        template: Template,
        values: [UUID: FieldValue],
        marks: [AdHocMark] = [],
        signature: UIImage? = nil,
        sourceURL: URL
    ) throws -> Data {
        guard let document = PDFDocument(url: sourceURL) else {
            throw PDFExportError.cannotOpenSource
        }
        guard document.pageCount > 0 else {
            throw PDFExportError.emptyDocument
        }

        // Embedded source: the full fill payload rides in the "Keywords"
        // Info key so an exported PDF can be reopened for re-editing.
        // It MUST be a documented Info key — CGPDFContext silently drops
        // custom keys (lesson learned empirically in the user's EYEreport
        // app; Keywords carried a 120KB payload intact there).
        let payload = FillSessionPayload(
            templateID: template.id,
            templateName: template.name,
            values: values,
            marks: marks
        )
        let payloadString = try payload.embeddedString()

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Form Filler",
            kCGPDFContextKeywords as String: payloadString,
        ]
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 612, height: 792),
            format: format
        )

        let data = renderer.pdfData { rendererContext in
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                let space = PageCoordinateSpace(page: page)
                let displaySize = space.displaySize
                guard displaySize.width > 0, displaySize.height > 0 else { continue }

                rendererContext.beginPage(
                    withBounds: CGRect(origin: .zero, size: displaySize),
                    pageInfo: [:]
                )
                drawPageContent(page, displaySize: displaySize, in: rendererContext.cgContext)

                for field in template.fields where field.pageIndex == pageIndex {
                    if let text = FieldValueFormatting.displayText(for: field, value: values[field.id]) {
                        drawFieldText(text, field: field, space: space)
                    }
                    if let signature,
                       field.type == .signature,
                       case .checkbox(true) = values[field.id] {
                        drawSignature(signature, field: field, space: space)
                    }
                }

                for mark in marks where mark.pageIndex == pageIndex {
                    drawMark(mark, space: space, in: rendererContext.cgContext)
                }
            }
        }
        return ensuringEmbeddedSource(data, payloadString: payloadString)
    }

    /// Draws the stored signature image aspect-fit and centered in the
    /// field's rect (display space — UIImage.draw matches its y-down).
    private func drawSignature(_ image: UIImage, field: FieldDefinition, space: PageCoordinateSpace) {
        let rect = space.viewRect(fromPDFRect: field.rect, in: space.displaySize)
        let size = image.size
        guard size.width > 0, size.height > 0, rect.width > 0, rect.height > 0 else { return }
        let scale = min(rect.width / size.width, rect.height / size.height)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        image.draw(in: CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        ))
    }

    /// Draws an ad-hoc checkmark or circle as vector strokes in display
    /// space. `MarkGeometry` supplies the same paths the preview overlay
    /// renders, so the two can never disagree.
    private func drawMark(_ mark: AdHocMark, space: PageCoordinateSpace, in ctx: CGContext) {
        let rect = space.viewRect(fromPDFRect: mark.rect, in: space.displaySize)
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(MarkGeometry.lineWidth(for: rect))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.addPath(MarkGeometry.path(for: mark.kind, in: rect))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Embedded fill payload

    /// Some render paths have been observed (on device, in EYEreport) to
    /// drop the documentInfo write. If the rendered bytes lack a readable
    /// payload, re-serialize ONCE through PDFKit's keywords attribute —
    /// page content is preserved. Keep BOTH writers pointed at Keywords.
    private func ensuringEmbeddedSource(_ data: Data, payloadString: String) -> Data {
        if Self.embeddedPayload(in: data) != nil { return data }
        guard let document = PDFDocument(data: data) else { return data }
        var attributes = document.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.keywordsAttribute] = payloadString
        document.documentAttributes = attributes
        guard let rewritten = document.dataRepresentation(),
              Self.embeddedPayload(in: rewritten) != nil else { return data }
        return rewritten
    }

    /// Reads the fill payload back out of an exported PDF, or nil if the
    /// PDF wasn't produced by this app (or a pipeline stripped its Info).
    static func embeddedPayload(in data: Data) -> FillSessionPayload? {
        for keywords in keywordsCandidates(in: data) {
            if let payload = FillSessionPayload.fromEmbeddedString(keywords) {
                return payload
            }
        }
        return nil
    }

    /// Keywords via CGPDFDocument.info (the write path's ground truth),
    /// plus PDFKit's read as a fallback — it surfaces the attribute as
    /// either a string or an array depending on how the PDF was written.
    private static func keywordsCandidates(in data: Data) -> [String] {
        var candidates: [String] = []
        if let provider = CGDataProvider(data: data as CFData),
           let document = CGPDFDocument(provider),
           let info = document.info {
            var stringRef: CGPDFStringRef?
            if CGPDFDictionaryGetString(info, "Keywords", &stringRef),
               let stringRef,
               let text = CGPDFStringCopyTextString(stringRef) {
                candidates.append(text as String)
            }
        }
        if let attributes = PDFDocument(data: data)?.documentAttributes {
            let keywords = attributes[PDFDocumentAttribute.keywordsAttribute]
            if let text = keywords as? String {
                candidates.append(text)
            } else if let list = keywords as? [String] {
                candidates.append(contentsOf: list)
            }
        }
        return candidates
    }

    /// Draws the original page (vector) upright into the y-down output
    /// context. `getDrawingTransform` is the documented Quartz API that
    /// maps the mediaBox into the target rect honoring /Rotate.
    private func drawPageContent(_ page: PDFPage, displaySize: CGSize, in ctx: CGContext) {
        guard let cgPage = page.pageRef else { return }
        ctx.saveGState()
        ctx.translateBy(x: 0, y: displaySize.height)
        ctx.scaleBy(x: 1, y: -1)
        let transform = cgPage.getDrawingTransform(
            .mediaBox,
            rect: CGRect(origin: .zero, size: displaySize),
            rotate: 0,
            preserveAspectRatio: true
        )
        ctx.concatenate(transform)
        ctx.drawPDFPage(cgPage)
        ctx.restoreGState()
    }

    /// Draws one field's text in display space (y-down, same space the
    /// fill preview positions its overlays in).
    private func drawFieldText(_ text: String, field: FieldDefinition, space: PageCoordinateSpace) {
        // 1:1 scale — display-space rect in PDF points (orientation-correct
        // even on rotated pages, where PDF-space width/height are swapped).
        let rect = space.viewRect(fromPDFRect: field.rect, in: space.displaySize)
        let multiline = field.type.isMultiline

        // White backing (default for multi-line): hides the form's ruled
        // lines behind the answer. Only ever drawn when there IS an
        // answer — this function isn't called for empty fields.
        if field.fillsWhiteBackground, let ctx = UIGraphicsGetCurrentContext() {
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(rect)
        }

        let fontSize = TextFitting.fittedFontSize(
            for: text,
            fontName: field.style.fontName,
            preferredSize: field.style.fontSize,
            in: rect.size,
            multiline: multiline
        )
        let font = UIFont(name: field.style.fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = multiline ? .byWordWrapping : .byClipping
        paragraph.alignment = switch field.style.alignment {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }

        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: ColorHex.uiColor(from: field.style.colorHex) ?? .black,
            .paragraphStyle: paragraph,
        ])

        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        switch field.type {
        case .checkbox:
            let size = attributed.boundingRect(with: rect.size, options: options, context: nil).size
            attributed.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
        case .multiLineText, .officeAddress:
            attributed.draw(with: rect, options: options, context: nil)
        case .singleLineText, .date, .staticText, .patientName, .signature,
             .doctorName, .officeFax, .officePhone, .officeEmail, .practitionerID:
            // (.signature never reaches here — displayText is nil — but the
            // switch must stay exhaustive.)
            let unbounded = CGFloat.greatestFiniteMagnitude
            let textHeight = attributed.boundingRect(
                with: CGSize(width: unbounded, height: unbounded),
                options: options,
                context: nil
            ).height
            let centered = CGRect(
                x: rect.minX,
                y: rect.minY + (rect.height - textHeight) / 2,
                width: rect.width,
                height: ceil(textHeight)
            )
            attributed.draw(with: centered, options: options, context: nil)
        }
    }
}
