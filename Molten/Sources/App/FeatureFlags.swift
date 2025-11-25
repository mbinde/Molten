//
//  FeatureFlags.swift
//  Molten
//
//  Created by Assistant on 11/21/25.
//  Feature flags for controlling what gets shipped with the app
//

import Foundation

/// Feature flags for controlling app functionality
/// These flags allow us to disable features for launch without removing code
/// TODO: Remove this file and all references once features are stable in production
enum FeatureFlags {

    // MARK: - Product Type Features

    /// Controls whether tools catalog and inventory are enabled
    /// Set to false to disable tools functionality for launch
    /// IMPLEMENTED: SQLite loading, filter menus
    nonisolated static let ENABLE_TOOLS = false

    /// Controls whether coatings catalog and inventory are enabled
    /// Set to false to disable coatings functionality for launch
    nonisolated static let ENABLE_COATINGS = true

    // MARK: - Feature Sections

    /// Controls whether the Projects section is enabled
    /// Set to false to disable project planning features for launch
    /// IMPLEMENTED: Tab visibility, Settings sections, tab management
    nonisolated static let ENABLE_PROJECTS = false

    /// Controls whether the Kiln Schedules section is enabled
    /// Set to false to disable kiln schedule features for launch
    /// IMPLEMENTED: Tab visibility, Settings sections, tab management
    nonisolated static let ENABLE_KILN_SCHEDULES = false

    /// Controls whether the Purchases section is enabled
    /// Set to false to disable purchase tracking for launch
    /// IMPLEMENTED: Tab visibility
    nonisolated static let ENABLE_PURCHASES = false

    /// Controls whether the Shopping Lists section is enabled
    /// Set to false to disable shopping list features for launch
    nonisolated static let ENABLE_SHOPPING_LISTS = true

    /// Controls whether the Recipes section is enabled
    /// Set to false to disable recipe features for launch
    /// IMPLEMENTED: Tab visibility
    nonisolated static let ENABLE_RECIPES = false

    // MARK: - Advanced Features

    /// Controls whether data export functionality is enabled
    /// Set to false to disable export features for launch
    nonisolated static let ENABLE_DATA_EXPORT = true

    /// Controls whether data import functionality is enabled
    /// Set to false to disable import features for launch
    nonisolated static let ENABLE_DATA_IMPORT = true

    /// Controls whether catalog updates/downloads are enabled
    /// Set to false to ship with bundled catalog only
    nonisolated static let ENABLE_CATALOG_UPDATES = true

    // MARK: - Free Tier Limits

    /// Maximum number of distinct glass items allowed in inventory for free tier
    /// Pro members have unlimited inventory items
    nonisolated static let FREE_TIER_INVENTORY_LIMIT = 25

    // MARK: - Debug Feature Flags (from DebugConfig)

    /// Master switch for all advanced features
    static let isFullFeaturesEnabled = false

    /// Individual feature flags
    static let advancedSearch = isFullFeaturesEnabled
    static let advancedImageLoading = isFullFeaturesEnabled
    static let advancedUIComponents = isFullFeaturesEnabled
    static let performanceOptimizations = isFullFeaturesEnabled
    static let batchOperations = isFullFeaturesEnabled
    static let advancedFiltering = isFullFeaturesEnabled
    static let coeGlassFilter = true

    /// Always enabled core features
    static let basicInventoryManagement = true
    static let coreDataPersistence = true
    static let basicSearch = true
    static let userPreferences = true

    // MARK: - Helper Methods

    /// Returns the available product types based on feature flags
    nonisolated static var availableProductTypes: [String] {
        var types = ["glass"] // Glass is always available
        if ENABLE_COATINGS {
            types.append("coating")
        }
        if ENABLE_TOOLS {
            types.append("tool")
        }
        return types
    }

    /// Checks if a product type is enabled
    nonisolated static func isProductTypeEnabled(_ type: String) -> Bool {
        switch type.lowercased() {
        case "glass":
            return true // Glass is always enabled
        case "coating":
            return ENABLE_COATINGS
        case "tool":
            return ENABLE_TOOLS
        default:
            return false
        }
    }

    /// Search implementation strategy
    static var searchImplementation: SearchType {
        return advancedSearch ? .advanced : .basic
    }

    /// Image loading strategy
    static var imageLoadingStrategy: ImageLoadingType {
        return advancedImageLoading ? .async : .sync
    }

    enum SearchType {
        case basic
        case advanced
    }

    enum ImageLoadingType {
        case sync
        case async
    }
}
