//
//  FillPageOverlayView.swift
//  Form Filler
//
//  Live preview overlays for fill mode. Font fitting happens in PDF point
//  space via TextFitting (the same function the export uses), then the
//  result is scaled to view points — so the preview is faithful to what
//  will export.
//

import SwiftUI
import UIKit

struct FillPageOverlayView: View {
    let viewModel: FillSessionViewModel
    let space: PageCoordinateSpace
    let pageSize: CGSize

    /// Live outline while dragging out a circle or comment box, in page
    /// view space.
    @State private var draggedCircleRect: CGRect?

    var body: some View {
        ZStack {
            ForEach(viewModel.fields(onPage: viewModel.currentPageIndex)) { field in
                FillFieldOverlay(
                    field: field,
                    text: viewModel.displayText(for: field),
                    signatureImage: field.type == .signature ? viewModel.signatureImage : nil,
                    isFocused: viewModel.focusedFieldID == field.id,
                    viewRect: space.viewRect(fromPDFRect: field.rect, in: pageSize),
                    scale: scale
                )
                .onTapGesture { viewModel.handleOverlayTap(field) }
            }
            ForEach(viewModel.marks(onPage: viewModel.currentPageIndex)) { mark in
                MarkOverlay(
                    mark: mark,
                    viewRect: space.viewRect(fromPDFRect: mark.rect, in: pageSize),
                    scale: scale
                )
            }
            if viewModel.activeTool != .entry {
                markToolLayer
            }
        }
    }

    private var scale: CGFloat {
        space.displaySize.width > 0 ? pageSize.width / space.displaySize.width : 1
    }

    // MARK: - Mark tools

    /// Full-page catcher while a mark tool is active: tap places (or
    /// removes) a mark; with the circle tool a drag draws the circle.
    private var markToolLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(width: pageSize.width, height: pageSize.height)
            .gesture(markGesture)
            .overlay {
                if let rect = draggedCircleRect {
                    Group {
                        if viewModel.activeTool == .comment {
                            Rectangle().stroke(
                                Color.black.opacity(0.6),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                        } else {
                            MarkShape(kind: .circle).stroke(
                                Color.black.opacity(0.6),
                                style: StrokeStyle(lineWidth: MarkGeometry.lineWidth(for: rect))
                            )
                        }
                    }
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                }
            }
    }

    private var markGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard viewModel.activeTool == .circle || viewModel.activeTool == .comment else { return }
                let rect = normalizedRect(value.startLocation, value.location)
                draggedCircleRect = max(rect.width, rect.height) > 6 ? rect : nil
            }
            .onEnded { value in
                defer { draggedCircleRect = nil }
                let rect = normalizedRect(value.startLocation, value.location)
                let isTap = max(rect.width, rect.height) <= 6
                let tapPDFPoint = space.pdfPoint(fromViewPoint: value.startLocation, in: pageSize)
                switch viewModel.activeTool {
                case .check:
                    viewModel.handleMarkTap(at: tapPDFPoint, kind: .check)
                case .circle where isTap:
                    viewModel.handleMarkTap(at: tapPDFPoint, kind: .circle)
                case .circle:
                    viewModel.addCircle(around: space.pdfRect(fromViewRect: rect, in: pageSize))
                case .comment where isTap:
                    viewModel.handleMarkTap(at: tapPDFPoint, kind: .comment)
                case .comment:
                    viewModel.promptComment(in: space.pdfRect(fromViewRect: rect, in: pageSize))
                case .entry:
                    break
                }
            }
    }

    private func normalizedRect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }
}

/// One rendered ad-hoc mark. Never intercepts touches — edits/removal go
/// through the tool layer's hit test so field taps keep working in
/// entry mode.
private struct MarkOverlay: View {
    let mark: AdHocMark
    let viewRect: CGRect
    /// View points per PDF point — comments fit their text in PDF points
    /// (export-identical) and scale up, like field text.
    let scale: CGFloat

    var body: some View {
        Group {
            if mark.kind == .comment {
                commentText
            } else {
                MarkShape(kind: mark.kind)
                    .stroke(
                        Color.black,
                        style: StrokeStyle(
                            lineWidth: MarkGeometry.lineWidth(for: viewRect),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
        .frame(width: viewRect.width, height: viewRect.height)
        .position(x: viewRect.midX, y: viewRect.midY)
        .allowsHitTesting(false)
        .accessibilityLabel(accessibilityDescription)
    }

    private var commentText: some View {
        let text = mark.text ?? ""
        let fitBox = CGSize(width: viewRect.width / scale, height: viewRect.height / scale)
        let fitted = TextFitting.fittedFontSize(
            for: text,
            fontName: mark.resolvedFontName,
            preferredSize: mark.resolvedFontSize,
            in: fitBox,
            multiline: true
        )
        return Text(text)
            .font(.custom(mark.resolvedFontName, fixedSize: fitted * scale))
            .foregroundStyle(.black)
            .frame(width: viewRect.width, height: viewRect.height, alignment: .topLeading)
            .clipped()
            .background {
                if mark.hasWhiteBackground { Color.white }
            }
            .overlay {
                if mark.hasBorder {
                    Rectangle().strokeBorder(Color.black, lineWidth: max(1, scale))
                }
            }
    }

    private var accessibilityDescription: String {
        switch mark.kind {
        case .check: "Checkmark"
        case .circle: "Circle mark"
        case .comment: "Comment: \(mark.text ?? "")"
        }
    }
}

/// SwiftUI face of `MarkGeometry` — identical strokes to the export.
private struct MarkShape: Shape {
    let kind: AdHocMark.Kind

    func path(in rect: CGRect) -> Path {
        Path(MarkGeometry.path(for: kind, in: rect))
    }
}

private struct FillFieldOverlay: View {
    let field: FieldDefinition
    let text: String?
    /// Non-nil only for a signed signature field.
    var signatureImage: UIImage? = nil
    let isFocused: Bool
    let viewRect: CGRect
    let scale: CGFloat

    var body: some View {
        ZStack {
            // Matches the export's white backing behind filled content.
            if field.fillsWhiteBackground && (text != nil || signatureImage != nil) {
                Color.white
            }
            border
            if let text {
                fittedText(text)
            }
            if let signatureImage {
                Image(uiImage: signatureImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: viewRect.width, height: viewRect.height)
            }
        }
        .frame(width: viewRect.width, height: viewRect.height)
        .position(x: viewRect.midX, y: viewRect.midY)
        .contentShape(Rectangle())
        .accessibilityLabel("\(field.name): \(accessibilityValue)")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityValue: String {
        if signatureImage != nil { return "signed" }
        return text ?? "empty"
    }

    @ViewBuilder
    private var border: some View {
        if isFocused {
            Rectangle().strokeBorder(Color.accentColor, lineWidth: 1.5)
        } else if text == nil && signatureImage == nil {
            Rectangle().strokeBorder(
                .secondary.opacity(0.45),
                style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
            )
        }
    }

    private func fittedText(_ text: String) -> some View {
        // Fit in PDF points (export-identical), then scale for display.
        // The fit box is the *display-space* size — on rotated pages the
        // PDF-space rect has width/height swapped, and the export fits
        // against display space too.
        let fitBox = CGSize(width: viewRect.width / scale, height: viewRect.height / scale)
        let fittedPDFSize = TextFitting.fittedFontSize(
            for: text,
            fontName: field.style.fontName,
            preferredSize: field.style.fontSize,
            in: fitBox,
            multiline: field.type.isMultiline
        )
        return Text(text)
            .font(.custom(field.style.fontName, fixedSize: fittedPDFSize * scale))
            .foregroundStyle(ColorHex.color(from: field.style.colorHex) ?? .black)
            .frame(width: viewRect.width, height: viewRect.height, alignment: alignment)
            .clipped()
    }

    private var alignment: Alignment {
        let multiline = field.type.isMultiline
        switch field.style.alignment {
        case .leading: return field.type == .checkbox ? .center : (multiline ? .topLeading : .leading)
        case .center: return multiline ? .top : .center
        case .trailing: return multiline ? .topTrailing : .trailing
        }
    }
}
