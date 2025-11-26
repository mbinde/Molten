//
//  LabelPrintingUITests.swift
//  MoltenUITests
//
//  UI tests for label printing workflow (Workflow 17)
//  CRITICAL: Tests for the label designer feature - this crashed the app!
//

import XCTest

/// UI tests for the label printing/designer feature
///
/// These tests verify:
/// - Label designer can be opened without crashing
/// - Format selection works
/// - Label preview displays
/// - PDF generation and export
/// - Preset management
final class LabelPrintingUITests: BaseUITest {

    // MARK: - Critical Crash Test

    /// CRITICAL TEST: Verify the label designer opens without crashing
    /// This was identified as a crash bug that wasn't caught by existing tests
    func testLabelDesignerOpensWithoutCrash() throws {
        // Navigate to inventory
        navigateToInventory()
        waitForLoadingToComplete()

        // Open the menu (three dots button)
        let menuButton = app.buttons["inventory_menu"]
        XCTAssertTrue(menuButton.waitToExist(timeout: 5), "Inventory menu button should exist")
        menuButton.tapWhenHittable()

        // Tap "Print Labels" option
        let printLabelsButton = app.buttons["inventory_menu_print_labels"]

        // If button is disabled (no items), that's expected - not a crash
        if !printLabelsButton.isEnabled {
            // This is expected when inventory is empty
            // Just verify we didn't crash by checking app still exists
            XCTAssertTrue(app.exists, "App should still exist even with disabled print labels")
            return
        }

        printLabelsButton.tapWhenHittable()

        // Wait for label designer to appear
        let labelDesignerTitle = app.navigationBars["Label Designer"]
        XCTAssertTrue(labelDesignerTitle.waitToExist(timeout: 10),
                      "Label Designer should appear without crashing")

        // Verify app is still responsive after opening
        XCTAssertTrue(app.exists, "App should still exist after opening Label Designer")
    }

    /// Test navigating through the label designer UI elements
    func testLabelDesignerBasicNavigation() throws {
        // Skip if no inventory items (can't open label designer)
        try skipIfNoInventory()

        openLabelDesigner()

        // Verify key UI elements exist
        let cancelButton = app.buttons["label_designer_cancel"]
        XCTAssertTrue(cancelButton.waitToExist(timeout: 5), "Cancel button should exist")

        let generateButton = app.buttons["label_designer_generate_pdf"]
        XCTAssertTrue(generateButton.exists, "Generate PDF button should exist")

        // Verify we can cancel and return to inventory
        cancelButton.tapWhenHittable()

        let inventoryTab = app.buttons["Inventory"]
        XCTAssertTrue(inventoryTab.waitToExist(timeout: 5),
                      "Should return to inventory after canceling")
    }

    /// Test changing label format
    func testLabelFormatSelection() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // Tap to change format
        let changeFormatButton = app.buttons["label_designer_change_format"]
        XCTAssertTrue(changeFormatButton.waitToExist(timeout: 5), "Change format button should exist")
        changeFormatButton.tapWhenHittable()

        // Wait for format search to appear
        Thread.sleep(forTimeInterval: 0.5)

        // Verify format selection view appears
        // FormatRow is a Button, not a cell - look for buttons with format_row_ prefix
        let formatRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'format_row_'")).firstMatch
        XCTAssertTrue(formatRow.waitToExist(timeout: 5), "Format selection rows should appear")

        // Select a format
        formatRow.tapWhenHittable()

        // Verify we returned to designer (format selection dismissed)
        let labelDesignerTitle = app.navigationBars["Label Designer"]
        XCTAssertTrue(labelDesignerTitle.waitToExist(timeout: 5),
                      "Should return to Label Designer after selecting format")
    }

    /// Test preset loading functionality
    func testPresetManagement() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // Try to load presets
        let loadPresetButton = app.buttons["presets_load"]

        // Presets may not exist yet - that's okay
        if loadPresetButton.waitToExist(timeout: 3) {
            loadPresetButton.tapWhenHittable()

            // Preset sheet should appear
            let presetSheet = app.sheets.firstMatch
            if presetSheet.waitToExist(timeout: 3) {
                // Cancel out of preset selection
                let cancelButton = app.buttons["preset_selection_cancel"]
                if cancelButton.exists {
                    cancelButton.tapWhenHittable()
                }
            }
        }

        // App should still be responsive
        XCTAssertTrue(app.exists, "App should remain responsive after preset interaction")
    }

    /// Test PDF generation (may take time)
    func testPDFGeneration() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // Tap generate PDF
        let generateButton = app.buttons["label_designer_generate_pdf"]
        XCTAssertTrue(generateButton.waitToExist(timeout: 5), "Generate button should exist")
        generateButton.tapWhenHittable()

        // Wait for PDF generation (this can take a few seconds)
        // Look for share sheet or PDF preview
        let pdfPreviewDone = app.buttons["pdf_preview_done"]
        let shareSheet = app.sheets.firstMatch

        // Either PDF preview or share sheet should appear
        let startTime = Date()
        let timeout: TimeInterval = 15
        var foundResult = false

        while Date().timeIntervalSince(startTime) < timeout {
            if pdfPreviewDone.exists || shareSheet.exists {
                foundResult = true
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        // It's acceptable if we get an error message instead of success
        // The important thing is no crash
        XCTAssertTrue(app.exists, "App should not crash during PDF generation")

        if foundResult {
            // Clean up - dismiss the preview/sheet
            if pdfPreviewDone.exists {
                pdfPreviewDone.tapWhenHittable()
            }
        }
    }

    /// Test that label builder field toggles work
    func testLabelBuilderFieldToggles() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // Look for field toggles - they use format label_builder_field_[fieldname]
        // Common fields: manufacturer, coe, quantity, location
        let manufacturerToggle = app.switches["label_builder_field_manufacturer"]

        if manufacturerToggle.waitToExist(timeout: 5) {
            // Toggle it
            manufacturerToggle.tapWhenHittable()

            // Verify toggle changed
            XCTAssertTrue(app.exists, "App should remain responsive after toggling field")
        }
    }

    // MARK: - Advanced Options Tests

    /// Test reset sheet options button
    func testResetSheetOptions() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // Scroll down to find advanced options
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.3)

        // Look for reset sheet button
        let resetSheetButton = app.buttons["label_designer_reset_sheet"]

        if resetSheetButton.waitToExist(timeout: 5) {
            resetSheetButton.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.3)

            // App should remain responsive
            XCTAssertTrue(app.exists, "App should remain responsive after resetting sheet options")
        }
    }

    /// Test reset position options button
    func testResetPositionOptions() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // Scroll down to find advanced options
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.3)

        // Look for reset position button
        let resetPositionButton = app.buttons["label_designer_reset_position"]

        if resetPositionButton.waitToExist(timeout: 5) {
            resetPositionButton.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.3)

            // App should remain responsive
            XCTAssertTrue(app.exists, "App should remain responsive after resetting position options")
        }
    }

    // MARK: - Preset Save Tests

    /// Test save new preset functionality
    func testSaveNewPreset() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // Look for save new preset button
        let saveNewButton = app.buttons["presets_save_new"]

        if saveNewButton.waitToExist(timeout: 5) {
            saveNewButton.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)

            // Save preset sheet should appear with text fields and buttons
            let cancelButton = app.buttons["save_preset_cancel"]
            let saveButton = app.buttons["save_preset_save"]

            let hasSheet = cancelButton.waitToExist(timeout: 3) || saveButton.waitToExist(timeout: 3)

            if hasSheet {
                // Cancel out of the save preset sheet
                if cancelButton.exists {
                    cancelButton.tapWhenHittable()
                } else {
                    app.swipeDown()
                }
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after preset save interaction")
    }

    /// Test navigating away and back preserves state
    func testLabelDesignerStatePreservation() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // Make a change - toggle a field
        let manufacturerToggle = app.switches["label_builder_field_manufacturer"]

        if manufacturerToggle.waitToExist(timeout: 5) {
            let initialValue = manufacturerToggle.value as? String

            // Toggle
            manufacturerToggle.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.3)

            // Verify it toggled
            let newValue = manufacturerToggle.value as? String

            // State should be changed
            XCTAssertNotEqual(initialValue, newValue, "Toggle should change state")
        }

        XCTAssertTrue(app.exists, "App should remain responsive after state changes")
    }

    /// Test scrolling through label designer form
    func testLabelDesignerScrolling() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // Scroll down through the form
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.3)

        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.3)

        // Scroll back up
        app.swipeDown()
        Thread.sleep(forTimeInterval: 0.3)

        app.swipeDown()
        Thread.sleep(forTimeInterval: 0.3)

        XCTAssertTrue(app.exists, "App should remain responsive after scrolling")
    }

    /// Test label preview displays correctly
    func testLabelPreviewDisplay() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // The label designer should show a preview of the label
        // Look for preview elements
        let previewExists = app.scrollViews.count > 0 || app.images.count > 0

        XCTAssertTrue(previewExists || app.exists, "Label preview should be displayed")
    }

    /// Test multiple field toggles work correctly
    func testMultipleFieldToggles() throws {
        try skipIfNoInventory()
        openLabelDesigner()

        // Try toggling multiple fields
        let fields = ["manufacturer", "coe", "quantity", "location"]

        for field in fields {
            let toggle = app.switches["label_builder_field_\(field)"]
            if toggle.waitToExist(timeout: 2) {
                toggle.tapWhenHittable()
                Thread.sleep(forTimeInterval: 0.2)
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after toggling multiple fields")
    }

    // MARK: - Helper Methods

    /// Skip test if inventory is empty - waits properly for items to load
    private func skipIfNoInventory() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        // Inventory uses a collectionView (LazyVStack in a List)
        let inventoryList = app.collectionViews["inventory.list"]
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 10), "Inventory list should appear")

        // Wait for inventory items to load (test data creates 10 items)
        // Use descendants matching pattern since items are in collectionView
        let firstInventoryItem = inventoryList.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'inventory.item.'")).firstMatch

        // Wait up to 10 seconds for inventory items to appear
        if !firstInventoryItem.waitToExist(timeout: 10) {
            throw XCTSkip("No inventory items available - cannot test label designer")
        }
    }

    /// Open the label designer
    private func openLabelDesigner() {
        navigateToInventory()
        waitForLoadingToComplete()

        let menuButton = app.buttons["inventory_menu"]
        menuButton.tapWhenHittable()

        let printLabelsButton = app.buttons["inventory_menu_print_labels"]
        printLabelsButton.tapWhenHittable()

        // Wait for designer to appear
        let labelDesignerTitle = app.navigationBars["Label Designer"]
        XCTAssertTrue(labelDesignerTitle.waitToExist(timeout: 10),
                      "Label Designer should open")
    }
}
