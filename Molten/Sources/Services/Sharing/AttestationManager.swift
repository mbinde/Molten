//
//  AttestationManager.swift
//  Molten
//
//  Manages App Attest key generation, attestation, and assertion generation
//  Provides cryptographic proof that requests come from the legitimate app
//

import Foundation
import DeviceCheck
import CryptoKit

/// Errors that can occur during attestation operations
public enum AttestationError: Error, LocalizedError {
    case keyGenerationFailed
    case attestationFailed
    case assertionFailed
    case noKeyExists
    case unsupported

    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate attestation key"
        case .attestationFailed:
            return "Failed to attest key with server"
        case .assertionFailed:
            return "Failed to generate assertion"
        case .noKeyExists:
            return "No attestation key exists. Generate one first."
        case .unsupported:
            return "App Attest is not supported on this device"
        }
    }
}

/// Protocol for App Attest service (for testing)
@MainActor
public protocol AppAttestServiceProtocol {
    var isSupported: Bool { get }
    func generateKey() async throws -> String
    func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data
}

/// Production implementation wrapping DCAppAttestService
@MainActor
public class AppAttestServiceAdapter: AppAttestServiceProtocol {
    private let service = DCAppAttestService.shared

    public init() {}

    public var isSupported: Bool {
        service.isSupported
    }

    public func generateKey() async throws -> String {
        try await service.generateKey()
    }

    public func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await service.attestKey(keyId, clientDataHash: clientDataHash)
    }

    public func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
        try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
    }
}

/// Protocol for attestation management (for dependency injection)
@MainActor
public protocol AttestationManagerProtocol {
    var isSupported: Bool { get }
    func generateAssertion(requestData: Data) async throws -> Data
    func createRequestData(method: String, path: String, body: Data?) -> Data
}

/// Manages App Attest attestation and assertion generation
@MainActor
public class AttestationManager: AttestationManagerProtocol {

    // MARK: - Properties

    private let attestService: AppAttestServiceProtocol
    private let userDefaults: UserDefaults
    private let keyIdKey = "molten.appAttest.keyId"

    // MARK: - Initialization

    public init(
        attestService: AppAttestServiceProtocol = AppAttestServiceAdapter(),
        userDefaults: UserDefaults = .standard
    ) {
        self.attestService = attestService
        self.userDefaults = userDefaults
    }

    // MARK: - Device Support

    public var isSupported: Bool {
        attestService.isSupported
    }

    // MARK: - Key Management

    /// Generate or retrieve existing attestation key
    /// - Returns: Key identifier
    public func generateKey() async throws -> String {
        // Return existing key if available
        if let existingKeyId = userDefaults.string(forKey: keyIdKey) {
            return existingKeyId
        }

        // Generate new key
        guard isSupported else {
            throw AttestationError.unsupported
        }

        let keyId = try await attestService.generateKey()

        // Store key ID
        userDefaults.set(keyId, forKey: keyIdKey)

        return keyId
    }

    /// Get current key ID if one exists
    public var currentKeyId: String? {
        userDefaults.string(forKey: keyIdKey)
    }

    // MARK: - Attestation

    /// Attest the key with server challenge
    /// - Parameters:
    ///   - keyId: Key identifier to attest
    ///   - challenge: Server challenge data
    /// - Returns: Attestation object to send to server
    public func attestKey(keyId: String, challenge: Data) async throws -> Data {
        guard isSupported else {
            throw AttestationError.unsupported
        }

        // Hash the challenge
        let hash = SHA256.hash(data: challenge)
        let clientDataHash = Data(hash)

        do {
            let attestation = try await attestService.attestKey(keyId, clientDataHash: clientDataHash)
            return attestation
        } catch {
            throw AttestationError.attestationFailed
        }
    }

    // MARK: - Assertions

    /// Generate assertion for API request
    /// - Parameter requestData: Data representing the request (method + path + body hash)
    /// - Returns: Assertion data to include in request header
    public func generateAssertion(requestData: Data) async throws -> Data {
        guard isSupported else {
            throw AttestationError.unsupported
        }

        guard let keyId = currentKeyId else {
            throw AttestationError.noKeyExists
        }

        // Hash the request data
        let hash = SHA256.hash(data: requestData)
        let clientDataHash = Data(hash)

        do {
            let assertion = try await attestService.generateAssertion(keyId, clientDataHash: clientDataHash)
            return assertion
        } catch {
            throw AttestationError.assertionFailed
        }
    }

    // MARK: - Helpers

    /// Create request data for assertion from HTTP request components
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - path: Request path
    ///   - body: Request body (optional)
    /// - Returns: Combined data for assertion
    public func createRequestData(method: String, path: String, body: Data?) -> Data {
        var components = [method, path]

        if let body = body {
            let bodyHash = SHA256.hash(data: body)
            components.append(bodyHash.compactMap { String(format: "%02x", $0) }.joined())
        }

        return components.joined(separator: "-").data(using: .utf8) ?? Data()
    }
}
