//
//  PDFRenderService.swift
//  Form Filler
//

import UIKit
import PDFKit

/// Renders a template's PDF pages to images for display in our own canvas
/// (PDFKit as engine only — CLAUDE.md invariant #4). The document is opened
/// read-only and never written.
///
/// Scale is quantized to half-steps and results are cached, so continuous
/// pinch gestures don't trigger a render per frame — only a "material"
/// zoom change produces a new image.
///
/// `@unchecked Sendable`: PDFDocument isn't formally Sendable, but this
/// class only ever reads from it, and NSCache is thread-safe.
nonisolated final class PDFRenderService: @unchecked Sendable {
    private let document: PDFDocument
    private let cache = NSCache<NSString, UIImage>()

    /// Longest rendered edge in pixels — memory guard for large scans.
    private static let maxPixelEdge: CGFloat = 4096

    init?(url: URL) {
        guard let document = PDFDocument(url: url) else { return nil }
        self.document = document
        cache.countLimit = 12
    }

    var pageCount: Int { document.pageCount }

    func coordinateSpace(forPage index: Int) -> PageCoordinateSpace? {
        guard let page = document.page(at: index) else { return nil }
        return PageCoordinateSpace(page: page)
    }

    /// Renders a page at `scale` pixels per PDF point (quantized and
    /// clamped). Runs off the main actor; cached per page+scale.
    @concurrent func image(forPage index: Int, scale rawScale: CGFloat) async -> UIImage? {
        guard let page = document.page(at: index) else { return nil }
        let displaySize = PageCoordinateSpace(page: page).displaySize
        guard displaySize.width > 0, displaySize.height > 0 else { return nil }

        var scale = min(max((rawScale * 2).rounded(.up) / 2, 0.5), 8)
        let longestEdge = max(displaySize.width, displaySize.height)
        if longestEdge * scale > Self.maxPixelEdge {
            scale = Self.maxPixelEdge / longestEdge
        }

        let key = "\(index)@\(scale)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image = page.thumbnail(
            of: CGSize(width: displaySize.width * scale, height: displaySize.height * scale),
            for: .mediaBox
        )
        cache.setObject(image, forKey: key)
        return image
    }
}
