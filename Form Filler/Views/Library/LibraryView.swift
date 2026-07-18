//
//  LibraryView.swift
//  Form Filler
//
//  Top bar layout (user decision 2026-07-17): Reopen Exported PDF on the
//  far left, search centered, then sort / settings-gear / import-plus on
//  the right with (+) outermost. Backup & restore live in Settings.
//

import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var isPickingFile = false
    @State private var isPickingExportedPDF = false
    @State private var isShowingSettings = false
    @State private var pendingImport: PendingImport?
    @State private var templateBeingEdited: Template?
    @State private var templateToDelete: Template?
    @State private var isConfirmingDelete = false
    @AppStorage("librarySortOrder") private var sortOrder: LibrarySortOrder = .recentlyModified

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Form Filler")
                .navigationBarTitleDisplayMode(.inline)
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
            // fileImporter allows one presentation per view, so the second
            // picker hangs off an invisible anchor.
            Color.clear
                .fileImporter(isPresented: $isPickingExportedPDF, allowedContentTypes: [.pdf]) { result in
                    if case .success(let url) = result,
                       let route = viewModel.prepareFillRestore(from: url) {
                        // Route through the detail screen so Back lands on
                        // the fill/edit chooser, same as the normal flow.
                        navigationPath.append(route.templateID)
                        navigationPath.append(route)
                    }
                }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isPickingExportedPDF = true
            } label: {
                Label("Reopen Exported PDF", systemImage: "doc.text.magnifyingglass")
                    .labelStyle(.titleAndIcon)
            }
        }
        ToolbarItem(placement: .principal) {
            searchField
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Picker("Arrange By", selection: $sortOrder) {
                    ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
            } label: {
                Label("Arrange", systemImage: "arrow.up.arrow.down")
            }
            Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
            Button("Import PDF", systemImage: "plus") { isPickingFile = true }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search templates", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.fill.tertiary, in: Capsule())
        .frame(width: 320)
    }

    // MARK: - Content

    /// Templates matching the search text (name or category), arranged by
    /// the chosen sort order.
    private var filteredTemplates: [Template] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = query.isEmpty
            ? viewModel.templates
            : viewModel.templates.filter {
                $0.name.localizedStandardContains(query)
                    || ($0.category?.localizedStandardContains(query) ?? false)
            }
        return sortOrder.sorted(matching)
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
