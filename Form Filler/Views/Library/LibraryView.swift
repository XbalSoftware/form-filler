//
//  LibraryView.swift
//  Form Filler
//
//  Stage 1 placeholder: proves the store round-trips by listing templates.
//  Stage 2 replaces this with the real grid, import flow, and actions.
//

import SwiftUI

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let message = viewModel.loadErrorMessage {
                    ContentUnavailableView(
                        "Couldn't Load Templates",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                } else if viewModel.templates.isEmpty {
                    ContentUnavailableView(
                        "No Templates",
                        systemImage: "doc.badge.plus",
                        description: Text("Import a PDF referral form to get started.")
                    )
                } else {
                    templateList
                }
            }
            .navigationTitle("Form Filler")
        }
        .onAppear { viewModel.onAppear() }
    }

    private var templateList: some View {
        List(viewModel.templates) { template in
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                Text("\(template.fields.count) fields\(template.category.map { " · \($0)" } ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    LibraryView()
}
