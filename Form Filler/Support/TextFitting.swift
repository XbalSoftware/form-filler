//
//  TextFitting.swift
//  Form Filler
//
//  Auto-shrink (CLAUDE.md): text overflowing its rect steps the font size
//  down to fit rather than clipping. This is THE shared fit function —
//  the fill-preview overlays and the PDF export must both use it so what
//  you see is exactly what exports. Measurements are in PDF points.
//

import UIKit

nonisolated enum TextFitting {
    /// Largest font size ≤ `preferredSize` (stepping down by 0.5) at which
    /// `text` fits inside `boxSize`. Single-line text must fit without
    /// wrapping; multiline text wraps at the box width and must fit the
    /// height. Never returns less than `minimumSize`.
    static func fittedFontSize(
        for text: String,
        fontName: String,
        preferredSize: CGFloat,
        in boxSize: CGSize,
        multiline: Bool,
        minimumSize: CGFloat = 4
    ) -> CGFloat {
        guard !text.isEmpty, boxSize.width > 0, boxSize.height > 0 else { return preferredSize }
        var size = preferredSize
        while size > minimumSize {
            if fits(text, fontName: fontName, fontSize: size, in: boxSize, multiline: multiline) {
                return size
            }
            size -= 0.5
        }
        return minimumSize
    }

    private static func fits(
        _ text: String,
        fontName: String,
        fontSize: CGFloat,
        in boxSize: CGSize,
        multiline: Bool
    ) -> Bool {
        let font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        let unbounded = CGFloat.greatestFiniteMagnitude
        let constraint = multiline
            ? CGSize(width: boxSize.width, height: unbounded)
            : CGSize(width: unbounded, height: unbounded)
        let bounding = (text as NSString).boundingRect(
            with: constraint,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return multiline
            ? bounding.height <= boxSize.height
            : bounding.width <= boxSize.width && bounding.height <= boxSize.height
    }
}
