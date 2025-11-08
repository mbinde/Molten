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
final class InventorySharingAPIClient {

    // MARK: - Properties

    private let session: URLSessionProtocol
    private let baseURL: URL

    // MARK: - Initialization

    init(session: URLSessionProtocol = URLSession.shared, baseURL: URL = URL(string: "https://api.example.com")!) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: - Upload

    /// Upload inventory snapshot with share code
    /// - Parameters:
    ///   - shareCode: Share code for this snapshot
    ///   - snapshotData: Serialized snapshot data
    ///   - publicKey: Public key for signature verification
    func uploadSnapshot(shareCode: String, snapshotData: Data, publicKey: Data) async throws {
        let url = baseURL.appendingPathComponent("share")

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
    func downloadSnapshot(shareCode: String) async throws -> DownloadedSnapshot {
        let url = baseURL.appendingPathComponent("share").appendingPathComponent(shareCode)

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
    /// - Parameter shareCode: Share code to delete
    func deleteShare(shareCode: String) async throws {
        let url = baseURL.appendingPathComponent("share").appendingPathComponent(shareCode)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

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
    func updateSnapshot(shareCode: String, snapshotData: Data, publicKey: Data) async throws {
        let url = baseURL.appendingPathComponent("share").appendingPathComponent(shareCode)

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
}
