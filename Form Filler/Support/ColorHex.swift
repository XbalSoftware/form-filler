//
//  ColorHex.swift
//  Form Filler
//
//  FieldStyle stores colors as "#RRGGBB" strings (Codable-friendly,
//  viewer-independent). These helpers are the single conversion point;
//  the export renderer will use `uiColor(from:)` too.
//

import SwiftUI
import UIKit

nonisolated enum ColorHex {
    static func uiColor(from hex: String) -> UIColor? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        return UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    static func color(from hex: String) -> Color? {
        uiColor(from: hex).map(Color.init)
    }

    static func hex(from color: Color) -> String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        func component(_ value: CGFloat) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", component(red), component(green), component(blue))
    }
}
