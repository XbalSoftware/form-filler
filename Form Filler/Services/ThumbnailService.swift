//
//  ThumbnailService.swift
//  Form Filler
//

import UIKit
import PDFKit

/// Renders library thumbnails from a template's first PDF page and caches
/// them as `thumbnail.png` in the template's folder. PDFKit is used purely
/// as a rendering engine here (CLAUDE.md invariant #4); the original PDF is
/// only ever read.
nonisolated struct ThumbnailService: Sendable {
    /// Thumbnail width in pixels (rendered at 2× a ~320pt card).
    var targetPixelWidth: CGFloat = 640

    /// Returns the cached thumbnail if present, otherwise renders page 1,
    /// caches it best-effort, and returns it. Runs off the main actor.
    @concurrent func thumbnail(for template: Template, in store: TemplateStore) async -> UIImage? {
        let cacheURL = store.thumbnailURL(for: template.id)
        if let data = try? Data(contentsOf: cacheURL), let cached = UIImage(data: data) {
            return cached
        }

        guard let document = PDFDocument(url: store.pdfURL(for: template)),
              let page = document.page(at: 0) else {
            return nil
        }

        // Aspect ratio must respect /Rotate: a 90°/270° page displays with
        // width and height swapped.
        var pageSize = page.bounds(for: .mediaBox).size
        if page.rotation % 180 != 0 {
            pageSize = CGSize(width: pageSize.height, height: pageSize.width)
        }
        guard pageSize.width > 0, pageSize.height > 0 else { return nil }

        let scale = targetPixelWidth / pageSize.width
        let image = page.thumbnail(
            of: CGSize(width: pageSize.width * scale, height: pageSize.height * scale),
            for: .mediaBox
        )

        // Cache failures are harmless — we just re-render next launch.
        try? image.pngData()?.write(to: cacheURL, options: .atomic)
        return image
    }
}
