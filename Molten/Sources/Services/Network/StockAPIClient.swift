//
//  StockAPIClient.swift
//  Molten
//
//  API client for stock database update operations.
//  Handles version checking and database downloads.
//

import Foundation
import OSLog

// MARK: - Version Metadata

/// Metadata about the current stock database version
struct StockVersionMetadata: Codable, Equatable {
    let version: Int
    let releaseDate: Date
    let fileSize: Int64
    let checksum: String

    enum CodingKeys: String, CodingKey {
        case version
        case releaseDate = "release_date"
        case fileSize = "file_size"
        case checksum
    }
}

// MARK: - Errors

enum StockAPIError: LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError(String)
    case checksumMismatch
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error (HTTP \(statusCode))"
        case .decodingError(let message):
            return "Failed to parse response: \(message)"
        case .checksumMismatch:
            return "Downloaded file checksum doesn't match expected value"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}

// MARK: - Protocol

/// Protocol for stock API operations
@MainActor
protocol StockAPIClientProtocol {
    func getLatestVersion() async throws -> StockVersionMetadata
    func downloadStockDatabase(progressHandler: (@Sendable (Double) -> Void)?) async throws -> Data
}

// MARK: - Implementation

/// API client for stock database operations
@MainActor
class StockAPIClient: NSObject, StockAPIClientProtocol {

    private let session: URLSessionProtocol
    private let baseURL: URL
    private let log = Logger(subsystem: "Molten", category: "StockAPI")

    init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = URL(string: "https://www.moltenglass.app")!
    ) {
        self.session = session
        self.baseURL = baseURL
        super.init()
    }

    // MARK: - Version Check

    /// Get latest stock database version metadata
    func getLatestVersion() async throws -> StockVersionMetadata {
        let url = baseURL.appendingPathComponent("api/v1/stock/version")
        log.debug("Fetching stock version from: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                return try decoder.decode(StockVersionMetadata.self, from: data)
            } catch {
                log.error("Failed to decode stock version: \(error)")
                throw StockAPIError.decodingError(error.localizedDescription)
            }

        case 404:
            // No stock database available yet
            log.info("No stock database available (404)")
            throw StockAPIError.serverError(statusCode: 404)

        default:
            throw StockAPIError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Database Download

    /// Download the full stock SQLite database
    /// - Parameter progressHandler: Optional closure for progress updates (0.0 to 1.0)
    /// - Returns: Stock SQLite database data (uncompressed binary)
    func downloadStockDatabase(
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> Data {

        let url = baseURL.appendingPathComponent("api/v1/stock/database")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/x-sqlite3", forHTTPHeaderField: "Accept")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 120  // 2 minutes for larger file

        log.info("Downloading stock database...")

        // Use download task for progress tracking
        let delegate = StockDownloadProgressDelegate(progressHandler: progressHandler)
        let (localURL, response) = try await session.download(for: request, delegate: delegate)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            // Read downloaded file
            var data = try Data(contentsOf: localURL)

            // Decompress if gzipped
            if let contentEncoding = httpResponse.value(forHTTPHeaderField: "Content-Encoding"),
               contentEncoding.lowercased() == "gzip" {
                log.debug("Decompressing gzipped stock data")
                data = try data.gunzipped()
            } else if data.isGzipped {
                log.debug("Detected gzipped data, decompressing")
                data = try data.gunzipped()
            }

            log.info("Downloaded stock database: \(data.count) bytes (decompressed)")

            // Verify SQLite file signature
            guard data.count >= 16 else {
                throw StockAPIError.invalidResponse
            }
            let header = String(data: data.prefix(16), encoding: .ascii) ?? ""
            guard header.hasPrefix("SQLite format 3") else {
                log.error("Downloaded file is not a valid SQLite database")
                throw StockAPIError.invalidResponse
            }

            // Cleanup temp file
            try? FileManager.default.removeItem(at: localURL)

            return data

        case 404:
            log.error("Stock database not found")
            throw StockAPIError.serverError(statusCode: 404)

        case 429:
            log.warning("Rate limit exceeded")
            throw StockAPIError.serverError(statusCode: 429)

        default:
            log.error("Server error: \(httpResponse.statusCode)")
            throw StockAPIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Download Progress Delegate

private final class StockDownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

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
