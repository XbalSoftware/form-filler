//
//  MarkGeometry.swift
//  Form Filler
//
//  The stroke paths for ad-hoc marks, shared by the fill-preview overlay
//  (SwiftUI Path) and the PDF export (CGContext) so what you see is what
//  prints. Coordinates are whatever display-space rect the caller passes.
//

import CoreGraphics

nonisolated enum MarkGeometry {
    static func lineWidth(for rect: CGRect) -> CGFloat {
        max(1.4, min(rect.width, rect.height) * 0.1)
    }

    static func path(for kind: AdHocMark.Kind, in rect: CGRect) -> CGPath {
        switch kind {
        case .check: checkPath(in: rect)
        case .circle: CGPath(ellipseIn: rect, transform: nil)
        case .comment: CGMutablePath()   // comments are text, not strokes
        }
    }

    /// A tick: short down-stroke to the notch, long up-stroke out.
    /// (y-down display coordinates.)
    private static func checkPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.82))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.88, y: rect.minY + rect.height * 0.16))
        return path
    }
}
