//
//  EntitlementService.swift
//  Molten
//
//  Service for checking subscription entitlements and enforcing limits
//  Uses SubscriptionConfig for centralized limit definitions
//

import Foundation

/// Service that manages subscription entitlements and limit enforcement
actor EntitlementService {

    // MARK: - Properties

    /// Current subscription tier
    /// TODO: In production, this should be fetched from StoreKit/App Store
    private var tier: SubscriptionTier

    /// Expose current tier for checking
    var currentTier: SubscriptionTier {
        tier
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

    /// Refresh subscription status from StoreKit
    /// TODO: Implement StoreKit integration
    func refreshSubscriptionStatus() async {
        // TODO: Query StoreKit for current subscription status
        // For now, defaults to free tier
    }

    // MARK: - Inventory Limits

    /// Check if user can add a new inventory item
    func canAddInventoryItem(currentCount: Int) -> Bool {
        guard let limit = SubscriptionConfig.inventoryLimit(for: tier) else {
            return true // unlimited (premium)
        }
        return currentCount < limit
    }

    /// Get the inventory item limit for current tier (nil = unlimited)
    func getInventoryLimit() -> Int? {
        return SubscriptionConfig.inventoryLimit(for: tier)
    }

    // MARK: - Shopping List Limits

    /// Check if user can add a new shopping list item
    func canAddShoppingListItem(currentCount: Int) -> Bool {
        guard let limit = SubscriptionConfig.shoppingListLimit(for: tier) else {
            return true // unlimited (premium)
        }
        return currentCount < limit
    }

    /// Get the shopping list item limit for current tier (nil = unlimited)
    func getShoppingListLimit() -> Int? {
        return SubscriptionConfig.shoppingListLimit(for: tier)
    }

    // MARK: - Projects Limits

    /// Check if user can add a new project
    func canAddProject(currentCount: Int) -> Bool {
        guard let limit = SubscriptionConfig.projectsLimit(for: tier) else {
            return true // unlimited (premium)
        }
        return currentCount < limit
    }

    /// Get the projects limit for current tier (nil = unlimited)
    func getProjectsLimit() -> Int? {
        return SubscriptionConfig.projectsLimit(for: tier)
    }

    // MARK: - Logbook Entry Limits

    /// Check if user can add a new logbook entry
    func canAddLogbookEntry(currentCount: Int) -> Bool {
        guard let limit = SubscriptionConfig.logbookEntriesLimit(for: tier) else {
            return true // unlimited (premium)
        }
        return currentCount < limit
    }

    /// Get the logbook entries limit for current tier (nil = unlimited)
    func getLogbookEntriesLimit() -> Int? {
        return SubscriptionConfig.logbookEntriesLimit(for: tier)
    }

    // MARK: - Feature Access

    /// Check if user can use batch label printing
    func canUseBatchLabelPrinting() -> Bool {
        return SubscriptionConfig.allowsBatchLabelPrinting(for: tier)
    }

    /// Check if user can use CSV import
    func canUseCSVImport() -> Bool {
        return SubscriptionConfig.allowsCSVImport(for: tier)
    }

    /// Check if user can use bulk editing
    func canUseBulkEditing() -> Bool {
        return SubscriptionConfig.allowsBulkEditing(for: tier)
    }

    /// Check if user can use custom fields
    func canUseCustomFields() -> Bool {
        return SubscriptionConfig.allowsCustomFields(for: tier)
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
    func enforceFeatureAccess(_ feature: PremiumFeature) throws {
        switch feature {
        case .batchLabelPrinting:
            if !canUseBatchLabelPrinting() {
                throw EntitlementError.featureRequiresPremium(feature: feature)
            }
        case .csvImport:
            if !canUseCSVImport() {
                throw EntitlementError.featureRequiresPremium(feature: feature)
            }
        case .bulkEditing:
            if !canUseBulkEditing() {
                throw EntitlementError.featureRequiresPremium(feature: feature)
            }
        case .customFields:
            if !canUseCustomFields() {
                throw EntitlementError.featureRequiresPremium(feature: feature)
            }
        }
    }
}

// MARK: - Supporting Types

/// Premium features that can be gated
enum PremiumFeature: String, Sendable {
    case batchLabelPrinting = "Batch Label Printing"
    case csvImport = "CSV Import"
    case bulkEditing = "Bulk Editing"
    case customFields = "Custom Fields"
}

/// Errors thrown when entitlement checks fail
enum EntitlementError: Error, LocalizedError {
    case inventoryLimitReached(limit: Int)
    case shoppingListLimitReached(limit: Int)
    case projectsLimitReached(limit: Int)
    case logbookEntriesLimitReached(limit: Int)
    case featureRequiresPremium(feature: PremiumFeature)

    var errorDescription: String? {
        switch self {
        case .inventoryLimitReached(let limit):
            return "You've reached the free tier limit of \(limit) inventory items. Upgrade to premium for unlimited items."
        case .shoppingListLimitReached(let limit):
            return "You've reached the free tier limit of \(limit) shopping list items. Upgrade to premium for unlimited items."
        case .projectsLimitReached(let limit):
            return "You've reached the free tier limit of \(limit) projects. Upgrade to premium for unlimited projects."
        case .logbookEntriesLimitReached(let limit):
            return "You've reached the free tier limit of \(limit) logbook entries. Upgrade to premium for unlimited entries."
        case .featureRequiresPremium(let feature):
            return "\(feature.rawValue) requires a premium subscription. Upgrade to unlock this feature."
        }
    }
}
