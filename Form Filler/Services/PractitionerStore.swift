//
//  PractitionerStore.swift
//  Form Filler
//
//  Persists the practitioner profiles as one JSON file in Application
//  Support. Plain data (the user's own details, no PHI), atomic writes,
//  same encoder conventions as TemplateStore.
//

import Foundation

nonisolated struct PractitionerStore: Sendable {
    static let fileName = "practitioners.json"

    let fileURL: URL

    init(directoryURL: URL = URL.applicationSupportDirectory) {
        self.fileURL = directoryURL.appending(path: Self.fileName)
    }

    /// All profiles, in their saved order. Missing/undecodable file = none.
    func load() -> [PractitionerProfile] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? TemplateStore.makeDecoder().decode([PractitionerProfile].self, from: data)) ?? []
    }

    func save(_ profiles: [PractitionerProfile]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try TemplateStore.makeEncoder().encode(profiles)
        try data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
