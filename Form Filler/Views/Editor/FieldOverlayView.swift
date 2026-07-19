//
//  FieldOverlayView.swift
//  Form Filler
//
//  One field on the editor canvas: tappable to select, draggable to move
//  (with edge snapping), corner handles to resize when selected. All
//  geometry is in page view space; commits go back to the view model,
//  which converts to PDF space.
//

import SwiftUI

struct FieldOverlayView: View {
    let field: FieldDefinition
    let baseRect: CGRect                 // view space at zoom 1
    /// View points per PDF point — needed to render the name label at the
    /// exact size fill-mode text will render.
    let scale: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let snap: (CGRect) -> CGRect
    let onCommit: (CGRect) -> Void

    @State private var moveTranslation: CGSize = .zero
    @State private var isMoving = false
    @State private var liveResizeRect: CGRect?

    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        func point(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
            case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
            case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
            case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            }
        }
    }

    private var displayRect: CGRect {
        if let liveResizeRect { return liveResizeRect }
        if isMoving {
            return snap(baseRect.offsetBy(dx: moveTranslation.width, dy: moveTranslation.height))
        }
        return baseRect
    }

    var body: some View {
        ZStack {
            fieldBody
            if isSelected {
                ForEach(Corner.allCases, id: \.self) { corner in
                    handle(for: corner)
                }
            }
        }
    }

    private var fieldBody: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor.opacity(isSelected ? 0.18 : 0.10))
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.accentColor.opacity(0.55),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .overlay {
                nameLabel
            }
            .frame(width: displayRect.width, height: displayRect.height)
            .position(x: displayRect.midX, y: displayRect.midY)
            .onTapGesture(perform: onTap)
            .gesture(moveGesture)
            .accessibilityLabel("\(field.name), \(field.type.displayName) field")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The field's name inside its box — rendered with the SAME fitting,
    /// font, and alignment fill mode will use for the entered text, so
    /// alignment can be perfected right in the editor (grey marks it as a
    /// placeholder). Checkbox/signature fields keep a small caption label
    /// since their content isn't styled text.
    @ViewBuilder
    private var nameLabel: some View {
        if field.type == .checkbox || field.type == .signature {
            Text(field.name)
                .font(.system(size: max(7, min(10, displayRect.height * 0.55))))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.gray)
                .padding(.horizontal, 3)
                .frame(width: displayRect.width, height: displayRect.height, alignment: .leading)
        } else {
            let fitBox = CGSize(width: displayRect.width / scale, height: displayRect.height / scale)
            let fitted = TextFitting.fittedFontSize(
                for: field.name,
                fontName: field.style.fontName,
                preferredSize: field.style.fontSize,
                in: fitBox,
                multiline: field.type.isMultiline
            )
            Text(field.name)
                .font(.custom(field.style.fontName, fixedSize: fitted * scale))
                .foregroundStyle(.gray)
                .frame(width: displayRect.width, height: displayRect.height, alignment: fillAlignment)
                .clipped()
        }
    }

    /// Mirrors FillFieldOverlay's alignment resolution.
    private var fillAlignment: Alignment {
        let multiline = field.type.isMultiline
        switch field.style.alignment {
        case .leading: return multiline ? .topLeading : .leading
        case .center: return multiline ? .top : .center
        case .trailing: return multiline ? .topTrailing : .trailing
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                isMoving = true
                moveTranslation = value.translation
            }
            .onEnded { value in
                let final = snap(baseRect.offsetBy(dx: value.translation.width, dy: value.translation.height))
                isMoving = false
                moveTranslation = .zero
                onCommit(final)
            }
    }

    private func handle(for corner: Corner) -> some View {
        let center = corner.point(in: displayRect)
        // The red bottom-left handle is the only one that changes height;
        // the others adjust width only (fields usually share one height).
        return Circle()
            .fill(.background)
            .stroke(corner == .bottomLeft ? Color.red : Color.accentColor, lineWidth: 2)
            .frame(width: 12, height: 12)
            .contentShape(Circle().inset(by: -10))   // generous touch target
            .position(center)
            .gesture(
                DragGesture(
                    minimumDistance: 1,
                    coordinateSpace: .named(EditorPageOverlayView.coordinateSpaceName)
                )
                .onChanged { value in
                    liveResizeRect = resizedRect(dragging: corner, to: value.location)
                }
                .onEnded { value in
                    let final = resizedRect(dragging: corner, to: value.location)
                    liveResizeRect = nil
                    onCommit(final)
                }
            )
    }

    /// Only the bottom-left corner may change the height — fields usually
    /// keep one shared height, and width-only handles make stretching a
    /// field along a line much easier (user decision 2026-07-18).
    private func resizedRect(dragging corner: Corner, to location: CGPoint) -> CGRect {
        let minWidth = TemplateEditorViewModel.minimumViewSize.width
        let minHeight = TemplateEditorViewModel.minimumViewSize.height
        var left = baseRect.minX
        var right = baseRect.maxX
        let top = baseRect.minY
        var bottom = baseRect.maxY

        switch corner {
        case .topLeft, .bottomLeft:
            left = min(location.x, right - minWidth)
        case .topRight, .bottomRight:
            right = max(location.x, left + minWidth)
        }
        if corner == .bottomLeft {
            bottom = max(location.y, top + minHeight)
        }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}
