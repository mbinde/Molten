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

    // MARK: - Initialization

    init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = URL(string: "https://api.example.com")!,
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
        let url = baseURL.appendingPathComponent("v1/share")

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
            return // Success
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
        let url = baseURL.appendingPathComponent("v1/share").appendingPathComponent(shareCode)

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

        return DownloadedSnapshot(snapshotData: snapshotData, publicKey: publicKey)
    }

    // MARK: - Delete

    /// Delete a share by code
    /// - Parameters:
    ///   - shareCode: Share code to delete
    ///   - ownershipSignature: Signature proving ownership (signed with original private key)
    open func deleteShare(shareCode: String, ownershipSignature: Data) async throws {
        let url = baseURL.appendingPathComponent("v1/share").appendingPathComponent(shareCode)

        print("🔐 [API] DELETE URL: \(url)")
        print("🔐 [API] Ownership signature (base64): \(ownershipSignature.base64EncodedString())")

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        // Add ownership signature
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        print("🔐 [API] Request headers: \(request.allHTTPHeaderFields ?? [:])")

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SharingAPIError.invalidResponse
        }

        print("🔐 [API] Response status: \(httpResponse.statusCode)")

        // Log response body for debugging
        if let responseBody = String(data: data, encoding: .utf8) {
            print("🔐 [API] Response body: \(responseBody)")
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
        let url = baseURL.appendingPathComponent("v1/share").appendingPathComponent(shareCode)

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

    // MARK: - Private Helpers

    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
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
