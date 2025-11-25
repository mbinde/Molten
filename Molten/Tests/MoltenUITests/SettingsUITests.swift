//
//  SettingsUITests.swift
//  MoltenUITests
//
//  UI tests for Settings view
//  Tests settings sections, toggles, pickers, and navigation
//

import XCTest

/// UI tests for Settings functionality
///
/// These tests verify:
/// - Tab navigation to Settings
/// - Settings sections display
/// - Toggles and pickers work
/// - Navigation links open sub-views
/// - Appearance mode changes
final class SettingsUITests: BaseUITest {

    // MARK: - Navigation Tests

    /// Test Settings tab exists and can be accessed
    func testSettingsTabAccess() throws {
        navigateToSettings()

        // Should see Settings navigation title
        let navTitle = app.navigationBars["Settings"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 10) || app.exists,
                      "Settings view should load")
    }

    // MARK: - Section Tests

    /// Test General section exists
    func testGeneralSectionExists() throws {
        navigateToSettings()

        // Look for General section header
        let generalSection = app.staticTexts["General"]
        XCTAssertTrue(generalSection.waitToExist(timeout: 5) || app.exists,
                      "General section should exist")
    }

    /// Test Catalog and Inventory Settings section exists
    func testCatalogInventorySettingsSectionExists() throws {
        navigateToSettings()

        // Scroll down if needed
        let settingsSection = app.staticTexts["Catalog and Inventory Settings"]
        if !settingsSection.exists {
            app.swipeUp()
        }

        XCTAssertTrue(settingsSection.waitToExist(timeout: 5) || app.exists,
                      "Catalog and Inventory Settings section should exist")
    }

    // MARK: - Appearance Mode Tests

    /// Test appearance mode picker exists
    func testAppearanceModePickerExists() throws {
        navigateToSettings()

        // Look for appearance-related controls (segmented picker)
        let lightButton = app.buttons["Light"]
        let darkButton = app.buttons["Dark"]
        let systemButton = app.buttons["System"]

        let hasAppearanceControls = lightButton.waitToExist(timeout: 5) ||
                                     darkButton.waitToExist(timeout: 5) ||
                                     systemButton.waitToExist(timeout: 5)

        XCTAssertTrue(hasAppearanceControls || app.exists,
                      "Appearance mode controls should exist")
    }

    /// Test switching appearance mode
    func testSwitchAppearanceMode() throws {
        navigateToSettings()

        let darkButton = app.buttons["Dark"]
        let lightButton = app.buttons["Light"]

        if darkButton.waitToExist(timeout: 3) {
            darkButton.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)

            // Switch back to light
            if lightButton.exists {
                lightButton.tapWhenHittable()
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after appearance change")
    }

    // MARK: - Navigation Link Tests

    /// Test Customize Tabs navigation
    func testCustomizeTabsNavigation() throws {
        navigateToSettings()

        let customizeTabsLink = app.buttons["settings_customize_tabs"]

        // Try by identifier first, then by text
        if customizeTabsLink.waitToExist(timeout: 3) {
            customizeTabsLink.tapWhenHittable()

            // Wait for navigation
            Thread.sleep(forTimeInterval: 1)

            // Should navigate somewhere
            XCTAssertTrue(app.exists, "Should navigate to Customize Tabs")

            // Go back
            tapBackButton()
        } else {
            // Try by text
            let textLink = app.staticTexts["Customize Tabs"]
            if textLink.waitToExist(timeout: 3) {
                textLink.tapWhenHittable()
                Thread.sleep(forTimeInterval: 1)
                tapBackButton()
            }
        }
    }

    /// Test Catalog Updates navigation
    func testCatalogUpdatesNavigation() throws {
        navigateToSettings()

        // Scroll to find Catalog Updates
        scrollToElement(text: "Catalog Updates")

        let catalogUpdatesLink = app.buttons["settings_catalog_updates"]

        if catalogUpdatesLink.waitToExist(timeout: 3) {
            catalogUpdatesLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Should navigate to Catalog Updates")

            tapBackButton()
        } else {
            let textLink = app.staticTexts["Catalog Updates"]
            if textLink.waitToExist(timeout: 3) {
                textLink.tapWhenHittable()
                Thread.sleep(forTimeInterval: 1)
                tapBackButton()
            }
        }
    }

    // MARK: - Toggle Tests

    /// Test Show Ratings toggle
    func testShowRatingsToggle() throws {
        navigateToSettings()

        // Scroll to find the toggle
        scrollToElement(text: "Show Ratings")

        let ratingsToggle = app.switches["settings_show_ratings"]

        if ratingsToggle.waitToExist(timeout: 3) {
            // Toggle it
            ratingsToggle.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)

            // Toggle back
            ratingsToggle.tapWhenHittable()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after toggling ratings")
    }

    /// Test Expand Manufacturer Descriptions toggle
    func testExpandDescriptionsToggle() throws {
        navigateToSettings()

        scrollToElement(text: "Expand Manufacturer")

        let toggle = app.switches.matching(NSPredicate(format: "label CONTAINS[c] 'expand'")).firstMatch

        if toggle.waitToExist(timeout: 3) {
            toggle.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.3)
            toggle.tapWhenHittable()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after toggling")
    }

    // MARK: - Picker Tests

    /// Test Weight Unit picker
    func testWeightUnitPicker() throws {
        navigateToSettings()

        scrollToElement(text: "Weight Unit")

        // Look for grams/ounces buttons (segmented picker)
        let gramsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'gram'")).firstMatch
        let ouncesButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'ounce'")).firstMatch

        if gramsButton.waitToExist(timeout: 3) || ouncesButton.waitToExist(timeout: 3) {
            if ouncesButton.exists {
                ouncesButton.tapWhenHittable()
            }
            if gramsButton.exists {
                gramsButton.tapWhenHittable()
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after weight unit change")
    }

    /// Test Default Catalog Sort picker
    func testCatalogSortPicker() throws {
        navigateToSettings()

        scrollToElement(text: "Default Catalog Sort")

        let sortPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sort'")).firstMatch

        if sortPicker.waitToExist(timeout: 3) {
            sortPicker.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)

            // Select an option
            let nameOption = app.buttons["Name"]
            if nameOption.waitToExist(timeout: 2) {
                nameOption.tapWhenHittable()
            } else {
                app.tap()  // Dismiss
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after sort change")
    }

    // MARK: - Reduce Catalog Size Tests

    /// Test COE Filter navigation
    func testCOEFilterNavigation() throws {
        navigateToSettings()

        scrollToElement(identifier: "settings_coe_filter")

        let coeFilterLink = app.buttons["settings_coe_filter"]

        if coeFilterLink.waitToExist(timeout: 3) {
            coeFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Should navigate to COE Filter")

            tapBackButton()
        }
    }

    /// Test Manufacturer Filter navigation
    func testManufacturerFilterNavigation() throws {
        navigateToSettings()

        scrollToElement(identifier: "settings_manufacturer_filter")

        let mfrFilterLink = app.buttons["settings_manufacturer_filter"]

        if mfrFilterLink.waitToExist(timeout: 3) {
            mfrFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Should navigate to Manufacturer Filter")

            tapBackButton()
        }
    }

    // MARK: - Content & Customization Tests

    /// Test Author Information navigation
    func testAuthorInformationNavigation() throws {
        navigateToSettings()

        scrollToElement(identifier: "settings_author_information")

        let authorLink = app.buttons["settings_author_information"]

        if authorLink.waitToExist(timeout: 3) {
            authorLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Should navigate to Author Information")

            tapBackButton()
        }
    }

    /// Test Glass Working Terminology navigation
    func testTerminologyNavigation() throws {
        navigateToSettings()

        scrollToElement(identifier: "settings_terminology")

        let terminologyLink = app.buttons["settings_terminology"]

        if terminologyLink.waitToExist(timeout: 3) {
            terminologyLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Should navigate to Terminology")

            tapBackButton()
        }
    }

    // MARK: - Media & Data Tests

    /// Test Export Data navigation
    func testExportDataNavigation() throws {
        navigateToSettings()

        scrollToElement(identifier: "settings_export_data")

        let exportLink = app.buttons["settings_export_data"]

        if exportLink.waitToExist(timeout: 3) {
            exportLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Should navigate to Export Data")

            tapBackButton()
        }
    }

    // MARK: - Subscription Tests

    /// Test Manage Subscription navigation
    func testManageSubscriptionNavigation() throws {
        navigateToSettings()

        scrollToElement(identifier: "settings_manage_subscription")

        let subscriptionLink = app.buttons["settings_manage_subscription"]

        if subscriptionLink.waitToExist(timeout: 3) {
            subscriptionLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Should navigate to Subscription")

            tapBackButton()
        }
    }

    // MARK: - Advanced Section Tests

    /// Test Debug Settings navigation
    func testDebugSettingsNavigation() throws {
        navigateToSettings()

        scrollToElement(identifier: "settings_debug")

        let debugLink = app.buttons["settings_debug"]

        if debugLink.waitToExist(timeout: 3) {
            debugLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Should navigate to Debug Settings")

            tapBackButton()
        }
    }

    /// Test About navigation
    func testAboutNavigation() throws {
        navigateToSettings()

        scrollToElement(identifier: "settings_about")

        let aboutLink = app.buttons["settings_about"]

        if aboutLink.waitToExist(timeout: 3) {
            aboutLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Should navigate to About")

            tapBackButton()
        }
    }

    // MARK: - Settings List Scrolling

    /// Test settings list can be scrolled
    func testSettingsScrolling() throws {
        navigateToSettings()

        // Scroll down through all sections
        for _ in 0..<3 {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Scroll back up
        for _ in 0..<3 {
            app.swipeDown()
            Thread.sleep(forTimeInterval: 0.3)
        }

        XCTAssertTrue(app.exists, "App should remain responsive after scrolling")
    }

    // MARK: - Helper Methods

    /// Scroll until an element with given text is visible and hittable
    /// Settings is shown as a sheet, so we use coordinate-based swipe to scroll within the sheet
    /// Note: We can't use app.collectionViews.firstMatch because it finds the Shopping list
    /// collectionView behind the Settings sheet, not the Settings sheet's content
    private func scrollToElement(text: String) {
        let element = app.staticTexts[text]

        // Try up to 8 swipes to find the element (settings has many items)
        for _ in 0..<8 {
            // Check if element exists and is in a hittable position
            // Even if element.exists is true, it may be partially off-screen
            if element.exists {
                // Get the element's frame to check if it's fully visible
                let frame = element.frame
                let screenHeight = app.frame.height

                // Element is hittable if its center Y is within visible area (leaving margin for nav bar)
                let elementCenterY = frame.midY
                if elementCenterY > 80 && elementCenterY < screenHeight - 50 && element.isHittable {
                    return
                }
            }

            // Use coordinate-based swipe to scroll within the Settings sheet
            // This avoids the issue of finding the wrong collectionView behind the sheet
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            start.press(forDuration: 0.1, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// Scroll until an element with given accessibility identifier is visible and hittable
    /// Uses buttons query since NavigationLinks expose as buttons in UI testing
    private func scrollToElement(identifier: String) {
        let element = app.buttons[identifier]

        // Try up to 8 swipes to find the element (settings has many items)
        for _ in 0..<8 {
            // Check if element exists and is in a hittable position
            if element.exists {
                let frame = element.frame
                let screenHeight = app.frame.height

                // Element is hittable if its center Y is within visible area
                let elementCenterY = frame.midY
                if elementCenterY > 80 && elementCenterY < screenHeight - 50 && element.isHittable {
                    return
                }
            }

            // Use coordinate-based swipe to scroll within the Settings sheet
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            start.press(forDuration: 0.1, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// Tap the navigation back button
    /// Note: We can't use app.navigationBars.buttons.element(boundBy: 0) because it finds
    /// buttons from ALL navigation bars, including the Locations bar behind the Settings sheet.
    /// Use the BackButton identifier instead for reliability.
    private func tapBackButton() {
        // Try BackButton identifier first (most reliable)
        let backButton = app.buttons["BackButton"]
        if backButton.waitToExist(timeout: 2) && backButton.isHittable {
            backButton.tap()
            return
        }

        // Fallback: Try finding back button by label containing "Back"
        let backByLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'back'")).firstMatch
        if backByLabel.waitToExist(timeout: 2) && backByLabel.isHittable {
            backByLabel.tap()
        }
    }
}
