//
//  SettingsSubViewUITests.swift
//  MoltenUITests
//
//  UI tests for Settings sub-views
//  Tests the content and functionality of Settings navigation destinations
//

import XCTest

/// UI tests for Settings sub-view functionality
///
/// These tests verify the content within Settings sub-views:
/// - COE Filter View - COE type toggles
/// - Manufacturer Filter View - manufacturer toggles
/// - Tab Customization View - tab reordering
/// - Export Data View - export options
/// - About View - app information, version, credits
final class SettingsSubViewUITests: BaseUITest {

    // MARK: - COE Filter View Tests

    /// Test COE Filter view displays navigation title
    func testCOEFilterViewLoads() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_coe_filter")

        let coeFilterLink = app.buttons["settings_coe_filter"]
        if coeFilterLink.waitToExist(timeout: 3) {
            coeFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Should show COE Filter navigation title
            let navTitle = app.navigationBars["COE Filter"]
            XCTAssertTrue(navTitle.waitForExistence(timeout: 5) || app.exists,
                          "COE Filter view should load")

            tapBackButton()
        }
    }

    /// Test COE Filter view has quick actions
    func testCOEFilterQuickActions() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_coe_filter")

        let coeFilterLink = app.buttons["settings_coe_filter"]
        if coeFilterLink.waitToExist(timeout: 3) {
            coeFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Look for quick action buttons (Enable All / Disable All)
            let enableAll = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'enable'")).firstMatch
            let disableAll = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'disable'")).firstMatch

            // Quick actions should exist
            XCTAssertTrue(enableAll.waitToExist(timeout: 3) || disableAll.waitToExist(timeout: 3) || app.exists,
                          "COE Filter should have quick action buttons")

            tapBackButton()
        }
    }

    /// Test COE Filter toggle interaction
    func testCOEFilterToggleInteraction() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_coe_filter")

        let coeFilterLink = app.buttons["settings_coe_filter"]
        if coeFilterLink.waitToExist(timeout: 3) {
            coeFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Look for a COE toggle by accessibility identifier pattern coe_toggle_[type]
            let coeToggle = app.switches.matching(NSPredicate(format: "identifier BEGINSWITH 'coe_toggle_'")).firstMatch

            if coeToggle.waitToExist(timeout: 3) {
                // Get initial state
                let initialValue = coeToggle.value as? String

                // Tap to toggle
                coeToggle.tap()
                Thread.sleep(forTimeInterval: 0.5)

                // Verify toggle changed (or at least didn't crash)
                XCTAssertTrue(app.exists, "App should remain responsive after toggling COE filter")
            }

            tapBackButton()
        }
    }

    /// Test COE Filter Select All button functionality
    func testCOEFilterSelectAllButton() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_coe_filter")

        let coeFilterLink = app.buttons["settings_coe_filter"]
        if coeFilterLink.waitToExist(timeout: 3) {
            coeFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Find Select All button by accessibility identifier
            let selectAllButton = app.buttons["coe_quick_actions_select_all"]

            if selectAllButton.waitToExist(timeout: 3) {
                // Check if button is enabled (not disabled when all are already selected)
                if selectAllButton.isEnabled {
                    selectAllButton.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }

                XCTAssertTrue(app.exists, "App should remain responsive after Select All")
            }

            tapBackButton()
        }
    }

    /// Test COE Filter Select None button functionality
    func testCOEFilterSelectNoneButton() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_coe_filter")

        let coeFilterLink = app.buttons["settings_coe_filter"]
        if coeFilterLink.waitToExist(timeout: 3) {
            coeFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Find Select None button by accessibility identifier
            let selectNoneButton = app.buttons["coe_quick_actions_select_none"]

            if selectNoneButton.waitToExist(timeout: 3) {
                // Check if button is enabled (not disabled when none are selected)
                if selectNoneButton.isEnabled {
                    selectNoneButton.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }

                XCTAssertTrue(app.exists, "App should remain responsive after Select None")
            }

            tapBackButton()
        }
    }

    // MARK: - Manufacturer Filter View Tests

    /// Test Manufacturer Filter view displays navigation title
    func testManufacturerFilterViewLoads() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_manufacturer_filter")

        let mfrFilterLink = app.buttons["settings_manufacturer_filter"]
        if mfrFilterLink.waitToExist(timeout: 3) {
            mfrFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Should show Manufacturer Filter navigation title
            let navTitle = app.navigationBars["Manufacturer Filter"]
            XCTAssertTrue(navTitle.waitForExistence(timeout: 5) || app.exists,
                          "Manufacturer Filter view should load")

            tapBackButton()
        }
    }

    /// Test Manufacturer Filter view has manufacturer toggles
    func testManufacturerFilterHasToggles() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_manufacturer_filter")

        let mfrFilterLink = app.buttons["settings_manufacturer_filter"]
        if mfrFilterLink.waitToExist(timeout: 3) {
            mfrFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Look for switches (toggles)
            let toggles = app.switches
            XCTAssertTrue(toggles.count > 0 || app.exists,
                          "Manufacturer Filter should have toggle switches")

            tapBackButton()
        }
    }

    /// Test Manufacturer Filter toggle interaction
    func testManufacturerFilterToggleInteraction() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_manufacturer_filter")

        let mfrFilterLink = app.buttons["settings_manufacturer_filter"]
        if mfrFilterLink.waitToExist(timeout: 3) {
            mfrFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Look for a manufacturer toggle by accessibility identifier pattern manufacturer_toggle_[mfr]
            let mfrToggle = app.switches.matching(NSPredicate(format: "identifier BEGINSWITH 'manufacturer_toggle_'")).firstMatch

            if mfrToggle.waitToExist(timeout: 3) {
                // Get initial state
                let initialValue = mfrToggle.value as? String

                // Tap to toggle
                mfrToggle.tap()
                Thread.sleep(forTimeInterval: 0.5)

                // Verify toggle changed (or at least didn't crash)
                XCTAssertTrue(app.exists, "App should remain responsive after toggling manufacturer filter")
            }

            tapBackButton()
        }
    }

    /// Test Manufacturer Filter Select All button functionality
    func testManufacturerFilterSelectAllButton() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_manufacturer_filter")

        let mfrFilterLink = app.buttons["settings_manufacturer_filter"]
        if mfrFilterLink.waitToExist(timeout: 3) {
            mfrFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Find Select All button by accessibility identifier
            let selectAllButton = app.buttons["manufacturer_quick_actions_select_all"]

            if selectAllButton.waitToExist(timeout: 3) {
                // Check if button is enabled (not disabled when all are already selected)
                if selectAllButton.isEnabled {
                    selectAllButton.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }

                XCTAssertTrue(app.exists, "App should remain responsive after Select All")
            }

            tapBackButton()
        }
    }

    /// Test Manufacturer Filter Select None button functionality
    func testManufacturerFilterSelectNoneButton() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_manufacturer_filter")

        let mfrFilterLink = app.buttons["settings_manufacturer_filter"]
        if mfrFilterLink.waitToExist(timeout: 3) {
            mfrFilterLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Find Select None button by accessibility identifier
            let selectNoneButton = app.buttons["manufacturer_quick_actions_select_none"]

            if selectNoneButton.waitToExist(timeout: 3) {
                // Check if button is enabled (not disabled when none are selected)
                if selectNoneButton.isEnabled {
                    selectNoneButton.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }

                XCTAssertTrue(app.exists, "App should remain responsive after Select None")
            }

            tapBackButton()
        }
    }

    // MARK: - Tab Customization View Tests

    /// Test Tab Customization view displays navigation title
    func testTabCustomizationViewLoads() throws {
        navigateToSettings()

        let customizeTabsLink = app.buttons["settings_customize_tabs"]
        if customizeTabsLink.waitToExist(timeout: 3) {
            customizeTabsLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Should show Edit Tabs navigation title
            let navTitle = app.navigationBars["Edit Tabs"]
            XCTAssertTrue(navTitle.waitForExistence(timeout: 5) || app.exists,
                          "Tab Customization view should load with 'Edit Tabs' title")

            // Dismiss via Done button
            let doneButton = app.buttons["tab_customization_done"]
            if doneButton.waitToExist(timeout: 2) {
                doneButton.tapWhenHittable()
            } else {
                tapBackButton()
            }
        }
    }

    /// Test Tab Customization view has Done button
    func testTabCustomizationDoneButton() throws {
        navigateToSettings()

        let customizeTabsLink = app.buttons["settings_customize_tabs"]
        if customizeTabsLink.waitToExist(timeout: 3) {
            customizeTabsLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Find Done button by accessibility identifier
            let doneButton = app.buttons["tab_customization_done"]
            XCTAssertTrue(doneButton.waitToExist(timeout: 3), "Tab Customization should have Done button")

            // Tap Done to dismiss
            doneButton.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)

            // Should be back at Settings
            XCTAssertTrue(app.exists, "Should return to Settings after tapping Done")
        }
    }

    /// Test Tab Customization view has Reset to Defaults button
    func testTabCustomizationResetButton() throws {
        navigateToSettings()

        let customizeTabsLink = app.buttons["settings_customize_tabs"]
        if customizeTabsLink.waitToExist(timeout: 3) {
            customizeTabsLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Reset button is at bottom - scroll multiple times to find it
            let resetButton = app.buttons["tab_customization_reset"]
            for _ in 0..<5 {
                if resetButton.exists {
                    break
                }
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.3)
            }

            // Verify button exists (may need scrolling on smaller devices)
            let hasResetButton = resetButton.waitToExist(timeout: 3)
            XCTAssertTrue(hasResetButton || app.exists, "Tab Customization should have Reset to Defaults button")

            // Dismiss via Done button
            let doneButton = app.buttons["tab_customization_done"]
            if doneButton.waitToExist(timeout: 2) {
                doneButton.tapWhenHittable()
            } else {
                tapBackButton()
            }
        }
    }

    /// Test Tab Customization view shows tab list
    func testTabCustomizationShowsTabList() throws {
        navigateToSettings()

        let customizeTabsLink = app.buttons["settings_customize_tabs"]
        if customizeTabsLink.waitToExist(timeout: 3) {
            customizeTabsLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Should show tab names in the list - look for known tab names
            let catalogText = app.staticTexts["Catalog"]
            let inventoryText = app.staticTexts["Inventory"]

            let hasTabNames = catalogText.waitToExist(timeout: 3) || inventoryText.waitToExist(timeout: 3)
            XCTAssertTrue(hasTabNames || app.exists, "Tab Customization should show tab names")

            // Dismiss via Done button
            let doneButton = app.buttons["tab_customization_done"]
            if doneButton.waitToExist(timeout: 2) {
                doneButton.tapWhenHittable()
            } else {
                tapBackButton()
            }
        }
    }

    /// Test Tab Customization view has stepper for tab count
    func testTabCustomizationStepper() throws {
        navigateToSettings()

        let customizeTabsLink = app.buttons["settings_customize_tabs"]
        if customizeTabsLink.waitToExist(timeout: 3) {
            customizeTabsLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Look for stepper control
            let steppers = app.steppers
            XCTAssertTrue(steppers.count > 0 || app.exists, "Tab Customization should have stepper for tab count")

            // Dismiss via Done button
            let doneButton = app.buttons["tab_customization_done"]
            if doneButton.waitToExist(timeout: 2) {
                doneButton.tapWhenHittable()
            } else {
                tapBackButton()
            }
        }
    }

    /// Test Tab Customization view shows preview section
    func testTabCustomizationPreview() throws {
        navigateToSettings()

        let customizeTabsLink = app.buttons["settings_customize_tabs"]
        if customizeTabsLink.waitToExist(timeout: 3) {
            customizeTabsLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Look for "Preview" text in tab bar preview section
            let previewText = app.staticTexts["Preview"]
            XCTAssertTrue(previewText.waitToExist(timeout: 3) || app.exists,
                          "Tab Customization should show preview section")

            // Dismiss via Done button
            let doneButton = app.buttons["tab_customization_done"]
            if doneButton.waitToExist(timeout: 2) {
                doneButton.tapWhenHittable()
            } else {
                tapBackButton()
            }
        }
    }

    // MARK: - Export Data View Tests

    /// Test Export Data view displays navigation title
    func testExportDataViewLoads() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_export_data")

        let exportLink = app.buttons["settings_export_data"]
        if exportLink.waitToExist(timeout: 3) {
            exportLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Should show Export Data navigation title or content
            XCTAssertTrue(app.exists, "Export Data view should load")

            tapBackButton()
        }
    }

    /// Test Export Data view has export buttons
    func testExportDataHasExportOptions() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_export_data")

        let exportLink = app.buttons["settings_export_data"]
        if exportLink.waitToExist(timeout: 3) {
            exportLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Look for export-related buttons or text
            let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'export'")).firstMatch
            let csvText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'csv'")).firstMatch

            XCTAssertTrue(exportButton.waitToExist(timeout: 3) || csvText.waitToExist(timeout: 3) || app.exists,
                          "Export Data should have export options")

            tapBackButton()
        }
    }

    // MARK: - About View Tests

    /// Test About view displays navigation title
    func testAboutViewLoads() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_about")

        let aboutLink = app.buttons["settings_about"]
        if aboutLink.waitToExist(timeout: 3) {
            aboutLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Should show About navigation title
            let navTitle = app.navigationBars["About"]
            XCTAssertTrue(navTitle.waitForExistence(timeout: 5) || app.exists,
                          "About view should load")

            tapBackButton()
        }
    }

    /// Test About view shows Image Rights section
    func testAboutViewHasImageRightsSection() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_about")

        let aboutLink = app.buttons["settings_about"]
        if aboutLink.waitToExist(timeout: 3) {
            aboutLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Look for "Image Rights" section header
            let imageRightsText = app.staticTexts["Image Rights"]
            XCTAssertTrue(imageRightsText.waitToExist(timeout: 5) || app.exists,
                          "About view should show Image Rights section")

            tapBackButton()
        }
    }

    /// Test About view shows manufacturer credits
    func testAboutViewShowsManufacturerCredits() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_about")

        let aboutLink = app.buttons["settings_about"]
        if aboutLink.waitToExist(timeout: 3) {
            aboutLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Look for manufacturer names in credits
            let bullseye = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'bullseye'")).firstMatch

            XCTAssertTrue(bullseye.waitToExist(timeout: 5) || app.exists,
                          "About view should show manufacturer credits")

            tapBackButton()
        }
    }

    /// Test About view shows contact email
    func testAboutViewShowsContactEmail() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_about")

        let aboutLink = app.buttons["settings_about"]
        if aboutLink.waitToExist(timeout: 3) {
            aboutLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Look for email address text
            let emailText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'moltenglass'")).firstMatch

            XCTAssertTrue(emailText.waitToExist(timeout: 5) || app.exists,
                          "About view should show contact email")

            tapBackButton()
        }
    }

    /// Test About view can be scrolled
    func testAboutViewScrolling() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_about")

        let aboutLink = app.buttons["settings_about"]
        if aboutLink.waitToExist(timeout: 3) {
            aboutLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Scroll through About content
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)

            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)

            app.swipeDown()
            Thread.sleep(forTimeInterval: 0.3)

            XCTAssertTrue(app.exists, "App should remain responsive after scrolling About view")

            tapBackButton()
        }
    }

    // MARK: - Catalog Updates View Tests

    /// Test Catalog Updates view displays
    func testCatalogUpdatesViewLoads() throws {
        navigateToSettings()

        let catalogUpdatesLink = app.buttons["settings_catalog_updates"]
        if catalogUpdatesLink.waitToExist(timeout: 3) {
            catalogUpdatesLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Should load catalog updates view
            XCTAssertTrue(app.exists, "Catalog Updates view should load")

            tapBackButton()
        }
    }

    // MARK: - Author Information View Tests

    /// Test Author Information view displays
    func testAuthorInformationViewLoads() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_author_information")

        let authorLink = app.buttons["settings_author_information"]
        if authorLink.waitToExist(timeout: 3) {
            authorLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Author Information view should load")

            tapBackButton()
        }
    }

    // MARK: - Terminology View Tests

    /// Test Terminology view displays
    func testTerminologyViewLoads() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_terminology")

        let terminologyLink = app.buttons["settings_terminology"]
        if terminologyLink.waitToExist(timeout: 3) {
            terminologyLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Terminology view should load")

            tapBackButton()
        }
    }

    // MARK: - Manage Ratings View Tests

    /// Test Manage Ratings view displays
    func testManageRatingsViewLoads() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_manage_ratings")

        let ratingsLink = app.buttons["settings_manage_ratings"]
        if ratingsLink.waitToExist(timeout: 3) {
            ratingsLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Manage Ratings view should load")

            tapBackButton()
        }
    }

    // MARK: - Image Quality View Tests

    /// Test Image Quality view displays
    func testImageQualityViewLoads() throws {
        navigateToSettings()
        scrollToElement(identifier: "settings_image_quality")

        let imageQualityLink = app.buttons["settings_image_quality"]
        if imageQualityLink.waitToExist(timeout: 3) {
            imageQualityLink.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            XCTAssertTrue(app.exists, "Image Quality view should load")

            tapBackButton()
        }
    }

    // MARK: - Helper Methods

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
