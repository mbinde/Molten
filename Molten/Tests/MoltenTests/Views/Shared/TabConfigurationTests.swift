//
//  TabConfigurationTests.swift
//  Molten
//
//  Created by Assistant on 10/22/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
@testable import Molten

@Suite("TabConfiguration Tests")
@MainActor
struct TabConfigurationTests {

    // MARK: - allAvailableTabs Tests

    @Test("allAvailableTabs should include Plans, Logbook, and Settings")
    func testAllAvailableTabsIncludesNewTabs() {
        // Act: Get all available tabs
        let availableTabs = TabConfiguration.allAvailableTabs()

        // Assert: Should include Plans, Logbook, and Settings
        #expect(availableTabs.contains(.projectPlans), "Plans tab should be available")
        #expect(availableTabs.contains(.logbook), "Logbook tab should be available")
        #expect(availableTabs.contains(.settings), "Settings tab should be available")
    }

    @Test("Logbook tab should have correct display name")
    func testLogbookDisplayName() {
        // Act: Get logbook display name
        let displayName = DefaultTab.logbook.displayName

        // Assert: Should be "Logbook" not "Logs"
        #expect(displayName == "Logbook", "Logbook tab should display as 'Logbook'")
    }

    @Test("allAvailableTabs should exclude legacy Projects tab")
    func testAllAvailableTabsExcludesProjectsTab() {
        // Act: Get all available tabs
        let availableTabs = TabConfiguration.allAvailableTabs()

        // Assert: Should NOT include the legacy .projects tab
        #expect(!availableTabs.contains(.projects), "Legacy Projects tab should be excluded")
    }

    @Test("allAvailableTabs should include core tabs")
    func testAllAvailableTabsIncludesCoreTabs() {
        // Act: Get all available tabs
        let availableTabs = TabConfiguration.allAvailableTabs()

        // Assert: Should include core tabs
        #expect(availableTabs.contains(.catalog), "Catalog tab should be available")
        #expect(availableTabs.contains(.inventory), "Inventory tab should be available")
        #expect(availableTabs.contains(.shopping), "Shopping tab should be available")
        #expect(availableTabs.contains(.purchases), "Purchases tab should be available")
    }

    // MARK: - Default Configuration Tests

    @Test("defaultTabOrder should return all available tabs in preferred order")
    func testDefaultTabOrderContainsAllTabs() {
        // Act: Get default tab order
        let tabs = TabConfiguration.defaultTabOrder()
        let availableTabs = TabConfiguration.allAvailableTabs()

        // Assert: Should have all available tabs
        #expect(Set(tabs) == Set(availableTabs), "Default order should contain all available tabs")
        #expect(tabs.count == availableTabs.count, "Should have no duplicates")
    }

    @Test("defaultTabOrder should put common tabs first")
    func testDefaultTabOrderPrioritizesCommonTabs() {
        // Act: Get default tab order
        let tabs = TabConfiguration.defaultTabOrder()

        // Assert: Core tabs should come before specialty tabs
        let catalogIndex = tabs.firstIndex(of: .catalog) ?? 99
        let inventoryIndex = tabs.firstIndex(of: .inventory) ?? 99
        let settingsIndex = tabs.firstIndex(of: .settings) ?? 99

        #expect(catalogIndex < settingsIndex, "Catalog should come before Settings")
        #expect(inventoryIndex < settingsIndex, "Inventory should come before Settings")
    }

    @Test("defaultMaxVisibleTabs should return reasonable values")
    func testDefaultMaxVisibleTabs() {
        // Act: Get default max visible tabs
        let maxVisible = TabConfiguration.defaultMaxVisibleTabs()

        // Assert: Should be in reasonable range
        #expect(maxVisible >= 3, "Should show at least 3 tabs")
        #expect(maxVisible <= 8, "Should not show more than 8 tabs")
    }

    // MARK: - Tab Bar and More Menu Tests

    @Test("tabBarTabs should return first N tabs")
    func testTabBarTabsReturnsFirstN() {
        // Arrange: Create configuration
        let config = createCleanConfiguration()
        config.tabs = [.catalog, .inventory, .shopping, .purchases, .projectPlans, .logbook]
        config.maxVisibleTabs = 4

        // Act: Get tab bar tabs
        let tabBarTabs = config.tabBarTabs

        // Assert: Should only return first 4 tabs
        #expect(tabBarTabs.count == 4)
        #expect(tabBarTabs == [.catalog, .inventory, .shopping, .purchases])
    }

    @Test("moreTabs should return remaining tabs after maxVisibleTabs")
    func testMoreTabsReturnsRemaining() {
        // Arrange: Create configuration
        let config = createCleanConfiguration()
        config.tabs = [.catalog, .inventory, .shopping, .purchases, .projectPlans, .logbook]
        config.maxVisibleTabs = 4

        // Act: Get more tabs
        let moreTabs = config.moreTabs

        // Assert: Should return remaining tabs
        #expect(moreTabs.count == 2)
        #expect(moreTabs == [.projectPlans, .logbook])
    }

    @Test("needsMoreTab should be true when tabs exceed maxVisibleTabs")
    func testNeedsMoreTabWithOverflow() {
        // Arrange: Create configuration with more tabs than max visible
        let config = createCleanConfiguration()
        config.tabs = [.catalog, .inventory, .shopping, .purchases, .projectPlans]
        config.maxVisibleTabs = 4

        // Assert: Should need More tab
        #expect(config.needsMoreTab == true)
    }

    @Test("needsMoreTab should be false when tabs equal maxVisibleTabs")
    func testNeedsMoreTabExactMatch() {
        // Arrange: Create configuration with exactly max visible tabs
        let config = createCleanConfiguration()
        config.tabs = [.catalog, .inventory, .shopping, .purchases]
        config.maxVisibleTabs = 4

        // Assert: Should NOT need More tab
        #expect(config.needsMoreTab == false)
    }

    @Test("needsMoreTab should be false when tabs less than maxVisibleTabs")
    func testNeedsMoreTabFewerTabs() {
        // Arrange: Create configuration with fewer tabs than max
        let config = createCleanConfiguration()
        config.tabs = [.catalog, .inventory, .shopping]
        config.maxVisibleTabs = 4

        // Assert: Should NOT need More tab
        #expect(config.needsMoreTab == false)
    }

    // MARK: - Tab Reordering Tests

    @Test("moveTabs should reorder tabs correctly")
    func testMoveTabsReorders() {
        // Arrange: Create configuration with specific order
        let config = createCleanConfiguration()
        config.tabs = [.catalog, .inventory, .shopping, .purchases]

        // Act: Move catalog (index 0) to position 2
        let source = IndexSet(integer: 0)
        config.moveTabs(from: source, to: 2)

        // Assert: Order should be: inventory, catalog, shopping, purchases
        #expect(config.tabs[0] == .inventory)
        #expect(config.tabs[1] == .catalog)
        #expect(config.tabs[2] == .shopping)
        #expect(config.tabs[3] == .purchases)
    }

    @Test("moveTabs should maintain all tabs")
    func testMoveTabsPreservesAllTabs() {
        // Arrange: Create configuration
        let config = createCleanConfiguration()
        let originalTabs = config.tabs
        let originalCount = config.tabs.count

        // Act: Move a tab
        let source = IndexSet(integer: 0)
        config.moveTabs(from: source, to: config.tabs.count - 1)

        // Assert: Should still have all tabs
        #expect(config.tabs.count == originalCount)
        #expect(Set(config.tabs) == Set(originalTabs))
    }

    // MARK: - Configuration Validation Tests

    @Test("resetToDefaults should restore default configuration")
    func testResetToDefaultsRestores() {
        // Arrange: Create configuration and modify it
        let config = createCleanConfiguration()
        config.tabs = [.settings, .logbook]
        config.maxVisibleTabs = 8

        // Act: Reset to defaults
        config.resetToDefaults()

        // Assert: Should match default configuration
        let defaultTabs = TabConfiguration.defaultTabOrder()
        let defaultMaxVisible = TabConfiguration.defaultMaxVisibleTabs()
        #expect(config.tabs == defaultTabs)
        #expect(config.maxVisibleTabs == defaultMaxVisible)
    }

    // MARK: - MaxVisibleTabs Tests

    @Test("maxVisibleTabs should affect tabBarTabs count")
    func testMaxVisibleTabsAffectsTabBar() {
        // Arrange: Create configuration with 6 tabs
        let config = createCleanConfiguration()
        config.tabs = [.catalog, .inventory, .shopping, .purchases, .projectPlans, .logbook]

        // Act & Assert: Change maxVisibleTabs and verify tabBarTabs adapts
        config.maxVisibleTabs = 3
        #expect(config.tabBarTabs.count == 3)

        config.maxVisibleTabs = 5
        #expect(config.tabBarTabs.count == 5)

        config.maxVisibleTabs = 10
        #expect(config.tabBarTabs.count == 6, "Should not exceed total tabs")
    }

    @Test("maxVisibleTabs should affect moreTabs count")
    func testMaxVisibleTabsAffectsMoreMenu() {
        // Arrange: Create configuration with 6 tabs
        let config = createCleanConfiguration()
        config.tabs = [.catalog, .inventory, .shopping, .purchases, .projectPlans, .logbook]

        // Act & Assert: Change maxVisibleTabs and verify moreTabs adapts
        config.maxVisibleTabs = 4
        #expect(config.moreTabs.count == 2)

        config.maxVisibleTabs = 6
        #expect(config.moreTabs.count == 0)
    }

    // MARK: - Helper Methods

    /// Creates a clean TabConfiguration instance for testing
    /// This bypasses UserDefaults to ensure clean state
    private func createCleanConfiguration() -> TabConfiguration {
        // Clear UserDefaults for tab configuration
        UserDefaults.standard.removeObject(forKey: "userTabOrder")
        UserDefaults.standard.removeObject(forKey: "userMaxVisibleTabs")

        // Create new configuration
        return TabConfiguration()
    }
}
