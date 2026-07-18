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

struct FillPageOverlayView: View {
    let viewModel: FillSessionViewModel
    let space: PageCoordinateSpace
    let pageSize: CGSize

    var body: some View {
        ZStack {
            ForEach(viewModel.fields(onPage: viewModel.currentPageIndex)) { field in
                FillFieldOverlay(
                    field: field,
                    text: viewModel.displayText(for: field),
                    isFocused: viewModel.focusedFieldID == field.id,
                    viewRect: space.viewRect(fromPDFRect: field.rect, in: pageSize),
                    scale: scale
                )
                .onTapGesture { viewModel.handleOverlayTap(field) }
            }
        }
    }

    private var scale: CGFloat {
        space.displaySize.width > 0 ? pageSize.width / space.displaySize.width : 1
    }
}

private struct FillFieldOverlay: View {
    let field: FieldDefinition
    let text: String?
    let isFocused: Bool
    let viewRect: CGRect
    let scale: CGFloat

    var body: some View {
        ZStack {
            border
            if let text {
                fittedText(text)
            }
        }
        .frame(width: viewRect.width, height: viewRect.height)
        .position(x: viewRect.midX, y: viewRect.midY)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var border: some View {
        if isFocused {
            Rectangle().strokeBorder(Color.accentColor, lineWidth: 1.5)
        } else if text == nil {
            Rectangle().strokeBorder(
                .secondary.opacity(0.45),
                style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
            )
        }
    }

    private func fittedText(_ text: String) -> some View {
        // Fit in PDF points (export-identical), then scale for display.
        let fittedPDFSize = TextFitting.fittedFontSize(
            for: text,
            fontName: field.style.fontName,
            preferredSize: field.style.fontSize,
            in: field.rect.size,
            multiline: field.type == .multiLineText
        )
        return Text(text)
            .font(.custom(field.style.fontName, fixedSize: fittedPDFSize * scale))
            .foregroundStyle(ColorHex.color(from: field.style.colorHex) ?? .black)
            .frame(width: viewRect.width, height: viewRect.height, alignment: alignment)
            .clipped()
    }

    private var alignment: Alignment {
        let multiline = field.type == .multiLineText
        switch field.style.alignment {
        case .leading: return field.type == .checkbox ? .center : (multiline ? .topLeading : .leading)
        case .center: return multiline ? .top : .center
        case .trailing: return multiline ? .topTrailing : .trailing
        }
    }
}
