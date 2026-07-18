//
//  SettingsView.swift
//  Form Filler
//
//  Presented as a sheet from the library's gear button. Backup/restore
//  act through the LibraryViewModel so the grid refreshes and outcome
//  messages use the shared info/error alerts (attached here too, since
//  the library's own alerts can't present under this sheet).
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    /// Identifiable wrapper for the backup save picker.
    private struct BackupFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    let viewModel: LibraryViewModel

    @State private var backupFile: BackupFile?
    @State private var isPickingBackup = false
    @State private var isConfirmingReset = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                librarySection
                aboutSection
                resetSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $isPickingBackup, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                viewModel.restoreBackup(from: url)
            }
        }
        .sheet(item: $backupFile) { file in
            DocumentExportPicker(fileURL: file.url) { backupFile = nil }
        }
        .confirmationDialog(
            "Erase all app data?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Erase Everything", role: .destructive) { viewModel.resetApp() }
        } message: {
            Text("Deletes every template (including imported PDFs) and the saved fill draft. This can't be undone — consider backing up the library first.")
        }
        .alert("Something Went Wrong", isPresented: Bindable(viewModel).isPresentingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Library", isPresented: Bindable(viewModel).isPresentingInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.infoMessage ?? "")
        }
    }

    private var librarySection: some View {
        Section {
            Button("Back Up Library…", systemImage: "arrow.down.document") {
                if let url = viewModel.exportBackupToTemporaryFile() {
                    backupFile = BackupFile(url: url)
                }
            }
            Button("Restore from Backup…", systemImage: "arrow.counterclockwise") {
                isPickingBackup = true
            }
        } header: {
            Text("Library")
        } footer: {
            Text("A backup is a single file holding every template — field layouts and the original PDFs — and can rebuild the library from nothing. Backups never contain patient data.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            NavigationLink("About Form Filler") {
                AboutView()
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button("Reset App…", role: .destructive) {
                isConfirmingReset = true
            }
        } footer: {
            Text("Erases all user data stored by Form Filler on this iPad.")
        }
    }
}
