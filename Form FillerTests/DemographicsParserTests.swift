//
//  DemographicsParserTests.swift
//  Form FillerTests
//
//  Parsing of IRIS "FILE EXCERPT" demographics text. All sample text here
//  is fabricated — invented names, addresses, and numbers — never real
//  patient data.
//

import Foundation
import Testing
@testable import Form_Filler

struct DemographicsParserTests {

    /// A representative IRIS layout: clinic letterhead, the FILE EXCERPT
    /// divider, then the patient block, then the first exam entry.
    private let sample = """
    IRIS Test Clinic
    100 Example St, Suite 5
    Testville, AB
    T1T 1T1
    403.555.0100
    FILE EXCERPT
    Jane Q. Sample
    55 Imaginary Ave NW
    Testville, AB
    T2T2T2
    Birth Date: 1975-12-25
    123 456 789
    January 1, 2020 • Partial Exam
    signed • Dr Example
    """

    @Test func extractsAllPatientFields() {
        let demo = PatientDemographicsParser.parse(pdfText: sample)
        #expect(demo.fullName == "SAMPLE, Jane Q.")     // reformatted from Jane Q. Sample
        #expect(demo.address == "55 Imaginary Ave NW, Testville, AB, T2T 2T2")
        #expect(demo.dateOfBirth == "25 DEC 1975")     // reformatted from 1975-12-25
        #expect(demo.healthcareNumber == "12345-6789")  // reformatted from 123 456 789
    }

    @Test func neverCapturesTheClinicLetterhead() {
        let demo = PatientDemographicsParser.parse(pdfText: sample)
        // Clinic name/address/phone sit ABOVE the FILE EXCERPT divider.
        #expect(demo.fullName != "IRIS Test Clinic")
        #expect(demo.address?.contains("Example St") == false)
        #expect(demo.phone == nil)                       // clinic phone not grabbed
        #expect(demo.address?.contains("T1T 1T1") == false)
    }

    @Test func normalizesPostalCodeSpacing() {
        // "T2T2T2" (no internal space) → "T2T 2T2".
        let demo = PatientDemographicsParser.parse(pdfText: sample)
        #expect(demo.address?.hasSuffix("T2T 2T2") == true)
    }

    @Test func handlesUnitNumberAndLongerAddress() {
        let text = """
        FILE EXCERPT
        Mary-Anne Van Der Berg
        Unit 12, 4400 Some Very Long Street Name SW
        Calgary, AB
        T3A 0B1
        Birth Date: 1990-02-28
        987 654 321
        March 3, 2021 • Exam
        """
        let demo = PatientDemographicsParser.parse(pdfText: text)
        #expect(demo.fullName == "VAN DER BERG, Mary-Anne")  // particle surname
        #expect(demo.address == "Unit 12, 4400 Some Very Long Street Name SW, Calgary, AB, T3A 0B1")
        #expect(demo.dateOfBirth == "28 FEB 1990")     // reformatted from 1990-02-28
        #expect(demo.healthcareNumber == "98765-4321")  // reformatted from 987 654 321
    }

    @Test func reformatsBirthDateToDayMonthYear() {
        let text = """
        FILE EXCERPT
        Jane Q. Sample
        Birth Date: 2001-01-09
        January 1, 2020 • Exam
        """
        // Zero-padded day, month in caps.
        #expect(PatientDemographicsParser.parse(pdfText: text).dateOfBirth == "09 JAN 2001")
    }

    @Test func keepsUnparseableDateUnchanged() {
        let text = """
        FILE EXCERPT
        Jane Q. Sample
        Birth Date: 2020-13-45
        January 1, 2020 • Exam
        """
        // Impossible date: kept verbatim rather than silently mangled.
        #expect(PatientDemographicsParser.parse(pdfText: text).dateOfBirth == "2020-13-45")
    }

    /// Exam sections in IRIS order: autorefractor and keratometry both use
    /// OD:/OS: labels BEFORE the subjective refraction, so this also proves
    /// section-anchoring picks the right one.
    private let examSample = """
    FILE EXCERPT
    Jane Q. Sample
    January 1, 2020 • Partial Exam
    AutoRefractors
    Autorefractor
    OD: -2.25 -0.75 × 136°
    OS: -2.00 -0.50 × 68°
    PD: 69.0
    Keratometries
    Keratometry
    OD: 39.25 @163° × 40.25 @73°
    OS: 39.25 @17° × 39.75 @107°
    Subjective Refractions
    Subjective Refraction (BVA) Modified by SR (Jan 1, 2020)
    OD: -2.00 -1.00 × 130° ADD +1.25 20 / 15
    OS: -2.25 -0.50 × 70° ADD +1.25 20 / 15 -1
    OU: 0.37M
    """

    @Test func extractsRefractionAndVAFromSubjectiveRefraction() {
        let demo = PatientDemographicsParser.parse(pdfText: examSample)
        // Sphere/cyl/axis only — ADD dropped (user decision); NOT the -2.25
        // autorefractor value that appears first.
        #expect(demo.refractionOD == "-2.00 -1.00 × 130°")
        #expect(demo.refractionOS == "-2.25 -0.50 × 70°")
        #expect(demo.visualAcuityOD == "20/15")
        #expect(demo.visualAcuityOS == "20/15-1")
    }

    @Test func extractsKeratometry() {
        let demo = PatientDemographicsParser.parse(pdfText: examSample)
        // Compacted: first power @ padded first axis / second power.
        #expect(demo.keratometryOD == "39.25@163/40.25")
        #expect(demo.keratometryOS == "39.25@017/39.75")   // axis 17 → 017
    }

    @Test func extractsIntraocularPressure() {
        let text = """
        FILE EXCERPT
        Jane Q. Sample
        January 1, 2020 • Complete Exam
        Intraocular Pressure
        Measurements
        NCT
        OD: Average: 19 mmHg (8:52)
        OS: Average: 22 mmHg (8:52)
        Pachymetry
        """
        let demo = PatientDemographicsParser.parse(pdfText: text)
        // Bare number — "Average:" label, "mmHg", and timestamp dropped.
        #expect(demo.intraocularPressureOD == "19")
        #expect(demo.intraocularPressureOS == "22")
    }

    @Test func ignoresPachymetryLineWhenIOPNotRecorded() {
        // Partial exam: IOP header but no readings; the nearby Pachymetry
        // OS line (µm) must NOT be captured as IOP.
        let text = """
        FILE EXCERPT
        Jane Q. Sample
        January 1, 2020 • Partial Exam
        Intraocular Pressure
        Measurements
        Pachymetry
        Measurements
        OS: Pachymetry: 592 µm • Technique: NC
        """
        let demo = PatientDemographicsParser.parse(pdfText: text)
        #expect(demo.intraocularPressureOD == nil)
        #expect(demo.intraocularPressureOS == nil)
    }

    @Test func examFieldsMapThroughValueForType() {
        let demo = PatientDemographicsParser.parse(pdfText: examSample)
        #expect(demo.value(for: .patientRefractionOD) == "-2.00 -1.00 × 130°")
        #expect(demo.value(for: .patientVisualAcuityOS) == "20/15-1")
        #expect(demo.value(for: .patientKeratometryOD) == "39.25@163/40.25")
    }

    @Test func missingDividerYieldsEmpty() {
        let text = """
        Some unrelated PDF
        Jane Q. Sample
        Birth Date: 1975-12-25
        """
        let demo = PatientDemographicsParser.parse(pdfText: text)
        #expect(demo.isEmpty)
    }

    @Test func missingFieldsStayNilWithoutCrashing() {
        // Name only, no address / DOB / healthcare number.
        let text = """
        FILE EXCERPT
        Jane Q. Sample
        January 1, 2020 • Exam
        """
        let demo = PatientDemographicsParser.parse(pdfText: text)
        #expect(demo.fullName == "SAMPLE, Jane Q.")
        #expect(demo.address == nil)
        #expect(demo.dateOfBirth == nil)
        #expect(demo.healthcareNumber == nil)
    }

    @Test func reformatsNameAsLastCommaFirst() {
        func name(_ full: String) -> String? {
            PatientDemographicsParser.parse(pdfText: "FILE EXCERPT\n\(full)\nJan 1, 2020 • Exam").fullName
        }
        #expect(name("Alex Sample") == "SAMPLE, Alex")
        #expect(name("John James Sample") == "SAMPLE, John James")      // middle name kept
        #expect(name("Alex Von Sample") == "VON SAMPLE, Alex")          // two-word surname
        #expect(name("Juan de la Sample") == "DE LA SAMPLE, Juan")      // multi-particle
        #expect(name("Sample") == "Sample")                             // single word unchanged
    }

    @Test func valueForTypeMapsToPatientFields() {
        let demo = PatientDemographics(
            fullName: "Jane Q. Sample",
            address: "1 A St",
            dateOfBirth: "1975-12-25",
            healthcareNumber: "123 456 789",
            phone: nil
        )
        #expect(demo.value(for: .patientName) == "Jane Q. Sample")
        #expect(demo.value(for: .patientDateOfBirth) == "1975-12-25")
        #expect(demo.value(for: .patientHealthcareNumber) == "123 456 789")
        #expect(demo.value(for: .patientPhone) == nil)
        #expect(demo.value(for: .singleLineText) == nil)   // non-patient type
    }

    @Test func limitedDropsTypesTheTemplateLacks() {
        let demo = PatientDemographics(
            fullName: "Jane Q. Sample",
            address: "1 A St",
            dateOfBirth: "1975-12-25",
            healthcareNumber: "123 456 789",
            phone: "403 555 0000"
        )
        let limited = demo.limited(to: [.patientName, .patientDateOfBirth])
        #expect(limited.fullName == "Jane Q. Sample")
        #expect(limited.dateOfBirth == "1975-12-25")
        #expect(limited.address == nil)
        #expect(limited.healthcareNumber == nil)
        #expect(limited.phone == nil)
    }
}
