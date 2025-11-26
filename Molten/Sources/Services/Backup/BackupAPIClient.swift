//
//  BackupAPIClient.swift
//  Molten
//
//  API client for backup operations
//  Handles server communication for automatic inventory backups
//

import Foundation

/// API client for backup operations
@MainActor
class BackupAPIClient: NSObject {

    // MARK: - Properties

    private let session: URLSessionProtocol
    private let baseURL: URL
    private let attestationManager: AttestationManagerProtocol

    /// Default base URL for production API
    /// Using static let ensures URL parsing happens once at startup, not at runtime
    private static let defaultBaseURL: URL = {
        guard let url = URL(string: "https://www.moltenglass.app") else {
            fatalError("Invalid BackupAPIClient base URL configuration")
        }
        return url
    }()

    // MARK: - Initialization

    init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = BackupAPIClient.defaultBaseURL,
        attestationManager: AttestationManagerProtocol = AttestationManager()
    ) {
        self.session = session
        self.baseURL = baseURL
        self.attestationManager = attestationManager
        super.init()
    }

    // MARK: - Register Backup Key

    /// Register a new backup key with its public key
    /// - Parameters:
    ///   - backupKey: The backup key to register (e.g., "A1B-C2D-E3F")
    ///   - publicKey: Ed25519 public key for ownership verification
    /// - Throws: BackupAPIError on failure
    open func registerBackupKey(_ backupKey: String, publicKey: Data) async throws {
        let url = baseURL.appendingPathComponent("api/v1/backup/register")

        // Create request body
        let requestBody: [String: Any] = [
            "backupKey": backupKey,
            "publicKey": publicKey.base64EncodedString()
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackupAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 201:
            return // Success
        case 409:
            throw BackupAPIError.conflict
        case 401, 403:
            throw BackupAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw BackupAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw BackupAPIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Upload Backup

    /// Upload a backup
    /// - Parameters:
    ///   - backupKey: The backup key
    ///   - type: Backup type ("inventory" or "tags")
    ///   - data: Base64-encoded backup data
    ///   - checksum: SHA-256 checksum for deduplication
    ///   - ownershipSignature: Ed25519 signature of the backup key
    /// - Returns: Upload result with timestamp and skip status
    open func uploadBackup(
        backupKey: String,
        type: String,
        data: String,
        checksum: String,
        ownershipSignature: Data
    ) async throws -> BackupUploadResult {
        let url = baseURL.appendingPathComponent("api/v1/backup/\(backupKey)")

        // Create request body
        let requestBody: [String: Any] = [
            "type": type,
            "data": data,
            "checksum": checksum
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // Add ownership signature
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (responseData, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackupAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201:
            break // Success
        case 404:
            throw BackupAPIError.notFound
        case 401, 403:
            throw BackupAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: responseData)
            throw BackupAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw BackupAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw BackupAPIError.invalidData
        }

        let skipped = json["skipped"] as? Bool ?? false
        let timestamp = json["timestamp"] as? String ?? json["latestTimestamp"] as? String

        return BackupUploadResult(
            skipped: skipped,
            timestamp: timestamp
        )
    }

    // MARK: - Download Backup

    /// Download the latest backup of a type
    /// - Parameters:
    ///   - backupKey: The backup key
    ///   - type: Backup type ("inventory" or "tags")
    /// - Returns: Downloaded backup data
    open func downloadBackup(backupKey: String, type: String) async throws -> BackupDownloadResult {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent("api/v1/backup/\(backupKey)"), resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [URLQueryItem(name: "type", value: type)]

        guard let url = urlComponents.url else {
            throw BackupAPIError.invalidResponse
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackupAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 404:
            throw BackupAPIError.notFound
        case 401, 403:
            throw BackupAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw BackupAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw BackupAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let backupData = json["data"] as? String,
              let checksum = json["checksum"] as? String,
              let timestamp = json["timestamp"] as? String else {
            throw BackupAPIError.invalidData
        }

        let backupCount = json["backupCount"] as? Int ?? 0

        return BackupDownloadResult(
            data: backupData,
            checksum: checksum,
            timestamp: timestamp,
            backupCount: backupCount
        )
    }

    // MARK: - Private Helpers

    /// Default timeout for API requests (30 seconds)
    private static let defaultTimeout: TimeInterval = 30

    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var requestWithTimeout = request
        // Set timeout if not already configured
        if requestWithTimeout.timeoutInterval == 60 { // 60 is the default
            requestWithTimeout.timeoutInterval = Self.defaultTimeout
        }
        do {
            return try await session.data(for: requestWithTimeout)
        } catch {
            throw BackupAPIError.networkError(error)
        }
    }

    /// Add App Attest assertion to request
    private func addAttestation(to request: inout URLRequest) async throws {
        guard attestationManager.isSupported else {
            return
        }

        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""
        let body = request.httpBody

        let requestData = attestationManager.createRequestData(method: method, path: path, body: body)

        do {
            let assertion = try await attestationManager.generateAssertion(requestData: requestData)
            request.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-Apple-Assertion")
        } catch AttestationError.noKeyExists {
            // No key exists yet, skip attestation
            return
        } catch {
            throw error
        }
    }

    private func parseRateLimitReset(from data: Data) -> Date {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let resetAtString = json["resetAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: resetAtString) {
                return date
            }
        }
        return Date().addingTimeInterval(3600) // Default: 1 hour from now
    }
}

// MARK: - Response Types

/// Result of a backup upload operation
struct BackupUploadResult {
    let skipped: Bool
    let timestamp: String?
}

/// Result of a backup download operation
struct BackupDownloadResult {
    let data: String
    let checksum: String
    let timestamp: String
    let backupCount: Int
}
