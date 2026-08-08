//
//  FieldStyle.swift
//  Form Filler
//

import Foundation
import CoreGraphics

nonisolated enum TextAlignmentOption: String, Codable, CaseIterable, Sendable {
    case leading
    case center
    case trailing

    /// Unknown raw values fall back to leading rather than failing the decode.
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TextAlignmentOption(rawValue: raw) ?? .leading
    }
}

nonisolated struct FieldStyle: Codable, Equatable, Sendable {
    var fontName: String
    var fontSize: CGFloat
    var alignment: TextAlignmentOption
    var colorHex: String

    static let `default` = FieldStyle(
        fontName: "Helvetica",
        fontSize: 12,
        alignment: .leading,
        colorHex: "#000000"
    )

    init(fontName: String, fontSize: CGFloat, alignment: TextAlignmentOption, colorHex: String) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.alignment = alignment
        self.colorHex = colorHex
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = FieldStyle.default
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? fallback.fontName
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? fallback.fontSize
        alignment = try container.decodeIfPresent(TextAlignmentOption.self, forKey: .alignment) ?? fallback.alignment
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? fallback.colorHex
    }
}
