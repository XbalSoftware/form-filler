//
//  PatientDemographicsParser.swift
//  Form Filler
//
//  Extracts patient details from an IRIS EMR "FILE EXCERPT" PDF. The PDF
//  carries real, selectable text (PDFKit reads it directly — no OCR), so
//  parsing is deterministic: anchor on the "FILE EXCERPT" divider that
//  separates the clinic letterhead from the patient block, then pick out
//  fields by label/pattern. Position-independent by design, so it survives
//  the PDF being generated on any device.
//
//  Tuned to and only proven against one sample; every field is
//  extracted independently and defensively (a miss yields nil, never a
//  crash or a wrong guess), and the fill-mode review sheet is the safety
//  net — the clinician sees and can edit every value before it lands.
//

import Foundation
import PDFKit

nonisolated enum PatientDemographicsParser {

    /// Reads a PDF's text and parses it. nil if the file can't be read or
    /// nothing usable was found.
    static func demographics(fromPDFAt url: URL) -> PatientDemographics? {
        guard let document = PDFDocument(url: url), let text = document.string else { return nil }
        let parsed = parse(pdfText: text)
        return parsed.isEmpty ? nil : parsed
    }

    /// Pure text → demographics. Exposed for unit testing with synthetic,
    /// PHI-free sample text.
    static func parse(pdfText: String) -> PatientDemographics {
        let lines = pdfText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var result = PatientDemographics()
        parseDemographics(from: lines, into: &result)
        parseExamFindings(from: lines, into: &result)
        return result
    }

    // MARK: - Demographics

    private static func parseDemographics(from lines: [String], into result: inout PatientDemographics) {
        // The patient block sits between the "FILE EXCERPT" divider and the
        // first exam/entry line (IRIS marks entries with a "•" bullet).
        // Anchoring here skips the clinic letterhead above the divider, so
        // the clinic's own name/address/phone are never captured.
        guard let separator = lines.firstIndex(where: {
            $0.range(of: "FILE EXCERPT", options: .caseInsensitive) != nil
        }) else { return }

        let afterSeparator = lines[(separator + 1)...]
        let regionEnd = afterSeparator.firstIndex(where: { $0.contains("•") }) ?? lines.endIndex
        let region = Array(lines[(separator + 1)..<regionEnd])
        guard !region.isEmpty else { return }

        // Name: first line of the patient block, reformatted "LAST, First".
        result.fullName = region.first.flatMap(\.nilIfEmpty).map(reformattedName)

        // Address: the lines after the name, up to and including the postal
        // code — stop early if a labelled/number row appears first.
        var addressLines: [String] = []
        for line in region.dropFirst() {
            if let postal = normalizedPostalCode(line) {
                addressLines.append(postal)
                break
            }
            if matchesBirthDate(line) || firstHealthcareNumber(in: line) != nil { break }
            addressLines.append(line)
        }
        result.address = addressLines.isEmpty ? nil : addressLines.joined(separator: ", ")

        // DOB and healthcare # by pattern, anywhere in the patient region.
        let regionText = region.joined(separator: "\n")
        result.dateOfBirth = firstBirthDate(in: regionText).map(reformattedBirthDate)
        result.healthcareNumber = firstHealthcareNumber(in: regionText).map(reformattedHealthcareNumber)

        // Phone isn't present in IRIS PDFs; left nil deliberately.
    }

    // MARK: - Exam findings

    /// Exam sections all label each eye with "OD:"/"OS:" (or "O.D.:"/"O.S.:"),
    /// and the same labels recur across sections — so each finding is anchored
    /// to its own section header first, then the next OD/OS lines are read.
    private static func parseExamFindings(from lines: [String], into result: inout PatientDemographics) {
        // Refraction + VA: the user's chosen source is the most recent
        // "Subjective Refraction (BVA)" (the first such line in the report).
        if let (od, os) = odosValues(afterLineContaining: "Subjective Refraction (BVA)", in: lines) {
            let odParts = splitRefraction(od)
            let osParts = splitRefraction(os)
            result.refractionOD = odParts.refraction
            result.refractionOS = osParts.refraction
            result.visualAcuityOD = odParts.visualAcuity
            result.visualAcuityOS = osParts.visualAcuity
        }

        // Keratometry: compacted to "##.##@###/##.##" — first power, first
        // axis (zero-padded to 3 digits), second power; second axis dropped.
        if let (od, os) = odosValues(afterLineContaining: "Keratometry", in: lines) {
            result.keratometryOD = reformattedKeratometry(od)
            result.keratometryOS = reformattedKeratometry(os)
        }

        // IOP, normalized to "NN mmHg". Requiring "mmHg" on the OD/OS lines
        // guards against grabbing the neighbouring Pachymetry (µm) line when
        // IOP wasn't recorded (a partial exam shows the header but no values).
        if let (od, os) = odosValues(afterLineContaining: "Intraocular Pressure", in: lines, requiring: "mmHg") {
            result.intraocularPressureOD = cleanIOP(od)
            result.intraocularPressureOS = cleanIOP(os)
        }
    }

    /// Pulls the bare IOP number (e.g. "19") from a line like
    /// "Average: 19 mmHg (8:52)".
    private static func cleanIOP(_ raw: String) -> String? {
        capture(iopReading, in: raw) ?? raw.nilIfEmpty
    }

    /// "39.25 @163° × 40.25 @73°" → "39.25@163/40.25". First axis is padded
    /// to 3 digits; the second axis is dropped. Unrecognized input is kept.
    private static func reformattedKeratometry(_ raw: String) -> String {
        guard let match = keratometryReading.firstMatch(in: raw, range: fullRange(raw)),
              let power1 = Range(match.range(at: 1), in: raw),
              let axis1 = Range(match.range(at: 2), in: raw),
              let power2 = Range(match.range(at: 3), in: raw)
        else { return raw }
        let paddedAxis = Int(raw[axis1]).map { String(format: "%03d", $0) } ?? String(raw[axis1])
        return "\(raw[power1])@\(paddedAxis)/\(raw[power2])"
    }

    /// Finds the first line containing `anchor`, then reads the next OD and OS
    /// values within a few following lines. Returns their trimmed contents.
    /// `requiring`: if set, only OD/OS lines containing this token are
    /// considered (used by IOP to skip non-mmHg rows).
    private static func odosValues(afterLineContaining anchor: String, in lines: [String], requiring token: String? = nil) -> (od: String, os: String)? {
        guard let start = lines.firstIndex(where: { $0.contains(anchor) }) else { return nil }
        var od: String?
        var os: String?
        for line in lines[(start + 1)...].prefix(8) {
            if let token, !line.contains(token) { continue }
            if od == nil, let value = value(after: ["OD:", "O.D.:"], in: line) { od = value; continue }
            if os == nil, let value = value(after: ["OS:", "O.S.:"], in: line) { os = value }
            if od != nil, os != nil { break }
        }
        guard let od, let os else { return nil }
        return (od, os)
    }

    /// If `line` starts with one of `labels`, returns the trimmed remainder.
    private static func value(after labels: [String], in line: String) -> String? {
        for label in labels where line.hasPrefix(label) {
            return String(line.dropFirst(label.count)).trimmingCharacters(in: .whitespaces).nilIfEmpty
        }
        return nil
    }

    /// Splits a refraction line like "-2.00 -1.00 × 130° ADD +1.25 20 / 15"
    /// into the sphere/cyl/axis part (ADD dropped, per user decision) and the
    /// bundled Snellen VA ("20/15").
    private static func splitRefraction(_ raw: String) -> (refraction: String?, visualAcuity: String?) {
        let va = capture(visualAcuity, in: raw).map { $0.replacingOccurrences(of: " ", with: "") }

        var refractionPart = raw
        if let addRange = raw.range(of: "ADD", options: .caseInsensitive) {
            refractionPart = String(raw[..<addRange.lowerBound])
        } else if let vaText = capture(visualAcuity, in: raw), let vaRange = raw.range(of: vaText) {
            refractionPart = String(raw[..<vaRange.lowerBound])
        }
        return (refractionPart.trimmingCharacters(in: .whitespaces).nilIfEmpty, va)
    }

    // MARK: - Name

    /// Surname prefixes that appear as their own word and belong WITH the
    /// surname (e.g. "van der Berg"). Matched case-insensitively.
    private static let surnameParticles: Set<String> = [
        "von", "van", "der", "den", "de", "del", "della", "di", "da", "dos",
        "das", "du", "la", "le", "lo", "los", "las", "ter", "ten", "saint",
        "st", "st.", "af", "av", "bin", "ibn", "al", "el", "abu",
    ]

    /// Reformats "First Last" → "LAST, First" (surname upper-cased). The
    /// surname starts at the first particle after the given name, or (no
    /// particle) at the last word — so middle names stay with the given
    /// name. One-word names are returned unchanged. Genuinely ambiguous
    /// splits are left for the clinician to fix in the review sheet.
    private static func reformattedName(_ fullName: String) -> String {
        let tokens = fullName.split(separator: " ").map(String.init)
        guard tokens.count >= 2 else { return fullName }

        let surnameStart = tokens.indices.dropFirst().first {
            surnameParticles.contains(tokens[$0].lowercased())
        } ?? (tokens.count - 1)

        let given = tokens[..<surnameStart].joined(separator: " ")
        let surname = tokens[surnameStart...].joined(separator: " ").uppercased()
        return given.isEmpty ? surname : "\(surname), \(given)"
    }

    // MARK: - Field patterns

    private static let postalCode = regex(#"^[A-Za-z]\d[A-Za-z]\s?\d[A-Za-z]\d$"#)
    private static let birthDate = regex(#"Birth Date:\s*(\d{4}-\d{2}-\d{2})"#, caseInsensitive: true)
    // Alberta PHN: three groups of three digits (e.g. "999 999 999").
    private static let healthcareNumber = regex(#"\b(\d{3}\s\d{3}\s\d{3})\b"#)
    // Snellen VA bundled in refraction lines, e.g. "20 / 15" or "20 / 15 -1".
    private static let visualAcuity = regex(#"(\d{1,3}\s*/\s*\d{1,3}(?:\s*[+-]\s*\d+)?)"#)
    // IOP reading: captures just the number (e.g. "19") but requires a
    // following "mmHg" so only a real pressure value matches.
    private static let iopReading = regex(#"(\d{1,2}(?:\.\d)?)\s*mmHg"#)
    // Keratometry "power1 @axis1 × power2 @axis2" — groups: power1, axis1, power2.
    private static let keratometryReading = regex(#"([\d.]+)\s*@\s*(\d+)°?\s*[×x]\s*([\d.]+)"#)

    private static func matchesBirthDate(_ s: String) -> Bool {
        birthDate.firstMatch(in: s, range: fullRange(s)) != nil
    }

    private static func firstBirthDate(in s: String) -> String? {
        capture(birthDate, in: s)
    }

    /// IRIS prints DOB as ISO "yyyy-MM-dd"; referral forms are clearer with
    /// an unambiguous "DD MON YYYY" (month in caps, e.g. "01 JAN 1990"). On
    /// any parse failure the original string is kept unchanged.
    private static func reformattedBirthDate(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.isLenient = false     // reject impossible dates (e.g. month 13)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: iso) else { return iso }

        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.timeZone = TimeZone(identifier: "UTC")
        output.dateFormat = "dd MMM yyyy"
        return output.string(from: date).uppercased()
    }

    private static func firstHealthcareNumber(in s: String) -> String? {
        capture(healthcareNumber, in: s)
    }

    /// IRIS prints the Alberta PHN as "### ### ###"; forms expect the
    /// "#####-####" grouping (e.g. "999 999 999" → "99999-9999"). Anything
    /// that isn't exactly 9 digits is kept verbatim.
    private static func reformattedHealthcareNumber(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard digits.count == 9 else { return raw }
        let split = digits.index(digits.startIndex, offsetBy: 5)
        return "\(digits[..<split])-\(digits[split...])"
    }

    /// Returns the postal code normalized to "A1A 1A1", or nil if the line
    /// isn't a postal code.
    private static func normalizedPostalCode(_ line: String) -> String? {
        guard postalCode.firstMatch(in: line, range: fullRange(line)) != nil else { return nil }
        let compact = line.replacingOccurrences(of: " ", with: "").uppercased()
        guard compact.count == 6 else { return line.uppercased() }
        let mid = compact.index(compact.startIndex, offsetBy: 3)
        return "\(compact[..<mid]) \(compact[mid...])"
    }

    // MARK: - Regex helpers

    private static func regex(_ pattern: String, caseInsensitive: Bool = false) -> NSRegularExpression {
        // Patterns are compile-time constants; a failure here is a programmer
        // error, so trapping is appropriate.
        try! NSRegularExpression(
            pattern: pattern,
            options: caseInsensitive ? [.caseInsensitive] : []
        )
    }

    private static func fullRange(_ s: String) -> NSRange {
        NSRange(s.startIndex..., in: s)
    }

    private static func capture(_ re: NSRegularExpression, in s: String) -> String? {
        guard let match = re.firstMatch(in: s, range: fullRange(s)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: s)
        else { return nil }
        return String(s[range]).nilIfEmpty
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
