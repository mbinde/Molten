//
//  ReceiptPreferences.swift
//  Molten
//
//  Stores receipt import preferences and state in iCloud KeyValue store
//  with UserDefaults fallback. Tracks user ID, plus address, and sync state.
//

import Foundation

/// How the user identifies themselves for receipt import
public enum ReceiptIdentifierType: String {
    case plusAddress = "plus_address"  // User got a unique forwarding address
    case email = "email"               // User registered their email address
}

/// Manages receipt import preferences and state
/// Uses NSUbiquitousKeyValueStore for iCloud sync with UserDefaults as local cache
@MainActor
final class ReceiptPreferences {

    // MARK: - Constants

    private static let keyUserId = "molten.receipts.userId"
    private static let keyPlusAddress = "molten.receipts.plusAddress"
    private static let keyRegisteredEmail = "molten.receipts.registeredEmail"
    private static let keyIdentifierType = "molten.receipts.identifierType"
    private static let keyEmailVerified = "molten.receipts.emailVerified"
    private static let keyLastSyncTimestamp = "molten.receipts.lastSyncTimestamp"
    private static let keyEnabled = "molten.receipts.enabled"
    private static let keyPendingReceiptCount = "molten.receipts.pendingCount"
    private static let keyImportedReceiptCount = "molten.receipts.importedCount"

    // MARK: - Properties

    private let cloudStore: NSUbiquitousKeyValueStore
    private let localStore: UserDefaults

    // MARK: - Initialization

    init(
        cloudStore: NSUbiquitousKeyValueStore = .default,
        localStore: UserDefaults = .standard
    ) {
        self.cloudStore = cloudStore
        self.localStore = localStore

        // Synchronize with iCloud on init
        cloudStore.synchronize()

        // Migrate from local-only storage if needed
        migrateFromLocalIfNeeded()

        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Migration

    /// Migrate existing UserDefaults data to iCloud if not already synced
    private func migrateFromLocalIfNeeded() {
        // If we have local data but no cloud data, migrate it
        if localStore.string(forKey: Self.keyUserId) != nil &&
           cloudStore.string(forKey: Self.keyUserId) == nil {
            // Migrate all keys
            if let userId = localStore.string(forKey: Self.keyUserId) {
                cloudStore.set(userId, forKey: Self.keyUserId)
            }
            if let plusAddress = localStore.string(forKey: Self.keyPlusAddress) {
                cloudStore.set(plusAddress, forKey: Self.keyPlusAddress)
            }
            if let email = localStore.string(forKey: Self.keyRegisteredEmail) {
                cloudStore.set(email, forKey: Self.keyRegisteredEmail)
            }
            if let identifierType = localStore.string(forKey: Self.keyIdentifierType) {
                cloudStore.set(identifierType, forKey: Self.keyIdentifierType)
            }
            cloudStore.set(localStore.bool(forKey: Self.keyEmailVerified), forKey: Self.keyEmailVerified)
            cloudStore.set(localStore.bool(forKey: Self.keyEnabled), forKey: Self.keyEnabled)
            if let timestamp = localStore.object(forKey: Self.keyLastSyncTimestamp) as? Date {
                cloudStore.set(timestamp, forKey: Self.keyLastSyncTimestamp)
            }
            cloudStore.set(localStore.integer(forKey: Self.keyPendingReceiptCount), forKey: Self.keyPendingReceiptCount)

            cloudStore.synchronize()
        }
    }

    @objc private func cloudStoreDidChange(_ notification: Notification) {
        // Sync cloud changes to local cache
        syncCloudToLocal()
    }

    /// Sync cloud values to local UserDefaults cache
    private func syncCloudToLocal() {
        if let userId = cloudStore.string(forKey: Self.keyUserId) {
            localStore.set(userId, forKey: Self.keyUserId)
        } else {
            localStore.removeObject(forKey: Self.keyUserId)
        }
        if let plusAddress = cloudStore.string(forKey: Self.keyPlusAddress) {
            localStore.set(plusAddress, forKey: Self.keyPlusAddress)
        } else {
            localStore.removeObject(forKey: Self.keyPlusAddress)
        }
        if let email = cloudStore.string(forKey: Self.keyRegisteredEmail) {
            localStore.set(email, forKey: Self.keyRegisteredEmail)
        } else {
            localStore.removeObject(forKey: Self.keyRegisteredEmail)
        }
        if let identifierType = cloudStore.string(forKey: Self.keyIdentifierType) {
            localStore.set(identifierType, forKey: Self.keyIdentifierType)
        } else {
            localStore.removeObject(forKey: Self.keyIdentifierType)
        }
        localStore.set(cloudStore.bool(forKey: Self.keyEmailVerified), forKey: Self.keyEmailVerified)
        localStore.set(cloudStore.bool(forKey: Self.keyEnabled), forKey: Self.keyEnabled)
        if let timestamp = cloudStore.object(forKey: Self.keyLastSyncTimestamp) as? Date {
            localStore.set(timestamp, forKey: Self.keyLastSyncTimestamp)
        } else {
            localStore.removeObject(forKey: Self.keyLastSyncTimestamp)
        }
        localStore.set(cloudStore.longLong(forKey: Self.keyPendingReceiptCount), forKey: Self.keyPendingReceiptCount)
    }

    // MARK: - Private Helpers

    private func getString(forKey key: String) -> String? {
        // Prefer cloud, fallback to local
        cloudStore.string(forKey: key) ?? localStore.string(forKey: key)
    }

    private func setString(_ value: String?, forKey key: String) {
        if let value = value {
            cloudStore.set(value, forKey: key)
            localStore.set(value, forKey: key)
        } else {
            cloudStore.removeObject(forKey: key)
            localStore.removeObject(forKey: key)
        }
        cloudStore.synchronize()
    }

    private func getBool(forKey key: String) -> Bool {
        // Cloud store returns false for missing keys, which is fine
        cloudStore.bool(forKey: key)
    }

    private func setBool(_ value: Bool, forKey key: String) {
        cloudStore.set(value, forKey: key)
        localStore.set(value, forKey: key)
        cloudStore.synchronize()
    }

    private func getInt(forKey key: String) -> Int {
        Int(cloudStore.longLong(forKey: key))
    }

    private func setInt(_ value: Int, forKey key: String) {
        cloudStore.set(Int64(value), forKey: key)
        localStore.set(value, forKey: key)
        cloudStore.synchronize()
    }

    private func getDate(forKey key: String) -> Date? {
        cloudStore.object(forKey: key) as? Date ?? localStore.object(forKey: key) as? Date
    }

    private func setDate(_ value: Date?, forKey key: String) {
        if let value = value {
            cloudStore.set(value, forKey: key)
            localStore.set(value, forKey: key)
        } else {
            cloudStore.removeObject(forKey: key)
            localStore.removeObject(forKey: key)
        }
        cloudStore.synchronize()
    }

    // MARK: - User ID

    /// The registered user ID (nil if receipts not set up)
    var userId: String? {
        get { getString(forKey: Self.keyUserId) }
        set { setString(newValue, forKey: Self.keyUserId) }
    }

    // MARK: - Plus Address

    /// The plus address key for receiving receipt emails (e.g., "abc123def456")
    var plusAddress: String? {
        get { getString(forKey: Self.keyPlusAddress) }
        set { setString(newValue, forKey: Self.keyPlusAddress) }
    }

    /// The full forwarding email address (e.g., "receipts+abc123@moltenglass.app")
    var forwardingEmail: String? {
        guard let plusKey = plusAddress else { return nil }
        return "receipts+\(plusKey)@moltenglass.app"
    }

    // MARK: - Registered Email

    /// The user's registered email address (for email-based identification)
    var registeredEmail: String? {
        get { getString(forKey: Self.keyRegisteredEmail) }
        set { setString(newValue, forKey: Self.keyRegisteredEmail) }
    }

    /// Whether the registered email has been verified
    var emailVerified: Bool {
        get { getBool(forKey: Self.keyEmailVerified) }
        set { setBool(newValue, forKey: Self.keyEmailVerified) }
    }

    // MARK: - Identifier Type

    /// How the user identifies themselves (plus-address or email)
    var identifierType: ReceiptIdentifierType? {
        get {
            guard let rawValue = getString(forKey: Self.keyIdentifierType) else { return nil }
            return ReceiptIdentifierType(rawValue: rawValue)
        }
        set { setString(newValue?.rawValue, forKey: Self.keyIdentifierType) }
    }

    /// The email address to display/use based on identifier type
    /// - For plus-address: the forwarding email
    /// - For email: the registered email (with pending status if unverified)
    var receiptEmail: String? {
        switch identifierType {
        case .plusAddress:
            return forwardingEmail
        case .email:
            return registeredEmail
        case nil:
            // Legacy fallback: check if plus address exists
            return forwardingEmail
        }
    }

    // MARK: - Enabled State

    /// Whether receipt imports are enabled
    var isEnabled: Bool {
        get { getBool(forKey: Self.keyEnabled) }
        set { setBool(newValue, forKey: Self.keyEnabled) }
    }

    // MARK: - Last Sync Timestamp

    /// Timestamp of the last successful sync
    var lastSyncTimestamp: Date? {
        get { getDate(forKey: Self.keyLastSyncTimestamp) }
        set { setDate(newValue, forKey: Self.keyLastSyncTimestamp) }
    }

    /// Minutes since last sync (nil if never synced)
    var minutesSinceLastSync: Double? {
        guard let lastSync = lastSyncTimestamp else { return nil }
        return Date().timeIntervalSince(lastSync) / 60.0
    }

    // MARK: - Pending Receipt Count

    /// Number of pending (unacknowledged) receipts
    var pendingReceiptCount: Int {
        get { getInt(forKey: Self.keyPendingReceiptCount) }
        set { setInt(newValue, forKey: Self.keyPendingReceiptCount) }
    }

    // MARK: - Imported Receipt Count

    /// Number of receipts that have been imported (acted on) - cumulative, never decreases
    /// This tracks how many receipts the user has "used" for entitlement purposes
    /// Free tier allows 10, Pro tier allows unlimited
    var importedReceiptCount: Int {
        get { getInt(forKey: Self.keyImportedReceiptCount) }
        set { setInt(newValue, forKey: Self.keyImportedReceiptCount) }
    }

    // MARK: - Setup Status

    /// Check if receipts are fully set up
    var isSetUp: Bool {
        guard userId != nil && isEnabled else { return false }

        switch identifierType {
        case .plusAddress:
            return plusAddress != nil
        case .email:
            // Email must be registered AND verified
            return registeredEmail != nil && emailVerified
        case nil:
            // Legacy check
            return plusAddress != nil
        }
    }

    /// Check if we're waiting for email verification
    var isPendingEmailVerification: Bool {
        identifierType == .email && registeredEmail != nil && !emailVerified
    }

    /// Check if we're waiting for account recovery (no userId means recovery, not normal verification)
    /// During recovery, user doesn't have credentials yet - they must click the email link
    var isRecoveryPending: Bool {
        isPendingEmailVerification && userId == nil
    }

    // MARK: - Reset

    /// Clear all receipt preferences (for disabling receipts or testing)
    func reset() {
        let keys = [
            Self.keyUserId,
            Self.keyPlusAddress,
            Self.keyRegisteredEmail,
            Self.keyIdentifierType,
            Self.keyEmailVerified,
            Self.keyLastSyncTimestamp,
            Self.keyEnabled,
            Self.keyPendingReceiptCount
        ]

        for key in keys {
            cloudStore.removeObject(forKey: key)
            localStore.removeObject(forKey: key)
        }

        cloudStore.synchronize()
    }
}
