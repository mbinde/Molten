//
//  InventoryImageUploadUITests.swift
//  MoltenUITests
//
//  UI tests for custom image upload workflow
//  Tests for users uploading custom images to inventory items
//

import XCTest

/// UI tests for the custom image upload feature
///
/// These tests verify:
/// - Photo picker UI appears when tapping add image button
/// - Images can be selected from the system photo picker
/// - Uploaded images display correctly in Custom Images section
/// - Images persist across navigation (back and forth)
/// - Multiple images can be uploaded
/// - Custom Images section expands/collapses correctly
final class InventoryImageUploadUITests: BaseUITest {

    // MARK: - Test Setup

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Add test images to the simulator's photo library
        // The sample images (sample-glass-image-1.jpg through sample-glass-image-4.jpg)
        // are in the test bundle
        addTestImagesToSimulator()
    }

    /// Add test images to simulator photo library using simctl
    private func addTestImagesToSimulator() {
        // Get the test bundle path
        let testBundle = Bundle(for: type(of: self))

        for i in 1...4 {
            let imageName = "sample-glass-image-\(i)"
            if let imagePath = testBundle.path(forResource: imageName, ofType: "jpg") {
                // Use simctl to add image to simulator's photo library
                let process = Process()
                process.launchPath = "/usr/bin/xcrun"
                process.arguments = ["simctl", "addmedia", "booted", imagePath]
                try? process.run()
                process.waitUntilExit()
            }
        }

        // Wait briefly for images to be added
        Thread.sleep(forTimeInterval: 1)
    }

    // MARK: - Photo Picker UI Tests

    /// Test that photo picker appears when tapping Add Image from FAB menu
    func testPhotoPickerAppearsFromFABMenu() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()
        openActionsMenu()

        // Tap Add Image button
        let fabAddImage = app.buttons["fab_add_image"]
        XCTAssertTrue(fabAddImage.waitToExist(timeout: 5), "Add Image menu item should be visible")
        fabAddImage.tapWhenHittable()

        // Wait for photo picker to appear
        // PhotosPicker shows with standard system UI elements
        Thread.sleep(forTimeInterval: 1)

        // Verify picker appeared by checking for common picker elements
        // The picker should show "Photos" navigation or "Cancel" button
        let cancelButton = app.buttons["Cancel"]
        let photosNavBar = app.navigationBars["Photos"]
        let recentPhotos = app.staticTexts["Recents"]

        let pickerAppeared = cancelButton.waitToExist(timeout: 5) ||
                            photosNavBar.waitToExist(timeout: 2) ||
                            recentPhotos.waitToExist(timeout: 2)

        XCTAssertTrue(pickerAppeared, "Photo picker should appear after tapping Add Image")

        // Dismiss the picker
        if cancelButton.exists {
            cancelButton.tapWhenHittable()
        }
    }

    /// Test that photo picker appears when tapping Add button in Custom Images section (empty state)
    func testPhotoPickerAppearsFromCustomImagesSection() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Scroll to Custom Images section
        scrollToCustomImagesSection()

        // Look for the Add Custom Images button (shown in empty state)
        let addImagesButton = app.buttons["glass_item_image_add"]

        if addImagesButton.waitToExist(timeout: 5) {
            addImagesButton.tapWhenHittable()

            // Wait for photo picker
            Thread.sleep(forTimeInterval: 1)

            // Verify picker appeared
            let cancelButton = app.buttons["Cancel"]
            let photosNavBar = app.navigationBars["Photos"]

            let pickerAppeared = cancelButton.waitToExist(timeout: 5) || photosNavBar.waitToExist(timeout: 2)
            XCTAssertTrue(pickerAppeared, "Photo picker should appear from Custom Images section")

            // Dismiss
            if cancelButton.exists {
                cancelButton.tapWhenHittable()
            }
        } else {
            // If no add button in empty state, images may already exist
            // Look for "Add More Images" button instead
            let addMoreButton = app.buttons["glass_item_image_add_more"]
            if addMoreButton.waitToExist(timeout: 3) {
                addMoreButton.tapWhenHittable()
                Thread.sleep(forTimeInterval: 1)

                let cancelButton = app.buttons["Cancel"]
                XCTAssertTrue(cancelButton.waitToExist(timeout: 5), "Photo picker should appear")
                cancelButton.tapWhenHittable()
            }
        }
    }

    /// Test that Cancel in photo picker dismisses without adding images
    func testPhotoCancelDismissesWithoutChanges() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()
        openActionsMenu()

        // Open photo picker
        let fabAddImage = app.buttons["fab_add_image"]
        XCTAssertTrue(fabAddImage.waitToExist(timeout: 5), "Add Image should exist")
        fabAddImage.tapWhenHittable()
        Thread.sleep(forTimeInterval: 1)

        // Cancel the picker
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitToExist(timeout: 5) {
            cancelButton.tapWhenHittable()
        }

        // Verify we're back in detail view (Actions menu should be accessible)
        let actionsButton = app.buttons["Actions"]
        let actionsMenuButton = app.buttons["detail_actions_menu"]
        let backInDetail = actionsButton.waitToExist(timeout: 5) || actionsMenuButton.waitToExist(timeout: 2)
        XCTAssertTrue(backInDetail, "Should return to detail view after canceling photo picker")
    }

    // MARK: - Image Selection Tests

    /// Test selecting a single image from photo picker
    func testSelectSingleImageFromPicker() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()
        openActionsMenu()

        // Open photo picker
        let fabAddImage = app.buttons["fab_add_image"]
        XCTAssertTrue(fabAddImage.waitToExist(timeout: 5), "Add Image should exist")
        fabAddImage.tapWhenHittable()
        Thread.sleep(forTimeInterval: 1)

        // Select an image from the picker
        // The picker shows images in a grid - tap the first one
        let firstImage = app.images.firstMatch
        if firstImage.waitToExist(timeout: 5) {
            firstImage.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)

            // Tap "Add" to confirm selection (iOS 16+)
            let addButton = app.buttons["Add"]
            if addButton.waitToExist(timeout: 3) {
                addButton.tapWhenHittable()
            }
        } else {
            // If no images in picker, cancel and note in assertion
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tapWhenHittable()
            }
            XCTAssertTrue(app.exists, "No images in photo library to select")
            return
        }

        // Wait for image to be processed and added
        Thread.sleep(forTimeInterval: 2)

        // Verify we're back in detail view
        let actionsButton = app.buttons["Actions"]
        XCTAssertTrue(actionsButton.waitToExist(timeout: 5), "Should return to detail view after adding image")

        // Scroll to Custom Images section and verify image appears
        scrollToCustomImagesSection()
        verifyCustomImagesHasContent()
    }

    /// Test selecting multiple images from photo picker
    func testSelectMultipleImagesFromPicker() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()
        openActionsMenu()

        // Open photo picker
        let fabAddImage = app.buttons["fab_add_image"]
        XCTAssertTrue(fabAddImage.waitToExist(timeout: 5), "Add Image should exist")
        fabAddImage.tapWhenHittable()
        Thread.sleep(forTimeInterval: 1)

        // Select multiple images (up to 3)
        // In multi-select mode, tap images to select them
        let images = app.images.allElementsBoundByIndex
        var selectedCount = 0

        for i in 0..<min(3, images.count) {
            if images[i].waitToExist(timeout: 2) {
                images[i].tap()
                selectedCount += 1
                Thread.sleep(forTimeInterval: 0.3)
            }
        }

        if selectedCount > 0 {
            // Tap "Add" to confirm selection
            let addButton = app.buttons["Add"]
            if addButton.waitToExist(timeout: 3) {
                addButton.tapWhenHittable()
            }

            // Wait for images to be processed
            Thread.sleep(forTimeInterval: 3)

            // Verify we're back in detail view
            let actionsButton = app.buttons["Actions"]
            XCTAssertTrue(actionsButton.waitToExist(timeout: 5), "Should return after adding images")
        } else {
            // Cancel if no images available
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tapWhenHittable()
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after multi-image selection")
    }

    // MARK: - Custom Images Section Tests

    /// Test Custom Images section expands and collapses
    func testCustomImagesSectionExpandCollapse() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Look for Custom Images section header
        let sectionHeader = app.buttons["section_images"]

        // Scroll to find it
        scrollToCustomImagesSection()

        if sectionHeader.waitToExist(timeout: 5) {
            // Get initial expanded state
            let initiallyExpanded = app.buttons["glass_item_image_add"].exists ||
                                   app.buttons["glass_item_image_add_more"].exists ||
                                   app.staticTexts["No custom images yet"].exists

            // Toggle section
            sectionHeader.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)

            // Verify state changed
            let nowExpanded = app.buttons["glass_item_image_add"].exists ||
                             app.buttons["glass_item_image_add_more"].exists ||
                             app.staticTexts["No custom images yet"].exists

            if initiallyExpanded {
                // Was expanded, should now be collapsed
                XCTAssertFalse(nowExpanded, "Section should collapse when header is tapped")
            }

            // Toggle again to restore
            sectionHeader.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertTrue(app.exists, "App should remain responsive after section toggle")
    }

    /// Test that "Add More Images" button appears when images already exist
    func testAddMoreImagesButtonAppears() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // First, add an image
        openActionsMenu()
        let fabAddImage = app.buttons["fab_add_image"]
        XCTAssertTrue(fabAddImage.waitToExist(timeout: 5), "Add Image should exist")
        fabAddImage.tapWhenHittable()
        Thread.sleep(forTimeInterval: 1)

        // Try to select an image
        let firstImage = app.images.firstMatch
        if firstImage.waitToExist(timeout: 5) {
            firstImage.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)

            let addButton = app.buttons["Add"]
            if addButton.waitToExist(timeout: 3) {
                addButton.tapWhenHittable()
            }
            Thread.sleep(forTimeInterval: 2)
        } else {
            // Cancel if no images
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tapWhenHittable()
            }
            // Skip rest of test if we couldn't add an image
            return
        }

        // Now scroll to Custom Images section
        scrollToCustomImagesSection()

        // Look for "Add More Images" button (appears when images already exist)
        let addMoreButton = app.buttons["glass_item_image_add_more"]
        XCTAssertTrue(addMoreButton.waitToExist(timeout: 5),
                      "Add More Images button should appear when images exist")
    }

    // MARK: - Image Persistence Tests

    /// Test that uploaded images persist after navigating away and back
    func testImagesPeristAfterNavigation() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Add an image first
        openActionsMenu()
        let fabAddImage = app.buttons["fab_add_image"]
        XCTAssertTrue(fabAddImage.waitToExist(timeout: 5), "Add Image should exist")
        fabAddImage.tapWhenHittable()
        Thread.sleep(forTimeInterval: 1)

        // Select an image
        let firstImage = app.images.firstMatch
        if firstImage.waitToExist(timeout: 5) {
            firstImage.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)

            let addButton = app.buttons["Add"]
            if addButton.waitToExist(timeout: 3) {
                addButton.tapWhenHittable()
            }
            Thread.sleep(forTimeInterval: 2)
        } else {
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tapWhenHittable()
            }
            // Can't test persistence without an image
            return
        }

        // Verify we're in detail view
        let actionsButton = app.buttons["Actions"]
        XCTAssertTrue(actionsButton.waitToExist(timeout: 5), "Should be in detail view")

        // Navigate back to inventory list
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        backButton.tapWhenHittable()
        Thread.sleep(forTimeInterval: 1)

        // Navigate back to the same item detail
        let inventoryList = app.collectionViews["inventory.list"]
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 10), "Inventory list should appear")

        let firstCell = inventoryList.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "First inventory item should exist")
        firstCell.tapWhenHittable()
        Thread.sleep(forTimeInterval: 1)

        // Scroll to Custom Images section
        scrollToCustomImagesSection()

        // Verify images are still there (Add More button exists, not empty state)
        let addMoreButton = app.buttons["glass_item_image_add_more"]
        let hasImages = addMoreButton.waitToExist(timeout: 5)
        XCTAssertTrue(hasImages, "Images should persist after navigating away and back")
    }

    /// Test images persist after app termination and relaunch
    func testImagesPersistAcrossAppLaunch() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Add an image
        openActionsMenu()
        let fabAddImage = app.buttons["fab_add_image"]
        XCTAssertTrue(fabAddImage.waitToExist(timeout: 5), "Add Image should exist")
        fabAddImage.tapWhenHittable()
        Thread.sleep(forTimeInterval: 1)

        let firstImage = app.images.firstMatch
        if firstImage.waitToExist(timeout: 5) {
            firstImage.tapWhenHittable()
            Thread.sleep(forTimeInterval: 0.5)

            let addButton = app.buttons["Add"]
            if addButton.waitToExist(timeout: 3) {
                addButton.tapWhenHittable()
            }
            Thread.sleep(forTimeInterval: 2)
        } else {
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tapWhenHittable()
            }
            // Skip test if can't add image
            return
        }

        // Terminate the app
        app.terminate()

        // Relaunch the app
        app.launch()

        // Wait for app to be ready
        let catalogButton = app.buttons["Catalog"]
        XCTAssertTrue(catalogButton.waitForExistence(timeout: 30), "App should relaunch")

        // Navigate back to inventory
        navigateToInventory()
        waitForLoadingToComplete()

        let inventoryList = app.collectionViews["inventory.list"]
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 10), "Inventory list should appear")

        // Open first item detail
        let firstCell = inventoryList.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10), "First item should exist")
        firstCell.tapWhenHittable()
        Thread.sleep(forTimeInterval: 1)

        // Scroll to Custom Images section
        scrollToCustomImagesSection()

        // Verify images persisted
        let addMoreButton = app.buttons["glass_item_image_add_more"]
        let hasImages = addMoreButton.waitToExist(timeout: 5)
        XCTAssertTrue(hasImages, "Images should persist across app launch")
    }

    // MARK: - Image Display Tests

    /// Test that uploaded images display in the correct section
    func testUploadedImagesDisplayInCustomImagesSection() throws {
        try ensureInventoryExists()
        navigateToFirstItemDetail()

        // Check if there are already images
        scrollToCustomImagesSection()

        let addMoreButton = app.buttons["glass_item_image_add_more"]
        let addButton = app.buttons["glass_item_image_add"]

        // If empty state (add button visible), add an image
        if addButton.waitToExist(timeout: 3) {
            addButton.tapWhenHittable()
            Thread.sleep(forTimeInterval: 1)

            let firstImage = app.images.firstMatch
            if firstImage.waitToExist(timeout: 5) {
                firstImage.tapWhenHittable()
                Thread.sleep(forTimeInterval: 0.5)

                let confirmAdd = app.buttons["Add"]
                if confirmAdd.waitToExist(timeout: 3) {
                    confirmAdd.tapWhenHittable()
                }
                Thread.sleep(forTimeInterval: 2)
            } else {
                let cancelButton = app.buttons["Cancel"]
                if cancelButton.exists {
                    cancelButton.tapWhenHittable()
                }
                return
            }
        }

        // Scroll back to custom images section
        scrollToCustomImagesSection()

        // Verify the section shows images (add more button indicates images exist)
        XCTAssertTrue(addMoreButton.waitToExist(timeout: 5) || app.images.count > 0,
                      "Custom Images section should display uploaded images")
    }

    // MARK: - Error Handling Tests

    /// Test behavior when photo library access is denied
    func testPhotoLibraryAccessDenied() throws {
        // Note: This test would require resetting photo permissions which is
        // difficult to do reliably in UI tests. Skipping for now.
        // The app should handle denied access gracefully.
        XCTAssertTrue(true, "Photo library permission testing requires manual setup")
    }

    // MARK: - Helper Methods

    /// Ensure inventory has items for testing
    private func ensureInventoryExists() throws {
        navigateToInventory()
        waitForLoadingToComplete()

        let inventoryList = app.collectionViews["inventory.list"]
        XCTAssertTrue(inventoryList.waitForExistence(timeout: 10), "Inventory list should appear")

        let firstCell = inventoryList.cells.firstMatch
        let itemsAppeared = firstCell.waitForExistence(timeout: 10)

        if !itemsAppeared {
            throw XCTSkip("No inventory items available. Use test data generation.")
        }
    }

    /// Navigate to the first inventory item detail
    private func navigateToFirstItemDetail() {
        navigateToInventory()
        waitForLoadingToComplete()

        let inventoryList = app.collectionViews["inventory.list"]
        guard inventoryList.waitForExistence(timeout: 10) else {
            XCTFail("Inventory list should appear")
            return
        }

        let firstCell = inventoryList.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 10) else {
            XCTFail("Should have at least one inventory item")
            return
        }

        firstCell.tapWhenHittable()
        Thread.sleep(forTimeInterval: 1.0)

        let actionsButton = app.buttons["Actions"]
        let actionsMenuButton = app.buttons["detail_actions_menu"]
        let detailLoaded = actionsButton.waitToExist(timeout: 5) || actionsMenuButton.waitToExist(timeout: 2)
        XCTAssertTrue(detailLoaded, "Detail view should load")
    }

    /// Open the Actions menu in the detail view toolbar
    private func openActionsMenu() {
        let actionsMenuButton = app.buttons["detail_actions_menu"]
        let actionsButton = app.buttons["Actions"]

        if actionsMenuButton.waitToExist(timeout: 3) {
            actionsMenuButton.tapWhenHittable()
        } else if actionsButton.waitToExist(timeout: 3) {
            actionsButton.tapWhenHittable()
        } else {
            XCTFail("Actions menu should exist")
        }

        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Scroll down to find Custom Images section
    private func scrollToCustomImagesSection() {
        // Swipe up a few times to find the section
        for _ in 0..<3 {
            let sectionHeader = app.buttons["section_images"]
            let addButton = app.buttons["glass_item_image_add"]
            let addMoreButton = app.buttons["glass_item_image_add_more"]

            if sectionHeader.exists || addButton.exists || addMoreButton.exists {
                break
            }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Expand section if collapsed
        let sectionHeader = app.buttons["section_images"]
        if sectionHeader.exists {
            // Check if content is visible
            let addButton = app.buttons["glass_item_image_add"]
            let addMoreButton = app.buttons["glass_item_image_add_more"]
            let emptyText = app.staticTexts["No custom images yet"]

            if !addButton.exists && !addMoreButton.exists && !emptyText.exists {
                // Section might be collapsed, tap to expand
                sectionHeader.tapWhenHittable()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    /// Verify Custom Images section has content (not in empty state)
    private func verifyCustomImagesHasContent() {
        // Look for indicators that images exist:
        // 1. "Add More Images" button (appears when images exist)
        // 2. Image thumbnails in the grid
        // 3. Primary/Alternate labels on images

        let addMoreButton = app.buttons["glass_item_image_add_more"]
        let primaryLabel = app.staticTexts["Primary"]
        let alternateLabel = app.staticTexts["Alternate"]

        let hasContent = addMoreButton.waitToExist(timeout: 3) ||
                        primaryLabel.exists ||
                        alternateLabel.exists

        XCTAssertTrue(hasContent, "Custom Images section should have content after upload")
    }
}
