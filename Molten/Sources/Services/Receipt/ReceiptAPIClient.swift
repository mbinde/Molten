//
//  ReceiptAPIClient.swift
//  Molten
//
//  API client for receipt import operations
//  Handles server communication for receipt email imports
//

import CryptoKit
import Foundation

/// A candidate match from the catalog
public struct MatchCandidate: Codable, Identifiable, Sendable {
    public var id: String { catalogStableId }
    public let catalogStableId: String
    public let catalogName: String
    public let catalogManufacturer: String
    public let catalogType: String
    public let catalogSubtype: String?
    public let confidence: Double
    public let matchMethod: String
    public let matchDetails: String?

    enum CodingKeys: String, CodingKey {
        case catalogStableId = "catalog_stable_id"
        case catalogName = "catalog_name"
        case catalogManufacturer = "catalog_manufacturer"
        case catalogType = "catalog_type"
        case catalogSubtype = "catalog_subtype"
        case confidence
        case matchMethod = "match_method"
        case matchDetails = "match_details"
    }

    /// Memberwise initializer for creating matches client-side
    public nonisolated init(
        catalogStableId: String,
        catalogName: String,
        catalogManufacturer: String,
        catalogType: String,
        catalogSubtype: String? = nil,
        confidence: Double,
        matchMethod: String,
        matchDetails: String? = nil
    ) {
        self.catalogStableId = catalogStableId
        self.catalogName = catalogName
        self.catalogManufacturer = catalogManufacturer
        self.catalogType = catalogType
        self.catalogSubtype = catalogSubtype
        self.confidence = confidence
        self.matchMethod = matchMethod
        self.matchDetails = matchDetails
    }
}

/// Parsed item from a receipt
public struct ReceiptItem: Codable, Identifiable {
    public let id: Int
    public let rawSku: String?
    public let rawName: String
    public let quantity: Double?
    public let quantityUnit: String?  // e.g., "LB", "OZ", "EA", "1/4 LB"
    public let unitPrice: Double?
    public let totalPrice: Double?
    public let catalogStableId: String?
    public let matchConfidence: Double?
    public let matchMethod: String?
    public let matchCandidates: [MatchCandidate]?

    enum CodingKeys: String, CodingKey {
        case id
        case rawSku = "raw_sku"
        case rawName = "raw_name"
        case quantity
        case quantityUnit = "quantity_unit"
        case unitPrice = "unit_price"
        case totalPrice = "total_price"
        case catalogStableId = "catalog_stable_id"
        case matchConfidence = "match_confidence"
        case matchMethod = "match_method"
        case matchCandidates = "match_candidates"
    }

    /// Stable hash for identifying this receipt line across re-imports
    /// Uses rawName + rawSku + totalPrice to create a consistent identifier
    public var lineHash: String {
        let components = [
            rawName,
            rawSku ?? "",
            totalPrice.map { String(format: "%.2f", $0) } ?? ""
        ]
        let combined = components.joined(separator: "|")
        let digest = SHA256.hash(data: Data(combined.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}

/// Summary of a receipt (for list view)
public struct ReceiptSummary: Codable, Identifiable {
    public let id: String
    public let retailerId: String?  // Can be null for unparsed/failed receipts
    public let retailerName: String?
    public let orderNumber: String?
    public let orderDate: Date?
    public let totalAmount: Double?
    public let itemCount: Int
    public let status: String
    public let acknowledged: Bool
    public let receivedAt: Date
    public let parsedAt: Date?

    /// Whether this receipt failed to parse or is still pending
    public var isParseFailed: Bool {
        // Don't mark as failed if still pending or very recently received (parsing may still be in progress)
        guard !isPending else { return false }
        return retailerId == nil
    }

    /// Whether this receipt is still being processed
    /// Includes receipts with "pending" status OR very recently received (within 3 seconds)
    public var isPending: Bool {
        if status == "pending" { return true }
        // Treat very recent receipts as pending to avoid showing "failed" during parsing
        let secondsSinceReceived = Date().timeIntervalSince(receivedAt)
        return secondsSinceReceived < 3 && retailerId == nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case retailerId = "retailer_id"
        case retailerName = "retailer_name"
        case orderNumber = "order_number"
        case orderDate = "order_date"
        case totalAmount = "total_amount"
        case itemCount = "item_count"
        case status
        case acknowledged
        case receivedAt = "received_at"
        case parsedAt = "parsed_at"
    }
}

/// Full receipt detail (for detail view)
public struct ReceiptDetail: Codable, Identifiable {
    public let id: String
    public let retailerId: String?  // Can be null for unparsed/failed receipts
    public let retailerName: String?
    public let senderEmail: String
    public let subject: String?
    public let orderNumber: String?
    public let orderDate: Date?
    public let totalAmount: Double?
    public let status: String
    public let acknowledged: Bool
    public let receivedAt: Date
    public let parsedAt: Date?
    public let items: [ReceiptItem]

    /// Whether this receipt failed to parse or is still pending
    public var isParseFailed: Bool {
        // Don't mark as failed if still pending or very recently received (parsing may still be in progress)
        guard !isPending else { return false }
        return retailerId == nil
    }

    /// Whether this receipt is still being processed
    /// Includes receipts with "pending" status OR very recently received (within 3 seconds)
    public var isPending: Bool {
        if status == "pending" { return true }
        // Treat very recent receipts as pending to avoid showing "failed" during parsing
        let secondsSinceReceived = Date().timeIntervalSince(receivedAt)
        return secondsSinceReceived < 3 && retailerId == nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case retailerId = "retailer_id"
        case retailerName = "retailer_name"
        case senderEmail = "sender_email"
        case subject
        case orderNumber = "order_number"
        case orderDate = "order_date"
        case totalAmount = "total_amount"
        case status
        case acknowledged
        case receivedAt = "received_at"
        case parsedAt = "parsed_at"
        case items
    }
}

/// Response from the list receipts endpoint
public struct ReceiptListResponse: Codable {
    public let receipts: [ReceiptSummary]
    public let total: Int
    public let offset: Int
    public let limit: Int
}

/// Response from the register endpoint
public struct ReceiptRegisterResponse: Codable {
    public let userId: String
    public let plusKey: String
    public let forwardingEmail: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case plusKey = "plus_key"
        case forwardingEmail = "forwarding_email"
    }
}

/// Response from adding an email identifier
public struct AddEmailIdentifierResponse: Codable {
    public let type: String
    public let identifier: String
    public let verified: Bool
    public let message: String?
}

/// Response from adding a plus-address identifier
public struct AddPlusAddressIdentifierResponse: Codable {
    public let id: String
    public let type: String
    public let identifier: String
    public let forwardingEmail: String
    public let verified: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case identifier
        case forwardingEmail = "forwarding_email"
        case verified
    }
}

/// Response from checking email verification status
public struct EmailStatusResponse: Codable {
    public let hasEmail: Bool
    public let verified: Bool
}

/// API client for receipt operations
@MainActor
class ReceiptAPIClient: NSObject {

    // MARK: - Properties

    private let session: URLSessionProtocol
    private let baseURL: URL
    private let attestationManager: AttestationManagerProtocol

    /// Default base URL for production API
    private static let defaultBaseURL: URL = {
        guard let url = URL(string: "https://molten-receipt-worker.m-e94.workers.dev") else {
            fatalError("Invalid ReceiptAPIClient base URL configuration")
        }
        return url
    }()

    /// Custom date decoder for API responses
    private static let dateDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // Try date-only format (YYYY-MM-DD)
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
            if let date = dateOnlyFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }()

    // MARK: - Initialization

    init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = ReceiptAPIClient.defaultBaseURL,
        attestationManager: AttestationManagerProtocol = AttestationManager()
    ) {
        self.session = session
        self.baseURL = baseURL
        self.attestationManager = attestationManager
        super.init()
    }

    // MARK: - Register User

    /// Register a new receipt user with a public key
    /// - Parameter publicKey: Ed25519 public key for ownership verification
    /// - Returns: Registration response with user ID and plus address
    /// - Throws: ReceiptAPIError on failure
    open func register(publicKey: Data) async throws -> ReceiptRegisterResponse {
        let url = baseURL.appendingPathComponent("api/v1/receipts/register")

        // Create request body
        let requestBody: [String: Any] = [
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
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 201:
            break // Success
        case 409:
            throw ReceiptAPIError.conflict
        case 401, 403:
            throw ReceiptAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw ReceiptAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        return try Self.dateDecoder.decode(ReceiptRegisterResponse.self, from: data)
    }

    // MARK: - List Receipts

    /// List receipts for the authenticated user
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - ownershipSignature: Ed25519 signature of the user ID
    ///   - limit: Maximum number of receipts to return
    ///   - offset: Number of receipts to skip
    ///   - includeAcknowledged: Whether to include acknowledged receipts
    /// - Returns: List of receipt summaries
    open func listReceipts(
        userId: String,
        ownershipSignature: Data,
        limit: Int = 50,
        offset: Int = 0,
        includeAcknowledged: Bool = false
    ) async throws -> ReceiptListResponse {
        var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent("api/v1/receipts"),
            resolvingAgainstBaseURL: true
        )!

        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "include_acknowledged", value: includeAcknowledged ? "true" : "false")
        ]

        guard let url = urlComponents.url else {
            throw ReceiptAPIError.invalidResponse
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add auth headers
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401, 403:
            throw ReceiptAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw ReceiptAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        return try Self.dateDecoder.decode(ReceiptListResponse.self, from: data)
    }

    // MARK: - Get Receipt Detail

    /// Get detailed receipt information
    /// - Parameters:
    ///   - receiptId: The receipt ID
    ///   - userId: The user's ID
    ///   - ownershipSignature: Ed25519 signature of the user ID
    /// - Returns: Full receipt detail with items
    open func getReceipt(
        receiptId: String,
        userId: String,
        ownershipSignature: Data
    ) async throws -> ReceiptDetail {
        let url = baseURL.appendingPathComponent("api/v1/receipts/\(receiptId)")

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add auth headers
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 404:
            throw ReceiptAPIError.notFound
        case 401, 403:
            throw ReceiptAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw ReceiptAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        return try Self.dateDecoder.decode(ReceiptDetail.self, from: data)
    }

    // MARK: - Acknowledge Receipt

    /// Mark a receipt as acknowledged (imported)
    /// - Parameters:
    ///   - receiptId: The receipt ID
    ///   - userId: The user's ID
    ///   - ownershipSignature: Ed25519 signature of the user ID
    open func acknowledgeReceipt(
        receiptId: String,
        userId: String,
        ownershipSignature: Data
    ) async throws {
        let url = baseURL.appendingPathComponent("api/v1/receipts/\(receiptId)/acknowledge")

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth headers
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return // Success
        case 404:
            throw ReceiptAPIError.notFound
        case 401, 403:
            throw ReceiptAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw ReceiptAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Delete Receipt

    /// Delete a receipt (for dismissing duplicates)
    /// - Parameters:
    ///   - receiptId: The receipt ID
    ///   - userId: The user's ID
    ///   - ownershipSignature: Ed25519 signature of the user ID
    open func deleteReceipt(
        receiptId: String,
        userId: String,
        ownershipSignature: Data
    ) async throws {
        let url = baseURL.appendingPathComponent("api/v1/receipts/\(receiptId)")

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        // Add auth headers
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return // Success
        case 404:
            throw ReceiptAPIError.notFound
        case 401, 403:
            throw ReceiptAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw ReceiptAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Report Parse Issue

    /// Report a receipt parse issue for developer review
    /// - Parameters:
    ///   - receiptId: The receipt ID
    ///   - userId: The user's ID
    ///   - ownershipSignature: Ed25519 signature of the user ID
    ///   - notes: Optional user notes about the issue
    open func reportParseIssue(
        receiptId: String,
        userId: String,
        ownershipSignature: Data,
        notes: String? = nil
    ) async throws {
        let url = baseURL.appendingPathComponent("api/v1/receipts/\(receiptId)/report")

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth headers
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add body if notes provided
        if let notes = notes {
            let body = ["notes": notes]
            request.httpBody = try JSONEncoder().encode(body)
        }

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201:
            return // Success
        case 404:
            throw ReceiptAPIError.notFound
        case 401, 403:
            throw ReceiptAPIError.unauthorized
        case 409:
            // Already reported - treat as success
            return
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw ReceiptAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Get Receipt Email Body

    /// Get the original email body for a receipt
    /// - Parameters:
    ///   - receiptId: The receipt ID
    ///   - userId: The user's ID
    ///   - ownershipSignature: Ed25519 signature of the user ID
    /// - Returns: The email body text
    open func getReceiptEmail(
        receiptId: String,
        userId: String,
        ownershipSignature: Data
    ) async throws -> String {
        let url = baseURL.appendingPathComponent("api/v1/receipts/\(receiptId)/email")

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add auth headers
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 404:
            throw ReceiptAPIError.notFound
        case 401, 403:
            throw ReceiptAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw ReceiptAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        struct EmailResponse: Codable {
            let emailBody: String

            enum CodingKeys: String, CodingKey {
                case emailBody = "email_body"
            }
        }

        let emailResponse = try JSONDecoder().decode(EmailResponse.self, from: data)
        return emailResponse.emailBody
    }

    // MARK: - Add Identifier

    /// Add an email identifier to an existing user (requires verification)
    /// - Parameters:
    ///   - email: The email address to register
    ///   - userId: The user's ID
    ///   - ownershipSignature: Ed25519 signature of the user ID
    /// - Returns: Response indicating verification email was sent
    open func addEmailIdentifier(
        email: String,
        userId: String,
        ownershipSignature: Data
    ) async throws -> AddEmailIdentifierResponse {
        let url = baseURL.appendingPathComponent("api/v1/receipts/identifiers")

        // Create request body
        let requestBody: [String: Any] = [
            "type": "email",
            "value": email.lowercased()
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // Add auth headers
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 201:
            break // Success (201 = created, 200 = resent)
        case 409:
            throw ReceiptAPIError.conflict
        case 401, 403:
            throw ReceiptAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw ReceiptAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        return try Self.dateDecoder.decode(AddEmailIdentifierResponse.self, from: data)
    }

    // MARK: - Check Email Status

    /// Check if user has a verified email identifier
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - ownershipSignature: Ed25519 signature of the user ID
    /// - Returns: Email status response
    open func checkEmailStatus(
        userId: String,
        ownershipSignature: Data
    ) async throws -> EmailStatusResponse {
        let url = baseURL.appendingPathComponent("api/v1/receipts/email-status")

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add auth headers
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")
        request.setValue(ownershipSignature.base64EncodedString(), forHTTPHeaderField: "X-Ownership-Signature")

        // Add App Attest assertion
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401, 403:
            throw ReceiptAPIError.unauthorized
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw ReceiptAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        return try Self.dateDecoder.decode(EmailStatusResponse.self, from: data)
    }

    // MARK: - Account Recovery

    /// Response from recovery request
    public struct RecoveryResponse: Codable {
        public let message: String
    }

    /// Response from recovery status check
    public struct RecoveryStatusResponse: Codable {
        public let recovered: Bool
        public let userId: String?
        public let reason: String?
    }

    /// Request account recovery via email verification
    /// This sends a recovery email to the registered email address.
    /// When user clicks the link, their public key is rotated to the new one.
    /// - Parameters:
    ///   - email: The registered email address
    ///   - newPublicKey: The new Ed25519 public key to use after recovery
    /// - Returns: Response message (always generic for security)
    open func requestRecovery(
        email: String,
        newPublicKey: Data
    ) async throws -> RecoveryResponse {
        let url = baseURL.appendingPathComponent("api/v1/receipts/recover")

        // Create request body
        let requestBody: [String: Any] = [
            "email": email.lowercased(),
            "publicKey": newPublicKey.base64EncodedString()
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // Add App Attest assertion (no auth headers - this is unauthenticated)
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 400:
            // Could be "email not verified" - extract error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                throw ReceiptAPIError.badRequest(errorMsg)
            }
            throw ReceiptAPIError.badRequest("Invalid request")
        case 429:
            let resetAt = parseRateLimitReset(from: data)
            throw ReceiptAPIError.rateLimitExceeded(resetAt: resetAt)
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        return try Self.dateDecoder.decode(RecoveryResponse.self, from: data)
    }

    /// Check if account recovery has completed
    /// The app calls this with email + public key to see if the user clicked the recovery link
    /// - Parameters:
    ///   - email: The registered email address
    ///   - publicKey: The new public key that was sent during recovery request
    /// - Returns: RecoveryStatusResponse with recovered status and userId if recovered
    open func checkRecoveryStatus(
        email: String,
        publicKey: Data
    ) async throws -> RecoveryStatusResponse {
        let url = baseURL.appendingPathComponent("api/v1/receipts/recover/status")

        // Create request body
        let requestBody: [String: Any] = [
            "email": email.lowercased(),
            "publicKey": publicKey.base64EncodedString()
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // Add App Attest assertion (no auth headers - this is unauthenticated)
        try await addAttestation(to: &request)

        // Execute request
        let (data, response) = try await executeRequest(request)

        // Check status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 400:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                throw ReceiptAPIError.badRequest(errorMsg)
            }
            throw ReceiptAPIError.badRequest("Invalid request")
        default:
            throw ReceiptAPIError.serverError(httpResponse.statusCode)
        }

        // Parse response
        return try Self.dateDecoder.decode(RecoveryStatusResponse.self, from: data)
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
            throw ReceiptAPIError.networkError(error)
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
