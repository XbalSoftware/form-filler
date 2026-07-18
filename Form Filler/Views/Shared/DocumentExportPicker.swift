//
//  DocumentExportPicker.swift
//  Form Filler
//
//  UIDocumentPickerViewController wrapper for "Save to Files": exports a
//  copy of an already-written file to a user-chosen location. The source
//  stays in the temp export directory and is purged as usual.
//

import SwiftUI
import UIKit

struct DocumentExportPicker: UIViewControllerRepresentable {
    let fileURL: URL
    var onComplete: () -> Void = {}

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: () -> Void

        init(onComplete: @escaping () -> Void) {
            self.onComplete = onComplete
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onComplete()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onComplete()
        }
    }
}
