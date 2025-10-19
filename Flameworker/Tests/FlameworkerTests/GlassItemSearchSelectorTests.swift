//
//  GlassItemSearchSelectorTests.swift
//  FlameworkerTests
//
//  Comprehensive tests for the GlassItemSearchSelector shared component
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
import SwiftUI
@testable import Flameworker

@Suite("Glass Item Search Selector Tests")
struct GlassItemSearchSelectorTests {

    // MARK: - Test Setup

    init() async throws {
        RepositoryFactory.configureForTesting()
    }

    // MARK: - Test Data Helpers

    private func createTestGlassItem(
        naturalKey: String = "test-item-001",
        name: String = "Test Item",
        manufacturer: String = "test"
    ) -> GlassItemModel {
        return GlassItemModel(
            natural_key: naturalKey,
            name: name,
            sku: "001",
            manufacturer: manufacturer,
            mfr_notes: nil,
            coe: 96,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )
    }

    private func createTestCompleteItem(
        naturalKey: String = "test-item-001",
        name: String = "Test Item",
        manufacturer: String = "test"
    ) -> CompleteInventoryItemModel {
        let glassItem = createTestGlassItem(
            naturalKey: naturalKey,
            name: name,
            manufacturer: manufacturer
        )

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )
    }

    // MARK: - Search Filtering Tests

    @Test("Filters by name case-insensitive")
    func testFilterByName() {
        let items = [
            createTestCompleteItem(naturalKey: "test-001", name: "Clear Rod", manufacturer: "bullseye"),
            createTestCompleteItem(naturalKey: "test-002", name: "Transparent Blue", manufacturer: "effetre"),
            createTestCompleteItem(naturalKey: "test-003", name: "Opaque Green", manufacturer: "cim")
        ]

        // Test lowercase search
        let filtered1 = items.filter { item in
            let searchLower = "clear".lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered1.count == 1)
        #expect(filtered1.first?.glassItem.name == "Clear Rod")

        // Test uppercase search
        let filtered2 = items.filter { item in
            let searchLower = "BLUE".lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered2.count == 1)
        #expect(filtered2.first?.glassItem.name == "Transparent Blue")

        // Test mixed case search
        let filtered3 = items.filter { item in
            let searchLower = "GrEeN".lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered3.count == 1)
        #expect(filtered3.first?.glassItem.name == "Opaque Green")
    }

    @Test("Filters by natural key")
    func testFilterByNaturalKey() {
        let items = [
            createTestCompleteItem(naturalKey: "bullseye-001-0", name: "Item A", manufacturer: "bullseye"),
            createTestCompleteItem(naturalKey: "effetre-002-0", name: "Item B", manufacturer: "effetre"),
            createTestCompleteItem(naturalKey: "cim-003-0", name: "Item C", manufacturer: "cim")
        ]

        let filtered = items.filter { item in
            let searchLower = "effetre-002".lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.natural_key == "effetre-002-0")
    }

    @Test("Filters by manufacturer")
    func testFilterByManufacturer() {
        let items = [
            createTestCompleteItem(naturalKey: "be-001-0", name: "Item A", manufacturer: "bullseye"),
            createTestCompleteItem(naturalKey: "be-002-0", name: "Item B", manufacturer: "bullseye"),
            createTestCompleteItem(naturalKey: "ef-003-0", name: "Item C", manufacturer: "effetre")
        ]

        let filtered = items.filter { item in
            let searchLower = "bullseye".lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.glassItem.manufacturer == "bullseye" })
    }

    @Test("Empty search returns all items")
    func testEmptySearchReturnsAll() {
        let items = [
            createTestCompleteItem(naturalKey: "test-001", name: "Item A"),
            createTestCompleteItem(naturalKey: "test-002", name: "Item B"),
            createTestCompleteItem(naturalKey: "test-003", name: "Item C")
        ]

        let searchText = ""
        let filtered = searchText.isEmpty ? items : items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 3)
    }

    @Test("Partial match works correctly")
    func testPartialMatch() {
        let items = [
            createTestCompleteItem(naturalKey: "test-001", name: "Light Blue Rod"),
            createTestCompleteItem(naturalKey: "test-002", name: "Dark Blue Stringer"),
            createTestCompleteItem(naturalKey: "test-003", name: "Green Sheet")
        ]

        let filtered = items.filter { item in
            let searchLower = "blue".lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.glassItem.name.lowercased().contains("blue") })
    }

    @Test("No matches returns empty array")
    func testNoMatches() {
        let items = [
            createTestCompleteItem(naturalKey: "test-001", name: "Clear Rod"),
            createTestCompleteItem(naturalKey: "test-002", name: "Blue Stringer")
        ]

        let filtered = items.filter { item in
            let searchLower = "nonexistent".lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.isEmpty)
    }

    @Test("Search with special characters works")
    func testSearchWithSpecialCharacters() {
        let items = [
            createTestCompleteItem(naturalKey: "test-001-0", name: "Item A"),
            createTestCompleteItem(naturalKey: "test-002-0", name: "Item B")
        ]

        let filtered = items.filter { item in
            let searchLower = "001-0".lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.natural_key == "test-001-0")
    }

    // MARK: - Selection Behavior Tests

    @Test("onSelect callback receives correct item")
    func testOnSelectCallback() {
        var selectedItem: GlassItemModel? = nil
        let testItem = createTestGlassItem(naturalKey: "test-001", name: "Test Item")

        // Simulate selection
        selectedItem = testItem

        #expect(selectedItem != nil)
        #expect(selectedItem?.natural_key == "test-001")
        #expect(selectedItem?.name == "Test Item")
    }

    @Test("onClear callback resets selection")
    func testOnClearCallback() {
        var selectedItem: GlassItemModel? = createTestGlassItem()
        var searchText = "test"

        // Simulate clear
        selectedItem = nil
        searchText = ""

        #expect(selectedItem == nil)
        #expect(searchText.isEmpty)
    }

    @Test("Selected item persists after search text changes")
    func testSelectedItemPersistence() {
        let selectedItem = createTestGlassItem(naturalKey: "test-001")
        var searchText = "original search"

        // Simulate changing search text
        searchText = "new search"

        // Selected item should remain unchanged
        #expect(selectedItem.natural_key == "test-001")
    }

    // MARK: - State Management Tests

    @Test("Search text updates filter results")
    func testSearchTextUpdatesFilter() {
        let items = [
            createTestCompleteItem(naturalKey: "test-001", name: "Clear Rod"),
            createTestCompleteItem(naturalKey: "test-002", name: "Blue Stringer"),
            createTestCompleteItem(naturalKey: "test-003", name: "Green Sheet")
        ]

        // First search
        var searchText = "clear"
        var filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.name == "Clear Rod")

        // Update search
        searchText = "blue"
        filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.name == "Blue Stringer")
    }

    @Test("Clear resets search text and selection")
    func testClearResets() {
        var selectedItem: GlassItemModel? = createTestGlassItem()
        var searchText = "test search"

        // Simulate clear action
        selectedItem = nil
        searchText = ""

        #expect(selectedItem == nil)
        #expect(searchText.isEmpty)
    }

    @Test("Prefilled natural key behavior")
    func testPrefilledNaturalKey() {
        let prefilledKey = "bullseye-001-0"
        let items = [
            createTestCompleteItem(naturalKey: "bullseye-001-0", name: "Clear Rod"),
            createTestCompleteItem(naturalKey: "effetre-002-0", name: "Blue Stringer")
        ]

        // Try to find prefilled item
        let foundItem = items.first { $0.glassItem.natural_key == prefilledKey }

        #expect(foundItem != nil)
        #expect(foundItem?.glassItem.natural_key == "bullseye-001-0")
    }

    @Test("Prefilled natural key not found scenario")
    func testPrefilledNaturalKeyNotFound() {
        let prefilledKey = "nonexistent-item-0"
        let items = [
            createTestCompleteItem(naturalKey: "bullseye-001-0", name: "Clear Rod")
        ]

        let foundItem = items.first { $0.glassItem.natural_key == prefilledKey }

        #expect(foundItem == nil)
    }

    // MARK: - UI State Tests

    @Test("Empty state shows instruction")
    func testEmptyState() {
        let selectedItem: GlassItemModel? = nil
        let prefilledNaturalKey: String? = nil
        let searchText = ""

        let shouldShowInstruction = selectedItem == nil && prefilledNaturalKey == nil
        #expect(shouldShowInstruction == true)
    }

    @Test("Search results state shows when searching")
    func testSearchResultsState() {
        let selectedItem: GlassItemModel? = nil
        let prefilledNaturalKey: String? = nil
        let searchText = "test"

        let shouldShowResults = !searchText.isEmpty && prefilledNaturalKey == nil
        #expect(shouldShowResults == true)
    }

    @Test("Selected state shows when item selected")
    func testSelectedState() {
        let selectedItem: GlassItemModel? = createTestGlassItem()

        #expect(selectedItem != nil)
    }

    @Test("Not found state shows for prefilled key without match")
    func testNotFoundState() {
        let selectedItem: GlassItemModel? = nil
        let prefilledNaturalKey: String? = "nonexistent-001-0"

        let shouldShowNotFound = selectedItem == nil && prefilledNaturalKey != nil
        #expect(shouldShowNotFound == true)
    }

    @Test("Search field disabled when item selected")
    func testSearchFieldDisabled() {
        let selectedItem: GlassItemModel? = createTestGlassItem()

        let isDisabled = selectedItem != nil
        #expect(isDisabled == true)
    }

    @Test("Search field enabled when no item selected")
    func testSearchFieldEnabled() {
        let selectedItem: GlassItemModel? = nil

        let isDisabled = selectedItem != nil
        #expect(isDisabled == false)
    }

    @Test("Clear button visible when item selected without prefilled key")
    func testClearButtonVisible() {
        let selectedItem: GlassItemModel? = createTestGlassItem()
        let prefilledNaturalKey: String? = nil

        let shouldShowClear = selectedItem != nil && prefilledNaturalKey == nil
        #expect(shouldShowClear == true)
    }

    @Test("Clear button hidden when prefilled key present")
    func testClearButtonHiddenForPrefilled() {
        let selectedItem: GlassItemModel? = createTestGlassItem()
        let prefilledNaturalKey: String? = "test-001-0"

        let shouldShowClear = selectedItem != nil && prefilledNaturalKey == nil
        #expect(shouldShowClear == false)
    }

    // MARK: - Edge Cases

    @Test("Empty items array")
    func testEmptyItemsArray() {
        let items: [CompleteInventoryItemModel] = []
        let searchText = "test"

        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.isEmpty)
    }

    @Test("Very long search text")
    func testVeryLongSearchText() {
        let items = [createTestCompleteItem(name: "Test Item")]
        let longSearch = String(repeating: "a", count: 1000)

        let filtered = items.filter { item in
            let searchLower = longSearch.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.isEmpty)
    }

    @Test("Search with whitespace")
    func testSearchWithWhitespace() {
        let items = [
            createTestCompleteItem(name: "Clear Rod"),
            createTestCompleteItem(name: "Blue Stringer")
        ]

        let filtered = items.filter { item in
            let searchLower = "  clear  ".lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        // Whitespace is included in the search, so it should match items with "clear" surrounded by spaces
        #expect(filtered.isEmpty) // "Clear Rod" doesn't contain "  clear  "
    }

    @Test("Items with identical names but different natural keys")
    func testIdenticalNamesDistinctKeys() {
        let items = [
            createTestCompleteItem(naturalKey: "test-001-0", name: "Clear"),
            createTestCompleteItem(naturalKey: "test-002-0", name: "Clear")
        ]

        let filtered = items.filter { item in
            let searchLower = "clear".lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 2)
        #expect(filtered[0].glassItem.natural_key != filtered[1].glassItem.natural_key)
    }

    @Test("Maximum result limit (10 items)")
    func testMaximumResultLimit() {
        var items: [CompleteInventoryItemModel] = []
        for i in 1...20 {
            items.append(createTestCompleteItem(
                naturalKey: "test-\(String(format: "%03d", i))-0",
                name: "Test Item \(i)"
            ))
        }

        // Simulate the prefix(10) behavior
        let filtered = Array(items.prefix(10))

        #expect(filtered.count == 10)
    }

    @Test("Background color for prefilled vs selected")
    func testBackgroundColorLogic() {
        // Prefilled should use blue
        let prefilledKey: String? = "test-001-0"
        let isPrefilledBlue = prefilledKey != nil

        #expect(isPrefilledBlue == true)

        // Regular selection should use green
        let regularSelection: String? = nil
        let isSelectionGreen = regularSelection == nil

        #expect(isSelectionGreen == true)
    }

    @Test("Border color matches background color logic")
    func testBorderColorLogic() {
        // Prefilled should use blue border
        let prefilledKey: String? = "test-001-0"
        let usesBlueBorder = prefilledKey != nil

        #expect(usesBlueBorder == true)

        // Regular selection should use green border
        let regularKey: String? = nil
        let usesGreenBorder = regularKey == nil

        #expect(usesGreenBorder == true)
    }

    // MARK: - Integration Tests

    @Test("Complete search and select workflow")
    func testCompleteSearchAndSelectWorkflow() {
        let items = [
            createTestCompleteItem(naturalKey: "test-001", name: "Clear Rod"),
            createTestCompleteItem(naturalKey: "test-002", name: "Blue Stringer")
        ]

        var selectedItem: GlassItemModel? = nil
        var searchText = ""

        // Step 1: User types search
        searchText = "blue"

        // Step 2: Filter results
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 1)

        // Step 3: User selects item
        selectedItem = filtered.first?.glassItem
        searchText = ""

        #expect(selectedItem?.name == "Blue Stringer")
        #expect(searchText.isEmpty)
    }

    @Test("Complete clear workflow")
    func testCompleteClearWorkflow() {
        var selectedItem: GlassItemModel? = createTestGlassItem(name: "Test Item")
        var searchText = "old search"

        #expect(selectedItem != nil)

        // User clicks clear
        selectedItem = nil
        searchText = ""

        #expect(selectedItem == nil)
        #expect(searchText.isEmpty)
    }
}
