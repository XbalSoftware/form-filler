//
//  EditorPageOverlayView.swift
//  Form Filler
//
//  The editor's overlay layer for one page: a tap catcher for creating /
//  deselecting fields plus the draggable field overlays. Plugged into
//  PageCanvasView's overlay slot.
//

import SwiftUI

struct EditorPageOverlayView: View {
    let viewModel: TemplateEditorViewModel
    let space: PageCoordinateSpace
    let pageSize: CGSize

    static let coordinateSpaceName = "editorPage"

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .frame(width: pageSize.width, height: pageSize.height)
                .onTapGesture { location in
                    viewModel.handleCanvasTap(at: location, space: space, pageSize: pageSize)
                }
            ForEach(viewModel.fields(onPage: viewModel.currentPageIndex)) { field in
                FieldOverlayView(
                    field: field,
                    baseRect: space.viewRect(fromPDFRect: field.rect, in: pageSize),
                    isSelected: viewModel.selectedFieldID == field.id,
                    onTap: { viewModel.select(field) },
                    snap: { viewModel.snappedRect(for: $0, excluding: field.id, space: space, pageSize: pageSize) },
                    onCommit: { viewModel.setFieldRect(field.id, fromViewRect: $0, space: space, pageSize: pageSize) }
                )
            }
        }
        .coordinateSpace(name: Self.coordinateSpaceName)
    }
}
