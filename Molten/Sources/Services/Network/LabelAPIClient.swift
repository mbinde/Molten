//
//  LabelAPIClient.swift
//  Molten
//
//  API client for label database update operations
//

import Foundation
import OSLog

/// Protocol for label API operations (for dependency injection)
@MainActor
protocol LabelAPIClientProtocol {
    func getLatestVersion() async throws -> LabelVersionMetadata
    func downloadDatabase(version: Int?, progressHandler: (@Sendable (Double) -> Void)?) async throws -> Data
}

/// API client for label database updates
@MainActor
class LabelAPIClient: NSObject, LabelAPIClientProtocol {

    // MARK: - Properties

    private let session: URLSessionProtocol
    private let baseURL: URL
    private let log = Logger(subsystem: "Molten", category: "LabelAPI")

    // MARK: - Initialization

    init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = URL(string: "https://www.moltenglass.app")!
    ) {
        self.session = session
        self.baseURL = baseURL
        super.init()
    }

    // MARK: - Version API

    /// Get latest label database version metadata
    func getLatestVersion() async throws -> LabelVersionMetadata {
        let url = baseURL.appendingPathComponent("api/v1/labels/version")
        log.debug("📡 Fetching label version from: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await executeRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LabelUpdateError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                let metadata = try decoder.decode(LabelVersionMetadata.self, from: data)
                log.info("✅ Label version: \(metadata.version)")
                return metadata
            } catch {
                log.error("Failed to decode label version metadata: \(error)")
                throw LabelUpdateError.invalidResponse
            }

        case 429:
            log.warning("Rate limit exceeded for label version check")
            throw LabelUpdateError.serverError(statusCode: 429)

        default:
            throw LabelUpdateError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Database Download

    /// Download label database
    /// - Parameters:
    ///   - version: Specific version to download (nil = latest)
    ///   - progressHandler: Optional closure for progress updates (0.0 to 1.0)
    /// - Returns: Label SQLite database data
    func downloadDatabase(
        version: Int? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> Data {

        var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent("api/v1/labels/database"),
            resolvingAgainstBaseURL: true
        )!

        if let version = version {
            urlComponents.queryItems = [
                URLQueryItem(name: "version", value: "\(version)")
            ]
        }

        guard let url = urlComponents.url else {
            throw LabelUpdateError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/x-sqlite3", forHTTPHeaderField: "Accept")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        log.info("Downloading label database (version: \(version?.description ?? "latest"))")

        // Download without delegate for simplicity (progress tracking not critical for small DB)
        let (localURL, response) = try await session.download(for: request, delegate: nil)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LabelUpdateError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            // Read downloaded file
            var data = try Data(contentsOf: localURL)

            // Decompress if gzipped
            if let contentEncoding = httpResponse.value(forHTTPHeaderField: "Content-Encoding"),
               contentEncoding.lowercased() == "gzip" {
                log.debug("Decompressing gzipped label data")
                data = try data.gunzipped()
            } else if data.isGzipped {
                log.debug("Detected gzipped data, decompressing")
                data = try data.gunzipped()
            }

            log.info("Downloaded label database: \(data.count) bytes (decompressed)")

            // Verify SQLite file signature
            guard data.count >= 16 else {
                throw LabelUpdateError.invalidDatabase
            }
            let header = String(data: data.prefix(16), encoding: .ascii) ?? ""
            guard header.hasPrefix("SQLite format 3") else {
                log.error("Downloaded file is not a valid SQLite database")
                throw LabelUpdateError.invalidDatabase
            }

            // Cleanup temp file
            try? FileManager.default.removeItem(at: localURL)

            return data

        case 304:
            log.info("Label database not modified (304)")
            throw LabelUpdateError.updateNotAvailable

        case 404:
            log.error("Label database version not found")
            throw LabelUpdateError.updateNotAvailable

        case 429:
            log.warning("Rate limit exceeded")
            throw LabelUpdateError.serverError(statusCode: 429)

        default:
            log.error("Server error: \(httpResponse.statusCode)")
            throw LabelUpdateError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Private Helpers

    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            log.error("Network request failed: \(error.localizedDescription)")
            throw LabelUpdateError.downloadFailed(underlying: error)
        }
    }
}

// MARK: - Download Progress Delegate

private final class LabelDownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    let progressHandler: (@Sendable (Double) -> Void)?

    init(progressHandler: (@Sendable (Double) -> Void)?) {
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
