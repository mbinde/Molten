//
//  OnlineStockAPIClient.swift
//  Molten
//
//  API client for fetching online stock availability data
//

import Foundation
import os

// MARK: - Protocol

/// Protocol for online stock API operations
@MainActor
protocol OnlineStockAPIClientProtocol {
    /// Fetch stock availability for a single item
    func fetchStock(for itemStableId: String) async throws -> OnlineStockModel
    /// Fetch stock availability for multiple items
    func fetchStockBulk(for itemStableIds: [String]) async throws -> [OnlineStockModel]
}

// MARK: - Errors

/// Errors that can occur during online stock API operations
enum OnlineStockAPIError: LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError(String)
    case itemNotFound

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
        case .itemNotFound:
            return "Item not found"
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case (.networkError(let a), .networkError(let b)):
            return a == b
        case (.invalidResponse, .invalidResponse):
            return true
        case (.serverError(let a), .serverError(let b)):
            return a == b
        case (.decodingError(let a), .decodingError(let b)):
            return a == b
        case (.itemNotFound, .itemNotFound):
            return true
        default:
            return false
        }
    }
}

// MARK: - Implementation

/// API client for fetching online stock availability data from the backend
@MainActor
class OnlineStockAPIClient: OnlineStockAPIClientProtocol {
    private let session: URLSessionProtocol
    private let baseURL: URL
    private let log = Logger(subsystem: "Molten", category: "OnlineStockAPI")

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = URL(string: "https://www.moltenglass.app")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    /// Fetch stock availability for a single item
    /// - Parameter itemStableId: The stable ID of the item to check
    /// - Returns: Stock availability data for the item
    func fetchStock(for itemStableId: String) async throws -> OnlineStockModel {
        let url = baseURL.appendingPathComponent("api/v1/stock/\(itemStableId)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OnlineStockAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try decoder.decode(OnlineStockModel.self, from: data)
            } catch {
                log.error("Decoding error: \(error.localizedDescription)")
                throw OnlineStockAPIError.decodingError(error.localizedDescription)
            }
        case 404:
            throw OnlineStockAPIError.itemNotFound
        default:
            throw OnlineStockAPIError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    /// Fetch stock availability for multiple items
    /// - Parameter itemStableIds: Array of stable IDs to check
    /// - Returns: Array of stock availability data for each item
    func fetchStockBulk(for itemStableIds: [String]) async throws -> [OnlineStockModel] {
        let url = baseURL.appendingPathComponent("api/v1/stock/bulk")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["items": itemStableIds])
        request.timeoutInterval = 60

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OnlineStockAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OnlineStockAPIError.serverError(statusCode: httpResponse.statusCode)
        }

        struct BulkResponse: Codable {
            let items: [OnlineStockModel]
        }

        do {
            let result = try decoder.decode(BulkResponse.self, from: data)
            return result.items
        } catch {
            log.error("Bulk decoding error: \(error.localizedDescription)")
            throw OnlineStockAPIError.decodingError(error.localizedDescription)
        }
    }
}
