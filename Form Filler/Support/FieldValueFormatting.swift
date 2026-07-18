//
//  FieldValueFormatting.swift
//  Form Filler
//
//  Resolves a field + its (transient) value into the string that gets
//  drawn — shared by the fill-preview overlays and the PDF export so the
//  two can never disagree.
//

import Foundation

nonisolated enum FieldValueFormatting {
    static let defaultDateFormat = "dd/MM/yyyy"

    /// The text to draw for a field, or nil if nothing should be drawn.
    static func displayText(for field: FieldDefinition, value: FieldValue?) -> String? {
        switch field.type {
        case .staticText:
            guard let text = field.staticText, !text.isEmpty else { return nil }
            return text
        case .checkbox:
            if case .checkbox(true) = value { return "X" }
            return nil
        case .date:
            guard case .date(let date) = value else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = field.dateFormat ?? defaultDateFormat
            return formatter.string(from: date)
        case .singleLineText, .multiLineText, .patientName:
            guard case .text(let string) = value, !string.isEmpty else { return nil }
            return string
        }
    }
}
