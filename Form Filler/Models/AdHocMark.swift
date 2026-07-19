//
//  AdHocMark.swift
//  Form Filler
//
//  A one-off mark placed during a fill session, without a template field:
//  a checkmark stamped on a form's own printed checkbox, or a circle drawn
//  around an item. Session data like FieldValue — but Codable, because
//  marks travel inside FillSessionPayload (the draft vault and the payload
//  embedded in exported PDFs).
//
//  `rect` is in PDF page point space (invariant #2), same as field rects.
//

import Foundation
import CoreGraphics

nonisolated struct AdHocMark: Codable, Identifiable, Equatable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable {
        case check
        case circle
        /// A one-off typed comment box (rare notes that don't merit a
        /// template field). Its content lives in `text`.
        case comment

        /// Unknown raw values (newer schema) fall back to check.
        init(from decoder: any Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .check
        }
    }

    static let defaultCommentFontSize: CGFloat = 12

    /// Default footprint of a tapped-in checkmark, PDF points.
    static let defaultCheckSize = CGSize(width: 16, height: 16)
    /// Default footprint of a tapped-in (not dragged) circle, PDF points.
    static let defaultCircleSize = CGSize(width: 56, height: 28)
    /// Default footprint of a tapped-in (not dragged) comment box, PDF points.
    static let defaultCommentSize = CGSize(width: 200, height: 40)

    let id: UUID
    var kind: Kind
    var pageIndex: Int
    var rect: CGRect
    /// Comment kind only: the typed note.
    var text: String?
    // Comment styling (nil = defaults: 12pt, regular, no border, transparent).
    var fontSize: CGFloat?
    var isBold: Bool?
    var showsBorder: Bool?
    var whiteBackground: Bool?

    init(
        id: UUID = UUID(),
        kind: Kind,
        pageIndex: Int,
        rect: CGRect,
        text: String? = nil,
        fontSize: CGFloat? = nil,
        isBold: Bool? = nil,
        showsBorder: Bool? = nil,
        whiteBackground: Bool? = nil
    ) {
        self.id = id
        self.kind = kind
        self.pageIndex = pageIndex
        self.rect = rect
        self.text = text
        self.fontSize = fontSize
        self.isBold = isBold
        self.showsBorder = showsBorder
        self.whiteBackground = whiteBackground
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .check
        pageIndex = try container.decodeIfPresent(Int.self, forKey: .pageIndex) ?? 0
        rect = try container.decodeIfPresent(CGRect.self, forKey: .rect)
            ?? CGRect(origin: .zero, size: Self.defaultCheckSize)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize)
        isBold = try container.decodeIfPresent(Bool.self, forKey: .isBold)
        showsBorder = try container.decodeIfPresent(Bool.self, forKey: .showsBorder)
        whiteBackground = try container.decodeIfPresent(Bool.self, forKey: .whiteBackground)
    }

    // Resolved comment style, shared by the preview and the export.
    var resolvedFontSize: CGFloat { fontSize ?? Self.defaultCommentFontSize }
    var resolvedFontName: String { (isBold ?? false) ? "Helvetica-Bold" : "Helvetica" }
    var hasBorder: Bool { showsBorder ?? false }
    var hasWhiteBackground: Bool { whiteBackground ?? false }
}
