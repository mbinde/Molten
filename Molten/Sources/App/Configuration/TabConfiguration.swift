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

    /// Ordered list of visible tabs (shown in tab bar)
    var visibleTabs: [DefaultTab] = [] {
        didSet {
            saveConfiguration()
        }
    }

    /// Ordered list of hidden tabs (shown in More menu)
    var hiddenTabs: [DefaultTab] = [] {
        didSet {
            saveConfiguration()
        }
    }

    /// Maximum number of tabs to show in tab bar before using More tab
    /// iOS standard is 5 (4 tabs + More), but we use 4 for cleaner UI
    let maxVisibleTabs = 4

    // MARK: - Private Properties

    private let visibleTabsKey = "userVisibleTabs"
    private let hiddenTabsKey = "userHiddenTabs"

    // MARK: - Initialization

    init() {
        // Load saved configuration or use defaults
        if let savedVisible = UserDefaults.standard.array(forKey: visibleTabsKey) as? [Int],
           let savedHidden = UserDefaults.standard.array(forKey: hiddenTabsKey) as? [Int] {
            self.visibleTabs = savedVisible.compactMap { DefaultTab(rawValue: $0) }
            self.hiddenTabs = savedHidden.compactMap { DefaultTab(rawValue: $0) }

            // Validate loaded configuration
            if !isConfigurationValid() {
                resetToDefaults()
            }
        } else {
            // First launch - use defaults
            (self.visibleTabs, self.hiddenTabs) = Self.defaultConfiguration()
        }
    }

    // MARK: - Default Configuration

    /// Returns default tab configuration based on app features
    static func defaultConfiguration() -> (visible: [DefaultTab], hidden: [DefaultTab]) {
        let allAvailableTabs = Self.allAvailableTabs()

        // Default visible tabs (first 4)
        let defaultVisible: [DefaultTab] = [
            .catalog,
            .inventory,
            .shopping,
            .purchases
        ].filter { allAvailableTabs.contains($0) }

        // Hidden tabs (everything else)
        let defaultHidden = allAvailableTabs.filter { !defaultVisible.contains($0) }

        return (defaultVisible, defaultHidden)
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

        // Check that all tabs are accounted for
        let configuredTabs = Set(visibleTabs + hiddenTabs)
        let availableTabs = Set(allTabs)

        guard configuredTabs == availableTabs else {
            return false
        }

        // Check no duplicates
        guard Set(visibleTabs).count == visibleTabs.count else {
            return false
        }

        guard Set(hiddenTabs).count == hiddenTabs.count else {
            return false
        }

        return true
    }

    /// Resets configuration to defaults
    func resetToDefaults() {
        let (visible, hidden) = Self.defaultConfiguration()
        self.visibleTabs = visible
        self.hiddenTabs = hidden
    }

    /// Saves current configuration to UserDefaults
    private func saveConfiguration() {
        UserDefaults.standard.set(visibleTabs.map { $0.rawValue }, forKey: visibleTabsKey)
        UserDefaults.standard.set(hiddenTabs.map { $0.rawValue }, forKey: hiddenTabsKey)
    }

    // MARK: - Tab Management

    /// Returns tabs to show in the tab bar (respects maxVisibleTabs limit)
    var tabBarTabs: [DefaultTab] {
        return Array(visibleTabs.prefix(maxVisibleTabs))
    }

    /// Returns tabs to show in the More menu
    var moreTabs: [DefaultTab] {
        let overflowTabs = Array(visibleTabs.dropFirst(maxVisibleTabs))
        return overflowTabs + hiddenTabs
    }

    /// Checks if we need to show the More tab
    var needsMoreTab: Bool {
        return visibleTabs.count > maxVisibleTabs || !hiddenTabs.isEmpty
    }

    /// Moves a tab from visible to hidden
    func hideTab(_ tab: DefaultTab) {
        guard let index = visibleTabs.firstIndex(of: tab) else { return }
        visibleTabs.remove(at: index)
        hiddenTabs.append(tab)
    }

    /// Moves a tab from hidden to visible
    func showTab(_ tab: DefaultTab) {
        guard let index = hiddenTabs.firstIndex(of: tab) else { return }
        hiddenTabs.remove(at: index)
        visibleTabs.append(tab)
    }

    /// Reorders visible tabs
    func moveVisibleTab(from source: IndexSet, to destination: Int) {
        visibleTabs.move(fromOffsets: source, toOffset: destination)
    }

    /// Reorders hidden tabs
    func moveHiddenTab(from source: IndexSet, to destination: Int) {
        hiddenTabs.move(fromOffsets: source, toOffset: destination)
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
