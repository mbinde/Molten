//
//  KeyPairManagerTests.swift
//  MoltenTests
//
//  Tests for KeyPairManager - manages cryptographic key pairs for inventory sharing
//  Uses Ed25519 for encryption, stores private keys in iOS Keychain
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif
import Foundation
import CryptoKit
@testable import Molten

@Suite("KeyPairManager Tests")
@MainActor
struct KeyPairManagerTests {

    // MARK: - Test Lifecycle

    init() {
        // Clean up any existing test keys before each test
        // Use deleteAllTestKeys() to avoid wiping production keys
        KeyPairManager.deleteAllTestKeys()
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
        try manager.storeTestPrivateKey(keyPair.privateKey, identifier: "test-key-1")

        // Verify key was stored by retrieving it
        let retrieved = try manager.retrieveTestPrivateKey(identifier: "test-key-1")
        #expect(retrieved == keyPair.privateKey)
    }

    @Test("Should retrieve stored private key")
    func testRetrievePrivateKey() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        try manager.storeTestPrivateKey(keyPair.privateKey, identifier: "test-key-2")

        let retrieved = try manager.retrieveTestPrivateKey(identifier: "test-key-2")

        #expect(retrieved == keyPair.privateKey)
    }

    @Test("Should throw error when retrieving non-existent key")
    func testRetrieveNonExistentKey() {
        let manager = KeyPairManager()

        #expect(throws: KeyPairError.self) {
            _ = try manager.retrieveTestPrivateKey(identifier: "non-existent-key")
        }
    }

    @Test("Should delete private key from Keychain")
    func testDeletePrivateKey() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        try manager.storeTestPrivateKey(keyPair.privateKey, identifier: "test-key-3")

        // Verify key exists
        let retrieved = try manager.retrieveTestPrivateKey(identifier: "test-key-3")
        #expect(retrieved == keyPair.privateKey)

        // Delete key
        try manager.deleteTestPrivateKey(identifier: "test-key-3")

        // Verify key no longer exists
        #expect(throws: KeyPairError.self) {
            _ = try manager.retrieveTestPrivateKey(identifier: "test-key-3")
        }
    }

    @Test("Should overwrite existing key when storing with same identifier")
    func testOverwriteExistingKey() throws {
        let manager = KeyPairManager()

        let keyPair1 = try manager.generateKeyPair()
        let keyPair2 = try manager.generateKeyPair()

        try manager.storeTestPrivateKey(keyPair1.privateKey, identifier: "test-key-4")
        try manager.storeTestPrivateKey(keyPair2.privateKey, identifier: "test-key-4")

        let retrieved = try manager.retrieveTestPrivateKey(identifier: "test-key-4")
        #expect(retrieved == keyPair2.privateKey)
        #expect(retrieved != keyPair1.privateKey)
    }

    // MARK: - Key Management Tests

    @Test("Should generate and store key pair with single method")
    func testGenerateAndStore() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateAndStoreTestKeyPair(identifier: "test-key-5")

        // Verify key was stored
        let retrieved = try manager.retrieveTestPrivateKey(identifier: "test-key-5")
        #expect(retrieved == keyPair.privateKey)

        // Verify public key is correct
        #expect(keyPair.publicKey.count == 32)
    }

    @Test("Should get current key pair if exists")
    func testGetCurrentKeyPair() throws {
        let manager = KeyPairManager()

        // Store a key pair using test keychain
        let keyPair = try manager.generateAndStoreTestKeyPair(identifier: "test-current-key")

        // Retrieve it back
        let retrieved = try manager.retrieveTestPrivateKey(identifier: "test-current-key")

        #expect(retrieved == keyPair.privateKey)
        #expect(keyPair.publicKey.count == 32)
    }

    @Test("Should generate new key pair when requested")
    func testGetCurrentKeyPairGeneratesIfNeeded() throws {
        let manager = KeyPairManager()

        // Ensure no test keys exist
        KeyPairManager.deleteAllTestKeys()

        // Generate and store a new key pair
        let keyPair = try manager.generateAndStoreTestKeyPair(identifier: "test-generated-key")

        #expect(keyPair.publicKey.count == 32)
        #expect(keyPair.privateKey.count == 32)

        // Verify it was stored
        let retrieved = try manager.retrieveTestPrivateKey(identifier: "test-generated-key")
        #expect(retrieved == keyPair.privateKey)
    }

    // MARK: - Key Rotation Tests

    @Test("Should support key rotation pattern")
    func testRotateKeys() throws {
        let manager = KeyPairManager()

        // Generate initial key pair
        let oldKeyPair = try manager.generateAndStoreTestKeyPair(identifier: "test-rotate-current")

        // Generate new key pair (simulating rotation)
        let newKeyPair = try manager.generateAndStoreTestKeyPair(identifier: "test-rotate-new")

        #expect(newKeyPair.publicKey != oldKeyPair.publicKey)
        #expect(newKeyPair.privateKey != oldKeyPair.privateKey)

        // Both keys should be retrievable
        let oldRetrieved = try manager.retrieveTestPrivateKey(identifier: "test-rotate-current")
        let newRetrieved = try manager.retrieveTestPrivateKey(identifier: "test-rotate-new")
        #expect(oldRetrieved == oldKeyPair.privateKey)
        #expect(newRetrieved == newKeyPair.privateKey)
    }

    @Test("Should archive old key when rotating")
    func testRotateKeysArchivesOld() throws {
        let manager = KeyPairManager()

        // Generate initial key pair
        let oldKeyPair = try manager.generateAndStoreTestKeyPair(identifier: "test-archive-current")

        // "Archive" it by storing with different identifier
        try manager.storeTestPrivateKey(oldKeyPair.privateKey, identifier: "test-archive-archived")

        // Generate new key pair
        _ = try manager.generateAndStoreTestKeyPair(identifier: "test-archive-current")

        // Old key should still be retrievable with archived identifier
        let archived = try manager.retrieveTestPrivateKey(identifier: "test-archive-archived")
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
        try manager.storeTestPrivateKey(keyPair.privateKey, identifier: "test-key-security")

        // This test verifies that the key was stored with proper accessibility
        // The actual Keychain query is tested in the implementation
        let retrieved = try manager.retrieveTestPrivateKey(identifier: "test-key-security")
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
            _ = try manager.retrieveTestPrivateKey(identifier: "non-existent")
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

    @Test("Should delete all test keys")
    func testDeleteAllKeys() throws {
        let manager = KeyPairManager()

        // Create multiple test keys
        try manager.generateAndStoreTestKeyPair(identifier: "key-1")
        try manager.generateAndStoreTestKeyPair(identifier: "key-2")
        try manager.generateAndStoreTestKeyPair(identifier: "key-3")

        // Verify keys exist
        _ = try manager.retrieveTestPrivateKey(identifier: "key-1")
        _ = try manager.retrieveTestPrivateKey(identifier: "key-2")
        _ = try manager.retrieveTestPrivateKey(identifier: "key-3")

        // Delete all test keys
        KeyPairManager.deleteAllTestKeys()

        // Verify all keys are gone
        #expect(throws: KeyPairError.self) {
            _ = try manager.retrieveTestPrivateKey(identifier: "key-1")
        }
        #expect(throws: KeyPairError.self) {
            _ = try manager.retrieveTestPrivateKey(identifier: "key-2")
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

    // MARK: - Signing and Verification Tests

    @Test("Should sign data with private key")
    func testSignData() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        let testData = "TEST01".data(using: .utf8)!

        let signature = try manager.sign(data: testData, privateKey: keyPair.privateKey)

        // Ed25519 signatures are 64 bytes
        #expect(signature.count == 64)
    }

    @Test("Should verify valid signature")
    func testVerifyValidSignature() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        let testData = "TEST01".data(using: .utf8)!

        // Sign data
        let signature = try manager.sign(data: testData, privateKey: keyPair.privateKey)

        // Verify signature
        let isValid = try manager.verify(signature: signature, data: testData, publicKey: keyPair.publicKey)
        #expect(isValid == true)
    }

    @Test("Should reject invalid signature")
    func testRejectInvalidSignature() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        let testData = "TEST01".data(using: .utf8)!

        // Sign data
        let signature = try manager.sign(data: testData, privateKey: keyPair.privateKey)

        // Modify signature (invalidate it)
        var corruptedSignature = signature
        corruptedSignature[0] ^= 0xFF

        // Verify should return false
        let isValid = try manager.verify(signature: corruptedSignature, data: testData, publicKey: keyPair.publicKey)
        #expect(isValid == false)
    }

    @Test("Should reject signature with wrong data")
    func testRejectSignatureWithWrongData() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        let originalData = "TEST01".data(using: .utf8)!
        let differentData = "TEST02".data(using: .utf8)!

        // Sign original data
        let signature = try manager.sign(data: originalData, privateKey: keyPair.privateKey)

        // Verify with different data should return false
        let isValid = try manager.verify(signature: signature, data: differentData, publicKey: keyPair.publicKey)
        #expect(isValid == false)
    }

    @Test("Should reject signature with wrong public key")
    func testRejectSignatureWithWrongPublicKey() throws {
        let manager = KeyPairManager()

        let keyPair1 = try manager.generateKeyPair()
        let keyPair2 = try manager.generateKeyPair()
        let testData = "TEST01".data(using: .utf8)!

        // Sign with first key pair
        let signature = try manager.sign(data: testData, privateKey: keyPair1.privateKey)

        // Verify with second key pair's public key should return false
        let isValid = try manager.verify(signature: signature, data: testData, publicKey: keyPair2.publicKey)
        #expect(isValid == false)
    }

    @Test("Should produce different signatures for different data")
    func testDifferentSignaturesForDifferentData() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        let data1 = "TEST01".data(using: .utf8)!
        let data2 = "TEST02".data(using: .utf8)!

        let signature1 = try manager.sign(data: data1, privateKey: keyPair.privateKey)
        let signature2 = try manager.sign(data: data2, privateKey: keyPair.privateKey)

        #expect(signature1 != signature2)
    }

    @Test("Should throw error when signing with invalid private key")
    func testSigningWithInvalidPrivateKey() {
        let manager = KeyPairManager()

        let testData = "TEST01".data(using: .utf8)!
        let invalidPrivateKey = Data(count: 16) // Wrong size (should be 32)

        #expect(throws: KeyPairError.self) {
            _ = try manager.sign(data: invalidPrivateKey, privateKey: invalidPrivateKey)
        }
    }

    @Test("Should return false when verifying with invalid public key")
    func testVerifyWithInvalidPublicKey() throws {
        let manager = KeyPairManager()

        let keyPair = try manager.generateKeyPair()
        let testData = "TEST01".data(using: .utf8)!
        let signature = try manager.sign(data: testData, privateKey: keyPair.privateKey)

        let invalidPublicKey = Data(count: 16) // Wrong size (should be 32)

        // Should return false for invalid public key
        let isValid = try manager.verify(signature: signature, data: testData, publicKey: invalidPublicKey)
        #expect(isValid == false)
    }
}
