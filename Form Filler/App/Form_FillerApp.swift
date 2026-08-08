//
//  Form_FillerApp.swift
//  Form Filler
//

import SwiftUI

@main
struct Form_FillerApp: App {
    @State private var importInbox = PatientImportInbox()

    init() {
        // Any exported PDFs staged for a previous share are patient data;
        // make sure they never outlive a session.
        PDFExportService.purgeTemporaryExports()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(importInbox)
                // A PDF shared into the app (e.g. from the EMR's Share sheet).
                .onOpenURL { importInbox.receive(pdfAt: $0) }
        }
    }
}
