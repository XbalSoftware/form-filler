//
//  SignatureStore.swift
//  Form Filler
//
//  The user's single stored signature image, used by signature fields.
//  Drawn in-app or imported (PNG/JPEG) via Settings. This is the user's
//  own signature, not patient data, so unlike the fill draft it's plain
//  data on disk and rides along in library backups.
//

import UIKit

nonisolated enum SignatureStoreError: LocalizedError {
    case notAnImage

    var errorDescription: String? {
        switch self {
        case .notAnImage: "That file isn't a readable PNG or JPEG image."
        }
    }
}

nonisolated struct SignatureStore: Sendable {
    static let fileName = "signature.image"

    let fileURL: URL

    init(directoryURL: URL = URL.applicationSupportDirectory) {
        self.fileURL = directoryURL.appending(path: Self.fileName)
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false))
    }

    /// The stored image bytes (PNG or JPEG, as saved), or nil.
    func loadData() -> Data? {
        try? Data(contentsOf: fileURL)
    }

    func loadImage() -> UIImage? {
        loadData().flatMap(UIImage.init(data:))
    }

    /// Saves image bytes after validating they decode. Replaces any
    /// existing signature.
    func save(_ data: Data) throws {
        guard UIImage(data: data) != nil else {
            throw SignatureStoreError.notAnImage
        }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
