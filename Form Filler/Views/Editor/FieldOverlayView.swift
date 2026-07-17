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
            .overlay(alignment: .leading) {
                Text(field.name)
                    .font(.system(size: max(7, min(10, displayRect.height * 0.55))))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 3)
            }
            .frame(width: displayRect.width, height: displayRect.height)
            .position(x: displayRect.midX, y: displayRect.midY)
            .onTapGesture(perform: onTap)
            .gesture(moveGesture)
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
        return Circle()
            .fill(.background)
            .stroke(Color.accentColor, lineWidth: 2)
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

    private func resizedRect(dragging corner: Corner, to location: CGPoint) -> CGRect {
        let minWidth = TemplateEditorViewModel.minimumViewSize.width
        let minHeight = TemplateEditorViewModel.minimumViewSize.height
        var left = baseRect.minX
        var right = baseRect.maxX
        var top = baseRect.minY
        var bottom = baseRect.maxY

        switch corner {
        case .topLeft:
            left = min(location.x, right - minWidth)
            top = min(location.y, bottom - minHeight)
        case .topRight:
            right = max(location.x, left + minWidth)
            top = min(location.y, bottom - minHeight)
        case .bottomLeft:
            left = min(location.x, right - minWidth)
            bottom = max(location.y, top + minHeight)
        case .bottomRight:
            right = max(location.x, left + minWidth)
            bottom = max(location.y, top + minHeight)
        }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}
