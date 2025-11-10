//
//  CatalogAPIClient.swift
//  Molten
//
//  Created by Assistant on 11/9/25.
//  API client for catalog update operations
//

import Foundation
import OSLog

/// Protocol for catalog API operations (for dependency injection)
@MainActor
protocol CatalogAPIClientProtocol {
    func getLatestVersion() async throws -> CatalogVersionMetadata
    func downloadFullCatalog(version: Int?, progressHandler: ((Double) -> Void)?) async throws -> Data
}

/// API client for catalog update operations
@MainActor
class CatalogAPIClient: NSObject, CatalogAPIClientProtocol {

    // MARK: - Properties

    private let session: URLSessionProtocol
    private let baseURL: URL
    private let attestationManager: AttestationManagerProtocol
    private let pinnedCertificates: [Data]
    private let log = Logger(subsystem: "Molten", category: "CatalogAPI")

    // MARK: - Initialization

    init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = URL(string: "https://api.example.com")!,
        attestationManager: AttestationManagerProtocol = AttestationManager(),
        pinnedCertificates: [Data] = []
    ) {
        self.session = session
        self.baseURL = baseURL
        self.attestationManager = attestationManager
        self.pinnedCertificates = pinnedCertificates
        super.init()
    }

    // MARK: - Version API

    /// Get latest catalog version metadata
    func getLatestVersion() async throws -> CatalogVersionMetadata {
        let url = baseURL.appendingPathComponent("catalog/version")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Optional: Add App Attest assertion
        // (server may not require it for version checks)
        do {
            try await addAttestation(to: &request)
        } catch {
            log.warning("Failed to add App Attest assertion: \(error.localizedDescription)")
            // Continue without attestation - server may allow it
        }

        let (data, response) = try await executeRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CatalogUpdateError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CatalogVersionMetadata.self, from: data)

        case 401, 403:
            throw CatalogUpdateError.serverError(statusCode: httpResponse.statusCode)

        case 429:
            log.warning("Rate limit exceeded for version check")
            throw CatalogUpdateError.serverError(statusCode: 429)

        default:
            throw CatalogUpdateError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Data Download

    /// Download full catalog JSON
    /// - Parameters:
    ///   - version: Specific version to download (nil = latest)
    ///   - progressHandler: Optional closure for progress updates (0.0 to 1.0)
    /// - Returns: Decompressed catalog JSON data
    func downloadFullCatalog(
        version: Int? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> Data {

        var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent("catalog/data"),
            resolvingAgainstBaseURL: true
        )!

        if let version = version {
            urlComponents.queryItems = [
                URLQueryItem(name: "version", value: "\(version)")
            ]
        }

        guard let url = urlComponents.url else {
            throw CatalogUpdateError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        // REQUIRED: Add App Attest assertion for data downloads
        try await addAttestation(to: &request)

        log.info("Downloading catalog (version: \(version?.description ?? "latest"))")

        // Use download task for progress tracking and large files
        let delegate = DownloadProgressDelegate(progressHandler: progressHandler)
        let (localURL, response) = try await session.download(for: request, delegate: delegate)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CatalogUpdateError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            // Read downloaded file
            var data = try Data(contentsOf: localURL)

            // Decompress if gzipped
            if let contentEncoding = httpResponse.value(forHTTPHeaderField: "Content-Encoding"),
               contentEncoding.lowercased() == "gzip" {
                log.debug("Decompressing gzipped catalog data")
                data = try data.gunzipped()
            } else if data.isGzipped {
                log.debug("Detected gzipped data, decompressing")
                data = try data.gunzipped()
            }

            log.info("Downloaded catalog: \(data.count) bytes (decompressed)")

            // Cleanup temp file
            try? FileManager.default.removeItem(at: localURL)

            return data

        case 304:
            log.info("Catalog not modified (304)")
            throw CatalogUpdateError.updateNotAvailable

        case 401, 403:
            log.error("Authentication failed (\(httpResponse.statusCode))")
            throw CatalogUpdateError.serverError(statusCode: httpResponse.statusCode)

        case 404:
            log.error("Catalog version not found")
            throw CatalogUpdateError.updateNotAvailable

        case 429:
            log.warning("Rate limit exceeded")
            throw CatalogUpdateError.serverError(statusCode: 429)

        default:
            log.error("Server error: \(httpResponse.statusCode)")
            throw CatalogUpdateError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    /// Download delta catalog update (v2.0 feature - not implemented in v1.5)
    func downloadDeltaCatalog(from: Int, to: Int) async throws -> CatalogDelta {
        throw CatalogUpdateError.updateNotAvailable  // Not implemented yet
    }

    // MARK: - Private Helpers

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
            // Other attestation errors - log but don't fail request
            log.warning("Attestation failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Execute request and validate response
    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            log.error("Network request failed: \(error.localizedDescription)")
            throw CatalogUpdateError.downloadFailed(underlying: error)
        }
    }
}

// MARK: - Download Progress Delegate

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {

    let progressHandler: ((Double) -> Void)?

    init(progressHandler: ((Double) -> Void)?) {
        self.progressHandler = progressHandler
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        Task { @MainActor in
            progressHandler?(progress)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Download completed - handled by async/await return value
    }
}
