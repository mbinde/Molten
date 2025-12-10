//
//  ReceiptService.swift
//  Molten
//
//  High-level service for receipt import operations
//  Coordinates key management, API calls, and sync
//
//  Receipts are emails forwarded to a unique plus-address
//  that get parsed and can be imported as purchase records
//

import Foundation
import Combine
import CryptoKit

/// High-level service for receipt import operations
@MainActor
open class ReceiptService: ObservableObject {

    // MARK: - Constants

    /// Keychain identifier for receipt user's private key
    private static let receiptKeyIdentifier = "com.molten.receipts.key"

    // MARK: - Published Properties

    @Published public private(set) var isSetUp: Bool = false
    @Published public private(set) var pendingReceiptCount: Int = 0
    @Published public private(set) var receiptEmail: String?
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var identifierType: ReceiptIdentifierType?
    @Published public private(set) var isPendingEmailVerification: Bool = false

    // MARK: - Properties

    private let apiClient: ReceiptAPIClient
    private let keyPairManager: KeyPairManager
    private let preferences: ReceiptPreferences

    // MARK: - Initialization

    init(
        apiClient: ReceiptAPIClient = ReceiptAPIClient(),
        keyPairManager: KeyPairManager = KeyPairManager(),
        preferences: ReceiptPreferences = ReceiptPreferences()
    ) {
        self.apiClient = apiClient
        self.keyPairManager = keyPairManager
        self.preferences = preferences

        // Load initial state
        updatePublishedState()
    }

    // MARK: - State

    private func updatePublishedState() {
        isSetUp = preferences.isSetUp
        pendingReceiptCount = preferences.pendingReceiptCount
        receiptEmail = preferences.receiptEmail
        lastSyncDate = preferences.lastSyncTimestamp
        identifierType = preferences.identifierType
        isPendingEmailVerification = preferences.isPendingEmailVerification
    }

    /// Get the user ID (for display to user)
    var userId: String? {
        preferences.userId
    }

    /// Get the plus address (for display to user)
    var plusAddress: String? {
        preferences.plusAddress
    }

    // MARK: - Setup

    /// Enable receipt imports using a unique plus-address (privacy-focused option)
    /// User gets a unique forwarding address like receipts+abc123@moltenglass.app
    /// - Returns: The email address to forward receipts to
    /// - Throws: ReceiptAPIError on failure
    open func enableReceiptsWithPlusAddress() async throws -> String {
        // Generate key pair for ownership signing
        let keyPair = try keyPairManager.generateAndStoreKeyPair(identifier: Self.receiptKeyIdentifier)

        // Register with server
        let response = try await apiClient.register(publicKey: keyPair.publicKey)

        // Save preferences
        preferences.userId = response.userId
        preferences.plusAddress = response.plusKey
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true
        preferences.lastSyncTimestamp = nil
        preferences.pendingReceiptCount = 0

        // Update published state
        updatePublishedState()

        // Perform first sync
        try? await syncReceipts()

        return preferences.forwardingEmail ?? ""
    }

    /// Legacy method - calls enableReceiptsWithPlusAddress
    open func enableReceipts() async throws -> String {
        return try await enableReceiptsWithPlusAddress()
    }

    /// Enable receipt imports using an email address
    /// User registers their email, which requires verification via a link sent to that email
    /// - Parameter email: The email address to register
    /// - Throws: ReceiptAPIError on failure
    open func enableReceiptsWithEmail(_ email: String) async throws {
        print("[enableReceiptsWithEmail] Starting for email: \(email)")

        // Check if we already have a user ID (user might be adding email to existing account)
        let existingUserId = preferences.userId
        print("[enableReceiptsWithEmail] existingUserId: \(existingUserId ?? "nil")")

        if existingUserId == nil {
            // Need to create a new user first
            print("[enableReceiptsWithEmail] Creating new user...")
            let keyPair = try keyPairManager.generateAndStoreKeyPair(identifier: Self.receiptKeyIdentifier)
            let response = try await apiClient.register(publicKey: keyPair.publicKey)
            preferences.userId = response.userId
            preferences.plusAddress = response.plusKey
            print("[enableReceiptsWithEmail] Created user: \(response.userId)")
        }

        guard let userId = preferences.userId else {
            print("[enableReceiptsWithEmail] ERROR: No userId after registration!")
            throw ReceiptAPIError.unauthorized
        }

        // Get private key for signing
        print("[enableReceiptsWithEmail] Retrieving private key...")
        let privateKey: Data
        do {
            privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.receiptKeyIdentifier)
            print("[enableReceiptsWithEmail] Got private key")
        } catch {
            print("[enableReceiptsWithEmail] ERROR retrieving private key: \(error)")
            throw error
        }

        // Create ownership signature
        let ownershipSignature = try keyPairManager.sign(
            data: userId.data(using: .utf8)!,
            privateKey: privateKey
        )
        print("[enableReceiptsWithEmail] Created signature, calling addEmailIdentifier...")

        // Add email identifier
        do {
            _ = try await apiClient.addEmailIdentifier(
                email: email,
                userId: userId,
                ownershipSignature: ownershipSignature
            )
            print("[enableReceiptsWithEmail] addEmailIdentifier succeeded")
        } catch {
            print("[enableReceiptsWithEmail] addEmailIdentifier failed: \(error)")
            throw error
        }

        // Save preferences - email is pending verification
        preferences.registeredEmail = email.lowercased()
        preferences.identifierType = .email
        preferences.emailVerified = false
        preferences.isEnabled = true
        preferences.lastSyncTimestamp = nil
        preferences.pendingReceiptCount = 0

        // Update published state
        updatePublishedState()
    }

    /// Mark email as verified locally (called when deep link received or status check succeeds)
    open func markEmailVerified() {
        preferences.emailVerified = true
        updatePublishedState()
    }

    /// Resend verification email for pending email registration
    open func resendVerificationEmail() async throws {
        guard let userId = preferences.userId,
              let email = preferences.registeredEmail else {
            throw ReceiptAPIError.unauthorized
        }

        // Get private key for signing
        let privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.receiptKeyIdentifier)

        // Create ownership signature
        let ownershipSignature = try keyPairManager.sign(
            data: userId.data(using: .utf8)!,
            privateKey: privateKey
        )

        // Re-add the email identifier - server will resend verification email
        _ = try await apiClient.addEmailIdentifier(
            email: email,
            userId: userId,
            ownershipSignature: ownershipSignature
        )
    }

    /// Check email verification status with server
    /// - Returns: true if email is verified, false otherwise
    @discardableResult
    open func checkEmailVerificationStatus() async throws -> Bool {
        guard let userId = preferences.userId else {
            return false
        }

        // Get private key for signing
        let privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.receiptKeyIdentifier)

        // Create ownership signature
        let ownershipSignature = try keyPairManager.sign(
            data: userId.data(using: .utf8)!,
            privateKey: privateKey
        )

        let response = try await apiClient.checkEmailStatus(
            userId: userId,
            ownershipSignature: ownershipSignature
        )

        if response.verified {
            preferences.emailVerified = true
            updatePublishedState()
        }

        return response.verified
    }

    /// Disable receipt imports and clear all stored data
    open func disableReceipts() {
        preferences.reset()
        try? keyPairManager.deletePrivateKey(identifier: Self.receiptKeyIdentifier)
        updatePublishedState()
    }


    // MARK: - Sync

    /// Sync receipts from server
    /// - Returns: Number of pending receipts
    @discardableResult
    open func syncReceipts() async throws -> Int {
        guard let userId = preferences.userId else {
            throw ReceiptAPIError.unauthorized
        }

        isSyncing = true
        defer { isSyncing = false }

        // Get private key for signing
        let privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.receiptKeyIdentifier)

        // Create ownership signature (sign the user ID)
        let ownershipSignature = try keyPairManager.sign(
            data: userId.data(using: .utf8)!,
            privateKey: privateKey
        )

        // Fetch pending receipts (unacknowledged only)
        let response = try await apiClient.listReceipts(
            userId: userId,
            ownershipSignature: ownershipSignature,
            limit: 100,
            offset: 0,
            includeAcknowledged: false
        )

        // Update state
        preferences.pendingReceiptCount = response.total
        preferences.lastSyncTimestamp = Date()
        updatePublishedState()

        return response.total
    }

    /// List all receipts (for UI)
    /// - Parameters:
    ///   - limit: Maximum number to return
    ///   - offset: Number to skip
    ///   - includeAcknowledged: Whether to include imported receipts
    /// - Returns: Receipt list response
    public func listReceipts(
        limit: Int = 50,
        offset: Int = 0,
        includeAcknowledged: Bool = false
    ) async throws -> ReceiptListResponse {
        guard let userId = preferences.userId else {
            throw ReceiptAPIError.unauthorized
        }

        // Get private key for signing
        let privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.receiptKeyIdentifier)

        // Create ownership signature
        let ownershipSignature = try keyPairManager.sign(
            data: userId.data(using: .utf8)!,
            privateKey: privateKey
        )

        return try await apiClient.listReceipts(
            userId: userId,
            ownershipSignature: ownershipSignature,
            limit: limit,
            offset: offset,
            includeAcknowledged: includeAcknowledged
        )
    }

    /// Get full receipt detail
    /// - Parameter receiptId: The receipt ID
    /// - Returns: Full receipt detail with items
    public func getReceipt(receiptId: String) async throws -> ReceiptDetail {
        guard let userId = preferences.userId else {
            throw ReceiptAPIError.unauthorized
        }

        // Get private key for signing
        let privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.receiptKeyIdentifier)

        // Create ownership signature
        let ownershipSignature = try keyPairManager.sign(
            data: userId.data(using: .utf8)!,
            privateKey: privateKey
        )

        return try await apiClient.getReceipt(
            receiptId: receiptId,
            userId: userId,
            ownershipSignature: ownershipSignature
        )
    }

    /// Acknowledge a receipt (mark as imported)
    /// - Parameter receiptId: The receipt ID
    open func acknowledgeReceipt(receiptId: String) async throws {
        guard let userId = preferences.userId else {
            throw ReceiptAPIError.unauthorized
        }

        // Get private key for signing
        let privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.receiptKeyIdentifier)

        // Create ownership signature
        let ownershipSignature = try keyPairManager.sign(
            data: userId.data(using: .utf8)!,
            privateKey: privateKey
        )

        try await apiClient.acknowledgeReceipt(
            receiptId: receiptId,
            userId: userId,
            ownershipSignature: ownershipSignature
        )

        // Update pending count
        if preferences.pendingReceiptCount > 0 {
            preferences.pendingReceiptCount -= 1
            updatePublishedState()
        }
    }

    /// Get the original email body for a receipt
    /// - Parameter receiptId: The receipt ID
    /// - Returns: The email body text
    open func getReceiptEmail(receiptId: String) async throws -> String {
        guard let userId = preferences.userId else {
            throw ReceiptAPIError.unauthorized
        }

        // Get private key for signing
        let privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.receiptKeyIdentifier)

        // Create ownership signature
        let ownershipSignature = try keyPairManager.sign(
            data: userId.data(using: .utf8)!,
            privateKey: privateKey
        )

        return try await apiClient.getReceiptEmail(
            receiptId: receiptId,
            userId: userId,
            ownershipSignature: ownershipSignature
        )
    }

    // MARK: - Account Recovery

    /// Request account recovery via email
    /// Generates a new keypair and sends a recovery email.
    /// When user clicks the link, their account's public key is rotated.
    /// - Parameter email: The registered email address
    /// - Returns: A message indicating recovery email was sent (or would be sent)
    open func requestAccountRecovery(email: String) async throws -> String {
        print("[ReceiptService] requestAccountRecovery called for: \(email)")

        // Generate a new key pair (will replace old one on successful recovery)
        let keyPair: KeyPair
        do {
            keyPair = try keyPairManager.generateAndStoreKeyPair(identifier: Self.receiptKeyIdentifier)
            print("[ReceiptService] Generated new key pair")
        } catch {
            print("[ReceiptService] Failed to generate key pair: \(error)")
            throw error
        }

        // Send recovery request to server
        let response: ReceiptAPIClient.RecoveryResponse
        do {
            response = try await apiClient.requestRecovery(
                email: email,
                newPublicKey: keyPair.publicKey
            )
            print("[ReceiptService] API response: \(response.message)")
        } catch {
            print("[ReceiptService] API call failed: \(error)")
            throw error
        }

        // Store the email locally and set pending verification state
        // This triggers isPendingEmailVerification = true so UI shows verification waiting screen
        preferences.registeredEmail = email.lowercased()
        preferences.identifierType = .email
        preferences.emailVerified = false

        // Update published state to trigger UI refresh
        updatePublishedState()

        return response.message
    }

    /// Complete account recovery after user clicks email link
    /// Called when the app receives the deep link with user_id
    /// - Parameter userId: The recovered user ID from the deep link
    open func completeAccountRecovery(userId: String) {
        // Restore preferences with the recovered user ID
        // The public key was already rotated on the server when user clicked the link
        preferences.userId = userId
        preferences.identifierType = .email
        preferences.emailVerified = true
        preferences.isEnabled = true
        preferences.pendingReceiptCount = 0
        preferences.lastSyncTimestamp = nil

        // Update published state
        updatePublishedState()

        // Trigger sync to get receipt count
        Task {
            try? await syncReceipts()
        }
    }

    // MARK: - Helpers

    /// Create ownership signature for the current user
    func createOwnershipSignature() throws -> Data {
        guard let userId = preferences.userId else {
            throw ReceiptAPIError.unauthorized
        }

        let privateKey = try keyPairManager.retrievePrivateKey(identifier: Self.receiptKeyIdentifier)

        return try keyPairManager.sign(
            data: userId.data(using: .utf8)!,
            privateKey: privateKey
        )
    }
}
