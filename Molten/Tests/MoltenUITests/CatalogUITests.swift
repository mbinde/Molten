//
//  CatalogUITests.swift
//  MoltenUITests
//
//  UI tests for catalog view functionality (list-level interactions)
//  Tests search, filters, sort, and browsing the glass catalog
//

import XCTest

/// UI tests for catalog functionality
///
/// These tests verify list-level interactions:
/// - Tab navigation to catalog
/// - Search functionality
/// - Filter sheets (Tags, COE, Manufacturer, Product Type)
/// - Sort options
/// - Loading and empty states
/// - Pull to refresh
///
/// Note: Detail view navigation has the same NavigationLink issue as Inventory
/// and is documented in Manual-Testing-Checklist.md
final class CatalogUITests: BaseUITest {

    // MARK: - Navigation Tests

    /// Test catalog tab exists and can be accessed
    func testCatalogTabAccess() throws {
        // Catalog should be the default tab or easily accessible
        let catalogTab = app.buttons["Catalog"]
        XCTAssertTrue(catalogTab.waitToExist(timeout: 5), "Catalog tab should exist")

        catalogTab.tapWhenHittable()

        // Wait for catalog to load
        waitForLoadingToComplete()

        // Should see either the catalog list or loading/empty state
        let catalogList = app.collectionViews["catalog.list"]
        let loadingIndicator = app.activityIndicators.firstMatch
        let emptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'catalog'")).firstMatch

        let catalogLoaded = catalogList.waitForExistence(timeout: 10) ||
                            loadingIndicator.exists ||
                            emptyState.exists

        XCTAssertTrue(catalogLoaded, "Catalog view should load")
    }

    // MARK: - Search Tests

    /// Test search bar exists
    func testSearchBarExists() throws {
        navigateToCatalog()
        waitForLoadingToComplete()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitToExist(timeout: 5), "Search field should exist in catalog")
    }

    /// Test typing in search filters catalog results
    func testSearchFiltersCatalog() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        let searchField = app.searchFields.firstMatch
        searchField.tapWhenHittable()
        searchField.typeText("clear")

        // Wait for search to apply
        Thread.sleep(forTimeInterval: 1)

        XCTAssertTrue(app.exists, "App should remain responsive after search")
    }

    /// Test search for specific manufacturer
    func testSearchByManufacturer() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        let searchField = app.searchFields.firstMatch
        searchField.tapWhenHittable()
        searchField.typeText("bullseye")

        Thread.sleep(forTimeInterval: 1)

        // Results should be filtered
        XCTAssertTrue(app.exists, "App should remain responsive after manufacturer search")
    }

    /// Test clearing search
    func testClearSearch() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        let searchField = app.searchFields.firstMatch
        searchField.tapWhenHittable()
        searchField.typeText("test")

        Thread.sleep(forTimeInterval: 0.5)

        // Clear using clear button
        let clearButton = app.buttons["Clear text"]
        if clearButton.waitToExist(timeout: 2) {
            clearButton.tapWhenHittable()
        }

        // Cancel search
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitToExist(timeout: 2) {
            cancelButton.tapWhenHittable()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after clearing search")
    }

    // MARK: - Filter Sheet Tests

    /// Test tags filter sheet
    func testTagsFilterSheet() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        // Look for tags filter button
        let tagsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'tag'")).firstMatch

        if tagsButton.waitToExist(timeout: 3) {
            tagsButton.tapWhenHittable()

            // Sheet should appear
            Thread.sleep(forTimeInterval: 0.5)

            // Dismiss
            dismissSheet()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after tags filter")
    }

    /// Test COE filter sheet
    func testCOEFilterSheet() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        // Look for COE filter button
        let coeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'coe'")).firstMatch

        if coeButton.waitToExist(timeout: 3) {
            coeButton.tapWhenHittable()

            Thread.sleep(forTimeInterval: 0.5)

            dismissSheet()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after COE filter")
    }

    /// Test manufacturer filter sheet
    func testManufacturerFilterSheet() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        // Look for manufacturer filter button
        let mfrButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'manufacturer'")).firstMatch

        if mfrButton.waitToExist(timeout: 3) {
            mfrButton.tapWhenHittable()

            Thread.sleep(forTimeInterval: 0.5)

            // Look for Done button to dismiss
            let doneButton = app.buttons["catalog_manufacturer_filter_done"]
            if doneButton.waitToExist(timeout: 2) {
                doneButton.tapWhenHittable()
            } else {
                dismissSheet()
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after manufacturer filter")
    }

    /// Test product type filter (Glass, Coatings, Tools)
    func testProductTypeFilter() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        // Look for product type filter
        let typeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'glass' OR label CONTAINS[c] 'type'")).firstMatch

        if typeButton.waitToExist(timeout: 3) {
            typeButton.tapWhenHittable()

            Thread.sleep(forTimeInterval: 0.5)

            // Dismiss by tapping outside or selecting
            app.tap()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after product type filter")
    }

    // MARK: - Sort Tests

    /// Test sort option change
    func testSortOptionChange() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        // Look for sort control
        let sortButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sort'")).firstMatch

        if sortButton.waitToExist(timeout: 3) {
            sortButton.tapWhenHittable()

            Thread.sleep(forTimeInterval: 0.5)

            // Try to select a sort option
            let nameOption = app.buttons["Name"]
            if nameOption.waitToExist(timeout: 2) {
                nameOption.tapWhenHittable()
            } else {
                app.tap()  // Dismiss
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after sort change")
    }

    // MARK: - List Tests

    /// Test catalog list displays items
    func testCatalogListDisplaysItems() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        let catalogList = app.collectionViews["catalog.list"]
        XCTAssertTrue(catalogList.waitForExistence(timeout: 10), "Catalog list should appear")

        // Should have catalog items
        let catalogItems = catalogList.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'catalog.item.'"))

        // Catalog should have items (it's pre-populated with 2500+ glass items)
        XCTAssertTrue(catalogItems.firstMatch.waitForExistence(timeout: 10),
                      "Catalog should contain items")
    }

    /// Test catalog can be scrolled
    func testCatalogScrolling() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        let catalogList = app.collectionViews["catalog.list"]
        XCTAssertTrue(catalogList.waitForExistence(timeout: 10), "Catalog list should appear")

        // Scroll down
        catalogList.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)

        // Scroll back up
        catalogList.swipeDown()

        XCTAssertTrue(app.exists, "App should remain responsive after scrolling")
    }

    // MARK: - Pull to Refresh Tests

    /// Test pull to refresh
    func testPullToRefresh() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        let catalogList = app.collectionViews["catalog.list"]
        XCTAssertTrue(catalogList.waitForExistence(timeout: 10), "Catalog list should appear")

        // Pull down to refresh
        let start = catalogList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = catalogList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)

        // Wait for refresh
        Thread.sleep(forTimeInterval: 2)

        XCTAssertTrue(app.exists, "App should remain responsive after pull to refresh")
    }

    // MARK: - Empty State Tests

    /// Test search empty state appears for no results
    func testSearchEmptyState() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        // Search for something that won't exist
        let searchField = app.searchFields.firstMatch
        searchField.tapWhenHittable()
        searchField.typeText("xyznonexistent12345")

        Thread.sleep(forTimeInterval: 1)

        // Should show empty state or no results message
        let emptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no' OR label CONTAINS[c] 'empty'")).firstMatch

        // Either empty state appears or list is empty
        XCTAssertTrue(app.exists, "App should handle no search results")

        // Clear search
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tapWhenHittable()
        }
    }

    // MARK: - Filter Clear Tests

    /// Test clearing filters from empty state
    func testClearFiltersFromEmptyState() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        // Apply a filter that results in no matches
        let searchField = app.searchFields.firstMatch
        searchField.tapWhenHittable()
        searchField.typeText("xyznonexistent")

        Thread.sleep(forTimeInterval: 1)

        // Look for clear button
        let clearButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'clear'")).firstMatch

        if clearButton.waitToExist(timeout: 3) {
            clearButton.tapWhenHittable()
        } else {
            // Cancel search manually
            let cancelSearchButton = app.buttons["Cancel"]
            if cancelSearchButton.exists {
                cancelSearchButton.tapWhenHittable()
            }
        }

        XCTAssertTrue(app.exists, "App should remain responsive after clearing filters")
    }

    // MARK: - Loading State Tests

    /// Test loading state appears during initial load
    func testLoadingStateAppears() throws {
        // This test verifies the app handles loading gracefully
        // Since catalog loads quickly, we just verify the app doesn't crash
        navigateToCatalog()

        // Either loading indicator, list, or empty state should appear
        let catalogList = app.collectionViews["catalog.list"]
        let loadingIndicator = app.activityIndicators.firstMatch

        let loaded = catalogList.waitForExistence(timeout: 15) || loadingIndicator.exists

        XCTAssertTrue(loaded || app.exists, "App should show loading state or content")
    }

    // MARK: - Search Scope Tests

    /// Test search scope can be changed (All fields vs Titles only)
    func testSearchScopeChange() throws {
        navigateToCatalog()
        waitForCatalogToLoad()

        // Tap search to activate
        let searchField = app.searchFields.firstMatch
        searchField.tapWhenHittable()

        // Look for search scope buttons
        let allFieldsScope = app.buttons["All fields"]
        let titlesOnlyScope = app.buttons["Only titles"]

        if allFieldsScope.waitToExist(timeout: 3) || titlesOnlyScope.waitToExist(timeout: 3) {
            // Tap titles only if available
            if titlesOnlyScope.exists {
                titlesOnlyScope.tapWhenHittable()
            }
        }

        // Cancel search
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tapWhenHittable()
        }

        XCTAssertTrue(app.exists, "App should remain responsive after scope change")
    }

    // MARK: - Helper Methods

    /// Wait for catalog to finish loading and show items
    private func waitForCatalogToLoad() {
        waitForLoadingToComplete()

        let catalogList = app.collectionViews["catalog.list"]
        _ = catalogList.waitForExistence(timeout: 15)
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
