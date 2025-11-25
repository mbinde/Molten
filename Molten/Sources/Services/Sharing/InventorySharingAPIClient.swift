//
//  InventorySharingAPIClient.swift
//  Molten
//
//  API client for uploading and downloading inventory snapshots
//  Handles server communication for inventory sharing
//

import Foundation

/// API client for inventory sharing operations
@MainActor
class InventorySharingAPIClient: NSObject {

    // MARK: - Properties

    private let session: URLSessionProtocol
    private let baseURL: URL
    private let attestationManager: AttestationManager
    private let pinnedCertificates: [Data]

    /// Default base URL for production API
    /// Using static let ensures URL parsing happens once at startup, not at runtime
    private static let defaultBaseURL: URL = {
        guard let url = URL(string: "https://www.moltenglass.app") else {
            fatalError("Invalid InventorySharingAPIClient base URL configuration")
        }
        return url
    }()

    // MARK: - Initialization

    init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = InventorySharingAPIClient.defaultBaseURL,
        attestationManager: AttestationManager = AttestationManager(),
        pinnedCertificates: [Data] = []
    ) {
        self.session = session
        self.baseURL = baseURL
        self.attestationManager = attestationManager
        self.pinnedCertificates = pinnedCertificates
        super.init()
    }

    // MARK: - Upload

    /// Upload inventory snapshot with share code
    /// - Parameters:
    ///   - shareCode: Share code for this snapshot
    ///   - snapshotData: Serialized snapshot data
    ///   - publicKey: Public key for signature verification
    open func uploadSnapshot(shareCode: String, snapshotData: Data, publicKey: Data) async throws {
        let url = baseURL.appendingPathComponent("api/v1/share")

        // Create request body
        let requestBody: [String: Any] = [
            "shareCode": shareCode,
            "snapshotData": snapshotData.base64EncodedString(),
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
        let (_, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 201:
            return // Success - 201 Created is the ONLY valid response for POST
            // NOTE: 200 OK is NOT valid here - it likely means we hit the wrong endpoint and got HTML
        case 200:
            // This indicates we hit the wrong URL (e.g., Astro homepage returning 200)
            throw SharingAPIError.invalidResponse
        case 409:
            throw SharingAPIError.conflict
        case 401, 403:
            throw SharingAPIError.unauthorized
        default:
            throw SharingAPIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Download

    /// Download inventory snapshot by share code
    /// - Parameter shareCode: Share code to download
    /// - Returns: Downloaded snapshot with public key
    open func downloadSnapshot(shareCode: String) async throws -> DownloadedSnapshot {
        let url = baseURL.appendingPathComponent("api/v1/share").appendingPathComponent(shareCode)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 404:
            throw SharingAPIError.notFound
        case 401, 403:
            throw SharingAPIError.unauthorized
        default:
            throw SharingAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let snapshotBase64 = json["snapshotData"] as? String,
              let publicKeyBase64 = json["publicKey"] as? String,
              let snapshotData = Data(base64Encoded: snapshotBase64),
              let publicKey = Data(base64Encoded: publicKeyBase64) else {
            throw SharingAPIError.invalidData
        }

        // Extract optional metadata (displayName, shareNotes, expiresAt)
        let displayName = json["displayName"] as? String
        let shareNotes = json["shareNotes"] as? String
        let expiresAt: Date?
        if let expiresAtString = json["expiresAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            expiresAt = formatter.date(from: expiresAtString)
        } else {
            expiresAt = nil
        }

        return DownloadedSnapshot(
            snapshotData: snapshotData,
            publicKey: publicKey,
            displayName: displayName,
            shareNotes: shareNotes,
            expiresAt: expiresAt
        )
    }

    // MARK: - Delete

    /// Delete a share by code
    /// - Parameters:
    ///   - shareCode: Share code to delete
    ///   - ownershipSignature: Signature proving ownership (signed with original private key)
    open func deleteShare(shareCode: String, ownershipSignature: Data) async throws {
        let url = baseURL.appendingPathComponent("api/v1/share").appendingPathComponent(shareCode)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        // Add ownership signature
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (_, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 204:
            return // Success
        case 404:
            throw SharingAPIError.notFound
        case 401, 403:
            throw SharingAPIError.unauthorized
        default:
            throw SharingAPIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Update

    /// Update an existing share with new snapshot data
    /// - Parameters:
    ///   - shareCode: Share code to update
    ///   - snapshotData: New serialized snapshot data
    ///   - publicKey: Public key for signature verification
    ///   - ownershipSignature: Signature proving ownership (signed with original private key)
    open func updateSnapshot(shareCode: String, snapshotData: Data, publicKey: Data, ownershipSignature: Data) async throws {
        let url = baseURL.appendingPathComponent("api/v1/share").appendingPathComponent(shareCode)

        // Create request body
        let requestBody: [String: Any] = [
            "snapshotData": snapshotData.base64EncodedString(),
            "publicKey": publicKey.base64EncodedString()
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // Add ownership signature
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (_, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return // Success
        case 404:
            throw SharingAPIError.notFound
        case 401, 403:
            throw SharingAPIError.unauthorized
        default:
            throw SharingAPIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Expiring Shares

    /// Create an expiring share alias
    /// - Parameters:
    ///   - mainShareCode: The main share code to create an alias for
    ///   - displayName: Display name for this expiring share
    ///   - shareNotes: Optional notes for this expiring share
    ///   - expirationDuration: Duration in seconds until expiration
    /// - Returns: Tuple of (new share code, expiration date)
    open func createExpiringShare(
        mainShareCode: String,
        displayName: String,
        shareNotes: String?,
        expirationDuration: TimeInterval
    ) async throws -> (shareCode: String, expiresAt: Date) {
        let url = baseURL.appendingPathComponent("api/v1/share/expiring")

        // Create request body
        var requestBody: [String: Any] = [
            "mainShareCode": mainShareCode,
            "displayName": displayName,
            "expirationDuration": Int(expirationDuration)
        ]

        if let notes = shareNotes {
            requestBody["shareNotes"] = notes
        }

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
            throw SharingAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 201:
            break // Success - 201 Created is the ONLY valid response for POST
        case 200:
            // This indicates we hit the wrong URL (e.g., Astro homepage returning 200)
            throw SharingAPIError.invalidResponse
        case 404:
            throw SharingAPIError.notFound
        case 401, 403:
            throw SharingAPIError.unauthorized
        default:
            throw SharingAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shareCode = json["shareCode"] as? String,
              let expiresAtString = json["expiresAt"] as? String else {
            throw SharingAPIError.invalidData
        }

        // Parse ISO 8601 date with fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let expiresAt = formatter.date(from: expiresAtString) else {
            throw SharingAPIError.invalidData
        }

        return (shareCode, expiresAt)
    }

    /// Fetch all expiring shares for a main share code
    /// - Parameter mainShareCode: The main share code
    /// - Returns: Array of expiring share records
    open func fetchExpiringShares(forMainShareCode mainShareCode: String) async throws -> [ExpiringShareServerResponse] {
        let url = baseURL
            .appendingPathComponent("api/v1/share")
            .appendingPathComponent(mainShareCode)
            .appendingPathComponent("expiring")

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 404:
            throw SharingAPIError.notFound
        case 401, 403:
            throw SharingAPIError.unauthorized
        default:
            throw SharingAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let expiringSharesArray = json["expiringShares"] as? [[String: Any]] else {
            throw SharingAPIError.invalidData
        }

        let formatter = ISO8601DateFormatter()
        var shares: [ExpiringShareServerResponse] = []

        for shareDict in expiringSharesArray {
            guard let shareCode = shareDict["shareCode"] as? String,
                  let displayName = shareDict["displayName"] as? String,
                  let expiresAtString = shareDict["expiresAt"] as? String,
                  let createdAtString = shareDict["createdAt"] as? String,
                  let expiresAt = formatter.date(from: expiresAtString),
                  let createdAt = formatter.date(from: createdAtString) else {
                continue // Skip invalid entries
            }

            let shareNotes = shareDict["shareNotes"] as? String

            shares.append(ExpiringShareServerResponse(
                shareCode: shareCode,
                displayName: displayName,
                shareNotes: shareNotes,
                expiresAt: expiresAt,
                createdAt: createdAt
            ))
        }

        return shares
    }

    /// Delete an expiring share
    /// - Parameter shareCode: The expiring share code to delete
    open func deleteExpiringShare(shareCode: String) async throws {
        let url = baseURL
            .appendingPathComponent("api/v1/share/expiring")
            .appendingPathComponent(shareCode)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (_, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 204:
            return // Success
        case 404:
            throw SharingAPIError.notFound
        case 401, 403:
            throw SharingAPIError.unauthorized
        default:
            throw SharingAPIError.serverError(httpResponse.statusCode)
        }
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
            throw SharingAPIError.networkError(error)
        }
    }

    /// Add App Attest assertion to request
    private func addAttestation(to request: inout URLRequest) async throws {
        guard attestationManager.isSupported else {
            // App Attest not supported, skip
            return
        }

        // Create request data for assertion
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""
        let body = request.httpBody

        let requestData = attestationManager.createRequestData(method: method, path: path, body: body)

        // Generate assertion
        do {
            let assertion = try await attestationManager.generateAssertion(requestData: requestData)
            request.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-Apple-Assertion")
        } catch AttestationError.noKeyExists {
            // No key exists yet, skip attestation (will be added after first registration)
            return
        } catch {
            // Other attestation errors should fail the request
            throw error
        }
    }
}

// MARK: - URLSessionDelegate (Certificate Pinning)

extension InventorySharingAPIClient: URLSessionDelegate {

    nonisolated public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // If no pinned certificates, use default handling
        guard !pinnedCertificates.isEmpty else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Get server certificate
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data

        // Check if server certificate matches any pinned certificate
        let isPinned = pinnedCertificates.contains { pinnedCert in
            pinnedCert == serverCertificateData
        }

        if isPinned {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // Certificate doesn't match pinned certificates
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
