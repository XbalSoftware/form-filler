//
//  LibraryView.swift
//  Form Filler
//

import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    /// Identifiable wrapper for the backup save picker.
    private struct BackupFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var viewModel = LibraryViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var isPickingFile = false
    @State private var isPickingBackup = false
    @State private var isPickingExportedPDF = false
    @State private var backupFile: BackupFile?
    @State private var pendingImport: PendingImport?
    @State private var templateBeingEdited: Template?
    @State private var templateToDelete: Template?
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Form Filler")
                .searchable(text: $searchText, prompt: "Search templates")
                .toolbar { toolbarContent }
                .navigationDestination(for: UUID.self) { id in
                    if let template = viewModel.template(withID: id) {
                        TemplateDetailView(template: template, pdfURL: viewModel.pdfURL(for: template))
                    } else {
                        ContentUnavailableView("Template Not Found", systemImage: "questionmark.folder")
                    }
                }
                .navigationDestination(for: EditorRoute.self) { route in
                    if let template = viewModel.template(withID: route.templateID) {
                        TemplateEditorView(viewModel: viewModel.makeEditorViewModel(for: template))
                    } else {
                        ContentUnavailableView("Template Not Found", systemImage: "questionmark.folder")
                    }
                }
                .navigationDestination(for: FillRoute.self) { route in
                    if let template = viewModel.template(withID: route.templateID) {
                        FillSessionView(viewModel: viewModel.makeFillSessionViewModel(for: template))
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
        .background {
            // fileImporter allows one presentation per view, so the extra
            // pickers hang off invisible anchors.
            Color.clear
                .fileImporter(isPresented: $isPickingBackup, allowedContentTypes: [.json]) { result in
                    if case .success(let url) = result {
                        viewModel.restoreBackup(from: url)
                    }
                }
            Color.clear
                .fileImporter(isPresented: $isPickingExportedPDF, allowedContentTypes: [.pdf]) { result in
                    if case .success(let url) = result,
                       let route = viewModel.prepareFillRestore(from: url) {
                        navigationPath.append(route)
                    }
                }
        }
        .sheet(item: $backupFile) { file in
            DocumentExportPicker(fileURL: file.url) { backupFile = nil }
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
        .alert("Library", isPresented: $viewModel.isPresentingInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.infoMessage ?? "")
        }
        .onAppear { viewModel.onAppear() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button("Reopen Exported PDF…", systemImage: "doc.text.magnifyingglass") {
                    isPickingExportedPDF = true
                }
                Divider()
                Button("Back Up Library…", systemImage: "arrow.down.document") {
                    if let url = viewModel.exportBackupToTemporaryFile() {
                        backupFile = BackupFile(url: url)
                    }
                }
                Button("Restore from Backup…", systemImage: "arrow.counterclockwise") {
                    isPickingBackup = true
                }
            } label: {
                Label("Library Options", systemImage: "ellipsis.circle")
            }
            Button("Import PDF", systemImage: "plus") { isPickingFile = true }
        }
    }

    /// Templates matching the search text (name or category); all of them
    /// when the search is empty.
    private var filteredTemplates: [Template] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.templates }
        return viewModel.templates.filter {
            $0.name.localizedStandardContains(query)
                || ($0.category?.localizedStandardContains(query) ?? false)
        }
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
        } else if filteredTemplates.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            LibraryGridView(
                templates: filteredTemplates,
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
