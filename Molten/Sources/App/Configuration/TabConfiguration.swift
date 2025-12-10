//
//  TabConfiguration.swift
//  Molten
//
//  Created by Assistant on 10/22/25.
//

import Foundation
import SwiftUI
import Observation

/// Manages user's tab customization preferences
@Observable
class TabConfiguration {
    @MainActor static let shared = TabConfiguration()

    // MARK: - Published Properties

    /// Ordered list of all tabs (first N shown in tab bar, rest in More menu)
    var tabs: [DefaultTab] = [] {
        didSet {
            if !isInitializing {
                saveConfiguration()
            }
        }
    }

    /// Maximum number of tabs to show in tab bar before using More tab
    /// User-configurable, defaults based on device size
    var maxVisibleTabs: Int = 4 {
        didSet {
            if !isInitializing {
                saveConfiguration()
            }
        }
    }

    /// Whether to show text labels under tab icons
    /// User-configurable, defaults to true
    var showTabLabels: Bool = true {
        didSet {
            if !isInitializing {
                saveConfiguration()
            }
        }
    }

    // MARK: - Private Properties

    private let tabsKey = "userTabOrder"
    private let maxVisibleTabsKey = "userMaxVisibleTabs"
    private let showTabLabelsKey = "userShowTabLabels"
    private var isInitializing = true

    // MARK: - Initialization

    init() {
        // Load saved configuration or use defaults
        if let savedTabs = UserDefaults.standard.array(forKey: tabsKey) as? [Int] {
            self.tabs = savedTabs.compactMap { DefaultTab(rawValue: $0) }
            self.maxVisibleTabs = UserDefaults.standard.object(forKey: maxVisibleTabsKey) as? Int ?? Self.defaultMaxVisibleTabs()

            // Validate loaded configuration
            if !isConfigurationValid() {
                resetToDefaults()
            }
        } else {
            // First launch - use defaults
            self.tabs = Self.defaultTabOrder()
            self.maxVisibleTabs = Self.defaultMaxVisibleTabs()
        }

        // Load showTabLabels (defaults to true if not set)
        if UserDefaults.standard.object(forKey: showTabLabelsKey) != nil {
            self.showTabLabels = UserDefaults.standard.bool(forKey: showTabLabelsKey)
        } else {
            self.showTabLabels = true
        }

        isInitializing = false
    }

    // MARK: - Default Configuration

    /// Returns default tab order based on app features
    static func defaultTabOrder() -> [DefaultTab] {
        let allAvailableTabs = Self.allAvailableTabs()

        // Default order: Core features in tab bar (Catalog, Inventory, Shopping, Purchases)
        // Additional features in More menu (Locations, Projects, Logbook, Recipes, Kiln Schedules, Settings)
        let preferredOrder: [DefaultTab] = [
            .catalog,
            .inventory,
            .shopping,
            .purchases,     // Core feature - receipt imports
            .locations,     // In More menu - stores/classes
            .projectPlans,  // In More menu - Projects
            .logbook,       // In More menu
            .recipes,       // In More menu
            .kilnSchedules, // In More menu
            .settings       // In More menu
        ]

        // Return in preferred order, filtering to only available tabs
        return preferredOrder.filter { allAvailableTabs.contains($0) }
    }

    /// Returns default max visible tabs based on device size
    static func defaultMaxVisibleTabs() -> Int {
        #if os(iOS)
        // Use UIDevice idiom to determine default
        // Note: UIScreen.main deprecated in iOS 26.0, use trait-based sizing instead
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad - show more tabs
            return 6
        } else {
            // iPhone - show 4 tabs (Catalog, Inventory, Shopping, Purchases) + More
            return 4
        }
        #else
        // macOS
        return 8
        #endif
    }

    /// Returns all tabs that are currently available in the app
    /// (respects feature flags and other availability constraints)
    static func allAvailableTabs() -> [DefaultTab] {
        return DefaultTab.allCases.filter { tab in
            switch tab {
            case .projects:
                // Legacy combined Projects tab - check feature flag
                return FeatureFlags.ENABLE_PROJECTS
            case .projectPlans, .logbook:
                return FeatureFlags.ENABLE_PROJECTS
            case .kilnSchedules:
                return FeatureFlags.ENABLE_KILN_SCHEDULES
            case .recipes:
                return FeatureFlags.ENABLE_RECIPES
            case .purchases:
                return FeatureFlags.ENABLE_PURCHASES
            default:
                // Include all other tabs: catalog, inventory, shopping, settings, locations
                return true
            }
        }
    }

    // MARK: - Configuration Management

    /// Validates that current configuration is valid
    private func isConfigurationValid() -> Bool {
        let allTabs = Self.allAvailableTabs()

        // Check that all available tabs are present
        let configuredTabs = Set(tabs)
        let availableTabs = Set(allTabs)

        guard configuredTabs == availableTabs else {
            return false
        }

        // Check no duplicates
        guard Set(tabs).count == tabs.count else {
            return false
        }

        // Check maxVisibleTabs is reasonable
        guard maxVisibleTabs >= 3 && maxVisibleTabs <= 8 else {
            return false
        }

        return true
    }

    /// Resets configuration to defaults
    func resetToDefaults() {
        self.tabs = Self.defaultTabOrder()
        self.maxVisibleTabs = Self.defaultMaxVisibleTabs()
        self.showTabLabels = true
    }

    /// Saves current configuration to UserDefaults
    private func saveConfiguration() {
        // Don't save during initialization to avoid overwriting loaded values
        guard !isInitializing else { return }

        UserDefaults.standard.set(tabs.map { $0.rawValue }, forKey: tabsKey)
        UserDefaults.standard.set(maxVisibleTabs, forKey: maxVisibleTabsKey)
        UserDefaults.standard.set(showTabLabels, forKey: showTabLabelsKey)
    }

    // MARK: - Tab Management

    /// Returns tabs to show in the tab bar (respects maxVisibleTabs limit)
    var tabBarTabs: [DefaultTab] {
        return Array(tabs.prefix(maxVisibleTabs))
    }

    /// Returns tabs to show in the More menu
    var moreTabs: [DefaultTab] {
        return Array(tabs.dropFirst(maxVisibleTabs))
    }

    /// Checks if we need to show the More tab
    var needsMoreTab: Bool {
        return tabs.count > maxVisibleTabs
    }

    /// Reorders tabs
    func moveTabs(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Preview Support

extension TabConfiguration {
    /// Creates a configuration for previews/testing
    static func preview() -> TabConfiguration {
        let config = TabConfiguration()
        return config
    }
}
