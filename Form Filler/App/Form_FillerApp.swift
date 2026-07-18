//
//  Form_FillerApp.swift
//  Form Filler
//

import SwiftUI

@main
struct Form_FillerApp: App {
    init() {
        // Any exported PDFs staged for a previous share are patient data;
        // make sure they never outlive a session.
        PDFExportService.purgeTemporaryExports()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
    }
}
