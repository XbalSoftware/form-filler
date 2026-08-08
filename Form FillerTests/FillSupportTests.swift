//
//  FillSupportTests.swift
//  Form FillerTests
//
//  Shared fill/export logic: value → drawn-string resolution and
//  auto-shrink text fitting.
//

import CoreGraphics
import Foundation
import Testing
@testable import Form_Filler

private func makeField(
    type: FieldType,
    dateFormat: String? = nil,
    staticText: String? = nil
) -> FieldDefinition {
    FieldDefinition(
        name: "Test",
        type: type,
        rect: CGRect(x: 0, y: 0, width: 180, height: 24),
        dateFormat: dateFormat,
        staticText: staticText
    )
}

struct FieldValueFormattingTests {

    @Test func textPassesThrough() {
        let field = makeField(type: .singleLineText)
        #expect(FieldValueFormatting.displayText(for: field, value: .text("Jane Doe")) == "Jane Doe")
        #expect(FieldValueFormatting.displayText(for: field, value: .text("")) == nil)
        #expect(FieldValueFormatting.displayText(for: field, value: nil) == nil)
    }

    @Test func patientFieldTextPassesThrough() {
        // Patient detail fields hold plain .text, drawn like any text.
        for type in [FieldType.patientDateOfBirth, .patientHealthcareNumber, .patientPhone, .patientAddress] {
            let field = makeField(type: type)
            #expect(FieldValueFormatting.displayText(for: field, value: .text("value")) == "value")
            #expect(FieldValueFormatting.displayText(for: field, value: nil) == nil)
        }
    }

    @Test func staticTextIgnoresValueAndUsesStoredText() {
        let field = makeField(type: .staticText, staticText: "Anytown Eye Clinic")
        #expect(FieldValueFormatting.displayText(for: field, value: nil) == "Anytown Eye Clinic")
        #expect(FieldValueFormatting.displayText(for: field, value: .text("ignored")) == "Anytown Eye Clinic")
        let empty = makeField(type: .staticText, staticText: nil)
        #expect(FieldValueFormatting.displayText(for: empty, value: nil) == nil)
    }

    @Test func referralDateDefaultsToTodayButHonorsOverride() {
        let field = makeField(type: .referralDate)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"
        let today = formatter.string(from: Date()).uppercased()
        // No value → today; a typed override wins.
        #expect(FieldValueFormatting.displayText(for: field, value: nil) == today)
        #expect(FieldValueFormatting.displayText(for: field, value: .text("01 JAN 2020")) == "01 JAN 2020")
    }
}

struct PhoneFormattingTests {
    @Test func formatsTenDigitsAfterStrippingPunctuation() {
        #expect(PhoneFormatting.autoFormat("4035550123") == "(403) 555-0123")
        #expect(PhoneFormatting.autoFormat("  4035550123 ") == "(403) 555-0123")   // whitespace
        #expect(PhoneFormatting.autoFormat("403 555 0123") == "(403) 555-0123")    // spaces
        #expect(PhoneFormatting.autoFormat("403-555-0123") == "(403) 555-0123")    // dashes
        #expect(PhoneFormatting.autoFormat("403.555.0123") == "(403) 555-0123")    // dots
        #expect(PhoneFormatting.autoFormat("(403) 555-0123") == "(403) 555-0123")  // idempotent
    }

    @Test func leavesNonPhoneInputUnchanged() {
        #expect(PhoneFormatting.autoFormat("403555") == "403555")                  // too few
        #expect(PhoneFormatting.autoFormat("14035550123") == "14035550123")        // 11 digits
        #expect(PhoneFormatting.autoFormat("4035550123x12") == "4035550123x12")    // extension
        #expect(PhoneFormatting.autoFormat("call 4035550123") == "call 4035550123")// letters
        #expect(PhoneFormatting.autoFormat("") == "")
    }
}

struct TextFittingTests {
    private let box = CGSize(width: 180, height: 24)

    @Test func shortTextKeepsPreferredSize() {
        let size = TextFitting.fittedFontSize(
            for: "Jane", fontName: "Helvetica", preferredSize: 12, in: box, multiline: false
        )
        #expect(size == 12)
    }

    @Test func longTextShrinks() {
        let longText = "A very long patient name that cannot possibly fit at full size"
        let size = TextFitting.fittedFontSize(
            for: longText, fontName: "Helvetica", preferredSize: 12, in: box, multiline: false
        )
        #expect(size < 12)
        #expect(size >= 4)
    }

    @Test func neverShrinksBelowMinimum() {
        let absurd = String(repeating: "WWWWW ", count: 200)
        let size = TextFitting.fittedFontSize(
            for: absurd, fontName: "Helvetica", preferredSize: 12,
            in: CGSize(width: 30, height: 8), multiline: false
        )
        #expect(size == 4)
    }

    @Test func multilineFitsByWrappedHeight() {
        let paragraph = "Reason for referral: gradual decrease in visual acuity over six months, worse in the left eye."
        let tallBox = CGSize(width: 200, height: 300)
        let size = TextFitting.fittedFontSize(
            for: paragraph, fontName: "Helvetica", preferredSize: 12, in: tallBox, multiline: true
        )
        #expect(size == 12)   // plenty of height once wrapped

        let shortBox = CGSize(width: 200, height: 20)
        let shrunk = TextFitting.fittedFontSize(
            for: paragraph, fontName: "Helvetica", preferredSize: 12, in: shortBox, multiline: true
        )
        #expect(shrunk < 12)
    }

    @Test func emptyTextKeepsPreferredSize() {
        let size = TextFitting.fittedFontSize(
            for: "", fontName: "Helvetica", preferredSize: 12, in: box, multiline: false
        )
        #expect(size == 12)
    }
}
