//
//  EditorSupportTests.swift
//  Form FillerTests
//
//  Pure-logic pieces of the Stage 4 editor: edge snapping and color hex.
//

import CoreGraphics
import Foundation
import Testing
@testable import Form_Filler

struct EdgeSnappingTests {
    private let dragged = CGRect(x: 100, y: 100, width: 50, height: 20)

    @Test func snapsToNearbyVerticalEdge() {
        // dragged.maxX = 150; other.minX = 154 → within tolerance, snap +4.
        let other = CGRect(x: 154, y: 300, width: 40, height: 10)
        let snapped = EdgeSnapping.snapped(dragged, toEdgesOf: [other])
        #expect(snapped.minX == 104)
        #expect(snapped.minY == 100)   // y untouched — other's y edges are beyond tolerance
    }

    @Test func doesNotSnapBeyondTolerance() {
        let other = CGRect(x: 160, y: 300, width: 40, height: 10)   // 10pt gap
        #expect(EdgeSnapping.snapped(dragged, toEdgesOf: [other]) == dragged)
    }

    @Test func nearestEdgeWins() {
        let near = CGRect(x: 152, y: 300, width: 40, height: 10)    // 2pt away
        let far = CGRect(x: 155, y: 400, width: 40, height: 10)     // 5pt away
        let snapped = EdgeSnapping.snapped(dragged, toEdgesOf: [far, near])
        #expect(snapped.minX == 102)
    }

    @Test func axesSnapIndependently() {
        // Vertical edge from one neighbor, horizontal edge from another.
        let vertical = CGRect(x: 153, y: 500, width: 40, height: 10)   // maxX→minX: +3
        let horizontal = CGRect(x: 400, y: 96, width: 40, height: 10)  // minY 100 → 96: -4
        let snapped = EdgeSnapping.snapped(dragged, toEdgesOf: [vertical, horizontal])
        #expect(snapped.origin == CGPoint(x: 103, y: 96))
    }

    @Test func sizeIsNeverChangedBySnapping() {
        let other = CGRect(x: 154, y: 104, width: 40, height: 10)
        let snapped = EdgeSnapping.snapped(dragged, toEdgesOf: [other])
        #expect(snapped.size == dragged.size)
    }
}

struct ColorHexTests {
    @Test func parsesValidHex() {
        #expect(ColorHex.uiColor(from: "#3366FF") != nil)
        #expect(ColorHex.uiColor(from: "3366FF") != nil)     // bare, no hash
        #expect(ColorHex.uiColor(from: " #000000 ") != nil)  // stray whitespace
    }

    @Test func rejectsInvalidHex() {
        #expect(ColorHex.uiColor(from: "") == nil)
        #expect(ColorHex.uiColor(from: "#12345") == nil)     // too short
        #expect(ColorHex.uiColor(from: "#GGHHII") == nil)    // not hex
        #expect(ColorHex.uiColor(from: "#1234567") == nil)   // too long
    }

    @Test func roundTripsThroughColor() {
        let original = "#3366FF"
        let color = ColorHex.color(from: original)
        #expect(color != nil)
        #expect(ColorHex.hex(from: color!) == original)
    }

    @Test func blackAndWhiteRoundTrip() {
        #expect(ColorHex.hex(from: ColorHex.color(from: "#000000")!) == "#000000")
        #expect(ColorHex.hex(from: ColorHex.color(from: "#FFFFFF")!) == "#FFFFFF")
    }
}
