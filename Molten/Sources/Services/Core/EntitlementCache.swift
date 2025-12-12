//
//  EntitlementCache.swift
//  Molten
//
//  Local cache for subscription entitlements with grace period.
//  Allows offline usage for up to 14 days without network verification.
//
//  Flow:
//  1. On app launch: Load cached entitlement (if valid)
//  2. Background: Try to refresh from RevenueCat
//  3. On successful refresh: Update cache timestamp
//  4. After 14 days without refresh: Fall back to free tier
//
//  This decouples the app from RevenueCat initialization timing and
//  provides offline resilience for users in low-connectivity areas.
//

import Foundation

/// Local cache for subscription entitlements
/// Persists premium status with timestamp for offline grace period
@MainActor
final class EntitlementCache {

    // MARK: - Configuration

    /// How long the cached entitlement is valid (14 days)
    static let cacheValidityDuration: TimeInterval = 14 * 24 * 60 * 60

    /// When to start warning users about expiring cache (11 days = 3 days before expiry)
    static let warningThreshold: TimeInterval = 11 * 24 * 60 * 60

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let isPremium = "entitlementCache_isPremium"
        static let lastVerifiedAt = "entitlementCache_lastVerifiedAt"
        static let productIdentifier = "entitlementCache_productIdentifier"
        static let expirationDate = "entitlementCache_expirationDate"
    }

    // MARK: - Singleton

    static let shared = EntitlementCache()

    private init() {}

    // MARK: - Cache State

    /// Cached premium status (nil if no cache exists)
    var cachedIsPremium: Bool? {
        guard UserDefaults.standard.object(forKey: Keys.isPremium) != nil else {
            return nil
        }
        return UserDefaults.standard.bool(forKey: Keys.isPremium)
    }

    /// When the entitlement was last verified with RevenueCat
    var lastVerifiedAt: Date? {
        guard let timestamp = UserDefaults.standard.object(forKey: Keys.lastVerifiedAt) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Cached product identifier (for display purposes)
    var cachedProductIdentifier: String? {
        return UserDefaults.standard.string(forKey: Keys.productIdentifier)
    }

    /// Cached subscription expiration date (from RevenueCat)
    var cachedExpirationDate: Date? {
        guard let timestamp = UserDefaults.standard.object(forKey: Keys.expirationDate) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    // MARK: - Cache Validity

    /// Check if the cached entitlement is still valid (within grace period)
    var isCacheValid: Bool {
        guard let lastVerified = lastVerifiedAt else {
            return false
        }
        let age = Date().timeIntervalSince(lastVerified)
        return age < Self.cacheValidityDuration
    }

    /// How many days until the cache expires (nil if already expired or no cache)
    var daysUntilExpiry: Int? {
        guard let lastVerified = lastVerifiedAt else {
            return nil
        }
        let age = Date().timeIntervalSince(lastVerified)
        let remaining = Self.cacheValidityDuration - age
        guard remaining > 0 else {
            return nil
        }
        return Int(remaining / (24 * 60 * 60))
    }

    /// Whether we should show a warning about expiring cache
    var shouldShowExpiryWarning: Bool {
        guard let lastVerified = lastVerifiedAt,
              cachedIsPremium == true else {
            return false
        }
        let age = Date().timeIntervalSince(lastVerified)
        return age >= Self.warningThreshold && age < Self.cacheValidityDuration
    }

    // MARK: - Cache Operations

    /// Update the cache with fresh entitlement data from RevenueCat
    func updateCache(isPremium: Bool, productIdentifier: String?, expirationDate: Date?) {
        UserDefaults.standard.set(isPremium, forKey: Keys.isPremium)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastVerifiedAt)

        if let productId = productIdentifier {
            UserDefaults.standard.set(productId, forKey: Keys.productIdentifier)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.productIdentifier)
        }

        if let expDate = expirationDate {
            UserDefaults.standard.set(expDate.timeIntervalSince1970, forKey: Keys.expirationDate)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.expirationDate)
        }

        print("📦 [EntitlementCache] Updated cache: isPremium=\(isPremium), product=\(productIdentifier ?? "none")")
    }

    /// Get the effective premium status (cached if valid, otherwise false)
    func getEffectivePremiumStatus() -> Bool {
        // If cache is valid and shows premium, trust it
        if isCacheValid, let isPremium = cachedIsPremium, isPremium {
            if let days = daysUntilExpiry {
                print("📦 [EntitlementCache] Using cached premium status (\(days) days until refresh needed)")
            }
            return true
        }

        // Cache expired or shows free - return false
        // (Will be updated when RevenueCat fetch succeeds)
        if !isCacheValid && cachedIsPremium == true {
            print("📦 [EntitlementCache] Cache expired - falling back to free tier until refresh")
        }

        return false
    }

    /// Clear the cache (for testing or logout)
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: Keys.isPremium)
        UserDefaults.standard.removeObject(forKey: Keys.lastVerifiedAt)
        UserDefaults.standard.removeObject(forKey: Keys.productIdentifier)
        UserDefaults.standard.removeObject(forKey: Keys.expirationDate)
        print("📦 [EntitlementCache] Cache cleared")
    }

    // MARK: - Debug Info

    /// Get a human-readable cache status for debugging
    var debugDescription: String {
        guard let isPremium = cachedIsPremium,
              let lastVerified = lastVerifiedAt else {
            return "No cache"
        }

        let age = Date().timeIntervalSince(lastVerified)
        let ageHours = Int(age / 3600)
        let ageDays = ageHours / 24

        let status = isPremium ? "Premium" : "Free"
        let validity = isCacheValid ? "valid" : "EXPIRED"
        let daysLeft = daysUntilExpiry ?? 0

        return "\(status) (\(validity), \(ageDays)d old, \(daysLeft)d left)"
    }
}
