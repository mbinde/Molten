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
    func storePrivateKey(_ privateKey: Data, identifier: String) throws {
        // Delete existing key if present
        try? deletePrivateKey(identifier: identifier)

        // Prepare Keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: privateKey,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Add to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeyPairError.keychainError("Failed to store key: \(status)")
        }
    }

    /// Retrieve a private key from the Keychain
    func retrievePrivateKey(identifier: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

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

    /// Delete a private key from the Keychain
    func deletePrivateKey(identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: identifier
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyPairError.keychainError("Failed to delete key: \(status)")
        }
    }

    /// Delete all keys from the Keychain
    nonisolated static func deleteAllKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
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
}
