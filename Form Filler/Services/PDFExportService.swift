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

    /// `<TemplateName> – <yyyy-MM-dd>.pdf`. Never includes patient data.
    static func defaultFileName(for template: Template, on date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let safeName = template.name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
        return "\(safeName) – \(formatter.string(from: date)).pdf"
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

    func exportPDF(template: Template, values: [UUID: FieldValue], sourceURL: URL) throws -> Data {
        guard let document = PDFDocument(url: sourceURL) else {
            throw PDFExportError.cannotOpenSource
        }
        guard document.pageCount > 0 else {
            throw PDFExportError.emptyDocument
        }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextCreator as String: "Form Filler"]
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 612, height: 792),
            format: format
        )

        return renderer.pdfData { rendererContext in
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
                }
            }
        }
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
        let multiline = field.type == .multiLineText

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
        case .multiLineText:
            attributed.draw(with: rect, options: options, context: nil)
        case .singleLineText, .date, .staticText:
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
