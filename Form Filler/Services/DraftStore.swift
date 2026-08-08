//
//  DraftStore.swift
//  Form Filler
//
//  The draft autosave "vault of one" (explicit user request, 2026-07-17,
//  amending invariant #3): the single active fill session survives leaving
//  the screen or an app quit, ON THIS DEVICE ONLY, until the user clears
//  it. Adapted from the user's EYEreport app.
//
//  Privacy posture:
//    - payload AES.GCM-sealed (CryptoKit)
//    - key in the Keychain, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
//      no user-presence gate — restore is deliberately silent
//    - file `draft.sealed` in Application Support, excluded from backups
//    - written with complete file protection as defense-in-depth
//

import Foundation
import CryptoKit
import Security
import os

nonisolated enum DraftStoreError: LocalizedError {
    case keychain(OSStatus)
    case sealingFailed

    var errorDescription: String? {
        switch self {
        case .keychain(let status): "Couldn't access the draft encryption key (status \(status))."
        case .sealingFailed: "Couldn't encrypt the draft."
        }
    }
}

nonisolated struct DraftStore: Sendable {
    static let fileName = "draft.sealed"

    let fileURL: URL

    private static let logger = Logger(subsystem: "Xbal.Form-Filler", category: "DraftStore")
    private static let keychainService = "Xbal.Form-Filler"
    private static let keychainAccount = "draft-vault-key"

    init(directoryURL: URL = URL.applicationSupportDirectory) {
        self.fileURL = directoryURL.appending(path: Self.fileName)
    }

    // MARK: - API

    /// The saved draft, or nil if none exists / it can't be decrypted.
    /// Unreadable drafts are treated as absent (and removed) rather than
    /// surfaced as errors — there is nothing the user could do about them.
    func load() -> FillSessionPayload? {
        guard let sealed = try? Data(contentsOf: fileURL) else { return nil }
        guard let key = try? Self.symmetricKey(),
              let box = try? AES.GCM.SealedBox(combined: sealed),
              let plain = try? AES.GCM.open(box, using: key),
              let payload = try? FillSessionPayload.makeDecoder()
                  .decode(FillSessionPayload.self, from: plain)
        else {
            Self.logger.error("Discarding undecryptable draft")
            clear()
            return nil
        }
        return payload
    }

    func save(_ payload: FillSessionPayload) throws {
        let key = try Self.symmetricKey()
        let plain = try FillSessionPayload.makeEncoder().encode(payload)
        guard let sealed = try AES.GCM.seal(plain, using: key).combined else {
            throw DraftStoreError.sealingFailed
        }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try sealed.write(to: fileURL, options: [.atomic, .completeFileProtection])
        excludeFromBackup()
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Clears the draft only if it belongs to the given template — so
    /// clearing one form's session can't wipe a draft saved for another.
    func clear(for templateID: UUID) {
        guard load()?.templateID == templateID else { return }
        clear()
    }

    // MARK: - Plumbing

    /// The draft must never leave the device: not in iCloud/finder backups
    /// (this flag) and not restorable to another device (the key's
    /// ThisDeviceOnly accessibility).
    private func excludeFromBackup() {
        var url = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try url.setResourceValues(values)
        } catch {
            Self.logger.error("Couldn't exclude draft from backup: \(error)")
        }
    }

    /// Loads the AES key from the Keychain, creating it on first use.
    private static func symmetricKey() throws -> SymmetricKey {
        if let data = try existingKeyData() {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: key.withUnsafeBytes { Data($0) },
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem, let data = try existingKeyData() {
            return SymmetricKey(data: data)   // lost a race with another save
        }
        guard status == errSecSuccess else { throw DraftStoreError.keychain(status) }
        return key
    }

    private static func existingKeyData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw DraftStoreError.keychain(status)
        }
    }
}
