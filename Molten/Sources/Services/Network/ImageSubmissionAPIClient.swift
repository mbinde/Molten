//
//  ImageSubmissionAPIClient.swift
//  Molten
//
//  API client for submitting manufacturer images for consideration
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Error Types

/// Errors that can occur during image submission
public enum ImageSubmissionError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    case rateLimitExceeded(resetAt: Date)
    case unauthorized
    case imageProcessingFailed
    case imageTooLarge(maxMB: Int)
    case termsNotAccepted

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
        case .rateLimitExceeded(let resetAt):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Daily submission limit exceeded. Try again after \(formatter.string(from: resetAt))."
        case .unauthorized:
            return "Unauthorized request"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .imageTooLarge(let maxMB):
            return "Image too large (max \(maxMB)MB)"
        case .termsNotAccepted:
            return "You must accept the terms to submit an image"
        }
    }
}

// MARK: - Response Types

/// Response from a successful image submission
public struct ImageSubmissionResponse {
    public let submissionId: String
}

// MARK: - Protocol

/// Protocol for image submission API operations (for testing)
@MainActor
protocol ImageSubmissionAPIClientProtocol {
    func submitImage(
        image: Data,
        glassItem: GlassItemModel,
        email: String,
        hasPermission: Bool,
        offersFreeOfCharge: Bool
    ) async throws -> ImageSubmissionResponse
}

// MARK: - Implementation

/// API client for submitting community images
@MainActor
class ImageSubmissionAPIClient: ImageSubmissionAPIClientProtocol {

    // MARK: - Properties

    private let session: URLSessionProtocol
    private let baseURL: URL
    private let attestationManager: AttestationManagerProtocol

    /// Maximum image size in MB
    private static let maxImageSizeMB = 5

    /// Default timeout for API requests
    private static let defaultTimeout: TimeInterval = 60  // Longer timeout for image uploads

    /// Default base URL for production API
    static let defaultBaseURL: URL = {
        guard let url = URL(string: "https://www.moltenglass.app") else {
            fatalError("Invalid ImageSubmissionAPIClient base URL configuration")
        }
        return url
    }()

    // MARK: - Initialization

    init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = ImageSubmissionAPIClient.defaultBaseURL,
        attestationManager: AttestationManagerProtocol = AttestationManager()
    ) {
        self.session = session
        self.baseURL = baseURL
        self.attestationManager = attestationManager
    }

    // MARK: - Submit Image

    /// Submit a community image for consideration
    /// - Parameters:
    ///   - image: JPEG image data
    ///   - glassItem: The glass item this image is for
    ///   - email: Contact email address
    ///   - hasPermission: User confirmed they have permission to share
    ///   - offersFreeOfCharge: User offers image free of charge
    /// - Returns: Submission response with ID
    /// - Throws: ImageSubmissionError on failure
    func submitImage(
        image: Data,
        glassItem: GlassItemModel,
        email: String,
        hasPermission: Bool,
        offersFreeOfCharge: Bool
    ) async throws -> ImageSubmissionResponse {

        // Validate terms
        guard hasPermission && offersFreeOfCharge else {
            throw ImageSubmissionError.termsNotAccepted
        }

        // Check image size
        let maxBytes = Self.maxImageSizeMB * 1024 * 1024
        if image.count > maxBytes {
            throw ImageSubmissionError.imageTooLarge(maxMB: Self.maxImageSizeMB)
        }

        // Build URL
        let url = baseURL.appendingPathComponent("api/v1/submit-image")

        // Build request body
        let requestBody: [String: Any] = [
            "glassItem": [
                "stable_id": glassItem.stable_id,
                "name": glassItem.name,
                "manufacturer": glassItem.manufacturer,
                "code": glassItem.sku
            ],
            "email": email,
            "image": image.base64EncodedString(),
            "hasPermission": true,
            "offersFreeOfCharge": true
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = Self.defaultTimeout

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageSubmissionError.invalidResponse
        }

        // Handle status codes
        switch httpResponse.statusCode {
        case 200:
            // Parse response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool,
               success,
               let submissionId = json["submissionId"] as? String {
                return ImageSubmissionResponse(submissionId: submissionId)
            }
            throw ImageSubmissionError.invalidResponse

        case 400:
            // Bad request - parse error
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                throw ImageSubmissionError.serverError(error)
            }
            throw ImageSubmissionError.serverError("Invalid request")

        case 401:
            throw ImageSubmissionError.unauthorized

        case 413:
            throw ImageSubmissionError.imageTooLarge(maxMB: Self.maxImageSizeMB)

        case 429:
            let resetAt = parseRateLimitReset(from: data, headers: httpResponse.allHeaderFields)
            throw ImageSubmissionError.rateLimitExceeded(resetAt: resetAt)

        default:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                throw ImageSubmissionError.serverError(error)
            }
            throw ImageSubmissionError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }

    // MARK: - Private Helpers

    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw ImageSubmissionError.networkError(error)
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

    private func parseRateLimitReset(from data: Data, headers: [AnyHashable: Any]) -> Date {
        // Try X-RateLimit-Reset header first
        if let resetAtString = headers["X-RateLimit-Reset"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: resetAtString) {
                return date
            }
        }

        // Try response body
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
