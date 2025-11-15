//
//  CloudKitIdentityService.swift
//  Molten
//
//  Service for retrieving and hashing CloudKit user identity for ratings
//

import Foundation
import CloudKit
import CryptoKit

/// Protocol for CloudKit container operations (for testing)
public protocol CKContainerProtocol: Sendable {
    func fetchUserRecordID() async throws -> CKRecord.ID
}

/// Adapter for production CloudKit container
extension CKContainer: CKContainerProtocol {
    public func fetchUserRecordID() async throws -> CKRecord.ID {
        return try await userRecordID()
    }
}

/// Errors that can occur during CloudKit identity operations
public enum CloudKitIdentityError: Error, LocalizedError {
    case unavailable
    case fetchFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "CloudKit is not available"
        case .fetchFailed(let error):
            return "Failed to fetch user ID: \(error.localizedDescription)"
        }
    }
}

/// Protocol for CloudKit identity service (for dependency injection)
public protocol CloudKitIdentityServiceProtocol {
    var isAvailable: Bool { get }
    func getHashedUserID() async throws -> String
    func clearCache()
}

/// Service for retrieving and hashing CloudKit user identity
/// Uses SHA-256 to hash the user record ID for privacy
@MainActor
public class CloudKitIdentityService: CloudKitIdentityServiceProtocol {

    // MARK: - Properties

    /// CloudKit container for fetching user identity
    /// Marked nonisolated because CKContainer is thread-safe and this reference is only used
    /// in async methods that properly isolate to MainActor. This prevents deallocation issues
    /// when the service is deallocated from MainActor context.
    nonisolated private let container: CKContainerProtocol
    private var cachedHashedID: String?

    // MARK: - Initialization

    public init(container: CKContainerProtocol) {
        self.container = container
    }

    /// Convenience initializer using default CloudKit container
    public convenience init() {
        self.init(container: CKContainer.default())
    }

    // MARK: - Public Methods

    /// Check if CloudKit is available
    public var isAvailable: Bool {
        return true // Container exists, actual availability checked on first fetch
    }

    /// Get hashed CloudKit user record ID
    /// Result is cached to avoid repeated network calls
    /// - Returns: SHA-256 hash of user record ID (64 hex characters)
    /// - Throws: CloudKitIdentityError if fetch fails
    public func getHashedUserID() async throws -> String {
        // Return cached value if available
        if let cached = cachedHashedID {
            return cached
        }

        // Fetch user record ID from CloudKit
        do {
            let recordID = try await container.fetchUserRecordID()
            let hashedID = hashUserRecordID(recordID.recordName)

            // Cache the result
            cachedHashedID = hashedID

            return hashedID
        } catch {
            throw CloudKitIdentityError.fetchFailed(error)
        }
    }

    /// Clear cached hashed user ID
    /// Call this if user signs out or switches iCloud accounts
    public func clearCache() {
        cachedHashedID = nil
    }

    // MARK: - Deinitialization

    deinit {
        // Explicitly clear cache before deallocation
        cachedHashedID = nil
    }

    // MARK: - Private Methods

    /// Hash user record ID using SHA-256
    /// - Parameter recordName: CloudKit user record name
    /// - Returns: Hex-encoded SHA-256 hash
    private func hashUserRecordID(_ recordName: String) -> String {
        let data = Data(recordName.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
