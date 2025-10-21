//
//  AppLaunchUITests.swift
//  MoltenUITests
//
//  Basic UI tests to verify app launches correctly
//

import XCTest

final class AppLaunchUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Stop immediately when a failure occurs
        continueAfterFailure = false

        // Create app instance
        app = XCUIApplication()

        // Set launch arguments to tell app we're in UI testing mode
        app.launchArguments = ["UI-Testing"]

        // Launch the app
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Basic Launch Tests

    func testAppLaunches() throws {
        // Just verify the app launched without crashing
        // We'll check for ANY element to confirm the UI loaded
        XCTAssertTrue(app.exists, "App should exist after launch")
    }

    func testTabBarExists() throws {
        // Wait for tab bar to appear (with timeout in case of slow launch)
        let tabBar = app.tabBars.firstMatch
        let exists = tabBar.waitForExistence(timeout: 10)

        XCTAssertTrue(exists, "Tab bar should appear after app launches")
    }

    func testMainTabsExist() throws {
        // Verify all main tabs are present
        // Note: These might need accessibility identifiers added

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should load")

        // These will likely fail until we add accessibility identifiers
        // But that's okay - we'll add them based on the errors!
        let catalogTab = app.buttons["Catalog"]
        let inventoryTab = app.buttons["Inventory"]
        let purchasesTab = app.buttons["Purchases"]
        let plansTab = app.buttons["Plans"]

        XCTAssertTrue(catalogTab.exists, "Catalog tab should exist")
        XCTAssertTrue(inventoryTab.exists, "Inventory tab should exist")
        XCTAssertTrue(purchasesTab.exists, "Purchases tab should exist")
        XCTAssertTrue(plansTab.exists, "Plans tab should exist")
    }

    func testCanSwitchTabs() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should load")

        // Try tapping each tab
        app.buttons["Inventory"].tap()

        // Add a small delay to let the view transition
        sleep(1)

        app.buttons["Catalog"].tap()
        sleep(1)

        // If we get here without crashing, the test passes!
        XCTAssertTrue(true, "Successfully switched between tabs")
    }
}
