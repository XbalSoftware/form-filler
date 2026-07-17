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
    let template: Template
    let pdfURL: URL

    @State private var renderService: PDFRenderService?
    @State private var selectedPage = 0
    @State private var didFailToLoad = false

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
    }

    private var modeButtons: some View {
        HStack(spacing: 20) {
            Button {
                // Stage 4: template editor
            } label: {
                Label("Edit Template", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(true)

            Button {
                // Stage 5: fill mode
            } label: {
                Label("Fill Form", systemImage: "pencil.and.list.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(true)
        }
        .controlSize(.large)
        .frame(maxWidth: 560)
    }
}
