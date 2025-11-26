//
//  SubscriptionConfig.swift
//  Molten
//
//  Centralized subscription tier limits and entitlements
//  IMPORTANT: All subscription limits should be defined here for easy adjustment
//

import Foundation

// MARK: - Subscription Tier

/// Subscription tier enum
enum SubscriptionTier: Sendable {
    case free
    case premium

    // Explicitly implement Equatable in nonisolated context
    nonisolated static func == (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        switch (lhs, rhs) {
        case (.free, .free), (.premium, .premium):
            return true
        default:
            return false
        }
    }
}

/// Subscription tier configuration
/// Defines limits for free vs premium users
struct SubscriptionConfig: Sendable {

    // MARK: - Free Tier Limits
    // These can be easily adjusted as the product evolves

    struct FreeTierLimits: Sendable {
        /// Maximum inventory items
        nonisolated static let maxInventoryItems = 25

        /// Maximum shopping list items (user may reduce this)
        nonisolated static let maxShoppingListItems = FeatureFlags.FREE_TIER_SHOPPING_LIST_LIMIT

        /// Maximum projects
        nonisolated static let maxProjects = 5

        /// Maximum logbook entries
        nonisolated static let maxLogbookEntries = 10
    }

    // MARK: - Pro Tier Features

    struct ProFeatures: Sendable {
        /// Unlimited inventory items
        nonisolated static let unlimitedInventory = true

        /// Unlimited shopping list items
        nonisolated static let unlimitedShoppingList = true

        /// Unlimited projects
        nonisolated static let unlimitedProjects = true

        /// Unlimited logbook entries
        nonisolated static let unlimitedLogbookEntries = true

        /// Versioned cloud backups
        nonisolated static let versionedCloudBackups = true
    }

    // MARK: - Features Available to All Tiers

    struct UniversalFeatures: Sendable {
        /// Full catalog access
        nonisolated static let catalogAccess = true

        /// CloudKit sync
        nonisolated static let cloudKitSync = true

        /// Export capabilities
        nonisolated static let exportData = true

        /// Label printing
        nonisolated static let labelPrinting = true

        /// QR code scanning
        nonisolated static let qrCodeScanning = true

        /// Custom tags on inventory items
        nonisolated static let customInventoryTags = true

        /// Images on inventory items
        nonisolated static let inventoryItemImages = true

        /// Custom notes on inventory items
        nonisolated static let customInventoryNotes = true
    }

    // MARK: - Helper Methods

    /// Get inventory limit for a given tier
    nonisolated static func inventoryLimit(for tier: SubscriptionTier) -> Int? {
        switch tier {
        case .free:
            return FreeTierLimits.maxInventoryItems
        case .premium:
            return nil // unlimited
        }
    }

    /// Get shopping list limit for a given tier
    nonisolated static func shoppingListLimit(for tier: SubscriptionTier) -> Int? {
        switch tier {
        case .free:
            return FreeTierLimits.maxShoppingListItems
        case .premium:
            return nil // unlimited
        }
    }

    /// Get projects limit for a given tier
    nonisolated static func projectsLimit(for tier: SubscriptionTier) -> Int? {
        switch tier {
        case .free:
            return FreeTierLimits.maxProjects
        case .premium:
            return nil // unlimited
        }
    }

    /// Get logbook entries limit for a given tier
    nonisolated static func logbookEntriesLimit(for tier: SubscriptionTier) -> Int? {
        switch tier {
        case .free:
            return FreeTierLimits.maxLogbookEntries
        case .premium:
            return nil // unlimited
        }
    }

    /// Check if versioned cloud backups are allowed for a given tier
    nonisolated static func allowsVersionedCloudBackups(for tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free:
            return false
        case .premium:
            return ProFeatures.versionedCloudBackups
        }
    }
}
