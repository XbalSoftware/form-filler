//
//  TemplateDetailView.swift
//  Form Filler
//
//  Landing screen for one template. The Editor (Stage 4) and Fill (Stage 5)
//  entry points live here; until those stages exist the buttons are
//  disabled placeholders.
//

import SwiftUI

struct TemplateDetailView: View {
    let template: Template
    let thumbnail: UIImage?

    var body: some View {
        VStack(spacing: 24) {
            preview
            modeButtons
            Text("Template editing and form filling arrive in upcoming stages.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var preview: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 80))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: 420, maxHeight: .infinity)
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
