//
//  EntitlementService.swift
//  Molten
//
//  Service for checking subscription entitlements and enforcing limits
//  Uses SubscriptionConfig for centralized limit definitions
//

import Foundation
import Observation
import SwiftUI

/// Service that manages subscription entitlements and limit enforcement
@Observable
@MainActor
class EntitlementService {

    // MARK: - Properties

    /// Current subscription tier (fetched from RevenueCat)
    private(set) var tier: SubscriptionTier

    /// Debug override flag - observed property that triggers view updates
    /// This is set by the settings view and causes currentTier to be re-evaluated
    var debugRefreshTrigger: Int = 0

    /// Expose current tier for checking
    /// In debug/test builds, this can be overridden via DebugConfig
    var currentTier: SubscriptionTier {
        // Access the trigger to ensure this property is observed when it changes
        _ = debugRefreshTrigger
        // Read fresh from UserDefaults to get the most current debug settings
        let overrideEnabled = UserDefaults.standard.bool(forKey: "debugOverrideSubscriptionTier")
        let tierValue = UserDefaults.standard.integer(forKey: "debugSubscriptionTierValue")
        if overrideEnabled {
            let result: SubscriptionTier = tierValue == 1 ? .premium : .free
            return result
        }
        return tier
    }

    /// Force a refresh of the current tier (call after changing debug settings)
    func refreshTier() {
        // Increment trigger to cause views observing currentTier to re-evaluate
        debugRefreshTrigger += 1
    }

    // MARK: - Initialization

    /// Initialize with a specific tier (for testing and development)
    /// In production, this will integrate with StoreKit to determine actual tier
    init(tier: SubscriptionTier = .free) {
        self.tier = tier
    }

    // MARK: - Tier Management

    /// Update the subscription tier (called after successful purchase/restore)
    func updateTier(_ newTier: SubscriptionTier) {
        self.tier = newTier
    }

    /// Refresh subscription status (handled by RevenueCat)
    func refreshSubscriptionStatus() async {
        // RevenueCat handles subscription status
    }

    // MARK: - Inventory Limits

    /// Check if user can add a new inventory item
    func canAddInventoryItem(currentCount: Int) -> Bool {
        guard let limit = SubscriptionConfig.inventoryLimit(for: currentTier) else {
            return true // unlimited (premium)
        }
        return currentCount < limit
    }

    /// Get the inventory item limit for current tier (nil = unlimited)
    func getInventoryLimit() -> Int? {
        return SubscriptionConfig.inventoryLimit(for: currentTier)
    }

    // MARK: - Shopping List Limits

    /// Check if user can add a new shopping list item
    func canAddShoppingListItem(currentCount: Int) -> Bool {
        guard let limit = SubscriptionConfig.shoppingListLimit(for: currentTier) else {
            return true // unlimited (premium)
        }
        return currentCount < limit
    }

    /// Get the shopping list item limit for current tier (nil = unlimited)
    func getShoppingListLimit() -> Int? {
        return SubscriptionConfig.shoppingListLimit(for: currentTier)
    }

    // MARK: - Projects Limits

    /// Check if user can add a new project
    func canAddProject(currentCount: Int) -> Bool {
        guard let limit = SubscriptionConfig.projectsLimit(for: currentTier) else {
            return true // unlimited (premium)
        }
        return currentCount < limit
    }

    /// Get the projects limit for current tier (nil = unlimited)
    func getProjectsLimit() -> Int? {
        return SubscriptionConfig.projectsLimit(for: currentTier)
    }

    // MARK: - Logbook Entry Limits

    /// Check if user can add a new logbook entry
    func canAddLogbookEntry(currentCount: Int) -> Bool {
        guard let limit = SubscriptionConfig.logbookEntriesLimit(for: currentTier) else {
            return true // unlimited (premium)
        }
        return currentCount < limit
    }

    /// Get the logbook entries limit for current tier (nil = unlimited)
    func getLogbookEntriesLimit() -> Int? {
        return SubscriptionConfig.logbookEntriesLimit(for: currentTier)
    }

    // MARK: - Feature Access

    /// Check if user can use versioned cloud backups
    func canUseVersionedCloudBackups() -> Bool {
        return SubscriptionConfig.allowsVersionedCloudBackups(for: currentTier)
    }

    // MARK: - Enforcement Helpers

    /// Check and throw error if limit would be exceeded
    func enforceInventoryLimit(currentCount: Int) throws {
        if !canAddInventoryItem(currentCount: currentCount) {
            throw EntitlementError.inventoryLimitReached(limit: getInventoryLimit()!)
        }
    }

    /// Check and throw error if shopping list limit would be exceeded
    func enforceShoppingListLimit(currentCount: Int) throws {
        if !canAddShoppingListItem(currentCount: currentCount) {
            throw EntitlementError.shoppingListLimitReached(limit: getShoppingListLimit()!)
        }
    }

    /// Check and throw error if projects limit would be exceeded
    func enforceProjectsLimit(currentCount: Int) throws {
        if !canAddProject(currentCount: currentCount) {
            throw EntitlementError.projectsLimitReached(limit: getProjectsLimit()!)
        }
    }

    /// Check and throw error if logbook entries limit would be exceeded
    func enforceLogbookEntriesLimit(currentCount: Int) throws {
        if !canAddLogbookEntry(currentCount: currentCount) {
            throw EntitlementError.logbookEntriesLimitReached(limit: getLogbookEntriesLimit()!)
        }
    }

    /// Check and throw error if feature is not available
    func enforceFeatureAccess(_ feature: ProFeature) throws {
        switch feature {
        case .versionedCloudBackups:
            if !canUseVersionedCloudBackups() {
                throw EntitlementError.featureRequiresPro(feature: feature)
            }
        }
    }
}

// MARK: - Supporting Types

/// Pro features that can be gated
enum ProFeature: String, Sendable {
    case versionedCloudBackups = "Versioned Cloud Backups"
}

/// Errors thrown when entitlement checks fail
enum EntitlementError: Error, LocalizedError {
    case inventoryLimitReached(limit: Int)
    case shoppingListLimitReached(limit: Int)
    case projectsLimitReached(limit: Int)
    case logbookEntriesLimitReached(limit: Int)
    case featureRequiresPro(feature: ProFeature)

    var errorDescription: String? {
        switch self {
        case .inventoryLimitReached(let limit):
            return "You've reached the free tier limit of \(limit) inventory items. Upgrade to Pro for unlimited items."
        case .shoppingListLimitReached(let limit):
            return "You've reached the free tier limit of \(limit) shopping list items. Upgrade to Pro for unlimited items."
        case .projectsLimitReached(let limit):
            return "You've reached the free tier limit of \(limit) projects. Upgrade to Pro for unlimited projects."
        case .logbookEntriesLimitReached(let limit):
            return "You've reached the free tier limit of \(limit) logbook entries. Upgrade to Pro for unlimited entries."
        case .featureRequiresPro(let feature):
            return "\(feature.rawValue) requires Molten Pro. Upgrade to unlock this feature."
        }
    }
}
