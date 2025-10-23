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

    @Test("defaultConfiguration should return 4 visible tabs by default")
    func testDefaultConfigurationVisibleTabsCount() {
        // Act: Get default configuration
        let (visibleTabs, _) = TabConfiguration.defaultConfiguration()

        // Assert: Should have 4 visible tabs (Catalog, Inventory, Shopping, Purchases)
        #expect(visibleTabs.count == 4, "Should have 4 default visible tabs")
        #expect(visibleTabs.contains(.catalog))
        #expect(visibleTabs.contains(.inventory))
        #expect(visibleTabs.contains(.shopping))
        #expect(visibleTabs.contains(.purchases))
    }

    @Test("defaultConfiguration should put Plans, Logbook, and Settings in hidden tabs")
    func testDefaultConfigurationHiddenTabs() {
        // Act: Get default configuration
        let (_, hiddenTabs) = TabConfiguration.defaultConfiguration()

        // Assert: Plans, Logbook, and Settings should be hidden by default
        #expect(hiddenTabs.contains(.projectPlans), "Plans should be hidden by default")
        #expect(hiddenTabs.contains(.logbook), "Logbook should be hidden by default")
        #expect(hiddenTabs.contains(.settings), "Settings should be hidden by default")
    }

    // MARK: - Tab Visibility Management Tests

    @Test("hideTab should move tab from visible to hidden")
    func testHideTabMovesTabToHidden() {
        // Arrange: Create configuration with catalog in visible tabs
        let config = createCleanConfiguration()
        config.visibleTabs = [.catalog, .inventory, .shopping, .purchases]
        config.hiddenTabs = [.projectPlans, .logbook, .settings]

        // Act: Hide catalog tab
        config.hideTab(.catalog)

        // Assert: Catalog should now be in hidden tabs
        #expect(!config.visibleTabs.contains(.catalog), "Catalog should be removed from visible tabs")
        #expect(config.hiddenTabs.contains(.catalog), "Catalog should be added to hidden tabs")
    }

    @Test("showTab should move tab from hidden to visible")
    func testShowTabMovesTabToVisible() {
        // Arrange: Create configuration with settings in hidden tabs
        let config = createCleanConfiguration()
        config.visibleTabs = [.catalog, .inventory, .shopping, .purchases]
        config.hiddenTabs = [.projectPlans, .logbook, .settings]

        // Act: Show settings tab
        config.showTab(.settings)

        // Assert: Settings should now be in visible tabs
        #expect(config.visibleTabs.contains(.settings), "Settings should be added to visible tabs")
        #expect(!config.hiddenTabs.contains(.settings), "Settings should be removed from hidden tabs")
    }

    @Test("hideTab should do nothing if tab is not in visible tabs")
    func testHideTabWithNonVisibleTab() {
        // Arrange: Create configuration
        let config = createCleanConfiguration()
        let initialVisibleCount = config.visibleTabs.count
        let initialHiddenCount = config.hiddenTabs.count

        // Act: Try to hide a tab that's already hidden
        config.hideTab(.settings)

        // Assert: Counts should remain the same
        #expect(config.visibleTabs.count == initialVisibleCount)
        #expect(config.hiddenTabs.count == initialHiddenCount)
    }

    // MARK: - Tab Reordering Tests

    @Test("moveVisibleTab should reorder visible tabs")
    func testMoveVisibleTabReordersTabs() {
        // Arrange: Create configuration with specific order
        let config = createCleanConfiguration()
        config.visibleTabs = [.catalog, .inventory, .shopping, .purchases]

        // Act: Move catalog (index 0) to position 2
        let source = IndexSet(integer: 0)
        config.moveVisibleTab(from: source, to: 2)

        // Assert: Order should be: inventory, catalog, shopping, purchases
        #expect(config.visibleTabs[0] == .inventory)
        #expect(config.visibleTabs[1] == .catalog)
        #expect(config.visibleTabs[2] == .shopping)
        #expect(config.visibleTabs[3] == .purchases)
    }

    @Test("moveHiddenTab should reorder hidden tabs")
    func testMoveHiddenTabReordersTabs() {
        // Arrange: Create configuration with specific order
        let config = createCleanConfiguration()
        config.hiddenTabs = [.projectPlans, .logbook, .settings]

        // Act: Move settings (index 2) to position 0
        let source = IndexSet(integer: 2)
        config.moveHiddenTab(from: source, to: 0)

        // Assert: Order should be: settings, projectPlans, logbook
        #expect(config.hiddenTabs[0] == .settings)
        #expect(config.hiddenTabs[1] == .projectPlans)
        #expect(config.hiddenTabs[2] == .logbook)
    }

    // MARK: - More Tab Logic Tests

    @Test("tabBarTabs should return first 4 visible tabs when there are more than 4")
    func testTabBarTabsReturnsMaxFour() {
        // Arrange: Create configuration with 5 visible tabs
        let config = createCleanConfiguration()
        config.visibleTabs = [.catalog, .inventory, .shopping, .purchases, .projectPlans]
        config.hiddenTabs = [.logbook, .settings]

        // Act: Get tab bar tabs
        let tabBarTabs = config.tabBarTabs

        // Assert: Should only return first 4 tabs
        #expect(tabBarTabs.count == 4, "Tab bar should show max 4 tabs")
        #expect(tabBarTabs == [.catalog, .inventory, .shopping, .purchases])
    }

    @Test("tabBarTabs should return all visible tabs when there are 4 or fewer")
    func testTabBarTabsReturnsAllWhenFourOrLess() {
        // Arrange: Create configuration with 3 visible tabs
        let config = createCleanConfiguration()
        config.visibleTabs = [.catalog, .inventory, .shopping]
        config.hiddenTabs = [.purchases, .projectPlans, .logbook, .settings]

        // Act: Get tab bar tabs
        let tabBarTabs = config.tabBarTabs

        // Assert: Should return all 3 tabs
        #expect(tabBarTabs.count == 3)
        #expect(tabBarTabs == [.catalog, .inventory, .shopping])
    }

    @Test("moreTabs should include overflow visible tabs and all hidden tabs")
    func testMoreTabsIncludesOverflowAndHidden() {
        // Arrange: Create configuration with 5 visible tabs and 2 hidden tabs
        let config = createCleanConfiguration()
        config.visibleTabs = [.catalog, .inventory, .shopping, .purchases, .projectPlans]
        config.hiddenTabs = [.logbook, .settings]

        // Act: Get more tabs
        let moreTabs = config.moreTabs

        // Assert: Should include 5th visible tab + 2 hidden tabs = 3 total
        #expect(moreTabs.count == 3)
        #expect(moreTabs[0] == .projectPlans, "First overflow tab should be projectPlans")
        #expect(moreTabs[1] == .logbook, "Hidden tabs should follow overflow tabs")
        #expect(moreTabs[2] == .settings)
    }

    @Test("moreTabs should only include hidden tabs when 4 or fewer visible tabs")
    func testMoreTabsOnlyHiddenWhenNoOverflow() {
        // Arrange: Create configuration with 4 visible tabs and 3 hidden tabs
        let config = createCleanConfiguration()
        config.visibleTabs = [.catalog, .inventory, .shopping, .purchases]
        config.hiddenTabs = [.projectPlans, .logbook, .settings]

        // Act: Get more tabs
        let moreTabs = config.moreTabs

        // Assert: Should only include hidden tabs (no overflow)
        #expect(moreTabs.count == 3)
        #expect(moreTabs == [.projectPlans, .logbook, .settings])
    }

    @Test("needsMoreTab should be true when there are more than 4 visible tabs")
    func testNeedsMoreTabWithOverflow() {
        // Arrange: Create configuration with 5 visible tabs
        let config = createCleanConfiguration()
        config.visibleTabs = [.catalog, .inventory, .shopping, .purchases, .projectPlans]
        config.hiddenTabs = []

        // Assert: Should need More tab
        #expect(config.needsMoreTab == true, "Should need More tab with 5 visible tabs")
    }

    @Test("needsMoreTab should be true when there are hidden tabs")
    func testNeedsMoreTabWithHiddenTabs() {
        // Arrange: Create configuration with 4 visible tabs and 3 hidden tabs
        let config = createCleanConfiguration()
        config.visibleTabs = [.catalog, .inventory, .shopping, .purchases]
        config.hiddenTabs = [.projectPlans, .logbook, .settings]

        // Assert: Should need More tab
        #expect(config.needsMoreTab == true, "Should need More tab when there are hidden tabs")
    }

    @Test("needsMoreTab should be false when 4 or fewer visible tabs and no hidden tabs")
    func testNeedsMoreTabFalseWhenNoOverflowOrHidden() {
        // Arrange: Create configuration with 4 visible tabs and no hidden tabs
        let config = createCleanConfiguration()
        config.visibleTabs = [.catalog, .inventory, .shopping, .purchases]
        config.hiddenTabs = []

        // Assert: Should NOT need More tab
        #expect(config.needsMoreTab == false, "Should not need More tab with 4 visible tabs and no hidden tabs")
    }

    // MARK: - Configuration Validation Tests

    @Test("resetToDefaults should restore default configuration")
    func testResetToDefaultsRestoresDefaults() {
        // Arrange: Create configuration and modify it
        let config = createCleanConfiguration()
        config.visibleTabs = [.settings]
        config.hiddenTabs = [.catalog, .inventory, .shopping, .purchases, .projectPlans, .logbook]

        // Act: Reset to defaults
        config.resetToDefaults()

        // Assert: Should match default configuration
        let (defaultVisible, defaultHidden) = TabConfiguration.defaultConfiguration()
        #expect(config.visibleTabs == defaultVisible)
        #expect(config.hiddenTabs == defaultHidden)
    }

    // MARK: - Helper Methods

    /// Creates a clean TabConfiguration instance for testing
    /// This bypasses UserDefaults to ensure clean state
    private func createCleanConfiguration() -> TabConfiguration {
        // Clear UserDefaults for tab configuration
        UserDefaults.standard.removeObject(forKey: "userVisibleTabs")
        UserDefaults.standard.removeObject(forKey: "userHiddenTabs")

        // Create new configuration
        return TabConfiguration()
    }
}
