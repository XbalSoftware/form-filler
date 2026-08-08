//
//  PhoneFormatting.swift
//  Form Filler
//

import Foundation

nonisolated enum PhoneFormatting {
    /// Formats a number as "(###) ###-####" when, after removing whitespace
    /// and phone punctuation ( ( ) - . ), exactly ten digits remain. Any
    /// other content — a partial entry, 11+ digits, letters, or an
    /// extension — is returned unchanged, so it never fights real input.
    static func autoFormat(_ raw: String) -> String {
        let separators: Set<Character> = ["(", ")", "-", "."]
        let stripped = raw.filter { !$0.isWhitespace && !separators.contains($0) }
        guard stripped.count == 10, stripped.allSatisfy(\.isNumber) else { return raw }
        let area = stripped.prefix(3)
        let middle = stripped.dropFirst(3).prefix(3)
        let last = stripped.suffix(4)
        return "(\(area)) \(middle)-\(last)"
    }
}
