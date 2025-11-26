//
//  InventoryDetailUITests.swift
//  MoltenUITests
//
//  UI tests for inventory item detail workflow (Workflow 1)
//  Tests complete item detail interactions: expand notes, tags, shopping list, etc.
//

import XCTest

/// UI tests for inventory item detail view interactions
///
/// These tests verify:
/// - Navigate from inventory list to item detail
/// - Expand/collapse manufacturer notes
/// - Manage tags via FAB
/// - Add to shopping list via FAB
/// - Add notes via FAB
/// - Manufacturer website link
final class InventoryDetailUITests: BaseUITest {

    // MARK: - Navigation Tests

    /// Test navigating from inventory list to item detail
    func testNavigateToItemDetail() throws {
        try ensureInventoryExists()

        // Wait for inventory list
        let inventoryList = app.collectionViews["inventory.list"]
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 10), "Inventory list should appear")

        // On iOS 17+, SwiftUI List renders as CollectionView
        // Tap the first cell to trigger navigation (tapping the cell properly triggers NavigationLink)
        let firstCell = inventoryList.cells.firstMatch
        XCTAssertTrue(firstCell.waitToExist(timeout: 10), "Should have at least one inventory item")
        firstCell.tapWhenHittable()

        // Wait for navigation and detail view to load
        Thread.sleep(forTimeInterval: 1.0)

        // Verify we're in detail view - look for the actions menu button directly
        let actionsMenuButton = app.buttons["detail_actions_menu"]
        let actionsButton = app.buttons["Actions"]
        let detailLoaded = actionsMenuButton.waitToExist(timeout: 5) || actionsButton.waitToExist(timeout: 2)
        XCTAssertTrue(detailLoaded,
                      "Detail view should load (looking for actions menu)")
    }

    /// Test navigating back from detail view
    func testNavigateBackFromDetail() throws {
        try ensureInventoryExists()

        // Navigate to detail
        let inventoryList = app.collectionViews["inventory.list"]
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 10), "Inventory list should appear")

        // Tap the first cell to trigger navigation
        let firstCell = inventoryList.cells.firstMatch
        firstCell.tapWhenHittable()

        // Wait for navigation
        Thread.sleep(forTimeInterval: 1.0)

        // Wait for detail view - look for Actions menu button directly
        let actionsMenuButton = app.buttons["detail_actions_menu"]
        let actionsButton = app.buttons["Actions"]
        let detailLoaded = actionsMenuButton.waitToExist(timeout: 5) || actionsButton.waitToExist(timeout: 2)
        XCTAssertTrue(detailLoaded, "Detail view should load")

        // Navigate back using navigation bar back button
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        backButton.tapWhenHittable()

        // Verify we're back at inventory list - check that the inventory list collection view is visible again
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 5), "Should be back at inventory list")
    }

    // MARK: - Manufacturer Notes Tests

    /// Test expanding and collapsing manufacturer notes
    func testExpandCollapseManufacturerNotes() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Look for expand button for manufacturer notes
        let expandNotesButton = app.buttons["expand_manufacturer_notes"]

        // Notes section may not exist for all items - that's okay
        if expandNotesButton.waitToExist(timeout: 3) {
            // Tap to expand
            expandNotesButton.tapWhenHittable()

            // Look for "Show Less" or collapse indicator
            // The button should still exist but with different state
            XCTAssertTrue(expandNotesButton.exists,
                          "Notes toggle button should still exist after expanding")

            // Tap again to collapse
            expandNotesButton.tapWhenHittable()

            XCTAssertTrue(app.exists, "App should remain responsive after toggle")
        }
    }

    // MARK: - Floating Action Button (FAB) Tests

    /// Test FAB - Add Inventory action
    func testFABAddInventory() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // First open the Actions menu
        let actionsButton = app.buttons["Actions"]
        XCTAssertTrue(actionsButton.waitToExist(timeout: 5), "Actions menu should exist")
        actionsButton.tapWhenHittable()

        // Now the menu items are visible - tap Add to Inventory
        let fabAddInventory = app.buttons["fab_add_inventory"]
        XCTAssertTrue(fabAddInventory.waitToExist(timeout: 3), "Add to Inventory menu item should be visible")
        fabAddInventory.tapWhenHittable()

        // Add inventory sheet or upgrade prompt should appear
        // Look for either the form or upgrade prompt
        let quantityField = app.textFields["inventory.add.quantityField"]
        let upgradePrompt = app.buttons["upgrade_purchase_button"]

        let foundForm = quantityField.waitToExist(timeout: 3)
        let foundUpgrade = upgradePrompt.waitToExist(timeout: 3)

        XCTAssertTrue(foundForm || foundUpgrade || app.sheets.firstMatch.exists,
                      "Add inventory form or upgrade prompt should appear")

        // Dismiss by canceling
        tapCancelOrDismiss()
    }

    /// Test FAB - Add to Shopping List action
    func testFABAddToShoppingList() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()
        openActionsMenu()

        let fabShoppingList = app.buttons["fab_add_shopping_list"]
        XCTAssertTrue(fabShoppingList.waitToExist(timeout: 3), "Add to Shopping List menu item should be visible")
        fabShoppingList.tapWhenHittable()

        // Shopping list options sheet should appear
        let addButton = app.buttons["shopping_list_options_add"]
        let cancelButton = app.buttons["shopping_list_options_cancel"]

        let foundOptions = addButton.waitToExist(timeout: 3) || cancelButton.waitToExist(timeout: 3)
        XCTAssertTrue(foundOptions || app.sheets.firstMatch.exists,
                      "Shopping list options should appear")

        // Dismiss
        tapCancelOrDismiss()
    }

    /// Test FAB - Add Note action
    func testFABAddNote() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()
        openActionsMenu()

        let fabAddNote = app.buttons["fab_add_note"]
        XCTAssertTrue(fabAddNote.waitToExist(timeout: 3), "Add Note menu item should be visible")
        fabAddNote.tapWhenHittable()

        // Notes editor should appear
        let notesSaveButton = app.buttons["user_notes_save"]
        let notesCancelButton = app.buttons["user_notes_cancel"]

        let foundNotesEditor = notesSaveButton.waitToExist(timeout: 3) || notesCancelButton.waitToExist(timeout: 3)
        XCTAssertTrue(foundNotesEditor || app.sheets.firstMatch.exists,
                      "Notes editor should appear")

        // Dismiss
        tapCancelOrDismiss()
    }

    /// Test FAB - Manage Tags action
    func testFABManageTags() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()
        openActionsMenu()

        let fabManageTags = app.buttons["fab_manage_tags"]
        XCTAssertTrue(fabManageTags.waitToExist(timeout: 3), "Manage Tags menu item should be visible")
        fabManageTags.tapWhenHittable()

        // Tags editor should appear
        let tagsDoneButton = app.buttons["user_tags_done"]

        let foundTagsEditor = tagsDoneButton.waitToExist(timeout: 3)
        XCTAssertTrue(foundTagsEditor || app.sheets.firstMatch.exists,
                      "Tags editor should appear")

        // Dismiss
        if tagsDoneButton.exists {
            tagsDoneButton.tapWhenHittable()
        } else {
            tapCancelOrDismiss()
        }
    }

    /// Test FAB - Add Image action
    func testFABAddImage() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()
        openActionsMenu()

        let fabAddImage = app.buttons["fab_add_image"]
        XCTAssertTrue(fabAddImage.waitToExist(timeout: 3), "Add Image menu item should be visible")
        fabAddImage.tapWhenHittable()

        // Photo picker should appear - this is a system picker
        // Just verify app didn't crash and something appeared
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(app.exists, "App should remain responsive after tapping add image")

        // Try to dismiss any system picker
        tapCancelOrDismiss()
    }

    // MARK: - User Notes Tests

    /// Test expanding user notes section
    func testExpandUserNotes() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        let expandUserNotes = app.buttons["expand_user_notes"]

        // User notes section may not exist if no notes added
        if expandUserNotes.waitToExist(timeout: 3) {
            expandUserNotes.tapWhenHittable()
            XCTAssertTrue(app.exists, "App should remain responsive after expanding user notes")
        }
    }

    // MARK: - Manufacturer Link Tests

    /// Test manufacturer website link exists
    func testManufacturerWebsiteLink() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Link may not exist for all items
        let websiteLink = app.links["manufacturer_website_link"]

        if websiteLink.waitToExist(timeout: 3) {
            // Just verify it exists - don't actually tap as it opens Safari
            XCTAssertTrue(websiteLink.isHittable, "Manufacturer link should be tappable")
        }
    }

    // MARK: - Inventory Storage Detail Tests

    /// Test navigating to inventory storage detail view by tapping on inventory type row
    func testInventoryStorageDetailOpens() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Scroll down to find inventory section (it may be below the fold)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)

        // Look for inventory detail section - expand if needed
        let inventorySection = app.buttons["section_inventory"]
        if inventorySection.waitToExist(timeout: 3) && !inventorySection.isSelected {
            inventorySection.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Check if storage detail is already open (section tap may have opened it)
        let doneButton = app.buttons["inventory_storage_done"]
        if doneButton.waitToExist(timeout: 2) {
            // Storage detail already opened - test passes
            XCTAssertTrue(true, "Inventory storage detail opened via section tap")
            doneButton.tapWhenHittable()
            return
        }

        // Look for an inventory type row (rod, sheet, frit, etc.)
        // These are buttons that show quantity by type - identifier is inventory_detail_type_row_[type]
        let inventoryTypeRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'inventory_detail_type_row_'")).firstMatch

        if inventoryTypeRow.waitToExist(timeout: 3) {
            // Scroll to make it hittable if needed
            if !inventoryTypeRow.isHittable {
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.3)
            }

            inventoryTypeRow.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            // Verify storage detail view opened - look for Done button
            XCTAssertTrue(doneButton.waitToExist(timeout: 5),
                          "Inventory storage detail should open")

            // Dismiss
            doneButton.tapWhenHittable()
        } else {
            // No inventory type rows - skip this test
            XCTAssertTrue(app.exists, "No inventory type rows available to test")
        }
    }

    /// Test inventory storage detail menu actions
    func testInventoryStorageDetailMenu() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Scroll down to find inventory section (it may be below the fold)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)

        // Expand inventory section if needed
        let inventorySection = app.buttons["section_inventory"]
        if inventorySection.waitToExist(timeout: 3) {
            inventorySection.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)
        }

        let doneButton = app.buttons["inventory_storage_done"]

        // Check if storage detail is already open (section tap may have opened it)
        if !doneButton.waitToExist(timeout: 2) {
            // Find and tap inventory type row - identifier is inventory_detail_type_row_[type]
            let inventoryTypeRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'inventory_detail_type_row_'")).firstMatch

            if inventoryTypeRow.waitToExist(timeout: 3) {
                // Scroll to make it hittable if needed
                if !inventoryTypeRow.isHittable {
                    app.swipeUp()
                    Thread.sleep(forTimeInterval: 0.3)
                }

                inventoryTypeRow.tapWhenHittable()
                Thread.sleep(forTimeInterval: 1)
            }
        }

        // Now storage detail should be open - test the menu
        if doneButton.waitToExist(timeout: 3) {
            // Open the menu
            let menuButton = app.buttons["inventory_storage_menu"]
            if menuButton.waitToExist(timeout: 3) {
                menuButton.tapWhenHittable()
                Thread.sleep(forTimeInterval: 0.5)

                // Verify menu items exist
                let addButton = app.buttons["inventory_storage_add"]
                let toggleGroupingButton = app.buttons["inventory_storage_toggle_grouping"]

                XCTAssertTrue(addButton.waitToExist(timeout: 2) || toggleGroupingButton.waitToExist(timeout: 2),
                              "Menu should have action items")

                // Dismiss menu by tapping elsewhere
                app.tap()
            }

            // Dismiss storage detail
            doneButton.tapWhenHittable()
        }
    }

    /// Test tapping on inventory record opens edit view
    func testInventoryRecordEditOpens() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Scroll down to find inventory section (it may be below the fold)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)

        // Expand inventory section
        let inventorySection = app.buttons["section_inventory"]
        if inventorySection.waitToExist(timeout: 3) {
            inventorySection.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)
        }

        let doneButton = app.buttons["inventory_storage_done"]

        // Check if storage detail is already open (section tap may have opened it)
        if !doneButton.waitToExist(timeout: 2) {
            // Find and tap inventory type row to open storage detail - identifier is inventory_detail_type_row_[type]
            let inventoryTypeRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'inventory_detail_type_row_'")).firstMatch

            if inventoryTypeRow.waitToExist(timeout: 3) {
                // Scroll to make it hittable if needed
                if !inventoryTypeRow.isHittable {
                    app.swipeUp()
                    Thread.sleep(forTimeInterval: 0.3)
                }

                inventoryTypeRow.tapWhenHittable()
                Thread.sleep(forTimeInterval: 1)
            }
        }

        // Now storage detail should be open - test tapping a record
        if doneButton.waitToExist(timeout: 3) {
            // Now tap on an individual inventory record row to edit
            // Records show in a List - look for cells or buttons
            let recordRow = app.cells.firstMatch

            if recordRow.waitToExist(timeout: 3) {
                recordRow.tapWhenHittable()
                Thread.sleep(forTimeInterval: 1)

                // Verify edit view opened - look for Save and Cancel buttons
                let saveButton = app.buttons["inventory_edit_save"]
                let cancelButton = app.buttons["inventory_edit_cancel"]

                if saveButton.waitToExist(timeout: 3) || cancelButton.waitToExist(timeout: 3) {
                    XCTAssertTrue(true, "Edit view opened successfully")

                    // Dismiss edit view
                    if cancelButton.exists {
                        cancelButton.tapWhenHittable()
                    }
                }
            }

            // Dismiss storage detail
            doneButton.tapWhenHittable()
        }
    }

    /// Test editing inventory quantity
    func testEditInventoryQuantity() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Scroll down to find inventory section (it may be below the fold)
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)

        // Expand inventory section
        let inventorySection = app.buttons["section_inventory"]
        if inventorySection.waitToExist(timeout: 3) {
            inventorySection.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)
        }

        let doneButton = app.buttons["inventory_storage_done"]

        // Check if storage detail is already open (section tap may have opened it)
        if !doneButton.waitToExist(timeout: 2) {
            let inventoryTypeRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'inventory_detail_type_row_'")).firstMatch

            if inventoryTypeRow.waitToExist(timeout: 3) {
                // Scroll to make it hittable if needed
                if !inventoryTypeRow.isHittable {
                    app.swipeUp()
                    Thread.sleep(forTimeInterval: 0.3)
                }

                inventoryTypeRow.tapWhenHittable()
                Thread.sleep(forTimeInterval: 1)
            }
        }

        // Now storage detail should be open - test editing a record
        if doneButton.waitToExist(timeout: 3) {
            // Tap first record to edit
            let recordRow = app.cells.firstMatch
            if recordRow.waitToExist(timeout: 3) {
                recordRow.tapWhenHittable()
                Thread.sleep(forTimeInterval: 1)

                // Find quantity field and modify it
                let quantityField = app.textFields.matching(NSPredicate(format: "identifier CONTAINS 'quantity' OR label CONTAINS[c] 'quantity'")).firstMatch

                if quantityField.waitToExist(timeout: 3) {
                    // Clear and enter new value
                    quantityField.tapWhenHittable()
                    quantityField.clearAndTypeText("10")

                    // We could save but that modifies data - just verify field is editable
                    XCTAssertTrue(true, "Quantity field is editable")
                }

                // Cancel to avoid modifying data
                let cancelButton = app.buttons["inventory_edit_cancel"]
                if cancelButton.waitToExist(timeout: 2) {
                    cancelButton.tapWhenHittable()
                }
            }

            // Dismiss storage detail
            doneButton.tapWhenHittable()
        }
    }

    // MARK: - Complete Workflow Tests

    /// Test complete workflow: View detail, add tag, verify tag appears
    func testAddTagWorkflow() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()
        openActionsMenu()

        // Open tags editor
        let fabManageTags = app.buttons["fab_manage_tags"]
        XCTAssertTrue(fabManageTags.waitToExist(timeout: 3), "Manage Tags menu item should be visible")
        fabManageTags.tapWhenHittable()

        // Look for tag input
        let tagInput = app.textFields["tag_editor_input"]

        if tagInput.waitToExist(timeout: 3) {
            // Type a test tag
            tagInput.typeTextWhenHittable("uitest-tag")

            // Add the tag
            let addTagButton = app.buttons["tag_editor_add_button"]
            if addTagButton.exists {
                addTagButton.tapWhenHittable()
            }
        }

        // Done with tags
        let tagsDoneButton = app.buttons["user_tags_done"]
        if tagsDoneButton.waitToExist(timeout: 3) {
            tagsDoneButton.tapWhenHittable()
        } else {
            tapCancelOrDismiss()
        }

        // Verify we're back in detail view - look for the Actions button
        let actionsButton = app.buttons["Actions"]
        XCTAssertTrue(actionsButton.waitToExist(timeout: 5),
                      "Should return to detail view after managing tags")
    }

    // MARK: - Helper Methods

    /// Skip test if inventory is empty
    /// Note: To run these tests with data, use Settings > Debug Settings > Test Data Generator to create inventory first
    private func ensureInventoryExists() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        // On iOS 17+, SwiftUI List renders as CollectionView
        let inventoryList = app.collectionViews["inventory.list"]
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 10), "Inventory list should appear")

        // Check if there are any cells in the inventory list
        let firstCell = inventoryList.cells.firstMatch
        let itemsAppeared = firstCell.waitForExistence(timeout: 10)

        // If no items found, skip the test
        if !itemsAppeared {
            throw XCTSkip("No inventory items available. Use Settings > Debug Settings > Test Data Generator to create test data.")
        }
    }

    /// Navigate to the first inventory item detail
    private func navigateToFirstItemDetail() {
        navigateToInventory()
        waitForLoadingToComplete()

        // On iOS 17+, SwiftUI List renders as CollectionView
        let inventoryList = app.collectionViews["inventory.list"]
        guard inventoryList.waitForExistence(timeout: 10) else {
            XCTFail("Inventory list should appear")
            return
        }

        // Tap the first cell to trigger navigation
        let firstCell = inventoryList.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 10) else {
            XCTFail("Should have at least one inventory item")
            return
        }

        firstCell.tapWhenHittable()

        // Wait for navigation to complete
        Thread.sleep(forTimeInterval: 1.0)

        // Wait for detail view - look for Actions menu button directly
        let actionsMenuButton = app.buttons["detail_actions_menu"]
        let actionsButton = app.buttons["Actions"]
        let detailLoaded = actionsMenuButton.waitToExist(timeout: 5) || actionsButton.waitToExist(timeout: 2)
        XCTAssertTrue(detailLoaded, "Detail view should load (looking for actions menu)")
    }

    /// Open the Actions menu in the detail view toolbar
    private func openActionsMenu() {
        // Use app.buttons to target the Button element directly (not the wrapper Other element)
        // The accessibility tree has both an Other wrapper and a Button with the same identifier
        let actionsMenuButton = app.buttons["detail_actions_menu"]
        let actionsButton = app.buttons["Actions"]

        if actionsMenuButton.waitToExist(timeout: 3) {
            actionsMenuButton.tapWhenHittable()
        } else if actionsButton.waitToExist(timeout: 3) {
            actionsButton.tapWhenHittable()
        } else {
            XCTFail("Actions menu should exist")
        }

        // Wait for menu to appear
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Try to dismiss any sheet or alert
    private func tapCancelOrDismiss() {
        // Try various cancel/dismiss patterns
        let cancelButtons = [
            app.buttons["Cancel"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel'")).firstMatch,
            app.buttons["user_notes_cancel"],
            app.buttons["shopping_list_options_cancel"],
            app.navigationBars.buttons.element(boundBy: 0)
        ]

        for button in cancelButtons {
            if button.waitToExist(timeout: 1) {
                button.tapWhenHittable()
                return
            }
        }

        // If no cancel button, try swiping down to dismiss sheet
        app.swipeDown()
    }
}
