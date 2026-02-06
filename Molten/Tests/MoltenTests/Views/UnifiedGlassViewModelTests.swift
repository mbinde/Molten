//
//  UnifiedGlassViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2/5/26.
//  Tests for UnifiedGlassViewModel filtering and quick filter logic
//

import Foundation
import Testing
@testable import Molten

@Suite("UnifiedGlassViewModel Tests")
@MainActor
struct UnifiedGlassViewModelTests {

    // MARK: - Setup/Teardown

    init() {
        // Clean UserDefaults before each test to prevent pollution
        let keys = [
            "unifiedGlass.quickFilter",
            "unifiedGlass.sortOption",
            "unifiedGlass.selectedProductTypes",
            "unifiedGlass.selectedCOEs",
            "unifiedGlass.selectedManufacturers",
            "unifiedGlass.searchTitlesOnly",
            "unifiedGlass.selectedLocations",
            "unifiedGlass.selectedStore"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
    }

    // MARK: - Helper Methods

    /// Create test glass item with optional inventory
    func createGlassItem(
        manufacturer: String,
        sku: String,
        name: String,
        coe: Int32 = 90,
        hasInventory: Bool = false,
        quantity: Double = 0,
        locations: [String] = []
    ) -> CompleteInventoryItemModel {
        let stableId = "\(manufacturer)-\(sku)-glass"
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: nil,
            coe: coe,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )
        let catalogItem = UnifiedCatalogItem(glassItem: glassItem)

        // Create inventory if specified
        var inventory: [InventoryModel] = []
        if hasInventory && quantity > 0 {
            let location = locations.first ?? "Default"
            inventory.append(InventoryModel(
                item_stable_id: stableId,
                type: "rod",
                quantity: quantity,
                location: location
            ))
        }

        return CompleteInventoryItemModel(
            catalogItem: catalogItem,
            inventory: inventory,
            tags: [],
            userTags: []
        )
    }

    /// Create a ViewModel for testing
    func createViewModel() -> UnifiedGlassViewModel {
        UnifiedGlassViewModel(
            catalogService: AppDependencies.shared.catalogService,
            shoppingListService: AppDependencies.shared.shoppingListService,
            inventoryTrackingService: AppDependencies.shared.inventoryTrackingService
        )
    }

    // MARK: - Quick Filter Tests

    @Test("Quick filter defaults to 'All'")
    func testQuickFilterDefaultsToAll() async throws {
        let viewModel = createViewModel()
        #expect(viewModel.quickFilter == .all, "Default quick filter should be 'All'")
    }

    @Test("Quick filter 'All' mode shows all items")
    func testAllModeShowsAllItems() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red", hasInventory: true, quantity: 5),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Blue", hasInventory: false),
            createGlassItem(manufacturer: "bullseye", sku: "003", name: "Green", hasInventory: true, quantity: 3)
        ]

        viewModel.quickFilter = .all
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 3, "All mode should show all 3 items")
    }

    @Test("Quick filter 'My Glass' mode shows only items with inventory")
    func testMyGlassModeShowsOnlyInventoryItems() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red", hasInventory: true, quantity: 5),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Blue", hasInventory: false),
            createGlassItem(manufacturer: "bullseye", sku: "003", name: "Green", hasInventory: true, quantity: 3)
        ]

        viewModel.quickFilter = .myGlass
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 2, "My Glass mode should show only 2 items with inventory")
        #expect(viewModel.filteredItems.allSatisfy { $0.hasInventory }, "All items should have inventory")
    }

    @Test("Quick filter persists across filter switches")
    func testQuickFilterPersistsWithFilters() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red", coe: 90, hasInventory: true, quantity: 5),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Blue", coe: 96, hasInventory: true, quantity: 3),
            createGlassItem(manufacturer: "spectrum", sku: "003", name: "Green", coe: 90, hasInventory: false)
        ]

        // Set a COE filter in All mode
        viewModel.quickFilter = .all
        viewModel.selectedCOEs = [90]
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 2, "Should show 2 COE 90 items in All mode")

        // Switch to My Glass mode - filter should persist
        viewModel.quickFilter = .myGlass
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 1, "Should show 1 COE 90 item in My Glass mode (only one has inventory)")
        #expect(viewModel.selectedCOEs.contains(90), "COE filter should persist")
    }

    // MARK: - Search Tests

    @Test("Search filters items by name")
    func testSearchFiltersByName() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red Opal"),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Blue Transparent"),
            createGlassItem(manufacturer: "bullseye", sku: "003", name: "Red Striker")
        ]

        viewModel.debouncedSearchText = "Red"
        viewModel.searchTitlesOnly = true
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 2, "Should show 2 items with 'Red' in name")
    }

    @Test("Search titles only ignores manufacturer")
    func testSearchTitlesOnlyIgnoresManufacturer() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear"),
            createGlassItem(manufacturer: "spectrum", sku: "002", name: "Clear")
        ]

        viewModel.debouncedSearchText = "bullseye"
        viewModel.searchTitlesOnly = true
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 0, "Should show 0 items when searching manufacturer with titles only")
    }

    @Test("Search all fields includes manufacturer")
    func testSearchAllFieldsIncludesManufacturer() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear"),
            createGlassItem(manufacturer: "spectrum", sku: "002", name: "Clear")
        ]

        viewModel.debouncedSearchText = "bullseye"
        viewModel.searchTitlesOnly = false
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 1, "Should show 1 item from bullseye")
    }

    // MARK: - Manufacturer Filter Tests

    @Test("Manufacturer filter shows only selected manufacturers")
    func testManufacturerFilter() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red"),
            createGlassItem(manufacturer: "spectrum", sku: "002", name: "Blue"),
            createGlassItem(manufacturer: "bullseye", sku: "003", name: "Green")
        ]

        viewModel.selectedManufacturers = ["bullseye"]
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 2, "Should show 2 bullseye items")
        #expect(viewModel.filteredItems.allSatisfy { $0.catalogItem.manufacturer == "bullseye" })
    }

    @Test("Multiple manufacturers filter shows union")
    func testMultipleManufacturersFilter() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red"),
            createGlassItem(manufacturer: "spectrum", sku: "002", name: "Blue"),
            createGlassItem(manufacturer: "effetre", sku: "003", name: "Green")
        ]

        viewModel.selectedManufacturers = ["bullseye", "spectrum"]
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 2, "Should show 2 items from bullseye and spectrum")
    }

    // MARK: - COE Filter Tests

    @Test("COE filter shows only selected COEs")
    func testCOEFilter() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red", coe: 90),
            createGlassItem(manufacturer: "effetre", sku: "002", name: "Blue", coe: 104),
            createGlassItem(manufacturer: "bullseye", sku: "003", name: "Green", coe: 90)
        ]

        viewModel.selectedCOEs = [90]
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 2, "Should show 2 COE 90 items")
    }

    @Test("Multiple COE filter shows union")
    func testMultipleCOEFilter() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red", coe: 90),
            createGlassItem(manufacturer: "effetre", sku: "002", name: "Blue", coe: 104),
            createGlassItem(manufacturer: "spectrum", sku: "003", name: "Green", coe: 96)
        ]

        viewModel.selectedCOEs = [90, 96]
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 2, "Should show 2 items with COE 90 or 96")
    }

    // MARK: - Combined Filter Tests

    @Test("Combined filters apply intersection logic")
    func testCombinedFilters() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red", coe: 90),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Blue", coe: 96),
            createGlassItem(manufacturer: "spectrum", sku: "003", name: "Green", coe: 90)
        ]

        // Filter: bullseye AND COE 90
        viewModel.selectedManufacturers = ["bullseye"]
        viewModel.selectedCOEs = [90]
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 1, "Should show 1 item (bullseye + COE 90)")
        #expect(viewModel.filteredItems.first?.catalogItem.name == "Red")
    }

    @Test("Combined filters work with quick filter")
    func testCombinedFiltersWithQuickFilter() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red", coe: 90, hasInventory: true, quantity: 5),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Blue", coe: 90, hasInventory: false),
            createGlassItem(manufacturer: "spectrum", sku: "003", name: "Green", coe: 90, hasInventory: true, quantity: 3)
        ]

        // Filter: My Glass + COE 90
        viewModel.quickFilter = .myGlass
        viewModel.selectedCOEs = [90]
        viewModel.applyFilters()

        #expect(viewModel.filteredItems.count == 2, "Should show 2 COE 90 items with inventory")
        #expect(viewModel.filteredItems.allSatisfy { $0.hasInventory })
    }

    // MARK: - Sort Tests

    @Test("Sort by name orders alphabetically")
    func testSortByName() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Zebra"),
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Alpha"),
            createGlassItem(manufacturer: "bullseye", sku: "003", name: "Middle")
        ]

        viewModel.sortOption = .name
        viewModel.applyFilters()

        #expect(viewModel.filteredItems[0].catalogItem.name == "Alpha")
        #expect(viewModel.filteredItems[1].catalogItem.name == "Middle")
        #expect(viewModel.filteredItems[2].catalogItem.name == "Zebra")
    }

    @Test("Sort by manufacturer orders alphabetically")
    func testSortByManufacturer() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "spectrum", sku: "001", name: "A"),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "B"),
            createGlassItem(manufacturer: "effetre", sku: "003", name: "C")
        ]

        viewModel.sortOption = .manufacturer
        viewModel.applyFilters()

        #expect(viewModel.filteredItems[0].catalogItem.manufacturer == "bullseye")
        #expect(viewModel.filteredItems[1].catalogItem.manufacturer == "effetre")
        #expect(viewModel.filteredItems[2].catalogItem.manufacturer == "spectrum")
    }

    @Test("Sort by quantity orders descending")
    func testSortByQuantity() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Low", hasInventory: true, quantity: 2),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "High", hasInventory: true, quantity: 10),
            createGlassItem(manufacturer: "bullseye", sku: "003", name: "Medium", hasInventory: true, quantity: 5)
        ]

        viewModel.sortOption = .quantity
        viewModel.applyFilters()

        #expect(viewModel.filteredItems[0].catalogItem.name == "High")
        #expect(viewModel.filteredItems[1].catalogItem.name == "Medium")
        #expect(viewModel.filteredItems[2].catalogItem.name == "Low")
    }

    // MARK: - Filter Count Tests

    @Test("Filter counts are computed correctly")
    func testFilterCounts() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red", coe: 90),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Blue", coe: 90),
            createGlassItem(manufacturer: "spectrum", sku: "003", name: "Green", coe: 96)
        ]

        viewModel.applyFilters()

        #expect(viewModel.manufacturerCounts["bullseye"] == 2)
        #expect(viewModel.manufacturerCounts["spectrum"] == 1)
        #expect(viewModel.coeCounts[90] == 2)
        #expect(viewModel.coeCounts[96] == 1)
    }

    @Test("Filter counts update based on quick filter")
    func testFilterCountsUpdateWithQuickFilter() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red", hasInventory: true, quantity: 5),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Blue", hasInventory: false),
            createGlassItem(manufacturer: "spectrum", sku: "003", name: "Green", hasInventory: true, quantity: 3)
        ]

        // All mode
        viewModel.quickFilter = .all
        viewModel.applyFilters()
        #expect(viewModel.manufacturerCounts["bullseye"] == 2)

        // My Glass mode - only count items with inventory
        viewModel.quickFilter = .myGlass
        viewModel.applyFilters()
        #expect(viewModel.manufacturerCounts["bullseye"] == 1, "Should only count bullseye item with inventory")
    }

    // MARK: - Clear Filters Tests

    @Test("Clear all filters resets state")
    func testClearAllFilters() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red")
        ]

        // Set various filters
        viewModel.selectedManufacturers = ["bullseye"]
        viewModel.selectedCOEs = [90]
        viewModel.debouncedSearchText = "test"

        // Clear all
        viewModel.clearAllFilters()

        #expect(viewModel.selectedManufacturers.isEmpty)
        #expect(viewModel.selectedCOEs.isEmpty)
        #expect(viewModel.debouncedSearchText.isEmpty)
    }

    // MARK: - Active Filter Detection Tests

    @Test("hasActiveFilters detects active filters")
    func testHasActiveFilters() async throws {
        let viewModel = createViewModel()

        #expect(!viewModel.hasActiveFilters, "Should have no active filters initially")

        viewModel.selectedManufacturers = ["bullseye"]
        #expect(viewModel.hasActiveFilters, "Should detect manufacturer filter")

        viewModel.selectedManufacturers = []
        viewModel.selectedCOEs = [90]
        #expect(viewModel.hasActiveFilters, "Should detect COE filter")
    }

    @Test("activeFilterCount returns correct count")
    func testActiveFilterCount() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.activeFilterCount == 0)

        viewModel.selectedManufacturers = ["bullseye"]
        #expect(viewModel.activeFilterCount == 1)

        viewModel.selectedCOEs = [90]
        #expect(viewModel.activeFilterCount == 2)
    }

    // MARK: - Inventory/Shopping List ID Sets Tests

    @Test("inventoryItemIds contains items with inventory")
    func testInventoryItemIds() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = [
            createGlassItem(manufacturer: "bullseye", sku: "001", name: "Red", hasInventory: true, quantity: 5),
            createGlassItem(manufacturer: "bullseye", sku: "002", name: "Blue", hasInventory: false),
            createGlassItem(manufacturer: "bullseye", sku: "003", name: "Green", hasInventory: true, quantity: 3)
        ]

        let inventoryIds = viewModel.inventoryItemIds

        #expect(inventoryIds.count == 2)
        #expect(inventoryIds.contains("bullseye-001-glass"))
        #expect(inventoryIds.contains("bullseye-003-glass"))
        #expect(!inventoryIds.contains("bullseye-002-glass"))
    }

    // MARK: - Empty State Message Tests

    @Test("Empty state message describes active filters")
    func testEmptyStateMessage() async throws {
        let viewModel = createViewModel()
        viewModel.allItems = []

        // No filters
        viewModel.quickFilter = .all
        viewModel.applyFilters()
        #expect(viewModel.emptyStateMessage.contains("catalog items"))

        // With quick filter
        viewModel.quickFilter = .myGlass
        viewModel.applyFilters()
        #expect(viewModel.emptyStateMessage.contains("inventory"))

        // With search
        viewModel.debouncedSearchText = "red"
        viewModel.applyFilters()
        #expect(viewModel.emptyStateMessage.contains("'red'"))
    }
}
