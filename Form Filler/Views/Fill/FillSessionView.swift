//
//  FillSessionView.swift
//  Form Filler
//
//  Stage 5 fill mode: ordered form list on the left, live page preview
//  with value overlays on the right. Values are transient — leaving this
//  screen discards them (CLAUDE.md invariant #3).
//

import SwiftUI

struct FillRoute: Hashable {
    let templateID: UUID
}

struct FillSessionView: View {
    @State private var viewModel: FillSessionViewModel
    @State private var isConfirmingClear = false
    @State private var isConfirmingDiscard = false

    @Environment(\.dismiss) private var dismiss

    init(viewModel: FillSessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        HStack(spacing: 0) {
            FillFormListView(viewModel: viewModel)
                .frame(width: 360)
            Divider()
            previewColumn
        }
        .navigationTitle(viewModel.template.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", systemImage: "chevron.backward") {
                    if viewModel.hasAnyValues {
                        isConfirmingDiscard = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Clear All", systemImage: "eraser") {
                    isConfirmingClear = true
                }
                .disabled(!viewModel.hasAnyValues)
                ShareLink(
                    item: viewModel.makeExportItem(),
                    preview: SharePreview(viewModel.exportFileName)
                ) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(!viewModel.hasExportableContent)
            }
        }
        .confirmationDialog(
            "Clear all entered values?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) { viewModel.clearAll() }
        }
        .confirmationDialog(
            "Discard entered values?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard and Leave", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Entries are never saved. Leaving this screen discards them.")
        }
        .onDisappear {
            PDFExportService.purgeTemporaryExports()
        }
    }

    @ViewBuilder
    private var previewColumn: some View {
        if let renderService = viewModel.renderService {
            VStack(spacing: 8) {
                PageCanvasView(
                    renderService: renderService,
                    pageIndex: viewModel.currentPageIndex
                ) { space, pageSize in
                    FillPageOverlayView(viewModel: viewModel, space: space, pageSize: pageSize)
                }
                if renderService.pageCount > 1 {
                    PageStripView(renderService: renderService, selectedPage: $viewModel.currentPageIndex)
                }
            }
            .padding([.trailing, .vertical])
        } else {
            ContentUnavailableView(
                "Couldn't Open PDF",
                systemImage: "exclamationmark.triangle",
                description: Text("The template's PDF file couldn't be read.")
            )
        }
    }
}
