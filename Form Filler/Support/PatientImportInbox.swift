//
//  PatientImportInbox.swift
//  Form Filler
//
//  Receives a PDF shared into the app from another app (e.g. the EMR's
//  Share sheet). It parses the patient details, then DELETES the copy iOS
//  placed in Documents/Inbox so no PHI lingers on disk — the parsed values
//  live only in memory until the clinician applies them in a fill session.
//

import Foundation
import Observation

@MainActor
@Observable
final class PatientImportInbox {
    /// Patient details from a shared PDF, waiting for a fill session to pick
    /// them up. In-memory only — never persisted (PHI hygiene).
    var pending: PatientDemographics?
    /// One-shot message when a shared PDF couldn't be read as demographics.
    var failureMessage: String?

    /// Handles a PDF opened/shared into the app.
    func receive(pdfAt url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
            deleteInboxCopy(url)
        }

        if let demographics = PatientDemographicsParser.demographics(fromPDFAt: url) {
            pending = demographics
        } else {
            failureMessage = "No patient details could be read from that PDF. To add a blank form as a template instead, use the + button in your library."
        }
    }

    /// Removes the file only if it's the copy iOS staged in our Documents/
    /// Inbox (we don't declare in-place opening, so shares always land there).
    /// Never deletes a file outside our own inbox.
    private func deleteInboxCopy(_ url: URL) {
        let inbox = URL.documentsDirectory.appending(path: "Inbox").standardizedFileURL.path
        guard url.standardizedFileURL.path.hasPrefix(inbox) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
