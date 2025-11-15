//
//  RatingAPIClient.swift
//  Molten
//
//  API client for rating system endpoints
//

import Foundation

/// Errors that can occur during rating API operations
public enum RatingAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    case rateLimitExceeded
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .unauthorized:
            return "Unauthorized request"
        }
    }
}

/// Protocol for rating API operations (for testing)
public protocol RatingAPIClientProtocol {
    func submitRating(_ submission: RatingSubmissionModel, userIdHash: String, attestToken: String) async throws
    func fetchAllRatingsBulk() async throws -> [AggregatedRatingModel]
    func fetchRatings(itemStableIds: [String]) async throws -> [AggregatedRatingModel]
    func deleteAllRatings(userIdHash: String, attestToken: String) async throws -> Int
}

/// API client for rating system
public class RatingAPIClient: RatingAPIClientProtocol {

    // MARK: - Properties

    private let baseURL: String
    private let session: URLSession

    // MARK: - Initialization

    public init(
        baseURL: String = "https://www.moltenglass.app",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Submit Rating

    public func submitRating(
        _ submission: RatingSubmissionModel,
        userIdHash: String,
        attestToken: String
    ) async throws {
        // Build URL
        guard let url = URL(string: "\(baseURL)/api/v1/ratings/submit") else {
            throw RatingAPIError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        let body: [String: Any] = [
            "itemStableId": submission.itemStableId,
            "cloudkitUserIdHash": userIdHash,
            "starRating": submission.starRating,
            "words": submission.words,
            "appAttestToken": attestToken
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Execute request
        let (data, response) = try await session.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RatingAPIError.invalidResponse
        }

        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            // Success
            return
        case 429:
            throw RatingAPIError.rateLimitExceeded
        case 401:
            throw RatingAPIError.unauthorized
        default:
            // Try to parse error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                throw RatingAPIError.serverError(error)
            }
            throw RatingAPIError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }

    // MARK: - Fetch Ratings

    /// Fetch all ratings in bulk (single optimized request)
    public func fetchAllRatingsBulk() async throws -> [AggregatedRatingModel] {
        guard let url = URL(string: "\(baseURL)/api/v1/ratings/bulk") else {
            throw RatingAPIError.invalidURL
        }

        // Build request (allow caching since server sends Cache-Control headers)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Execute request
        let (data, response) = try await session.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RatingAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw RatingAPIError.serverError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response with custom date decoding
        // The response has ISO8601 generatedAt but Unix timestamp lastAggregated in ratings
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Custom date decoder to handle both formats
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            // Try Unix timestamp first
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }

            // Try ISO8601
            if let dateString = try? container.decode(String.self) {
                let formatter = ISO8601DateFormatter()
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }

        let json = try decoder.decode(BulkRatingsResponse.self, from: data)
        print("✅ [RatingAPIClient] Fetched \(json.count) ratings in bulk")
        return json.ratings
    }

    /// Fetch specific ratings by item IDs (deprecated - use fetchAllRatingsBulk instead)
    public func fetchRatings(itemStableIds: [String]) async throws -> [AggregatedRatingModel] {
        // Build URL with query parameters
        let itemsParam = itemStableIds.joined(separator: ",")
        guard let url = URL(string: "\(baseURL)/api/v1/ratings/fetch?items=\(itemsParam)") else {
            throw RatingAPIError.invalidURL
        }

        // Build request (disable cache to always get fresh data)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"

        // Execute request
        let (data, response) = try await session.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RatingAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw RatingAPIError.serverError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response directly to models
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970

        let json = try decoder.decode(FetchRatingsResponse.self, from: data)
        return json.ratings
    }

    // MARK: - Delete All Ratings

    public func deleteAllRatings(userIdHash: String, attestToken: String) async throws -> Int {
        // Build URL
        guard let url = URL(string: "\(baseURL)/api/v1/ratings/delete") else {
            throw RatingAPIError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        let body: [String: Any] = [
            "cloudkitUserIdHash": userIdHash,
            "appAttestToken": attestToken
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Execute request
        let (data, response) = try await session.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RatingAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw RatingAPIError.serverError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let deletedCount = json["deletedCount"] as? Int {
            return deletedCount
        }

        return 0
    }
}

// MARK: - Response Types

private struct FetchRatingsResponse: Codable {
    let ratings: [AggregatedRatingModel]
}

private struct BulkRatingsResponse: Codable {
    let ratings: [AggregatedRatingModel]
    let generatedAt: Date
    let count: Int
}
