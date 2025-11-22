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
        /// Maximum inventory items (user may reduce this to increase conversion)
        nonisolated static let maxInventoryItems = FeatureFlags.FREE_TIER_INVENTORY_LIMIT

        /// Maximum shopping list items (user may reduce this)
        nonisolated static let maxShoppingListItems = 15

        /// Maximum projects (user may reduce this)
        nonisolated static let maxProjects = 5

        /// Maximum logbook entries (user may reduce this)
        nonisolated static let maxLogbookEntries = 30

        /// Label printing: one template page at a time (no batch printing)
        nonisolated static let allowBatchLabelPrinting = false

        /// Maximum images per project (nil = unlimited for now)
        /// NOTE: May change to limit per-project rather than per-user in future
        nonisolated static let maxImagesPerProject: Int? = nil

        /// Maximum images per logbook entry (nil = unlimited for now)
        nonisolated static let maxImagesPerLogbookEntry: Int? = nil
    }

    // MARK: - Premium Tier Features

    struct PremiumFeatures: Sendable {
        /// Unlimited inventory items
        nonisolated static let unlimitedInventory = true

        /// Unlimited shopping list items
        nonisolated static let unlimitedShoppingList = true

        /// Unlimited projects
        nonisolated static let unlimitedProjects = true

        /// Unlimited logbook entries
        nonisolated static let unlimitedLogbookEntries = true

        /// Batch label printing with templates
        nonisolated static let batchLabelPrinting = true

        /// QR code scanning for inventory increment/decrement
        nonisolated static let qrCodeScanning = true

        /// Adding custom tags to inventory items
        nonisolated static let customInventoryTags = true

        /// Adding images to inventory items
        nonisolated static let inventoryItemImages = true

        /// Adding custom notes to inventory items
        nonisolated static let customInventoryNotes = true

        /// Custom fields (when implemented)
        nonisolated static let customFields = true

        /// Unlimited images
        nonisolated static let unlimitedImages = true
    }

    // MARK: - Features Available to All Tiers

    struct UniversalFeatures: Sendable {
        /// Full catalog access (read-only reference data)
        nonisolated static let catalogAccess = true

        /// CloudKit sync (no gating sync behind paywall)
        nonisolated static let cloudKitSync = true

        /// Export capabilities (free for now)
        nonisolated static let exportData = true

        /// Photo uploads (free for now, may limit per-project later)
        nonisolated static let photoUploads = true

        /// Basic label printing (one page at a time)
        nonisolated static let basicLabelPrinting = true

        /// CSV import (available to all users)
        nonisolated static let csvImport = true

        /// Bulk editing (available to all users)
        nonisolated static let bulkEditing = true
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

    /// Check if batch label printing is allowed for a given tier
    nonisolated static func allowsBatchLabelPrinting(for tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free:
            return FreeTierLimits.allowBatchLabelPrinting
        case .premium:
            return PremiumFeatures.batchLabelPrinting
        }
    }

    /// Check if CSV import is allowed for a given tier
    nonisolated static func allowsCSVImport(for tier: SubscriptionTier) -> Bool {
        return UniversalFeatures.csvImport  // Available to all tiers
    }

    /// Check if bulk editing is allowed for a given tier
    nonisolated static func allowsBulkEditing(for tier: SubscriptionTier) -> Bool {
        return UniversalFeatures.bulkEditing  // Available to all tiers
    }

    /// Check if QR code scanning is allowed for a given tier
    nonisolated static func allowsQRCodeScanning(for tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free:
            return false
        case .premium:
            return PremiumFeatures.qrCodeScanning
        }
    }

    /// Check if custom tags for inventory items are allowed for a given tier
    nonisolated static func allowsCustomInventoryTags(for tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free:
            return false
        case .premium:
            return PremiumFeatures.customInventoryTags
        }
    }

    /// Check if images for inventory items are allowed for a given tier
    nonisolated static func allowsInventoryItemImages(for tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free:
            return false
        case .premium:
            return PremiumFeatures.inventoryItemImages
        }
    }

    /// Check if custom notes for inventory items are allowed for a given tier
    nonisolated static func allowsCustomInventoryNotes(for tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free:
            return false
        case .premium:
            return PremiumFeatures.customInventoryNotes
        }
    }

    /// Check if custom fields are allowed for a given tier
    nonisolated static func allowsCustomFields(for tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free:
            return false
        case .premium:
            return PremiumFeatures.customFields
        }
    }
}
