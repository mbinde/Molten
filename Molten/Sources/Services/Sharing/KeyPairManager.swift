//
//  KeyPairManager.swift
//  Molten
//
//  Manages cryptographic key pairs for inventory sharing
//  - Generates Ed25519 key pairs
//  - Stores private keys securely in iOS Keychain
//  - Manages key rotation
//

import Foundation
import CryptoKit
import Security

/// Manages cryptographic key pairs for secure inventory sharing
@MainActor
final class KeyPairManager {

    // MARK: - Constants

    static let currentKeyIdentifier = "com.molten.sharing.current-key"
    static let archivedKeyIdentifier = "com.molten.sharing.archived-key"
    nonisolated private static let keychainService = "com.molten.sharing"

    // MARK: - Key Generation

    /// Generate a new Ed25519 key pair
    func generateKeyPair() throws -> KeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey

        return KeyPair(
            publicKey: publicKey.rawRepresentation,
            privateKey: privateKey.rawRepresentation
        )
    }

    // MARK: - Keychain Storage

    /// Store a private key in the Keychain
    /// - Note: Uses kSecAttrAccessibleWhenUnlocked to enable iCloud Keychain sync
    ///         This ensures keys transfer to new devices, allowing users to delete their data
    func storePrivateKey(_ privateKey: Data, identifier: String) throws {
        // Delete existing key if present
        try? deletePrivateKey(identifier: identifier)

        // Prepare Keychain query
        // CRITICAL: kSecAttrAccessibleWhenUnlocked enables iCloud Keychain sync
        // This ensures keys transfer when user upgrades phones, which is REQUIRED
        // for GDPR/privacy compliance - users must be able to delete their server data
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: privateKey,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: true  // Explicitly enable iCloud sync
        ]

        // Add to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeyPairError.keychainError("Failed to store key: \(status)")
        }
    }

    /// Retrieve a private key from the Keychain
    /// - Note: Tries to retrieve synchronizable key first, falls back to non-synchronizable for migration
    func retrievePrivateKey(identifier: String) throws -> Data {
        // Try to retrieve synchronizable key first (new format)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: identifier,
            kSecAttrSynchronizable as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)

        // If not found, try non-synchronizable (old format for migration)
        if status == errSecItemNotFound {
            query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
            status = SecItemCopyMatching(query as CFDictionary, &result)

            // If we found an old key, migrate it to synchronizable
            if status == errSecSuccess, let data = result as? Data {
                try migrateKeyToSynchronizable(data: data, identifier: identifier)
                return data
            }
        }

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeyPairError.keyNotFound
            }
            throw KeyPairError.keychainError("Failed to retrieve key: \(status)")
        }

        guard let data = result as? Data else {
            throw KeyPairError.keychainError("Invalid data format")
        }

        return data
    }

    /// Migrate an existing non-synchronizable key to synchronizable format
    private func migrateKeyToSynchronizable(data: Data, identifier: String) throws {
        // Delete old non-synchronizable key
        try deletePrivateKey(identifier: identifier)

        // Re-store with synchronizable flag
        try storePrivateKey(data, identifier: identifier)
    }

    /// Delete a private key from the Keychain
    /// - Note: Handles both synchronizable and non-synchronizable keys
    func deletePrivateKey(identifier: String) throws {
        // Try to delete synchronizable keys and non-synchronizable keys
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: identifier,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny  // Matches both types
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyPairError.keychainError("Failed to delete key: \(status)")
        }
    }

    /// Delete all keys from the Keychain
    /// - Note: Handles both synchronizable and non-synchronizable keys
    nonisolated static func deleteAllKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny  // Matches both types
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Key Management

    /// Generate and store a new key pair
    func generateAndStoreKeyPair(identifier: String) throws -> KeyPair {
        let keyPair = try generateKeyPair()
        try storePrivateKey(keyPair.privateKey, identifier: identifier)
        return keyPair
    }

    /// Get the current key pair (generates if doesn't exist)
    func getCurrentKeyPair() throws -> KeyPair {
        do {
            let privateKey = try retrievePrivateKey(identifier: Self.currentKeyIdentifier)
            let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
            return KeyPair(
                publicKey: signingKey.publicKey.rawRepresentation,
                privateKey: privateKey
            )
        } catch KeyPairError.keyNotFound {
            // Generate new key pair if doesn't exist
            return try generateAndStoreKeyPair(identifier: Self.currentKeyIdentifier)
        }
    }

    /// Rotate keys (archive current, generate new)
    func rotateKeys() throws -> KeyPair {
        // Get current key pair
        let currentKeyPair = try getCurrentKeyPair()

        // Archive current key
        try storePrivateKey(currentKeyPair.privateKey, identifier: Self.archivedKeyIdentifier)

        // Generate new key pair
        return try generateAndStoreKeyPair(identifier: Self.currentKeyIdentifier)
    }

    // MARK: - Import/Export

    /// Export public key as base64 string
    func exportPublicKey(_ publicKey: Data) -> String {
        return publicKey.base64EncodedString()
    }

    /// Import public key from base64 string
    func importPublicKey(_ base64: String) throws -> Data {
        guard let data = Data(base64Encoded: base64) else {
            throw KeyPairError.invalidBase64
        }

        guard data.count == 32 else {
            throw KeyPairError.invalidKeyLength
        }

        return data
    }

    // MARK: - Signing

    /// Sign data with private key
    /// - Parameters:
    ///   - data: Data to sign
    ///   - privateKey: Private key to sign with
    /// - Returns: Ed25519 signature
    func sign(data: Data, privateKey: Data) throws -> Data {
        do {
            let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
            let signature = try signingKey.signature(for: data)
            return signature
        } catch {
            throw KeyPairError.signingFailed
        }
    }

    /// Verify signature
    /// - Parameters:
    ///   - signature: Signature to verify
    ///   - data: Original data
    ///   - publicKey: Public key to verify against
    /// - Returns: True if signature is valid
    func verify(signature: Data, data: Data, publicKey: Data) throws -> Bool {
        do {
            let verifyingKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
            return verifyingKey.isValidSignature(signature, for: data)
        } catch {
            return false
        }
    }
}
