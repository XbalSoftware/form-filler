//
//  TemplateDetailView.swift
//  Form Filler
//
//  Landing screen for one template: interactive zoomable page preview
//  (the Stage 3 canvas) plus the Editor (Stage 4) and Fill (Stage 5) entry
//  points, disabled until those stages exist.
//

import SwiftUI

struct TemplateDetailView: View {
    /// Identifiable wrapper for the share popover.
    private struct SharedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    let template: Template
    let pdfURL: URL

    @State private var renderService: PDFRenderService?
    @State private var selectedPage = 0
    @State private var didFailToLoad = false
    @State private var sharedFile: SharedFile?
    @State private var shareError: String?

    var body: some View {
        Group {
            if let renderService {
                VStack(spacing: 12) {
                    PageCanvasView(renderService: renderService, pageIndex: selectedPage)
                    if renderService.pageCount > 1 {
                        PageStripView(renderService: renderService, selectedPage: $selectedPage)
                    }
                    modeButtons
                }
                .padding()
            } else if didFailToLoad {
                ContentUnavailableView(
                    "Couldn't Open PDF",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The template's PDF file couldn't be read.")
                )
            } else {
                ProgressView()
                    .task {
                        renderService = PDFRenderService(url: pdfURL)
                        didFailToLoad = renderService == nil
                    }
            }
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button("Share Template…", systemImage: "square.and.arrow.up.on.square") {
                    shareTemplatePDF()
                }
                Button("Share Blank PDF…", systemImage: "doc") {
                    shareBlankPDF()
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .popover(item: $sharedFile) { file in
                ActivityShareSheet(fileURL: file.url) { sharedFile = nil }
                    .frame(minWidth: 380, minHeight: 540)
            }
        }
        .alert(
            "Couldn't Share",
            isPresented: Binding(
                get: { shareError != nil },
                set: { if !$0 { shareError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareError ?? "")
        }
    }

    // MARK: - Sharing

    /// A copy of the original PDF carrying the template definition — a
    /// colleague's Import PDF recognizes it and recreates the template.
    /// Fields only: never includes practitioner profiles or signatures.
    private func shareTemplatePDF() {
        stageAndShare(fileName: TemplateShareService.shareFileName(for: template)) {
            try TemplateShareService.pdfWithEmbeddedTemplate(template, pdfData: Data(contentsOf: pdfURL))
        }
    }

    /// The imported original, byte-for-byte, under a clean filename.
    private func shareBlankPDF() {
        stageAndShare(fileName: TemplateShareService.blankFileName(for: template)) {
            try Data(contentsOf: pdfURL)
        }
    }

    private func stageAndShare(fileName: String, makeData: () throws -> Data) {
        do {
            let directory = PDFExportService.temporaryExportDirectory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: fileName)
            try makeData().write(to: url, options: .atomic)
            sharedFile = SharedFile(url: url)
        } catch {
            shareError = error.localizedDescription
        }
    }

    private var modeButtons: some View {
        HStack(spacing: 20) {
            NavigationLink(value: EditorRoute(templateID: template.id)) {
                Label("Edit Template", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            NavigationLink(value: FillRoute(templateID: template.id)) {
                Label("Fill Form", systemImage: "pencil.and.list.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(template.fields.isEmpty)
        }
        .controlSize(.large)
        .frame(maxWidth: 560)
    }
}
