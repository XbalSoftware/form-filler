//
//  FieldDefinition.swift
//  Form Filler
//

import Foundation
import CoreGraphics

/// A fillable field on a template page.
///
/// `rect` is in PDF page point space — bottom-left origin, relative to the
/// page's mediaBox, un-rotated (CLAUDE.md invariant #2). Never store screen
/// or view coordinates here.
nonisolated struct FieldDefinition: Codable, Identifiable, Equatable, Sendable {
    /// Default size for a newly placed single-line field.
    static let defaultSize = CGSize(width: 180, height: 24)

    let id: UUID
    var name: String
    var type: FieldType
    var pageIndex: Int
    var rect: CGRect
    var style: FieldStyle
    var sortOrder: Int
    /// Date fields only: DateFormatter format string. nil = app default.
    var dateFormat: String?
    /// Static-text fields only: the fixed text stamped on every fill.
    var staticText: String?

    init(
        id: UUID = UUID(),
        name: String,
        type: FieldType = .singleLineText,
        pageIndex: Int = 0,
        rect: CGRect,
        style: FieldStyle = .default,
        sortOrder: Int = 0,
        dateFormat: String? = nil,
        staticText: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.pageIndex = pageIndex
        self.rect = rect
        self.style = style
        self.sortOrder = sortOrder
        self.dateFormat = dateFormat
        self.staticText = staticText
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Field"
        type = try container.decodeIfPresent(FieldType.self, forKey: .type) ?? .singleLineText
        pageIndex = try container.decodeIfPresent(Int.self, forKey: .pageIndex) ?? 0
        rect = try container.decodeIfPresent(CGRect.self, forKey: .rect)
            ?? CGRect(origin: .zero, size: Self.defaultSize)
        style = try container.decodeIfPresent(FieldStyle.self, forKey: .style) ?? .default
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        dateFormat = try container.decodeIfPresent(String.self, forKey: .dateFormat)
        staticText = try container.decodeIfPresent(String.self, forKey: .staticText)
    }
}
