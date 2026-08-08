//
//  CoordinateConversionTests.swift
//  Form FillerTests
//
//  Mandatory before Stage 4 (project_state.md): the editor and export both
//  stand on this math. The mediaBox deliberately has a non-zero origin
//  (20, 30) — common in scanned PDFs — to catch origin-assumption bugs.
//

import CoreGraphics
import Foundation
import Testing
@testable import Form_Filler

private let box = CGRect(x: 20, y: 30, width: 600, height: 800)
private let allRotations = [0, 90, 180, 270]

private func space(_ rotation: Int) -> PageCoordinateSpace {
    PageCoordinateSpace(mediaBox: box, rotation: rotation)
}

private func approx(_ a: CGPoint, _ b: CGPoint, tolerance: CGFloat = 1e-9) -> Bool {
    abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance
}

private func approx(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 1e-9) -> Bool {
    approx(a.origin, b.origin, tolerance: tolerance)
        && abs(a.width - b.width) <= tolerance
        && abs(a.height - b.height) <= tolerance
}

struct CoordinateConversionTests {

    @Test func rotationIsNormalized() {
        #expect(space(0).rotation == 0)
        #expect(space(360).rotation == 0)
        #expect(space(-90).rotation == 270)
        #expect(space(450).rotation == 90)
        #expect(space(-180).rotation == 180)
    }

    @Test func displaySizeSwapsForQuarterTurns() {
        #expect(space(0).displaySize == CGSize(width: 600, height: 800))
        #expect(space(180).displaySize == CGSize(width: 600, height: 800))
        #expect(space(90).displaySize == CGSize(width: 800, height: 600))
        #expect(space(270).displaySize == CGSize(width: 800, height: 600))
    }

    /// The mediaBox's bottom-left corner (PDF origin) must land on the
    /// correct *displayed* corner for each rotation: rotating the sheet
    /// clockwise carries bottom-left → top-left (90°), top-right (180°),
    /// bottom-right (270°).
    @Test func pdfOriginLandsOnCorrectDisplayedCorner() {
        let origin = CGPoint(x: box.minX, y: box.minY)

        let s0 = space(0)
        #expect(approx(s0.viewPoint(fromPDFPoint: origin, in: s0.displaySize), CGPoint(x: 0, y: 800)))
        let s90 = space(90)
        #expect(approx(s90.viewPoint(fromPDFPoint: origin, in: s90.displaySize), CGPoint(x: 0, y: 0)))
        let s180 = space(180)
        #expect(approx(s180.viewPoint(fromPDFPoint: origin, in: s180.displaySize), CGPoint(x: 600, y: 0)))
        let s270 = space(270)
        #expect(approx(s270.viewPoint(fromPDFPoint: origin, in: s270.displaySize), CGPoint(x: 800, y: 600)))
    }

    @Test func pdfTopLeftLandsOnCorrectDisplayedCorner() {
        let topLeft = CGPoint(x: box.minX, y: box.maxY)   // (20, 830)

        let s0 = space(0)
        #expect(approx(s0.viewPoint(fromPDFPoint: topLeft, in: s0.displaySize), CGPoint(x: 0, y: 0)))
        let s90 = space(90)
        #expect(approx(s90.viewPoint(fromPDFPoint: topLeft, in: s90.displaySize), CGPoint(x: 800, y: 0)))
        let s180 = space(180)
        #expect(approx(s180.viewPoint(fromPDFPoint: topLeft, in: s180.displaySize), CGPoint(x: 600, y: 800)))
        let s270 = space(270)
        #expect(approx(s270.viewPoint(fromPDFPoint: topLeft, in: s270.displaySize), CGPoint(x: 0, y: 600)))
    }

    @Test func viewScalingIsProportional() {
        let s = space(0)
        let half = CGSize(width: 300, height: 400)
        let point = CGPoint(x: 320, y: 430)      // mediaBox-relative (300, 400) = center
        #expect(approx(s.viewPoint(fromPDFPoint: point, in: half), CGPoint(x: 150, y: 200)))
    }

    @Test func knownRectAtRotationZero() {
        let s = space(0)
        // Field rect in PDF space; mediaBox-relative u: 100–280, v: 600–624.
        let pdfRect = CGRect(x: 120, y: 630, width: 180, height: 24)
        let expected = CGRect(x: 100, y: 176, width: 180, height: 24)
        #expect(approx(s.viewRect(fromPDFRect: pdfRect, in: s.displaySize), expected))
    }

    @Test func knownRectAtRotation90SwapsWidthAndHeight() {
        let s = space(90)
        let pdfRect = CGRect(x: 120, y: 630, width: 180, height: 24)
        // dx = v (600…624), dy = u (100…280) → a tall thin box.
        let expected = CGRect(x: 600, y: 100, width: 24, height: 180)
        #expect(approx(s.viewRect(fromPDFRect: pdfRect, in: s.displaySize), expected))
    }

    @Test func pointRoundTripsAtEveryRotationAndArbitraryScale() {
        let pdfPoint = CGPoint(x: 137.25, y: 411.5)
        for rotation in allRotations {
            let s = space(rotation)
            let viewSize = CGSize(width: s.displaySize.width * 0.37, height: s.displaySize.height * 0.37)
            let roundTripped = s.pdfPoint(
                fromViewPoint: s.viewPoint(fromPDFPoint: pdfPoint, in: viewSize),
                in: viewSize
            )
            #expect(approx(roundTripped, pdfPoint, tolerance: 1e-6), "rotation \(rotation)")
        }
    }

    @Test func rectRoundTripsAtEveryRotationAndArbitraryScale() {
        let pdfRect = CGRect(x: 88.5, y: 233.25, width: 181.5, height: 23.75)
        for rotation in allRotations {
            let s = space(rotation)
            let viewSize = CGSize(width: s.displaySize.width * 1.6, height: s.displaySize.height * 1.6)
            let roundTripped = s.pdfRect(
                fromViewRect: s.viewRect(fromPDFRect: pdfRect, in: viewSize),
                in: viewSize
            )
            #expect(approx(roundTripped, pdfRect, tolerance: 1e-6), "rotation \(rotation)")
        }
    }

    @Test func viewRectsAreAlwaysNormalized() {
        // Whatever the rotation, converted rects must come back with
        // positive width/height and min-corner origin.
        let pdfRect = CGRect(x: 120, y: 630, width: 180, height: 24)
        for rotation in allRotations {
            let s = space(rotation)
            let converted = s.viewRect(fromPDFRect: pdfRect, in: s.displaySize)
            #expect(converted.width > 0 && converted.height > 0, "rotation \(rotation)")
        }
    }

    @Test func zeroSizesDoNotDivideByZero() {
        let s = space(90)
        #expect(s.pdfPoint(fromViewPoint: CGPoint(x: 10, y: 10), in: .zero) == .zero)
        let degenerate = PageCoordinateSpace(mediaBox: .zero, rotation: 0)
        #expect(degenerate.viewPoint(fromPDFPoint: .zero, in: CGSize(width: 100, height: 100)) == .zero)
    }
}
