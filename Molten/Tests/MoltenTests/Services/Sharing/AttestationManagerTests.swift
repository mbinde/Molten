//
//  AttestationManagerTests.swift
//  MoltenTests
//
//  Tests for App Attest attestation and assertion generation
//

import Testing
import Foundation
@testable import Molten

@Suite("AttestationManager Tests", .serialized)
@MainActor
struct AttestationManagerTests {

    // MARK: - Test Lifecycle

    init() {
        // Clean up keychain and UserDefaults
        UserDefaults.standard.removeObject(forKey: "molten.appAttest.keyId")
    }

    // MARK: - Device Support Tests

    @Test("Should check if App Attest is supported")
    func testIsSupported() async throws {
        let mockService = MockAppAttestService()
        mockService.isSupported = true
        let manager = AttestationManager(attestService: mockService)

        #expect(manager.isSupported == true)
    }

    @Test("Should handle unsupported devices")
    func testUnsupportedDevice() async throws {
        let mockService = MockAppAttestService()
        mockService.isSupported = false
        let manager = AttestationManager(attestService: mockService)

        #expect(manager.isSupported == false)
    }

    // MARK: - Key Generation Tests

    @Test("Should generate attestation key")
    func testGenerateKey() async throws {
        let mockService = MockAppAttestService()
        mockService.isSupported = true
        mockService.mockKeyId = "test-key-123"

        let manager = AttestationManager(attestService: mockService)

        let keyId = try await manager.generateKey()

        #expect(keyId == "test-key-123")
        #expect(mockService.generateKeyCalled)
    }

    @Test("Should store key ID after generation")
    func testStoreKeyId() async throws {
        let mockService = MockAppAttestService()
        mockService.isSupported = true
        mockService.mockKeyId = "stored-key-456"

        let manager = AttestationManager(attestService: mockService)

        _ = try await manager.generateKey()

        // Verify stored in UserDefaults
        let storedKeyId = UserDefaults.standard.string(forKey: "molten.appAttest.keyId")
        #expect(storedKeyId == "stored-key-456")
    }

    @Test("Should return existing key if already generated")
    func testReturnExistingKey() async throws {
        // Pre-store a key ID
        UserDefaults.standard.set("existing-key-789", forKey: "molten.appAttest.keyId")

        let mockService = MockAppAttestService()
        mockService.isSupported = true
        let manager = AttestationManager(attestService: mockService)

        let keyId = try await manager.generateKey()

        #expect(keyId == "existing-key-789")
        #expect(!mockService.generateKeyCalled, "Should not generate new key if one exists")
    }

    // MARK: - Attestation Tests

    @Test("Should attest key with challenge")
    func testAttestKey() async throws {
        let mockService = MockAppAttestService()
        mockService.isSupported = true
        mockService.mockKeyId = "attest-key"
        mockService.mockAttestation = Data("attestation-data".utf8)

        let manager = AttestationManager(attestService: mockService)

        // Generate key first
        let keyId = try await manager.generateKey()

        // Attest the key
        let challenge = Data("server-challenge".utf8)
        let attestation = try await manager.attestKey(keyId: keyId, challenge: challenge)

        #expect(attestation == Data("attestation-data".utf8))
        #expect(mockService.attestKeyCalled)
        #expect(mockService.lastKeyId == "attest-key")
    }

    // MARK: - Assertion Tests

    @Test("Should generate assertion for request")
    func testGenerateAssertion() async throws {
        let mockService = MockAppAttestService()
        mockService.isSupported = true
        mockService.mockAssertion = Data("assertion-data".utf8)

        // Pre-store key ID
        UserDefaults.standard.set("assertion-key", forKey: "molten.appAttest.keyId")

        let manager = AttestationManager(attestService: mockService)

        // Generate assertion
        let requestData = "POST-/share-ABC123".data(using: .utf8)!
        let assertion = try await manager.generateAssertion(requestData: requestData)

        #expect(assertion == Data("assertion-data".utf8))
        #expect(mockService.generateAssertionCalled)
    }

    @Test("Should throw error if no key exists when generating assertion")
    func testAssertionWithoutKey() async throws {
        let mockService = MockAppAttestService()
        mockService.isSupported = true

        let manager = AttestationManager(attestService: mockService)

        let requestData = Data("test".utf8)

        await #expect(throws: AttestationError.self) {
            _ = try await manager.generateAssertion(requestData: requestData)
        }
    }

    // MARK: - Complete Flow Test

    @Test("Should complete full attestation flow")
    func testCompleteAttestationFlow() async throws {
        let mockService = MockAppAttestService()
        mockService.isSupported = true
        mockService.mockKeyId = "flow-key"
        mockService.mockAttestation = Data("attestation".utf8)
        mockService.mockAssertion = Data("assertion".utf8)

        let manager = AttestationManager(attestService: mockService)

        // 1. Generate key
        let keyId = try await manager.generateKey()
        #expect(keyId == "flow-key")

        // 2. Attest key with challenge
        let challenge = Data("challenge".utf8)
        let attestation = try await manager.attestKey(keyId: keyId, challenge: challenge)
        #expect(attestation == Data("attestation".utf8))

        // 3. Generate assertion for request
        let requestData = Data("request".utf8)
        let assertion = try await manager.generateAssertion(requestData: requestData)
        #expect(assertion == Data("assertion".utf8))
    }

    // MARK: - Cleanup Helper

    private func cleanupUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "molten.appAttest.keyId")
    }
}

// MARK: - Mock App Attest Service

@MainActor
class MockAppAttestService: AppAttestServiceProtocol {
    var isSupported: Bool = true

    var mockKeyId: String?
    var mockAttestation: Data?
    var mockAssertion: Data?

    var generateKeyCalled = false
    var attestKeyCalled = false
    var generateAssertionCalled = false

    var lastKeyId: String?
    var lastChallenge: Data?

    func generateKey() async throws -> String {
        generateKeyCalled = true
        guard let keyId = mockKeyId else {
            throw AttestationError.keyGenerationFailed
        }
        return keyId
    }

    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        attestKeyCalled = true
        lastKeyId = keyId
        lastChallenge = clientDataHash
        guard let attestation = mockAttestation else {
            throw AttestationError.attestationFailed
        }
        return attestation
    }

    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        generateAssertionCalled = true
        lastKeyId = keyId
        guard let assertion = mockAssertion else {
            throw AttestationError.assertionFailed
        }
        return assertion
    }
}
