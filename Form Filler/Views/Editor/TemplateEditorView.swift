//
//  TemplateEditorView.swift
//  Form Filler
//
//  The Stage 4 editor screen: zoomable page canvas with field overlays on
//  the left, inspector (field list / field properties) on the right.
//  One finger edits; two fingers pan and pinch-zoom.
//

import SwiftUI

struct EditorRoute: Hashable {
    let templateID: UUID
}

struct TemplateEditorView: View {
    @State private var viewModel: TemplateEditorViewModel

    init(viewModel: TemplateEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        HStack(spacing: 0) {
            canvasColumn
            Divider()
            EditorInspectorView(viewModel: viewModel)
                .frame(width: 320)
        }
        .navigationTitle(viewModel.template.name)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: viewModel.selectedFieldID)
        .alert("Couldn't Save", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var canvasColumn: some View {
        if let renderService = viewModel.renderService {
            VStack(spacing: 8) {
                PageCanvasView(
                    renderService: renderService,
                    pageIndex: viewModel.currentPageIndex,
                    panRequiresTwoTouches: true
                ) { space, pageSize in
                    EditorPageOverlayView(viewModel: viewModel, space: space, pageSize: pageSize)
                }
                if renderService.pageCount > 1 {
                    PageStripView(renderService: renderService, selectedPage: $viewModel.currentPageIndex)
                }
                Text("Tap to add a field · drag to move · two fingers to pan and zoom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
            .padding([.leading, .top])
        } else {
            ContentUnavailableView(
                "Couldn't Open PDF",
                systemImage: "exclamationmark.triangle",
                description: Text("The template's PDF file couldn't be read.")
            )
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

struct EditorInspectorView: View {
    let viewModel: TemplateEditorViewModel

    var body: some View {
        Group {
            if viewModel.selectedField != nil {
                FieldInspectorForm(viewModel: viewModel)
            } else {
                FieldListView(viewModel: viewModel)
            }
        }
    }
}
