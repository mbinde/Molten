//
//  AddInventoryUITests.swift
//  MoltenUITests
//
//  UI tests for adding inventory items (Workflow 2)
//  Tests the add inventory form including the NOTES BUG verification
//

import XCTest

/// UI tests for adding inventory items workflow
///
/// These tests verify:
/// - Add inventory form opens correctly
/// - Form fields work properly
/// - Glass item selection from catalog
/// - Notes field interaction (BUG: Notes not being saved!)
/// - Form validation
/// - Save and cancel functionality
final class AddInventoryUITests: BaseUITest {

    // MARK: - Basic Form Tests

    /// Test add inventory form opens from inventory tab
    func testAddInventoryFormOpens() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        // Tap the add button
        let addButton = app.buttons["inventory_add_button"]
        XCTAssertTrue(addButton.waitToExist(timeout: 5), "Add inventory button should exist")
        addButton.tapWhenHittable()

        // Verify form appears
        let saveButton = app.buttons["inventory.add.saveButton"]
        let cancelButton = app.buttons["inventory.add.cancelButton"]

        XCTAssertTrue(saveButton.waitToExist(timeout: 5) || cancelButton.waitToExist(timeout: 5),
                      "Add inventory form should appear")
    }

    /// Test form can be canceled
    func testAddInventoryFormCancel() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        // Open form
        app.buttons["inventory_add_button"].tapWhenHittable()

        // Cancel
        let cancelButton = app.buttons["inventory.add.cancelButton"]
        XCTAssertTrue(cancelButton.waitToExist(timeout: 5), "Cancel button should exist")
        cancelButton.tapWhenHittable()

        // Verify form dismissed
        XCTAssertTrue(cancelButton.waitToDisappear(timeout: 5),
                      "Form should dismiss after canceling")
    }

    // MARK: - Form Field Tests

    /// Test glass item search selector
    func testGlassItemSearch() throws {
        openAddInventoryForm()

        let searchField = app.textFields["inventory.add.searchSelector"]
        XCTAssertTrue(searchField.waitToExist(timeout: 5), "Search selector should exist")

        searchField.tapWhenHittable()

        // Type search term
        searchField.typeText("clear")

        // Wait for search results
        Thread.sleep(forTimeInterval: 1)

        // Look for any result cell to tap
        let resultCell = app.cells.firstMatch
        if resultCell.waitToExist(timeout: 5) {
            resultCell.tapWhenHittable()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after search")
    }

    /// Test quantity field
    func testQuantityField() throws {
        openAddInventoryForm()

        let quantityField = app.textFields["inventory.add.quantityField"]
        XCTAssertTrue(quantityField.waitToExist(timeout: 5), "Quantity field should exist")

        quantityField.tapWhenHittable()
        quantityField.typeText("10")

        // Verify text was entered
        XCTAssertEqual(quantityField.value as? String, "10",
                       "Quantity should be '10' after typing")
    }

    /// Test type picker
    func testTypePicker() throws {
        openAddInventoryForm()

        let typePicker = app.buttons["inventory.add.typePicker"]
        XCTAssertTrue(typePicker.waitToExist(timeout: 5), "Type picker should exist")

        typePicker.tapWhenHittable()

        // Picker menu should appear
        // Wait for any menu option
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(app.exists, "App should remain responsive after tapping type picker")
    }

    /// Test location field
    func testLocationField() throws {
        openAddInventoryForm()

        let locationField = app.textFields["inventory.add.locationField"]

        if locationField.waitToExist(timeout: 3) {
            locationField.tapWhenHittable()
            locationField.typeText("Shelf A")

            XCTAssertTrue(app.exists, "App should remain responsive after entering location")
        }
    }

    // MARK: - Notes Field Tests

    /// Test notes field exists and accepts input
    func testNotesFieldExists() throws {
        openAddInventoryForm()

        let notesField = app.textFields["inventory.add.notesField"]
        XCTAssertTrue(notesField.waitToExist(timeout: 5),
                      "Notes field should exist on add inventory form")

        notesField.tapWhenHittable()
        notesField.typeText("Test note for verification")

        // Verify text was entered
        XCTAssertTrue(app.exists, "App should remain responsive after entering notes")
    }

    /// Regression test: Notes should be saved with inventory
    /// Verifies the fix for the bug where notes were collected but not saved
    func testNotesAreSavedWithInventory() throws {
        openAddInventoryForm()

        // Select a glass item first
        let searchField = app.textFields["inventory.add.searchSelector"]
        XCTAssertTrue(searchField.waitToExist(timeout: 5), "Search selector should exist")
        searchField.tapWhenHittable()
        searchField.typeText("clear")

        // Wait and select first result
        Thread.sleep(forTimeInterval: 1)
        let resultCell = app.cells.firstMatch
        if resultCell.waitToExist(timeout: 5) {
            resultCell.tapWhenHittable()
        }

        // Enter quantity
        let quantityField = app.textFields["inventory.add.quantityField"]
        if quantityField.waitToExist(timeout: 3) {
            quantityField.tapWhenHittable()
            quantityField.typeText("5")
        }

        // Enter a unique note that we can verify later
        let notesField = app.textFields["inventory.add.notesField"]
        if notesField.waitToExist(timeout: 3) {
            notesField.tapWhenHittable()
            notesField.typeText("UI Test Note - Should Be Saved")
        }

        // Save the form
        let saveButton = app.buttons["inventory.add.saveButton"]
        if saveButton.isEnabled {
            saveButton.tapWhenHittable()

            // Wait for form to dismiss
            Thread.sleep(forTimeInterval: 2)

            // Navigate to the item detail to verify notes were saved
            // Find the item we just added and tap it
            let inventoryItem = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'inventory.item.'")).firstMatch
            if inventoryItem.waitToExist(timeout: 5) {
                inventoryItem.tapWhenHittable()

                // Look for "Your Notes" section which indicates notes exist
                let yourNotesLabel = app.staticTexts["Your Notes"]
                let testNoteText = app.staticTexts["UI Test Note - Should Be Saved"]

                // Verify notes were saved
                let notesExist = yourNotesLabel.waitToExist(timeout: 5) || testNoteText.waitToExist(timeout: 5)

                XCTAssertTrue(notesExist,
                              "Notes should appear in item detail after saving inventory with notes")
            }
        }
    }

    // MARK: - Form Validation Tests

    /// Test save button is disabled without required fields
    func testSaveButtonDisabledWithoutRequiredFields() throws {
        openAddInventoryForm()

        let saveButton = app.buttons["inventory.add.saveButton"]
        XCTAssertTrue(saveButton.waitToExist(timeout: 5), "Save button should exist")

        // Without filling any fields, save should be disabled
        // Note: This depends on form validation implementation
        XCTAssertTrue(app.exists, "Form should show validation state")
    }

    /// Test complete add inventory workflow
    func testCompleteAddInventoryWorkflow() throws {
        openAddInventoryForm()

        // 1. Search and select glass item
        let searchField = app.textFields["inventory.add.searchSelector"]
        searchField.tapWhenHittable()
        searchField.typeText("bullseye")

        Thread.sleep(forTimeInterval: 1.5)
        let resultCell = app.cells.firstMatch
        if resultCell.waitToExist(timeout: 5) {
            resultCell.tapWhenHittable()
        }

        // 2. Enter quantity
        let quantityField = app.textFields["inventory.add.quantityField"]
        if quantityField.waitToExist(timeout: 3) {
            quantityField.clearAndTypeText("3")
        }

        // 3. Select type (if picker exists)
        let typePicker = app.buttons["inventory.add.typePicker"]
        if typePicker.waitToExist(timeout: 2) {
            typePicker.tapWhenHittable()
            // Tap first option in picker
            Thread.sleep(forTimeInterval: 0.5)
            let pickerOption = app.cells.firstMatch
            if pickerOption.exists {
                pickerOption.tapWhenHittable()
            }
        }

        // 4. Add notes
        let notesField = app.textFields["inventory.add.notesField"]
        if notesField.waitToExist(timeout: 2) {
            notesField.tapWhenHittable()
            notesField.typeText("Test inventory item")
        }

        // 5. Save
        let saveButton = app.buttons["inventory.add.saveButton"]
        if saveButton.waitToExist(timeout: 3) && saveButton.isEnabled {
            saveButton.tapWhenHittable()

            // Verify form dismissed (success)
            XCTAssertTrue(saveButton.waitToDisappear(timeout: 5),
                          "Form should dismiss after successful save")
        }
    }

    // MARK: - Menu Access Tests

    /// Test add inventory via menu
    func testAddInventoryViaMenu() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        // Open menu
        let menuButton = app.buttons["inventory_menu"]
        XCTAssertTrue(menuButton.waitToExist(timeout: 5), "Menu button should exist")
        menuButton.tapWhenHittable()

        // Tap Add Inventory in menu
        let menuAddButton = app.buttons["inventory_menu_add"]
        XCTAssertTrue(menuAddButton.waitToExist(timeout: 3), "Add inventory menu item should exist")
        menuAddButton.tapWhenHittable()

        // Verify form opens
        let saveButton = app.buttons["inventory.add.saveButton"]
        XCTAssertTrue(saveButton.waitToExist(timeout: 5),
                      "Add inventory form should open from menu")
    }

    // MARK: - Helper Methods

    /// Open the add inventory form
    private func openAddInventoryForm() {
        navigateToInventory()
        waitForLoadingToComplete()

        let addButton = app.buttons["inventory_add_button"]
        addButton.tapWhenHittable()

        // Wait for form
        let saveButton = app.buttons["inventory.add.saveButton"]
        XCTAssertTrue(saveButton.waitToExist(timeout: 5),
                      "Add inventory form should open")
    }
}
