//
//  ExportedFormPDF.swift
//  Form Filler
//
//  ShareLink item for a filled form. Uses FileRepresentation so receiving
//  apps (AirDrop, Files, Print, and notably EMR software) are handed a URL
//  to an actual .pdf file with a proper filename — not anonymous data.
//  The PDF is generated lazily, only when the user actually shares.
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

nonisolated struct ExportedFormPDF: Transferable {
    let template: Template
    let values: [UUID: FieldValue]
    let sourceURL: URL
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { item in
            SentTransferredFile(try item.writeTemporaryFile(), allowAccessingOriginalFile: false)
        }
    }

    /// Renders the filled PDF into the temp export directory (purged on
    /// launch and when leaving the fill screen) and returns its URL.
    func writeTemporaryFile() throws -> URL {
        let data = try PDFExportService().exportPDF(
            template: template,
            values: values,
            sourceURL: sourceURL
        )
        let directory = PDFExportService.temporaryExportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
