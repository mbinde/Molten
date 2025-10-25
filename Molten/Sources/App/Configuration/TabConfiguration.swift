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

    // MARK: - Private Properties

    private let tabsKey = "userTabOrder"
    private let maxVisibleTabsKey = "userMaxVisibleTabs"
    private var isInitializing = true

    // MARK: - Initialization

    init() {
        let isCompact = Self.shouldUseCompactLayout()

        // Load saved configuration or use defaults
        if let savedTabs = UserDefaults.standard.array(forKey: tabsKey) as? [Int] {
            self.tabs = savedTabs.compactMap { DefaultTab(rawValue: $0) }
            self.maxVisibleTabs = UserDefaults.standard.object(forKey: maxVisibleTabsKey) as? Int ?? Self.defaultMaxVisibleTabs()

            print("📱 TabConfiguration: Loaded from UserDefaults - maxVisibleTabs=\(maxVisibleTabs), tabs=\(tabs.map { $0.displayName })")

            // Validate loaded configuration
            if !isConfigurationValid(isCompact: isCompact) {
                print("📱 TabConfiguration: Configuration invalid, resetting to defaults")
                resetToDefaults()
            }
        } else {
            // First launch - use defaults
            self.tabs = Self.defaultTabOrder(isCompact: isCompact)
            self.maxVisibleTabs = Self.defaultMaxVisibleTabs()
            print("📱 TabConfiguration: No saved config, using defaults - maxVisibleTabs=\(maxVisibleTabs), tabs=\(tabs.map { $0.displayName })")
        }

        isInitializing = false
    }

    // MARK: - Default Configuration

    /// Determines if we should use compact layout (single Projects tab with menu)
    /// or expanded layout (separate Plans and Logs tabs)
    /// Uses device idiom to decide - iPhones use compact, iPads use expanded
    private static func shouldUseCompactLayout() -> Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom != .pad
        #else
        // macOS always uses expanded layout
        return false
        #endif
    }

    /// Returns default tab order based on app features
    /// - Parameter isCompact: If true, uses compact layout (combined Projects tab). If false, uses expanded layout (separate Plans/Logs tabs).
    static func defaultTabOrder(isCompact: Bool = true) -> [DefaultTab] {
        let allAvailableTabs = Self.allAvailableTabs(isCompact: isCompact)

        // Default order (common tabs first, then specialty tabs)
        let preferredOrder: [DefaultTab] = [
            .catalog,
            .inventory,
            .shopping,
            .purchases,
            .projects,     // Used in compact mode (iPhones)
            .projectPlans, // Used in expanded mode (iPads)
            .logbook,      // Used in expanded mode (iPads)
            .settings
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
            // iPad
            return 6
        } else {
            // iPhone - use conservative default of 5 tabs
            // Individual views can adjust based on their specific trait collection
            return 5
        }
        #else
        // macOS
        return 8
        #endif
    }

    /// Returns all tabs that are currently available in the app
    /// (respects feature flags and other availability constraints)
    /// - Parameter isCompact: If true, uses compact layout (combined Projects tab). If false, uses expanded layout (separate Plans/Logs tabs).
    static func allAvailableTabs(isCompact: Bool = true) -> [DefaultTab] {
        return DefaultTab.allCases.filter { tab in
            switch tab {
            case .projects:
                // Only show combined Projects tab in compact mode (iPhones)
                return isCompact
            case .projectPlans, .logbook:
                // Only show separate Plans/Logs tabs in expanded mode (iPads)
                return !isCompact
            default:
                // Include all other tabs: catalog, inventory, shopping, purchases, settings
                return true
            }
        }
    }

    // MARK: - Configuration Management

    /// Validates that current configuration is valid
    /// - Parameter isCompact: If true, validates for compact layout. If false, validates for expanded layout.
    private func isConfigurationValid(isCompact: Bool) -> Bool {
        let allTabs = Self.allAvailableTabs(isCompact: isCompact)

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
        let isCompact = Self.shouldUseCompactLayout()
        self.tabs = Self.defaultTabOrder(isCompact: isCompact)
        self.maxVisibleTabs = Self.defaultMaxVisibleTabs()
    }

    /// Saves current configuration to UserDefaults
    private func saveConfiguration() {
        // Don't save during initialization to avoid overwriting loaded values
        guard !isInitializing else { return }

        UserDefaults.standard.set(tabs.map { $0.rawValue }, forKey: tabsKey)
        UserDefaults.standard.set(maxVisibleTabs, forKey: maxVisibleTabsKey)
        print("📱 TabConfiguration: Saved maxVisibleTabs=\(maxVisibleTabs), tabs=\(tabs.map { $0.displayName })")
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
