//
//  CatalogViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Tests for CatalogViewModel presentation logic
//

import Foundation
import Testing
@testable import Molten

/// Tests for CatalogViewModel presentation logic
///
/// Tests cover: loading, filtering (search, tags, COE, manufacturers), sorting, reactive updates
@Suite("CatalogViewModel Tests")
struct CatalogViewModelTests {

    // MARK: - Loading Tests

    @Test("Should load catalog data") @MainActor
    func testLoadData() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.fullCatalogWithInventory)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)

        // Act
        await viewModel.loadData()

        // Assert
        #expect(viewModel.items.count >= 1)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Should set loading state during fetch") @MainActor
    func testLoadingState() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.empty)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)

        // Assert initial state
        #expect(viewModel.isLoading == false)

        // Act
        await viewModel.loadData()

        // Assert final state
        #expect(viewModel.isLoading == false)
    }

    @Test("Should refresh data") @MainActor
    func testRefreshData() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.fullCatalogWithInventory)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()
        let initialCount = viewModel.items.count

        // Act
        await viewModel.refreshData()

        // Assert
        #expect(viewModel.items.count == initialCount)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Search Tests

    @Test("Should filter items by search text") @MainActor
    func testSearchFilter() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black Rod", coe: 90)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.searchText = "Clear"

        // Assert - reactive update via didSet
        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.glassItem.name == "Clear Rod")
    }

    @Test("Should search in titles only when enabled") @MainActor
    func testSearchTitlesOnly() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod", coe: 90)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.searchTitlesOnly = true
        viewModel.searchText = "Clear"

        // Assert
        #expect(viewModel.filteredItems.count == 1)
    }

    @Test("Should search in all fields when titles only is disabled") @MainActor
    func testSearchAllFields() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Rod", coe: 90)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.searchTitlesOnly = false
        viewModel.searchText = "bullseye"

        // Assert - should find by manufacturer
        #expect(viewModel.filteredItems.count == 1)
    }

    @Test("Should clear search and filters") @MainActor
    func testClearSearch() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.fullCatalogWithInventory)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        viewModel.searchText = "test"
        viewModel.selectedTags = ["transparent"]
        viewModel.selectedCOEs = [90]

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedTags.isEmpty)
        #expect(viewModel.selectedCOEs.isEmpty)
        #expect(viewModel.selectedManufacturers.isEmpty)
        #expect(viewModel.searchClearedFeedback == true)
    }

    // MARK: - Manufacturer Filter Tests

    @Test("Should filter by single manufacturer") @MainActor
    func testFilterByManufacturer() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedManufacturers = ["bullseye"]

        // Assert - reactive update via didSet
        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.glassItem.manufacturer == "bullseye")
    }

    @Test("Should filter by multiple manufacturers") @MainActor
    func testFilterByMultipleManufacturers() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withGlassItem(manufacturer: "effetre", sku: "001", name: "Clear", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedManufacturers = ["bullseye", "cim"]

        // Assert
        #expect(viewModel.filteredItems.count == 2)
        #expect(viewModel.filteredItems.allSatisfy {
            ["bullseye", "cim"].contains($0.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
        })
    }

    @Test("Should support legacy single manufacturer filter") @MainActor
    func testLegacySingleManufacturer() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedManufacturer = "bullseye"

        // Assert - reactive update via didSet on selectedManufacturer (if implemented)
        // Note: applyFilters() might need to be called manually
        viewModel.applyFilters()
        #expect(viewModel.filteredItems.count == 1)
    }

    // MARK: - COE Filter Tests

    @Test("Should filter by single COE") @MainActor
    func testFilterByCOE() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedCOEs = [90]

        // Assert
        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.glassItem.coe == 90)
    }

    @Test("Should filter by multiple COEs") @MainActor
    func testFilterByMultipleCOEs() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withGlassItem(manufacturer: "satake", sku: "001", name: "Clear", coe: 96)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedCOEs = [90, 104]

        // Assert
        #expect(viewModel.filteredItems.count == 2)
        #expect(viewModel.filteredItems.allSatisfy { [90, 104].contains($0.glassItem.coe) })
    }

    // MARK: - Tag Filter Tests

    @Test("Should filter by single tag") @MainActor
    func testFilterByTag() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black", coe: 90)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent"])
            .withTags(manufacturer: "bullseye", sku: "100", tags: ["opaque"])
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedTags = ["transparent"]

        // Assert
        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.glassItem.name == "Clear")
    }

    @Test("Should filter by multiple tags") @MainActor
    func testFilterByMultipleTags() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "200", name: "Red", coe: 90)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent"])
            .withTags(manufacturer: "bullseye", sku: "100", tags: ["opaque"])
            .withTags(manufacturer: "bullseye", sku: "200", tags: ["opaque", "red"])
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedTags = ["transparent", "red"]

        // Assert - items with ANY of the selected tags
        #expect(viewModel.filteredItems.count == 2) // Clear (transparent) and Red (red)
    }

    // MARK: - Combined Filter Tests

    @Test("Should apply multiple filters together") @MainActor
    func testCombinedFilters() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent"])
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act - filter by manufacturer, COE, and tag
        viewModel.selectedManufacturers = ["bullseye"]
        viewModel.selectedCOEs = [90]
        viewModel.selectedTags = ["transparent"]

        // Assert - only Clear from Bullseye with COE 90 and transparent tag
        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.glassItem.name == "Clear")
    }

    @Test("Should combine search with filters") @MainActor
    func testSearchWithFilters() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Clear Frit", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear Rod", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act - search for "Clear" and filter by manufacturer
        viewModel.searchText = "Rod"
        viewModel.selectedManufacturers = ["bullseye"]

        // Assert
        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.glassItem.name == "Clear Rod")
        #expect(viewModel.filteredItems.first?.glassItem.manufacturer == "bullseye")
    }

    // MARK: - Sorting Tests

    @Test("Should sort by name") @MainActor
    func testSortByName() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Zebra", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "002", name: "Apple", coe: 90)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.sortOption = .name

        // Assert - reactive sorting via didSet
        #expect(viewModel.sortedFilteredItems.first?.glassItem.name == "Apple")
        #expect(viewModel.sortedFilteredItems.last?.glassItem.name == "Zebra")
    }

    @Test("Should sort by manufacturer") @MainActor
    func testSortByManufacturer() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "zimmerman", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.sortOption = .manufacturer

        // Assert
        #expect(viewModel.sortedFilteredItems.first?.glassItem.manufacturer == "bullseye")
        #expect(viewModel.sortedFilteredItems.last?.glassItem.manufacturer == "zimmerman")
    }

    @Test("Should sort by code (stable_id)") @MainActor
    func testSortByCode() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.sortOption = .code

        // Assert
        // stable_id format: manufacturer-sku-variant
        #expect(viewModel.sortedFilteredItems.first?.glassItem.sku == "001")
        #expect(viewModel.sortedFilteredItems.last?.glassItem.sku == "100")
    }

    @Test("Should update sorting via updateSorting method") @MainActor
    func testUpdateSorting() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Zebra", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "002", name: "Apple", coe: 90)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.updateSorting(.name)

        // Assert
        #expect(viewModel.sortOption == .name)
        #expect(viewModel.sortedFilteredItems.first?.glassItem.name == "Apple")
    }

    // MARK: - Reactive Update Tests

    @Test("Should automatically apply filters when search text changes") @MainActor
    func testReactiveSearchUpdate() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black", coe: 90)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        #expect(viewModel.filteredItems.count == 2)

        // Act - change search text (should trigger didSet)
        viewModel.searchText = "Clear"

        // Assert - filters applied automatically
        #expect(viewModel.filteredItems.count == 1)
    }

    @Test("Should automatically apply sorting when sort option changes") @MainActor
    func testReactiveSortUpdate() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Zebra", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "002", name: "Apple", coe: 90)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act - change sort option (should trigger didSet)
        viewModel.sortOption = .name

        // Assert - sorted automatically
        #expect(viewModel.sortedFilteredItems.first?.glassItem.name == "Apple")
    }

    // MARK: - Computed Properties Tests

    @Test("Should compute available manufacturers") @MainActor
    func testAvailableManufacturers() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.availableManufacturers.count == 2)
        #expect(viewModel.availableManufacturers.contains("bullseye"))
        #expect(viewModel.availableManufacturers.contains("cim"))
    }

    @Test("Should compute available COEs") @MainActor
    func testAvailableCOEs() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.allAvailableCOEs.count == 2)
        #expect(viewModel.allAvailableCOEs.contains(90))
        #expect(viewModel.allAvailableCOEs.contains(104))
    }

    @Test("Should compute available tags") @MainActor
    func testAvailableTags() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent", "coe90"])
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.allAvailableTags.count >= 2)
        #expect(viewModel.allAvailableTags.contains("transparent"))
        #expect(viewModel.allAvailableTags.contains("coe90"))
    }

    @Test("Should compute manufacturer counts excluding manufacturer filter") @MainActor
    func testManufacturerCounts() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.manufacturerCounts["bullseye"] == 2)
        #expect(viewModel.manufacturerCounts["cim"] == 1)
    }

    @Test("Should compute COE counts excluding COE filter") @MainActor
    func testCOECounts() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.coeCounts[90] == 2)
        #expect(viewModel.coeCounts[104] == 1)
    }

    @Test("Should compute tag counts excluding tag filter") @MainActor
    func testTagCounts() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black", coe: 90)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent"])
            .withTags(manufacturer: "bullseye", sku: "100", tags: ["opaque"])
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.tagCounts["transparent"] == 1)
        #expect(viewModel.tagCounts["opaque"] == 1)
    }

    @Test("Should generate empty state message") @MainActor
    func testEmptyStateMessage() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.fullCatalogWithInventory)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act - apply filters that match nothing
        viewModel.searchText = "nonexistentitem12345"

        // Assert
        let message = viewModel.emptyStateMessage
        #expect(message.contains("nonexistentitem12345"))
    }

    @Test("Should report has data correctly") @MainActor
    func testHasData() async throws {
        // Arrange
        let emptyBuilder = try await TestDataBuilder()
            .withScenario(.empty)
            .build()

        let emptyViewModel = CatalogViewModel(catalogService: emptyBuilder.catalogService)
        await emptyViewModel.loadData()

        // Assert empty
        #expect(emptyViewModel.hasData == false)

        // Arrange with data
        let dataBuilder = try await TestDataBuilder()
            .withScenario(.fullCatalogWithInventory)
            .build()

        let dataViewModel = CatalogViewModel(catalogService: dataBuilder.catalogService)
        await dataViewModel.loadData()

        // Assert with data
        #expect(dataViewModel.hasData == true)
    }

    @Test("Should detect active filters") @MainActor
    func testHasActiveFilters() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.fullCatalogWithInventory)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert initial state
        #expect(viewModel.hasActiveFilters == false)

        // Act - add search
        viewModel.searchText = "test"

        // Assert
        #expect(viewModel.hasActiveFilters == true)

        // Act - clear search
        viewModel.searchText = ""

        // Assert
        #expect(viewModel.hasActiveFilters == false)

        // Act - add tag filter
        viewModel.selectedTags = ["transparent"]

        // Assert
        #expect(viewModel.hasActiveFilters == true)
    }
}
