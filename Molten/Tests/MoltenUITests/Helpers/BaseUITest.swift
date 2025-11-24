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

        // NOTE: UI test mode flags (UI-Testing, RESET-DATABASE, USE-TEST-DATA)
        // are disabled until the app's UI test infrastructure is complete.
        // Tests currently run against production app with real/existing data.
        //
        // TODO: Enable these when MoltenApp's configureUITestEnvironment() is complete:
        // app.launchArguments = [
        //     "UI-Testing",           // Enable UI test mode
        //     "RESET-DATABASE",       // Start with clean database
        //     "USE-TEST-DATA",        // Populate known test data
        //     "DISABLE-ANIMATIONS"    // Faster, more reliable tests
        // ]

        // Launch the app
        app.launch()

        // Dismiss any onboarding/disclaimer screens
        dismissOnboardingScreensIfNeeded()

        // Wait for app to be ready (tab bar appears)
        // Using longer timeout (30s) to account for normal app startup with Core Data loading
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30),
                      "App should launch and show tab bar within 30 seconds")
    }

    /// Dismiss onboarding or disclaimer screens that might block the main UI
    private func dismissOnboardingScreensIfNeeded() {
        // Wait a moment for any sheets to appear
        Thread.sleep(forTimeInterval: 2)

        // Try to dismiss alpha disclaimer (has specific accessibility identifier)
        let alphaDisclaimerButton = app.buttons["alpha_disclaimer_acknowledge"]
        if alphaDisclaimerButton.waitForExistence(timeout: 5) {
            alphaDisclaimerButton.tap()
            // Wait for sheet to dismiss
            Thread.sleep(forTimeInterval: 1)
        }

        // Also try by label "Yes, I Understand"
        let understandButton = app.buttons["Yes, I Understand"]
        if understandButton.waitForExistence(timeout: 2) {
            understandButton.tap()
            Thread.sleep(forTimeInterval: 1)
        }

        // Try other common dismiss patterns
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 2) {
            continueButton.tap()
        }

        let gotItButton = app.buttons["Got It"]
        if gotItButton.waitForExistence(timeout: 2) {
            gotItButton.tap()
        }

        let dismissButton = app.buttons["Dismiss"]
        if dismissButton.waitForExistence(timeout: 2) {
            dismissButton.tap()
        }
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

    /// Navigate to the Settings tab
    func navigateToSettings() {
        app.buttons["Settings"].tapWhenHittable()
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
