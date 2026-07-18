//
//  ActivityShareSheet.swift
//  Form Filler
//
//  UIActivityViewController wrapper that shares a concrete file URL.
//  The PDF must already exist on disk: receivers (notably the user's EMR
//  software) get the URL itself, not a file promise — ShareLink's lazy
//  FileRepresentation was rejected by the EMR (same behavior seen in the
//  user's earlier EYEreport app).
//

import SwiftUI
import UIKit

struct ActivityShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    var onComplete: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
