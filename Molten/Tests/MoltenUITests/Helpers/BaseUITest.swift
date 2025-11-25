//
//  BaseUITest.swift
//  MoltenUITests
//
//  Created by Assistant on 10/28/25.
//  Base class for UI tests with common setup and navigation helpers
//

import XCTest

/// Base class for all UI tests
///
/// Provides:
/// - Automatic app launch with test configuration
/// - Common navigation helpers
/// - Consistent test setup/teardown
/// - Known test data environment
class BaseUITest: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Stop immediately when a failure occurs
        continueAfterFailure = false

        // Create app instance
        app = XCUIApplication()

        // Enable UI test mode with test data population
        // These flags tell the app to:
        // - Skip onboarding screens (alpha disclaimer)
        // - Disable animations for faster/more reliable tests
        // - Populate test data (inventory and shopping list items)
        app.launchArguments = [
            "UI-Testing",           // Enable UI test mode
            "USE-TEST-DATA",        // Populate known test data
            "DISABLE-ANIMATIONS"    // Faster, more reliable tests
        ]

        // Launch the app
        app.launch()

        // Wait for app to be ready (custom tab bar button appears)
        // The app uses a custom tab bar implementation (not TabView), so we look for
        // one of the tab buttons by name instead of app.tabBars
        // Using longer timeout (30s) to account for normal app startup with Core Data loading
        let catalogButton = app.buttons["Catalog"]
        XCTAssertTrue(catalogButton.waitForExistence(timeout: 30),
                      "App should launch and show tab bar within 30 seconds")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation Helpers

    /// Navigate to the Catalog tab
    func navigateToCatalog() {
        app.buttons["Catalog"].tapWhenHittable()
    }

    /// Navigate to the Inventory tab
    func navigateToInventory() {
        app.buttons["Inventory"].tapWhenHittable()
    }

    /// Navigate to the Purchases tab
    func navigateToPurchases() {
        app.buttons["Purchases"].tapWhenHittable()
    }

    /// Navigate to the Project Log tab
    func navigateToProjectLog() {
        app.buttons["Project Log"].tapWhenHittable()
    }

    /// Navigate to the Locations tab
    func navigateToLocations() {
        app.buttons["Locations"].tapWhenHittable()
    }

    /// Navigate to the Shopping tab
    func navigateToShopping() {
        app.buttons["Shopping"].tapWhenHittable()
    }

    /// Navigate to the Settings view
    /// Note: Settings is presented as a sheet, not a tab. Access via "More" menu.
    func navigateToSettings() {
        // Settings is accessed via the "More" button in the tab bar
        // First try direct Settings button (in case it's visible in tab bar)
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitToExist(timeout: 2) && settingsButton.isHittable {
            settingsButton.tapWhenHittable()
        } else {
            // Settings is in the More menu
            let moreButton = app.buttons["More"]
            if moreButton.waitToExist(timeout: 2) {
                moreButton.tapWhenHittable()

                // Wait for popover menu to appear
                Thread.sleep(forTimeInterval: 0.5)

                // Look for Settings in the More menu
                let settingsInMore = app.buttons["Settings"]
                if settingsInMore.waitToExist(timeout: 3) {
                    settingsInMore.tapWhenHittable()
                }
            }
        }

        // Wait for Settings sheet to fully appear
        // Settings is presented in a NavigationStack with "Settings" navigation title
        let navTitle = app.navigationBars["Settings"]
        _ = navTitle.waitForExistence(timeout: 5)

        // Wait a bit more for sheet content to render
        Thread.sleep(forTimeInterval: 1.0)

        // Wait for content to load - look for General section which should always be visible
        let generalSection = app.staticTexts["General"]
        _ = generalSection.waitForExistence(timeout: 5)
    }

    // MARK: - Common Actions

    /// Tap the "Add" button (usually in navigation bar)
    func tapAddButton() {
        // Try to find add button by common identifiers
        let addButton = app.buttons["addButton"].firstMatch
        if addButton.exists {
            addButton.tapWhenHittable()
        } else {
            // Fallback: Look for system add button
            app.navigationBars.buttons.matching(identifier: "Add").firstMatch.tapWhenHittable()
        }
    }

    /// Tap the "Cancel" button
    func tapCancelButton() {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel'")).firstMatch.tapWhenHittable()
    }

    /// Tap the "Save" button
    func tapSaveButton() {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save'")).firstMatch.tapWhenHittable()
    }

    // MARK: - Wait Helpers

    /// Wait for any loading indicators to disappear
    /// - Parameter timeout: Maximum time to wait (default: 5 seconds)
    func waitForLoadingToComplete(timeout: TimeInterval = 5) {
        let loadingIndicator = app.activityIndicators.firstMatch
        if loadingIndicator.exists {
            _ = loadingIndicator.waitToDisappear(timeout: timeout)
        }
    }

    // MARK: - Test Data Generation

    /// Generate test inventory data if needed (navigates to Settings > Test Data Generator)
    /// Use this at the start of tests that require inventory items
    func ensureTestInventoryExists() {
        // Check if inventory already has items
        navigateToInventory()
        waitForLoadingToComplete()

        // On iOS 17+, SwiftUI List renders as CollectionView
        let inventoryList = app.collectionViews["inventory.list"]
        guard inventoryList.waitForExistence(timeout: 10) else {
            // No inventory list found - try generating data
            generateTestInventory()
            return
        }

        // Check for cells in the inventory list
        let firstCell = inventoryList.cells.firstMatch
        if firstCell.waitToExist(timeout: 3) {
            // Already have inventory, no need to generate
            return
        }

        // No inventory found, generate test data
        generateTestInventory()
    }

    /// Generate test shopping list data if needed
    /// Use this at the start of tests that require shopping list items
    func ensureTestShoppingListExists() {
        // Navigate to shopping and check for items
        app.buttons["Shopping"].tapWhenHittable()
        waitForLoadingToComplete()

        let shoppingItem = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'shopping.item.'")).firstMatch
        if shoppingItem.waitToExist(timeout: 3) {
            // Already have shopping items, no need to generate
            return
        }

        // No shopping items found, generate test data
        generateTestShoppingList()
    }

    /// Navigate to Test Data Generator (Settings → Debug Settings → Test Data Generator)
    private func navigateToTestDataGenerator() {
        navigateToSettings()
        waitForLoadingToComplete()

        // Scroll down to find "Debug Settings" in Advanced section
        var foundDebugSettings = false
        for _ in 0..<3 {
            let debugSettingsText = app.staticTexts["Debug Settings"]
            if debugSettingsText.waitToExist(timeout: 2) {
                debugSettingsText.tapWhenHittable()
                foundDebugSettings = true
                break
            }
            app.swipeUp()
        }

        guard foundDebugSettings else { return }

        // Wait for Debug Settings to load
        Thread.sleep(forTimeInterval: 0.5)

        // Now tap "Test Data Generator" in Debug Settings
        let testDataGeneratorText = app.staticTexts["Test Data Generator"]
        if testDataGeneratorText.waitToExist(timeout: 3) {
            testDataGeneratorText.tapWhenHittable()
        }
    }

    /// Navigate to Test Data Generator and create inventory items
    private func generateTestInventory() {
        navigateToTestDataGenerator()

        // Tap the generate inventory button
        let generateButton = app.buttons["test_data_generate_inventory"]
        if generateButton.waitToExist(timeout: 5) {
            generateButton.tapWhenHittable()

            // Wait for generation to complete (watch for success message or progress to finish)
            let successText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Added'")).firstMatch
            _ = successText.waitToExist(timeout: 60) // Generation can take a while (25 items)

            // Navigate back to dismiss any open views
            dismissAnyOpenViews()
        }
    }

    /// Navigate to Test Data Generator and create shopping list items
    private func generateTestShoppingList() {
        navigateToTestDataGenerator()

        // Tap the generate shopping button
        let generateButton = app.buttons["test_data_generate_shopping"]
        if generateButton.waitToExist(timeout: 5) {
            generateButton.tapWhenHittable()

            // Wait for generation to complete
            let successText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Added'")).firstMatch
            _ = successText.waitToExist(timeout: 30)

            // Navigate back to dismiss any open views
            dismissAnyOpenViews()
        }
    }

    /// Dismiss any open modals, sheets, or navigation detail views to get back to main tab view
    private func dismissAnyOpenViews() {
        // Try tapping "Done" button if visible (often used in modals)
        let doneButton = app.buttons["Done"]
        if doneButton.waitToExist(timeout: 1) {
            doneButton.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Try to dismiss any sheets by swiping down
        app.swipeDown()
        Thread.sleep(forTimeInterval: 0.3)

        // Tap Catalog tab first (this will definitely leave settings)
        let catalogButton = app.buttons["Catalog"]
        if catalogButton.waitToExist(timeout: 2) {
            catalogButton.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// Wait for a specific navigation bar title to appear
    /// - Parameters:
    ///   - title: Expected navigation bar title
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    func waitForNavigationTitle(_ title: String, timeout: TimeInterval = 5) {
        let navBar = app.navigationBars[title]
        XCTAssertTrue(navBar.waitToExist(timeout: timeout),
                      "Navigation bar '\(title)' should appear within \(timeout) seconds")
    }

    // MARK: - Assertion Helpers

    /// Assert that an alert with specific title appeared
    /// - Parameter title: Expected alert title
    func assertAlertAppeared(withTitle title: String) {
        let alert = app.alerts[title]
        XCTAssertTrue(alert.waitToExist(timeout: 3),
                      "Alert '\(title)' should appear")
    }

    /// Assert that we're on a specific tab
    /// - Parameter tabName: Expected tab name
    func assertOnTab(_ tabName: String) {
        let tab = app.buttons[tabName]
        XCTAssertTrue(tab.isSelected, "Should be on '\(tabName)' tab")
    }
}
