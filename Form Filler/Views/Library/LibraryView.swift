//
//  LibraryView.swift
//  Form Filler
//

import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var isPickingFile = false
    @State private var pendingImport: PendingImport?
    @State private var templateBeingEdited: Template?
    @State private var templateToDelete: Template?
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Form Filler")
                .toolbar {
                    Button("Import PDF", systemImage: "plus") { isPickingFile = true }
                }
                .navigationDestination(for: UUID.self) { id in
                    if let template = viewModel.template(withID: id) {
                        TemplateDetailView(template: template, thumbnail: viewModel.thumbnails[id])
                    } else {
                        ContentUnavailableView("Template Not Found", systemImage: "questionmark.folder")
                    }
                }
        }
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                pendingImport = viewModel.preparePendingImport(from: url)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $pendingImport) { pending in
            TemplateFormSheet(
                title: "New Template",
                confirmLabel: "Import",
                name: pending.suggestedName,
                category: ""
            ) { name, category in
                viewModel.importTemplate(pending, name: name, category: category)
            }
        }
        .sheet(item: $templateBeingEdited) { template in
            TemplateFormSheet(
                title: "Edit Details",
                confirmLabel: "Save",
                name: template.name,
                category: template.category ?? ""
            ) { name, category in
                viewModel.updateDetails(of: template, name: name, category: category)
            }
        }
        .confirmationDialog(
            "Delete “\(templateToDelete?.name ?? "")”?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible,
            presenting: templateToDelete
        ) { template in
            Button("Delete Template", role: .destructive) { viewModel.delete(template) }
        } message: { _ in
            Text("This removes the template and its imported PDF. This can't be undone.")
        }
        .alert("Something Went Wrong", isPresented: $viewModel.isPresentingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear { viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.templates.isEmpty {
            ContentUnavailableView {
                Label("No Templates", systemImage: "doc.badge.plus")
            } description: {
                Text("Import a PDF referral form to get started.")
            } actions: {
                Button("Import PDF") { isPickingFile = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            LibraryGridView(
                templates: viewModel.templates,
                thumbnails: viewModel.thumbnails,
                onEditDetails: { templateBeingEdited = $0 },
                onDuplicate: { viewModel.duplicate($0) },
                onDelete: { template in
                    templateToDelete = template
                    isConfirmingDelete = true
                }
            )
        }
    }
}

#Preview {
    LibraryView()
}
