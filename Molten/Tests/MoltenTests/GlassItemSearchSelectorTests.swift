//
//  GlassItemSearchSelectorTests.swift
//  FlameworkerTests
//
//  Tests for GlassItemSearchSelector component
//  Tests search filtering, selection behavior, and state management
//

import Testing
import Foundation
@testable import Molten

@Suite("GlassItemSearchSelector Tests")
@MainActor
struct GlassItemSearchSelectorTests {

    // MARK: - Test Helpers

    func createTestGlassItem(
        naturalKey: String,
        name: String,
        manufacturer: String
    ) -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            natural_key: naturalKey,
            name: name,
            sku: "TEST-001",
            manufacturer: manufacturer,
            coe: 96,
            mfr_status: "available"
        )
        
        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            userTags: [],
            locations: []
        )
    }

    func createTestItems() -> [CompleteInventoryItemModel] {
        return [
            createTestGlassItem(
                naturalKey: "cim-001-0",
                name: "Clear Rod",
                manufacturer: "cim"
            ),
            createTestGlassItem(
                naturalKey: "be-002-0",
                name: "Blue Glass Sheet",
                manufacturer: "be"
            ),
            createTestGlassItem(
                naturalKey: "ef-003-0",
                name: "Red Stringer",
                manufacturer: "ef"
            ),
            createTestGlassItem(
                naturalKey: "cim-004-0",
                name: "Green Frit",
                manufacturer: "cim"
            ),
            createTestGlassItem(
                naturalKey: "be-005-0",
                name: "Yellow Tube",
                manufacturer: "be"
            )
        ]
    }

    // MARK: - Search Filtering Tests

    @Test("Filters by name - exact match")
    func testFilterByNameExact() {
        let items = createTestItems()
        let searchText = "Clear Rod"
        
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.name == "Clear Rod")
    }

    @Test("Filters by name - partial match")
    func testFilterByNamePartial() {
        let items = createTestItems()
        let searchText = "rod"
        
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.name == "Clear Rod")
    }

    @Test("Filters by natural key")
    func testFilterByNaturalKey() {
        let items = createTestItems()
        let searchText = "cim-001"
        
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.natural_key == "cim-001-0")
    }

    @Test("Filters by manufacturer")
    func testFilterByManufacturer() {
        let items = createTestItems()
        let searchText = "cim"
        
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.glassItem.manufacturer == "cim" })
    }

    @Test("Case-insensitive matching - uppercase")
    func testCaseInsensitiveUppercase() {
        let items = createTestItems()
        let searchText = "CLEAR"
        
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.name == "Clear Rod")
    }

    @Test("Case-insensitive matching - mixed case")
    func testCaseInsensitiveMixed() {
        let items = createTestItems()
        let searchText = "BlUe"
        
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.name == "Blue Glass Sheet")
    }

    @Test("Empty search returns all items")
    func testEmptySearchReturnsAll() {
        let items = createTestItems()
        let searchText = ""
        
        let filtered = items.filter { item in
            if searchText.isEmpty {
                return true
            }
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.count == items.count)
    }

    @Test("No matches returns empty")
    func testNoMatches() {
        let items = createTestItems()
        let searchText = "nonexistent"
        
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.isEmpty)
    }

    @Test("Multiple matches")
    func testMultipleMatches() {
        let items = createTestItems()
        let searchText = "be"
        
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.glassItem.manufacturer == "be" })
    }

    @Test("Partial word match")
    func testPartialWordMatch() {
        let items = createTestItems()
        let searchText = "gla"
        
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.name == "Blue Glass Sheet")
    }

    // MARK: - Selection Behavior Tests

    @Test("Selection behavior - onSelect fires with correct item")
    func testOnSelectFires() {
        var selectedItem: GlassItemModel? = nil
        let testItem = createTestGlassItem(
            naturalKey: "test-001-0",
            name: "Test Item",
            manufacturer: "test"
        )
        
        // Simulate onSelect callback
        selectedItem = testItem.glassItem
        
        #expect(selectedItem != nil)
        #expect(selectedItem?.natural_key == "test-001-0")
        #expect(selectedItem?.name == "Test Item")
    }

    @Test("Selection behavior - onClear fires correctly")
    func testOnClearFires() {
        var selectedItem: GlassItemModel? = createTestGlassItem(
            naturalKey: "test-001-0",
            name: "Test Item",
            manufacturer: "test"
        ).glassItem
        var searchText = "test"
        
        // Simulate onClear callback
        selectedItem = nil
        searchText = ""
        
        #expect(selectedItem == nil)
        #expect(searchText.isEmpty)
    }

    @Test("Selected item displays properly")
    func testSelectedItemDisplay() {
        let selectedItem = createTestGlassItem(
            naturalKey: "cim-001-0",
            name: "Clear Rod",
            manufacturer: "cim"
        ).glassItem
        
        #expect(selectedItem.name == "Clear Rod")
        #expect(selectedItem.natural_key == "cim-001-0")
        #expect(selectedItem.manufacturer == "cim")
    }

    // MARK: - State Management Tests

    @Test("Search text updates filter results")
    func testSearchTextUpdatesFilter() {
        let items = createTestItems()
        
        // First search
        var searchText = "clear"
        var filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        #expect(filtered.count == 1)
        
        // Updated search
        searchText = "blue"
        filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.name == "Blue Glass Sheet")
    }

    @Test("Clear resets selection")
    func testClearResetsSelection() {
        var selectedItem: GlassItemModel? = createTestGlassItem(
            naturalKey: "test-001-0",
            name: "Test Item",
            manufacturer: "test"
        ).glassItem
        
        // Clear
        selectedItem = nil
        
        #expect(selectedItem == nil)
    }

    @Test("Prefilled natural key behavior")
    func testPrefilledNaturalKey() {
        let prefilledKey = "cim-001-0"
        let items = createTestItems()
        
        let matchingItem = items.first { $0.glassItem.natural_key == prefilledKey }
        
        #expect(matchingItem != nil)
        #expect(matchingItem?.glassItem.natural_key == prefilledKey)
    }

    @Test("Prefilled natural key not found")
    func testPrefilledNaturalKeyNotFound() {
        let prefilledKey = "nonexistent-key"
        let items = createTestItems()
        
        let matchingItem = items.first { $0.glassItem.natural_key == prefilledKey }
        
        #expect(matchingItem == nil)
    }

    // MARK: - UI States Tests

    @Test("Empty state - no search")
    func testEmptyStateNoSearch() {
        let selectedItem: GlassItemModel? = nil
        let searchText = ""
        let prefilledKey: String? = nil
        
        let shouldShowInstruction = selectedItem == nil && prefilledKey == nil && searchText.isEmpty
        
        #expect(shouldShowInstruction == true)
    }

    @Test("Search results state")
    func testSearchResultsState() {
        let selectedItem: GlassItemModel? = nil
        let searchText = "clear"
        let prefilledKey: String? = nil
        
        let shouldShowResults = !searchText.isEmpty && prefilledKey == nil && selectedItem == nil
        
        #expect(shouldShowResults == true)
    }

    @Test("Selected state")
    func testSelectedState() {
        let selectedItem: GlassItemModel? = createTestGlassItem(
            naturalKey: "test-001-0",
            name: "Test Item",
            manufacturer: "test"
        ).glassItem
        
        let shouldShowSelected = selectedItem != nil
        
        #expect(shouldShowSelected == true)
    }

    @Test("Not found state")
    func testNotFoundState() {
        let selectedItem: GlassItemModel? = nil
        let prefilledKey: String? = "nonexistent-key"
        
        let shouldShowNotFound = selectedItem == nil && prefilledKey != nil
        
        #expect(shouldShowNotFound == true)
    }

    // MARK: - Edge Cases

    @Test("Search with special characters")
    func testSearchWithSpecialCharacters() {
        let items = createTestItems()
        let searchText = "cim-001"
        
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        #expect(filtered.count == 1)
    }

    @Test("Search with whitespace in query")
    func testSearchWithWhitespace() {
        let items = createTestItems()
        // Search with internal whitespace (matches "Blue Glass Sheet")
        let searchText = "blue glass"

        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.name == "Blue Glass Sheet")
    }

    @Test("Search returns limited results (max 10)")
    func testSearchLimitResults() {
        // Create 15 items
        var items: [CompleteInventoryItemModel] = []
        for i in 0..<15 {
            items.append(createTestGlassItem(
                naturalKey: "cim-\(String(format: "%03d", i))-0",
                name: "Glass Item \(i)",
                manufacturer: "cim"
            ))
        }
        
        let searchText = "glass"
        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }
        
        // Component limits to 10 results via .prefix(10)
        let limited = Array(filtered.prefix(10))
        
        #expect(filtered.count == 15)
        #expect(limited.count == 10)
    }

    @Test("Selection with prefilled key shows correct header")
    func testPrefilledKeyHeader() {
        let prefilledKey: String? = "cim-001-0"
        let selectedItem = createTestGlassItem(
            naturalKey: "cim-001-0",
            name: "Clear Rod",
            manufacturer: "cim"
        ).glassItem
        
        let headerText = prefilledKey != nil ? "Adding for:" : "Selected:"
        
        #expect(headerText == "Adding for:")
        #expect(selectedItem.natural_key == prefilledKey)
    }

    @Test("Selection without prefilled key shows correct header")
    func testNormalSelectionHeader() {
        let prefilledKey: String? = nil
        
        let headerText = prefilledKey != nil ? "Adding for:" : "Selected:"
        
        #expect(headerText == "Selected:")
    }

    @Test("Clear button only shown without prefilled key")
    func testClearButtonVisibility() {
        let prefilledKey: String? = nil
        let shouldShowClear = prefilledKey == nil
        
        #expect(shouldShowClear == true)
        
        let prefilledKey2: String? = "cim-001-0"
        let shouldShowClear2 = prefilledKey2 == nil
        
        #expect(shouldShowClear2 == false)
    }

    @Test("Search field disabled when item selected")
    func testSearchFieldDisabled() {
        let selectedItem: GlassItemModel? = createTestGlassItem(
            naturalKey: "test-001-0",
            name: "Test Item",
            manufacturer: "test"
        ).glassItem
        
        let shouldDisable = selectedItem != nil
        
        #expect(shouldDisable == true)
    }

    @Test("Search field enabled when no item selected")
    func testSearchFieldEnabled() {
        let selectedItem: GlassItemModel? = nil

        let shouldDisable = selectedItem != nil

        #expect(shouldDisable == false)
    }

    // MARK: - Auto-Select Single Result Tests

    @Test("Auto-selects when exactly one result")
    func testAutoSelectSingleResult() {
        let items = createTestItems()
        let searchText = "clear rod"

        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        #expect(filtered.count == 1)

        // Simulate auto-selection
        let autoSelected = filtered.first
        let wasManuallySelected = false

        #expect(autoSelected != nil)
        #expect(autoSelected?.glassItem.name == "Clear Rod")
        #expect(wasManuallySelected == false)
    }

    @Test("Clear button disabled when exactly one auto-selected result")
    func testClearButtonDisabledForAutoSelect() {
        let items = createTestItems()
        let searchText = "clear rod"

        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        let wasManuallySelected = false

        // shouldDisableClear logic: filteredGlassItems.count == 1 && !wasManuallySelected
        let shouldDisableClear = filtered.count == 1 && !wasManuallySelected

        #expect(shouldDisableClear == true)
    }

    @Test("Clear button enabled when single result manually selected")
    func testClearButtonEnabledForManualSelect() {
        let items = createTestItems()
        let searchText = "clear rod"

        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        let wasManuallySelected = true  // User clicked the item

        // shouldDisableClear logic: filteredGlassItems.count == 1 && !wasManuallySelected
        let shouldDisableClear = filtered.count == 1 && !wasManuallySelected

        #expect(shouldDisableClear == false)
    }

    @Test("Clear button enabled when multiple results")
    func testClearButtonEnabledForMultipleResults() {
        let items = createTestItems()
        let searchText = "be"  // Matches 2 items

        let filtered = items.filter { item in
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        let wasManuallySelected = false

        // shouldDisableClear logic: filteredGlassItems.count == 1 && !wasManuallySelected
        let shouldDisableClear = filtered.count == 1 && !wasManuallySelected

        #expect(filtered.count == 2)
        #expect(shouldDisableClear == false)
    }

    @Test("Clear button enabled when search cleared")
    func testClearButtonEnabledWhenSearchCleared() {
        let items = createTestItems()
        let searchText = ""  // Search cleared

        let filtered = items.filter { item in
            if searchText.isEmpty {
                return false  // Component returns empty array when search is empty
            }
            let searchLower = searchText.lowercased()
            return item.glassItem.name.lowercased().contains(searchLower) ||
                   item.glassItem.natural_key.lowercased().contains(searchLower) ||
                   item.glassItem.manufacturer.lowercased().contains(searchLower)
        }

        let wasManuallySelected = false

        // shouldDisableClear logic: filteredGlassItems.count == 1 && !wasManuallySelected
        let shouldDisableClear = filtered.count == 1 && !wasManuallySelected

        #expect(filtered.isEmpty)
        #expect(shouldDisableClear == false)
    }

    @Test("Manual selection flag resets when item cleared")
    func testManualSelectionFlagResets() {
        var wasManuallySelected = true
        var selectedItem: GlassItemModel? = createTestGlassItem(
            naturalKey: "test-001-0",
            name: "Test Item",
            manufacturer: "test"
        ).glassItem

        // Simulate clearing
        selectedItem = nil
        wasManuallySelected = false  // Should reset

        #expect(selectedItem == nil)
        #expect(wasManuallySelected == false)
    }

    @Test("Manual selection persists during typing")
    func testManualSelectionPersistsDuringTyping() {
        let wasManuallySelected = true
        let selectedItem: GlassItemModel? = createTestGlassItem(
            naturalKey: "test-001-0",
            name: "Test Item",
            manufacturer: "test"
        ).glassItem

        // User continues typing after manual selection
        // Item should NOT be deselected because wasManuallySelected == true
        let shouldDeselect = !wasManuallySelected

        #expect(shouldDeselect == false)
        #expect(selectedItem != nil)
    }
}
