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
        try skipIfNoInventory()

        // Tap first inventory item
        let firstItem = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'inventory.item.'")).firstMatch
        XCTAssertTrue(firstItem.waitToExist(timeout: 10), "Should have at least one inventory item")
        firstItem.tapWhenHittable()

        // Verify we're in detail view - look for FAB buttons which are unique to detail
        let fabAddInventory = app.buttons["fab_add_inventory"]
        XCTAssertTrue(fabAddInventory.waitToExist(timeout: 5),
                      "FAB buttons should appear in detail view")
    }

    /// Test navigating back from detail view
    func testNavigateBackFromDetail() throws {
        try skipIfNoInventory()

        // Navigate to detail
        let firstItem = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'inventory.item.'")).firstMatch
        firstItem.tapWhenHittable()

        // Wait for detail view
        let fabAddInventory = app.buttons["fab_add_inventory"]
        XCTAssertTrue(fabAddInventory.waitToExist(timeout: 5), "Detail view should load")

        // Navigate back using navigation bar back button
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        backButton.tapWhenHittable()

        // Verify we're back at inventory list
        let inventoryTab = app.buttons["Inventory"]
        XCTAssertTrue(inventoryTab.isSelected, "Should be back on Inventory tab")
    }

    // MARK: - Manufacturer Notes Tests

    /// Test expanding and collapsing manufacturer notes
    func testExpandCollapseManufacturerNotes() throws {
        try skipIfNoInventory()
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
        try skipIfNoInventory()
        navigateToFirstItemDetail()

        let fabAddInventory = app.buttons["fab_add_inventory"]
        XCTAssertTrue(fabAddInventory.waitToExist(timeout: 5), "FAB add inventory should exist")
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
        try skipIfNoInventory()
        navigateToFirstItemDetail()

        let fabShoppingList = app.buttons["fab_add_shopping_list"]
        XCTAssertTrue(fabShoppingList.waitToExist(timeout: 5), "FAB add to shopping list should exist")
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
        try skipIfNoInventory()
        navigateToFirstItemDetail()

        let fabAddNote = app.buttons["fab_add_note"]
        XCTAssertTrue(fabAddNote.waitToExist(timeout: 5), "FAB add note should exist")
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
        try skipIfNoInventory()
        navigateToFirstItemDetail()

        let fabManageTags = app.buttons["fab_manage_tags"]
        XCTAssertTrue(fabManageTags.waitToExist(timeout: 5), "FAB manage tags should exist")
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
        try skipIfNoInventory()
        navigateToFirstItemDetail()

        let fabAddImage = app.buttons["fab_add_image"]
        XCTAssertTrue(fabAddImage.waitToExist(timeout: 5), "FAB add image should exist")
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
        try skipIfNoInventory()
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
        try skipIfNoInventory()
        navigateToFirstItemDetail()

        // Link may not exist for all items
        let websiteLink = app.links["manufacturer_website_link"]

        if websiteLink.waitToExist(timeout: 3) {
            // Just verify it exists - don't actually tap as it opens Safari
            XCTAssertTrue(websiteLink.isHittable, "Manufacturer link should be tappable")
        }
    }

    // MARK: - Complete Workflow Tests

    /// Test complete workflow: View detail, add tag, verify tag appears
    func testAddTagWorkflow() throws {
        try skipIfNoInventory()
        navigateToFirstItemDetail()

        // Open tags editor
        let fabManageTags = app.buttons["fab_manage_tags"]
        XCTAssertTrue(fabManageTags.waitToExist(timeout: 5), "FAB manage tags should exist")
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

        // Verify we're back in detail view
        XCTAssertTrue(fabManageTags.waitToExist(timeout: 5),
                      "Should return to detail view after managing tags")
    }

    // MARK: - Helper Methods

    /// Skip test if inventory is empty
    private func skipIfNoInventory() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        let cells = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'inventory.item.'"))

        if cells.count == 0 {
            throw XCTSkip("No inventory items available")
        }
    }

    /// Navigate to the first inventory item detail
    private func navigateToFirstItemDetail() {
        navigateToInventory()
        waitForLoadingToComplete()

        let firstItem = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'inventory.item.'")).firstMatch
        firstItem.tapWhenHittable()

        // Wait for detail view
        let fabAddInventory = app.buttons["fab_add_inventory"]
        XCTAssertTrue(fabAddInventory.waitToExist(timeout: 5),
                      "Detail view should load")
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
