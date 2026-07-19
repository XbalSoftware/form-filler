//
//  FillSessionView.swift
//  Form Filler
//
//  Fill mode: ordered form list on the left, live page preview with value
//  overlays on the right. Values live in memory and autosave to the
//  encrypted on-device draft vault (every 5 seconds and whenever the
//  screen or app is left), so a session survives editing the template
//  mid-entry or an accidental exit — until "Clear form".
//

import SwiftUI

struct FillRoute: Hashable {
    let templateID: UUID
}

struct FillSessionView: View {
    /// Identifiable wrapper so the share popover / save sheet present per export.
    private struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var viewModel: FillSessionViewModel
    @State private var isConfirmingClear = false
    @State private var sharedFile: ExportedFile?
    @State private var savedFile: ExportedFile?
    @State private var draftToResume: FillSessionPayload?
    @State private var isShowingDraftPrompt = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

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
        .toolbar { toolbarContent }
        .confirmationDialog(
            "Clear this form?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear Form", role: .destructive) { viewModel.clearAll() }
        } message: {
            Text("This clears every entered value and deletes the saved draft.")
        }
        .alert(
            "Resume saved draft?",
            isPresented: $isShowingDraftPrompt,
            presenting: draftToResume
        ) { draft in
            Button("Resume") { viewModel.restoreDraft(draft) }
            Button("Start Fresh", role: .destructive) { viewModel.discardDraft() }
        } message: { draft in
            Text("Entries for this form were saved \(draft.savedAt.formatted(date: .abbreviated, time: .shortened)). Starting fresh deletes them.")
        }
        .alert("Something Went Wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            // Skip the prompt when the session already has values (e.g. a
            // reopened exported PDF, or returning from the editor).
            if !viewModel.hasAnyValues, let draft = viewModel.availableDraft() {
                draftToResume = draft
                isShowingDraftPrompt = true
            }
        }
        .task {
            // 5-second autosave heartbeat; unchanged ticks are free.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                viewModel.autosaveDraft()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                viewModel.autosaveDraft()
            }
        }
        .onDisappear {
            viewModel.autosaveDraft()
            PDFExportService.purgeTemporaryExports()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Clear form") { isConfirmingClear = true }
                .disabled(!viewModel.hasAnyValues)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 8) {
                Button("Print", systemImage: "printer") {
                    withExportedFile { printPDF(at: $0) }
                }
                Button("Save", systemImage: "folder") {
                    withExportedFile { savedFile = ExportedFile(url: $0) }
                }
                .sheet(item: $savedFile) { file in
                    DocumentExportPicker(fileURL: file.url) { savedFile = nil }
                }
                Button("Share", systemImage: "square.and.arrow.up") {
                    withExportedFile { sharedFile = ExportedFile(url: $0) }
                }
                .popover(item: $sharedFile) { file in
                    ActivityShareSheet(fileURL: file.url) {
                        sharedFile = nil
                    }
                    .frame(minWidth: 380, minHeight: 540)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(!viewModel.hasExportableContent)
        }
    }

    /// Renders + writes the PDF, then hands the file URL to `action`;
    /// export errors land in the shared error alert.
    private func withExportedFile(_ action: (URL) -> Void) {
        do {
            action(try viewModel.exportToTemporaryFile())
        } catch {
            viewModel.errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func printPDF(at url: URL) {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = viewModel.exportFileName
        printInfo.outputType = .general
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = url
        controller.present(animated: true)
    }

    /// Entry (taps focus fields) vs. the ad-hoc mark tools.
    private var toolPicker: some View {
        VStack(spacing: 2) {
            Picker("Tool", selection: Bindable(viewModel).activeTool) {
                Label("Type", systemImage: "character.cursor.ibeam")
                    .tag(FillSessionViewModel.FillTool.entry)
                Label("Checkmark", systemImage: "checkmark")
                    .tag(FillSessionViewModel.FillTool.check)
                Label("Circle", systemImage: "circle")
                    .tag(FillSessionViewModel.FillTool.circle)
                Label("Comment", systemImage: "text.bubble")
                    .tag(FillSessionViewModel.FillTool.comment)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 460)
            Text(toolHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(height: 14)
        }
    }

    private var toolHint: String {
        switch viewModel.activeTool {
        case .entry: ""
        case .check: "Tap the form to place a checkmark · tap a checkmark to remove it"
        case .circle: "Drag to circle an item · tap a circle to remove it"
        case .comment: "Tap or drag out a box to add a comment · tap a comment to edit or delete it"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    // MARK: - Preview column

    @ViewBuilder
    private var previewColumn: some View {
        if let renderService = viewModel.renderService {
            VStack(spacing: 8) {
                toolPicker
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
