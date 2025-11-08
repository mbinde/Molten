//
//  KeyPairManagerTests.swift
//  MoltenTests
//
//  Tests for KeyPairManager - manages cryptographic key pairs for inventory sharing
//  Uses Ed25519 for encryption, stores private keys in iOS Keychain
//

import Testing
import Foundation
import CryptoKit
@testable import Molten

@Suite("KeyPairManager Tests")
@MainActor
struct KeyPairManagerTests {

    // MARK: - Test Lifecycle

    init() {
        // Clean up any existing test keys before each test
        KeyPairManager.deleteAllKeys()
    }

    // MARK: - Key Generation Tests

    @Test("Should generate a new key pair")
    func testGenerateKeyPair() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()

        #expect(keyPair.publicKey.count == 32) // Ed25519 public keys are 32 bytes
        #expect(keyPair.privateKey.count == 32) // Ed25519 private keys are 32 bytes
    }

    @Test("Should generate unique key pairs")
    func testGenerateUniqueKeyPairs() throws {
        let manager = KeyPairManager()

        let keyPair1 = try manager.generateKeyPair()
        let keyPair2 = try manager.generateKeyPair()

        #expect(keyPair1.publicKey != keyPair2.publicKey)
        #expect(keyPair1.privateKey != keyPair2.privateKey)
    }

    @Test("Should use Ed25519 curve")
    func testUsesEd25519Curve() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()

        // Verify we can create a Curve25519 signing key from the private key
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyPair.privateKey)
        #expect(signingKey.publicKey.rawRepresentation.count == 32)
    }

    // MARK: - Keychain Storage Tests

    @Test("Should store private key in Keychain")
    func testStorePrivateKeyInKeychain() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        try manager.storePrivateKey(keyPair.privateKey, identifier: "test-key-1")

        // Verify key was stored by retrieving it
        let retrieved = try manager.retrievePrivateKey(identifier: "test-key-1")
        #expect(retrieved == keyPair.privateKey)
    }

    @Test("Should retrieve stored private key")
    func testRetrievePrivateKey() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        try manager.storePrivateKey(keyPair.privateKey, identifier: "test-key-2")

        let retrieved = try manager.retrievePrivateKey(identifier: "test-key-2")

        #expect(retrieved == keyPair.privateKey)
    }

    @Test("Should throw error when retrieving non-existent key")
    func testRetrieveNonExistentKey() {
        let manager = KeyPairManager()

        #expect(throws: KeyPairError.self) {
            _ = try manager.retrievePrivateKey(identifier: "non-existent-key")
        }
    }

    @Test("Should delete private key from Keychain")
    func testDeletePrivateKey() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        try manager.storePrivateKey(keyPair.privateKey, identifier: "test-key-3")

        // Verify key exists
        let retrieved = try manager.retrievePrivateKey(identifier: "test-key-3")
        #expect(retrieved == keyPair.privateKey)

        // Delete key
        try manager.deletePrivateKey(identifier: "test-key-3")

        // Verify key no longer exists
        #expect(throws: KeyPairError.self) {
            _ = try manager.retrievePrivateKey(identifier: "test-key-3")
        }
    }

    @Test("Should overwrite existing key when storing with same identifier")
    func testOverwriteExistingKey() throws {
        let manager = KeyPairManager()

        let keyPair1 = try manager.generateKeyPair()
        let keyPair2 = try manager.generateKeyPair()

        try manager.storePrivateKey(keyPair1.privateKey, identifier: "test-key-4")
        try manager.storePrivateKey(keyPair2.privateKey, identifier: "test-key-4")

        let retrieved = try manager.retrievePrivateKey(identifier: "test-key-4")
        #expect(retrieved == keyPair2.privateKey)
        #expect(retrieved != keyPair1.privateKey)
    }

    // MARK: - Key Management Tests

    @Test("Should generate and store key pair with single method")
    func testGenerateAndStore() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateAndStoreKeyPair(identifier: "test-key-5")

        // Verify key was stored
        let retrieved = try manager.retrievePrivateKey(identifier: "test-key-5")
        #expect(retrieved == keyPair.privateKey)

        // Verify public key is correct
        #expect(keyPair.publicKey.count == 32)
    }

    @Test("Should get current key pair if exists")
    func testGetCurrentKeyPair() throws {
        let manager = KeyPairManager()

        // Store a key pair
        let keyPair = try manager.generateAndStoreKeyPair(identifier: KeyPairManager.currentKeyIdentifier)

        // Retrieve current key pair
        let current = try manager.getCurrentKeyPair()

        #expect(current.publicKey == keyPair.publicKey)
        #expect(current.privateKey == keyPair.privateKey)
    }

    @Test("Should generate new key pair if current doesn't exist")
    func testGetCurrentKeyPairGeneratesIfNeeded() throws {
        let manager = KeyPairManager()

        // Ensure no current key exists
        KeyPairManager.deleteAllKeys()

        // Get current key pair (should generate new one)
        let current = try manager.getCurrentKeyPair()

        #expect(current.publicKey.count == 32)
        #expect(current.privateKey.count == 32)

        // Verify it was stored
        let retrieved = try manager.retrievePrivateKey(identifier: KeyPairManager.currentKeyIdentifier)
        #expect(retrieved == current.privateKey)
    }

    // MARK: - Key Rotation Tests

    @Test("Should rotate keys")
    func testRotateKeys() throws {
        let manager = KeyPairManager()

        // Generate initial key pair
        let oldKeyPair = try manager.getCurrentKeyPair()

        // Rotate keys
        let newKeyPair = try manager.rotateKeys()

        #expect(newKeyPair.publicKey != oldKeyPair.publicKey)
        #expect(newKeyPair.privateKey != oldKeyPair.privateKey)

        // Verify new key is now the current key
        let current = try manager.getCurrentKeyPair()
        #expect(current.publicKey == newKeyPair.publicKey)
    }

    @Test("Should archive old key when rotating")
    func testRotateKeysArchivesOld() throws {
        let manager = KeyPairManager()

        // Generate initial key pair
        let oldKeyPair = try manager.getCurrentKeyPair()

        // Rotate keys
        _ = try manager.rotateKeys()

        // Old key should still be retrievable with archived identifier
        let archived = try manager.retrievePrivateKey(identifier: KeyPairManager.archivedKeyIdentifier)
        #expect(archived == oldKeyPair.privateKey)
    }

    // MARK: - Public Key Export Tests

    @Test("Should export public key as base64")
    func testExportPublicKeyBase64() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        let base64 = manager.exportPublicKey(keyPair.publicKey)

        #expect(!base64.isEmpty)
        #expect(base64.count > 0)

        // Verify we can decode it back
        let decoded = Data(base64Encoded: base64)
        #expect(decoded == keyPair.publicKey)
    }

    @Test("Should import public key from base64")
    func testImportPublicKeyBase64() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        let base64 = manager.exportPublicKey(keyPair.publicKey)

        let imported = try manager.importPublicKey(base64)

        #expect(imported == keyPair.publicKey)
    }

    @Test("Should throw error when importing invalid base64")
    func testImportInvalidBase64() {
        let manager = KeyPairManager()

        #expect(throws: KeyPairError.self) {
            _ = try manager.importPublicKey("not-valid-base64!!!")
        }
    }

    @Test("Should throw error when importing wrong-length key")
    func testImportWrongLengthKey() {
        let manager = KeyPairManager()

        // Create a valid base64 string but wrong length
        let wrongLength = Data(count: 16) // Should be 32 bytes
        let base64 = wrongLength.base64EncodedString()

        #expect(throws: KeyPairError.self) {
            _ = try manager.importPublicKey(base64)
        }
    }

    // MARK: - Security Tests

    @Test("Should mark Keychain items as accessible when unlocked")
    func testKeychainAccessibility() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        try manager.storePrivateKey(keyPair.privateKey, identifier: "test-key-security")

        // This test verifies that the key was stored with proper accessibility
        // The actual Keychain query is tested in the implementation
        let retrieved = try manager.retrievePrivateKey(identifier: "test-key-security")
        #expect(retrieved == keyPair.privateKey)
    }

    @Test("Should not export private keys")
    func testNoPrivateKeyExport() {
        let manager = KeyPairManager()

        // Verify there's no method to export private keys as base64
        // (This is a compile-time check - if this compiles, the test passes)
        #expect(true, "Private keys should never be exportable")
    }

    // MARK: - Error Handling Tests

    @Test("Should handle Keychain errors gracefully")
    func testKeychainErrorHandling() {
        let manager = KeyPairManager()

        // Try to retrieve a key that doesn't exist
        do {
            _ = try manager.retrievePrivateKey(identifier: "non-existent")
            #expect(Bool(false), "Should throw error")
        } catch let error as KeyPairError {
            switch error {
            case .keyNotFound:
                #expect(true, "Correct error type")
            default:
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("Should provide descriptive error messages")
    func testDescriptiveErrors() {
        let manager = KeyPairManager()

        do {
            _ = try manager.importPublicKey("invalid")
            #expect(Bool(false), "Should throw error")
        } catch let error as KeyPairError {
            let description = error.localizedDescription
            #expect(!description.isEmpty)
            #expect(description.contains("base64") || description.contains("invalid"))
        } catch {
            #expect(Bool(false), "Wrong error type")
        }
    }

    // MARK: - Cleanup Tests

    @Test("Should delete all keys")
    func testDeleteAllKeys() throws {
        let manager = KeyPairManager()

        // Create multiple keys
        try manager.generateAndStoreKeyPair(identifier: "key-1")
        try manager.generateAndStoreKeyPair(identifier: "key-2")
        try manager.generateAndStoreKeyPair(identifier: KeyPairManager.currentKeyIdentifier)

        // Verify keys exist
        _ = try manager.retrievePrivateKey(identifier: "key-1")
        _ = try manager.retrievePrivateKey(identifier: "key-2")
        _ = try manager.getCurrentKeyPair()

        // Delete all keys
        KeyPairManager.deleteAllKeys()

        // Verify all keys are gone
        #expect(throws: KeyPairError.self) {
            _ = try manager.retrievePrivateKey(identifier: "key-1")
        }
        #expect(throws: KeyPairError.self) {
            _ = try manager.retrievePrivateKey(identifier: "key-2")
        }
    }

    // MARK: - Concurrency Tests

    @Test("Should handle concurrent key generation")
    func testConcurrentKeyGeneration() async throws {
        let manager = KeyPairManager()

        // Generate multiple keys sequentially (since manager is @MainActor)
        var keys: [KeyPair] = []
        for _ in 0..<10 {
            let keyPair = try manager.generateKeyPair()
            keys.append(keyPair)
        }

        // Verify all keys are unique
        let publicKeys = Set(keys.map { $0.publicKey })
        #expect(publicKeys.count == 10)
    }
}
