//
//  ScreenshotAutomation.swift
//  ScreenshotAutomation
//
//  Automated screenshot generation for marketing and documentation.
//  Captures all key screens with realistic data for website and App Store.
//

import XCTest

final class ScreenshotAutomation: XCTestCase {

    var app: XCUIApplication!
    var screenshotCounter = 0

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()

        // Launch arguments to configure app for screenshots
        app.launchArguments = [
            "-UITestMode", "true",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]

        // Reset screenshot counter for each test
        screenshotCounter = 0

        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot Generation Tests

    /// Complete screenshot suite for marketing materials
    func testGenerateMarketingScreenshots() throws {
        // Wait for app to fully load
        sleep(2)

        // 1. Catalog View - Main browsing screen
        takeScreenshot(named: "01-catalog-browse")

        // 2. Glass Item Detail - Show a colorful glass rod
        // Tap on first item in catalog
        if app.tables.cells.firstMatch.exists {
            app.tables.cells.firstMatch.tap()
            sleep(1)
            takeScreenshot(named: "02-glass-detail")

            // Go back to catalog
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        // 3. Search and Filters
        // Tap search field if it exists
        let searchFields = app.searchFields
        if searchFields.count > 0 {
            searchFields.firstMatch.tap()
            usleep(500_000)  // 0.5 seconds
            searchFields.firstMatch.typeText("blue")
            sleep(1)
            takeScreenshot(named: "03-catalog-search")

            // Clear search
            if app.buttons["Clear text"].exists {
                app.buttons["Clear text"].tap()
            }
            usleep(500_000)  // 0.5 seconds
        }

        // 4. Navigate to Inventory tab
        let inventoryTab = app.tabBars.buttons["Inventory"]
        if inventoryTab.exists {
            inventoryTab.tap()
            sleep(1)
            takeScreenshot(named: "04-inventory-view")
        }

        // 5. Navigate to Shopping List tab
        let shoppingTab = app.tabBars.buttons["Shopping"]
        if shoppingTab.exists {
            shoppingTab.tap()
            sleep(1)
            takeScreenshot(named: "05-shopping-list")
        }

        // 6. Navigate to Purchases tab
        let purchasesTab = app.tabBars.buttons["Purchases"]
        if purchasesTab.exists {
            purchasesTab.tap()
            sleep(1)
            takeScreenshot(named: "06-purchases")
        }

        // 7. Navigate to Projects tab
        let projectsTab = app.tabBars.buttons["Projects"]
        if projectsTab.exists {
            projectsTab.tap()
            sleep(1)
            takeScreenshot(named: "07-project-log")
        }

        // 8. Go back to Catalog and show filters
        let catalogTab = app.tabBars.buttons["Catalog"]
        if catalogTab.exists {
            catalogTab.tap()
            sleep(1)
        }

        // Look for filter button
        let filterButton = app.navigationBars.buttons.matching(identifier: "Filter").firstMatch
        if filterButton.exists {
            filterButton.tap()
            sleep(1)
            takeScreenshot(named: "08-catalog-filters")

            // Dismiss filter sheet
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            } else if app.buttons["Close"].exists {
                app.buttons["Close"].tap()
            }
            usleep(500_000)  // 0.5 seconds
        }
    }

    /// Screenshots specifically for App Store submission
    /// These follow Apple's recommended showcase flow
    func testGenerateAppStoreScreenshots() throws {
        sleep(2)

        // Screen 1: Hero shot - Main catalog with filters applied
        takeScreenshot(named: "AppStore-01-Hero-Catalog")

        // Screen 2: Feature shot - Glass detail with rich info
        if app.tables.cells.count > 0 {
            app.tables.cells.firstMatch.tap()
            sleep(1)
            takeScreenshot(named: "AppStore-02-Detail")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        // Screen 3: Inventory management
        if app.tabBars.buttons["Inventory"].exists {
            app.tabBars.buttons["Inventory"].tap()
            sleep(1)
            takeScreenshot(named: "AppStore-03-Inventory")
        }

        // Screen 4: Shopping list
        if app.tabBars.buttons["Shopping"].exists {
            app.tabBars.buttons["Shopping"].tap()
            sleep(1)
            takeScreenshot(named: "AppStore-04-Shopping")
        }

        // Screen 5: Project tracking
        if app.tabBars.buttons["Projects"].exists {
            app.tabBars.buttons["Projects"].tap()
            sleep(1)
            takeScreenshot(named: "AppStore-05-Projects")
        }
    }

    /// Generate screenshots in dark mode
    func testGenerateDarkModeScreenshots() throws {
        // Note: To run this, you need to configure the simulator for dark mode
        // This test will capture the same screens but in dark appearance

        sleep(2)
        takeScreenshot(named: "Dark-01-catalog")

        if app.tabBars.buttons["Inventory"].exists {
            app.tabBars.buttons["Inventory"].tap()
            sleep(1)
            takeScreenshot(named: "Dark-02-inventory")
        }

        if app.tabBars.buttons["Shopping"].exists {
            app.tabBars.buttons["Shopping"].tap()
            sleep(1)
            takeScreenshot(named: "Dark-03-shopping")
        }
    }

    // MARK: - Helper Methods

    /// Takes a screenshot with a descriptive name
    private func takeScreenshot(named name: String) {
        screenshotCounter += 1
        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = String(format: "%02d-%@", screenshotCounter, name)
        attachment.lifetime = .keepAlways
        add(attachment)

        print("📸 Screenshot saved: \(attachment.name)")
    }

    /// Wait for element to appear
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
}

// MARK: - Screenshot Configuration Extension

extension XCUIApplication {
    /// Configure app launch for screenshot generation
    func configureForScreenshots() {
        launchArguments += [
            "-UITestMode", "true",
            "-MockData", "true",
            "-AnimationsDisabled", "false", // Keep animations for natural look
            "-ResetOnboarding", "true"
        ]
    }
}
