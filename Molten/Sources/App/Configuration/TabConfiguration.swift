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
@MainActor
@Observable
class TabConfiguration {
    static let shared = TabConfiguration()

    // MARK: - Published Properties

    /// Ordered list of all tabs (first N shown in tab bar, rest in More menu)
    var tabs: [DefaultTab] = [] {
        didSet {
            saveConfiguration()
        }
    }

    /// Maximum number of tabs to show in tab bar before using More tab
    /// User-configurable, defaults based on device size
    var maxVisibleTabs: Int = 4 {
        didSet {
            saveConfiguration()
        }
    }

    // MARK: - Private Properties

    private let tabsKey = "userTabOrder"
    private let maxVisibleTabsKey = "userMaxVisibleTabs"

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
    }

    // MARK: - Default Configuration

    /// Returns default tab order based on app features
    static func defaultTabOrder() -> [DefaultTab] {
        let allAvailableTabs = Self.allAvailableTabs()

        // Default order (common tabs first, then specialty tabs)
        let preferredOrder: [DefaultTab] = [
            .catalog,
            .inventory,
            .shopping,
            .purchases,
            .projectPlans,
            .logbook,
            .settings
        ]

        // Return in preferred order, filtering to only available tabs
        return preferredOrder.filter { allAvailableTabs.contains($0) }
    }

    /// Returns default max visible tabs based on device size
    static func defaultMaxVisibleTabs() -> Int {
        #if os(iOS)
        // Use screen width to determine default
        let screenWidth = UIScreen.main.bounds.width
        if screenWidth >= 834 {
            // iPad or large device
            return 6
        } else if screenWidth >= 414 {
            // iPhone Pro Max models
            return 5
        } else {
            // Standard iPhone
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
                // Legacy combined tab - use Plans and Logbook instead
                return false
            default:
                // Include all tabs: catalog, inventory, shopping, purchases,
                // projectPlans, logbook, and settings
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
    }

    /// Saves current configuration to UserDefaults
    private func saveConfiguration() {
        UserDefaults.standard.set(tabs.map { $0.rawValue }, forKey: tabsKey)
        UserDefaults.standard.set(maxVisibleTabs, forKey: maxVisibleTabsKey)
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
