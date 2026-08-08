//
//  CoordinateConversion.swift
//  Form Filler
//
//  THE coordinate authority (CLAUDE.md invariant #2). Field geometry is
//  stored in PDF page point space: bottom-left origin, relative to the
//  page's mediaBox, un-rotated. Views display the page as *rotated* (per
//  the page's /Rotate entry) with a top-left origin. Every conversion
//  between those two spaces goes through PageCoordinateSpace — nowhere else.
//

import Foundation
import CoreGraphics
import PDFKit

/// Pure geometry for one PDF page: its mediaBox (which may have a non-zero
/// origin in scanned documents) and its display rotation.
///
/// "View space" here means the coordinate system of the *displayed* page at
/// some size `viewSize`: top-left origin, y down, rotation already applied.
/// `viewSize` is whatever size the page is currently laid out at; the same
/// math therefore works for any zoom level as long as callers pass the
/// size the page content is actually occupying.
nonisolated struct PageCoordinateSpace: Equatable, Sendable {
    let mediaBox: CGRect
    /// Clockwise display rotation in degrees; always one of 0/90/180/270.
    let rotation: Int

    init(mediaBox: CGRect, rotation: Int) {
        self.mediaBox = mediaBox
        let wrapped = ((rotation % 360) + 360) % 360
        self.rotation = (wrapped / 90) * 90
    }

    /// The size the page occupies on screen (in PDF points, before any
    /// view scaling): 90°/270° rotations swap width and height.
    var displaySize: CGSize {
        rotation % 180 == 0
            ? mediaBox.size
            : CGSize(width: mediaBox.height, height: mediaBox.width)
    }

    // MARK: - Points

    func viewPoint(fromPDFPoint point: CGPoint, in viewSize: CGSize) -> CGPoint {
        // Page-local coordinates, y up, origin at the mediaBox corner.
        let u = point.x - mediaBox.minX
        let v = point.y - mediaBox.minY
        let w = mediaBox.width
        let h = mediaBox.height

        // Rotate into displayed coordinates (y down, top-left origin),
        // still in PDF points.
        let display: CGPoint
        switch rotation {
        case 90:  display = CGPoint(x: v, y: u)
        case 180: display = CGPoint(x: w - u, y: v)
        case 270: display = CGPoint(x: h - v, y: w - u)
        default:  display = CGPoint(x: u, y: h - v)
        }

        let d = displaySize
        guard d.width > 0, d.height > 0 else { return .zero }
        return CGPoint(
            x: display.x * viewSize.width / d.width,
            y: display.y * viewSize.height / d.height
        )
    }

    func pdfPoint(fromViewPoint point: CGPoint, in viewSize: CGSize) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let d = displaySize
        let dx = point.x * d.width / viewSize.width
        let dy = point.y * d.height / viewSize.height
        let w = mediaBox.width
        let h = mediaBox.height

        let u: CGFloat
        let v: CGFloat
        switch rotation {
        case 90:  u = dy;     v = dx
        case 180: u = w - dx; v = dy
        case 270: u = w - dy; v = h - dx
        default:  u = dx;     v = h - dy
        }
        return CGPoint(x: u + mediaBox.minX, y: v + mediaBox.minY)
    }

    // MARK: - Rects

    /// Rects stay axis-aligned in both spaces (rotations are multiples of
    /// 90°), so converting two opposite corners and normalizing is exact.
    func viewRect(fromPDFRect rect: CGRect, in viewSize: CGSize) -> CGRect {
        let a = viewPoint(fromPDFPoint: CGPoint(x: rect.minX, y: rect.minY), in: viewSize)
        let b = viewPoint(fromPDFPoint: CGPoint(x: rect.maxX, y: rect.maxY), in: viewSize)
        return normalizedRect(corner: a, corner: b)
    }

    func pdfRect(fromViewRect rect: CGRect, in viewSize: CGSize) -> CGRect {
        let a = pdfPoint(fromViewPoint: CGPoint(x: rect.minX, y: rect.minY), in: viewSize)
        let b = pdfPoint(fromViewPoint: CGPoint(x: rect.maxX, y: rect.maxY), in: viewSize)
        return normalizedRect(corner: a, corner: b)
    }

    private func normalizedRect(corner a: CGPoint, corner b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }
}

extension PageCoordinateSpace {
    /// The one sanctioned bridge from PDFKit into our coordinate math.
    /// (`nonisolated` must be restated here: extensions don't inherit it
    /// from the type under MainActor-by-default isolation.)
    nonisolated init(page: PDFPage) {
        self.init(mediaBox: page.bounds(for: .mediaBox), rotation: page.rotation)
    }
}
