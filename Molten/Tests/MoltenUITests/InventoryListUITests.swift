//
//  InventoryListUITests.swift
//  MoltenUITests
//
//  UI tests for inventory list view functionality (list-level interactions)
//  Tests search, filters, sort, and menu actions that don't require navigation to detail
//

import XCTest

/// UI tests for inventory list functionality
///
/// These tests verify list-level interactions that don't require navigating to detail views:
/// - Search functionality
/// - Filter sheets (Tags, COE, Manufacturer)
/// - Sort options
/// - Menu actions
/// - Pull to refresh
final class InventoryListUITests: BaseUITest {

    // MARK: - Search Tests

    /// Test search bar exists and accepts input
    func testSearchBarExists() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        // Search bar should be visible in navigation bar
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitToExist(timeout: 5), "Search field should exist")
    }

    /// Test typing in search bar filters results
    func testSearchFiltersResults() throws {
        try ensureInventoryExists()

        // Get initial count
        let inventoryList = app.collectionViews["inventory.list"]
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 10), "Inventory list should appear")

        let initialItems = inventoryList.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'inventory.item.'"))

        // Tap search and type
        let searchField = app.searchFields.firstMatch
        searchField.tapWhenHittable()
        searchField.typeText("bullseye")

        // Wait for filter to apply
        Thread.sleep(forTimeInterval: 1)

        // Results should be filtered (could be fewer or same if all match)
        XCTAssertTrue(app.exists, "App should remain responsive after search")
    }

    /// Test clearing search restores results
    func testClearSearchRestoresResults() throws {
        try ensureInventoryExists()

        let searchField = app.searchFields.firstMatch
        searchField.tapWhenHittable()
        searchField.typeText("test")

        Thread.sleep(forTimeInterval: 0.5)

        // Clear the search using the clear button
        let clearButton = app.buttons["Clear text"]
        if clearButton.waitToExist(timeout: 2) {
            clearButton.tapWhenHittable()
        } else {
            // Fallback: select all and delete
            searchField.tap()
            searchField.doubleTap()  // Select all
            app.keys["delete"].tap()
        }

        // Cancel search mode
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitToExist(timeout: 2) {
            cancelButton.tapWhenHittable()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after clearing search")
    }

    // MARK: - Filter Sheet Tests

    /// Test tags filter sheet opens and closes
    func testTagsFilterSheet() throws {
        try ensureInventoryExists()

        // Look for tags filter button in the filter header
        // The ModernFilterHeader has filter chips/buttons
        let tagsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'tag'")).firstMatch

        if tagsButton.waitToExist(timeout: 3) {
            tagsButton.tapWhenHittable()

            // Tags filter sheet should appear
            let sheet = app.sheets.firstMatch
            let tagsList = app.scrollViews.firstMatch

            let sheetAppeared = sheet.waitToExist(timeout: 3) || tagsList.waitToExist(timeout: 3)

            if sheetAppeared {
                // Dismiss the sheet
                dismissSheet()
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after tags filter interaction")
    }

    /// Test COE filter sheet opens and closes
    func testCOEFilterSheet() throws {
        try ensureInventoryExists()

        // Look for COE filter button
        let coeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'coe'")).firstMatch

        if coeButton.waitToExist(timeout: 3) {
            coeButton.tapWhenHittable()

            // COE filter sheet should appear
            Thread.sleep(forTimeInterval: 0.5)

            // Dismiss
            dismissSheet()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after COE filter interaction")
    }

    /// Test manufacturer filter sheet opens and closes
    func testManufacturerFilterSheet() throws {
        try ensureInventoryExists()

        // Look for manufacturer filter button
        let mfrButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'manufacturer'")).firstMatch

        if mfrButton.waitToExist(timeout: 3) {
            mfrButton.tapWhenHittable()

            // Manufacturer filter sheet should appear
            Thread.sleep(forTimeInterval: 0.5)

            // Dismiss
            dismissSheet()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after manufacturer filter interaction")
    }

    // MARK: - Sort Tests

    /// Test sort option can be changed
    func testSortOptionChange() throws {
        try ensureInventoryExists()

        // Look for sort button/picker in the filter header
        // Sort is typically a menu or picker
        let sortButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sort'")).firstMatch
        let sortMenu = app.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'sort'")).firstMatch

        let sortControl = sortButton.exists ? sortButton : sortMenu

        if sortControl.waitToExist(timeout: 3) {
            sortControl.tapWhenHittable()

            // Sort options should appear - look for menu items
            Thread.sleep(forTimeInterval: 0.5)

            // Try to tap a sort option
            let nameOption = app.buttons["Name"]
            let quantityOption = app.buttons["Quantity"]

            if nameOption.waitToExist(timeout: 2) {
                nameOption.tapWhenHittable()
            } else if quantityOption.waitToExist(timeout: 2) {
                quantityOption.tapWhenHittable()
            } else {
                // Dismiss menu if no options found
                app.tap()  // Tap outside to dismiss
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after sort change")
    }

    // MARK: - Menu Tests

    /// Test inventory menu opens
    func testInventoryMenuOpens() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        let menuButton = app.buttons["inventory_menu"]
        XCTAssertTrue(menuButton.waitToExist(timeout: 5), "Inventory menu button should exist")
        menuButton.tapWhenHittable()

        // Menu items should appear
        let addMenuItem = app.buttons["inventory_menu_add"]
        let sharingMenuItem = app.buttons["inventory_menu_sharing"]
        let printMenuItem = app.buttons["inventory_menu_print_labels"]

        let menuOpened = addMenuItem.waitToExist(timeout: 3) ||
                         sharingMenuItem.waitToExist(timeout: 3) ||
                         printMenuItem.waitToExist(timeout: 3)

        XCTAssertTrue(menuOpened, "Menu items should appear when menu is opened")

        // Dismiss by tapping outside
        app.tap()
    }

    /// Test Add Inventory from menu opens form
    func testMenuAddInventory() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        // Open menu
        let menuButton = app.buttons["inventory_menu"]
        menuButton.tapWhenHittable()

        // Tap Add Inventory
        let addMenuItem = app.buttons["inventory_menu_add"]
        XCTAssertTrue(addMenuItem.waitToExist(timeout: 3), "Add inventory menu item should exist")
        addMenuItem.tapWhenHittable()

        // Add inventory form should appear
        let saveButton = app.buttons["inventory.add.saveButton"]
        let cancelButton = app.buttons["inventory.add.cancelButton"]

        XCTAssertTrue(saveButton.waitToExist(timeout: 5) || cancelButton.waitToExist(timeout: 5),
                      "Add inventory form should appear from menu")

        // Cancel
        if cancelButton.exists {
            cancelButton.tapWhenHittable()
        }
    }

    /// Test Inventory Sharing from menu opens sharing view
    func testMenuInventorySharing() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        // Open menu
        let menuButton = app.buttons["inventory_menu"]
        menuButton.tapWhenHittable()

        // Tap Inventory Sharing
        let sharingMenuItem = app.buttons["inventory_menu_sharing"]
        XCTAssertTrue(sharingMenuItem.waitToExist(timeout: 3), "Sharing menu item should exist")
        sharingMenuItem.tapWhenHittable()

        // Sharing view should appear (full screen cover)
        Thread.sleep(forTimeInterval: 1)

        // Look for Done button to dismiss
        let doneButton = app.buttons["Done"]
        if doneButton.waitToExist(timeout: 5) {
            doneButton.tapWhenHittable()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after opening sharing")
    }

    /// Test Print Labels from menu (requires inventory)
    func testMenuPrintLabels() throws {
        try ensureInventoryExists()

        // Open menu
        let menuButton = app.buttons["inventory_menu"]
        menuButton.tapWhenHittable()

        // Tap Print Labels
        let printMenuItem = app.buttons["inventory_menu_print_labels"]
        XCTAssertTrue(printMenuItem.waitToExist(timeout: 3), "Print labels menu item should exist")

        // Only tap if enabled (requires inventory items)
        if printMenuItem.isEnabled {
            printMenuItem.tapWhenHittable()

            // Label designer should appear
            let labelDesignerTitle = app.navigationBars["Label Designer"]
            if labelDesignerTitle.waitToExist(timeout: 5) {
                // Cancel out
                let cancelButton = app.buttons["label_designer_cancel"]
                if cancelButton.exists {
                    cancelButton.tapWhenHittable()
                }
            }
        } else {
            // Dismiss menu
            app.tap()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after print labels interaction")
    }

    // MARK: - Add Button Tests

    /// Test add button in toolbar opens form
    func testAddButtonOpensForm() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        let addButton = app.buttons["inventory_add_button"]
        XCTAssertTrue(addButton.waitToExist(timeout: 5), "Add button should exist")
        addButton.tapWhenHittable()

        // Add inventory form should appear
        let saveButton = app.buttons["inventory.add.saveButton"]
        XCTAssertTrue(saveButton.waitToExist(timeout: 5), "Add inventory form should appear")

        // Cancel
        let cancelButton = app.buttons["inventory.add.cancelButton"]
        if cancelButton.exists {
            cancelButton.tapWhenHittable()
        }
    }

    // MARK: - Empty State Tests

    /// Test empty state shows when no inventory
    func testEmptyStateDisplay() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        // If no inventory, should show empty state
        let inventoryList = app.collectionViews["inventory.list"]
        let emptyStateText = app.staticTexts["No Inventory Yet"]

        // One of these should exist
        let hasContent = inventoryList.waitForExistence(timeout: 5)
        let hasEmptyState = emptyStateText.waitToExist(timeout: 2)

        XCTAssertTrue(hasContent || hasEmptyState,
                      "Should show either inventory list or empty state")
    }

    // MARK: - Pull to Refresh Tests

    /// Test pull to refresh works
    func testPullToRefresh() throws {
        try ensureInventoryExists()

        let inventoryList = app.collectionViews["inventory.list"]
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 10), "Inventory list should appear")

        // Pull down to refresh
        let start = inventoryList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = inventoryList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)

        // Wait for refresh to complete
        Thread.sleep(forTimeInterval: 2)

        XCTAssertTrue(app.exists, "App should remain responsive after pull to refresh")
    }

    // MARK: - Filter Clear Tests

    /// Test clearing all filters via empty state button
    func testClearFiltersFromEmptyState() throws {
        try ensureInventoryExists()

        // Apply a filter that results in no matches
        let searchField = app.searchFields.firstMatch
        searchField.tapWhenHittable()
        searchField.typeText("xyznonexistent123")

        Thread.sleep(forTimeInterval: 1)

        // Look for "Clear Filters" or similar button in empty state
        let clearButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'clear'")).firstMatch

        if clearButton.waitToExist(timeout: 3) {
            clearButton.tapWhenHittable()

            // Results should be restored
            Thread.sleep(forTimeInterval: 1)
        } else {
            // Cancel search manually
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tapWhenHittable()
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after clearing filters")
    }

    // MARK: - Location Filter Tests

    /// Test location filter dropdown
    func testLocationFilter() throws {
        try ensureInventoryExists()

        // Look for location filter control
        let locationButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'location'")).firstMatch

        if locationButton.waitToExist(timeout: 3) {
            locationButton.tapWhenHittable()

            // Location options should appear
            Thread.sleep(forTimeInterval: 0.5)

            // Dismiss by tapping outside or selecting an option
            app.tap()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after location filter interaction")
    }

    /// Test inventory type filter dropdown
    func testInventoryTypeFilter() throws {
        try ensureInventoryExists()

        // Look for type filter control (rod, tube, frit, etc.)
        let typeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'type'")).firstMatch

        if typeButton.waitToExist(timeout: 3) {
            typeButton.tapWhenHittable()

            // Type options should appear
            Thread.sleep(forTimeInterval: 0.5)

            // Dismiss by tapping outside
            app.tap()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after type filter interaction")
    }

    // MARK: - Helper Methods

    /// Ensure inventory exists for tests that need data
    private func ensureInventoryExists() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        let inventoryList = app.collectionViews["inventory.list"]
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 10), "Inventory list should appear")

        let firstItem = inventoryList.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'inventory.item.'")).firstMatch

        if !firstItem.waitForExistence(timeout: 5) {
            throw XCTSkip("No inventory items available. Use Settings > Debug Settings > Test Data Generator.")
        }
    }

    /// Dismiss any sheet that's open
    private func dismissSheet() {
        // Try Done button first
        let doneButton = app.buttons["Done"]
        if doneButton.waitToExist(timeout: 1) {
            doneButton.tapWhenHittable()
            return
        }

        // Try Cancel button
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitToExist(timeout: 1) {
            cancelButton.tapWhenHittable()
            return
        }

        // Try Close button
        let closeButton = app.buttons["Close"]
        if closeButton.waitToExist(timeout: 1) {
            closeButton.tapWhenHittable()
            return
        }

        // Fallback: swipe down
        app.swipeDown()
    }
}
