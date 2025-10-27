//
//  CatalogViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  TDD tests for CatalogViewModel - Protocol-based testability
//

import Foundation
import Testing
@testable import Molten

@Suite("CatalogViewModel Tests - Protocol-Based Design")
@MainActor
struct CatalogViewModelTests {

    // MARK: - Initialization Tests

    @Test("Should initialize with empty state")
    func testInitialization() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.empty)
            .build()

        // Act
        let viewModel = CatalogViewModel(catalogService: builder.catalogService)

        // Assert
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.filteredItems.isEmpty)
        #expect(viewModel.sortedFilteredItems.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedTags.isEmpty)
        #expect(viewModel.selectedCOEs.isEmpty)
        #expect(viewModel.selectedManufacturers.isEmpty)
        #expect(viewModel.sortOption == .name)
    }

    // MARK: - Data Loading Tests

    @Test("Should load catalog items successfully")
    func testLoadData() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)

        // Act
        await viewModel.loadData()

        // Assert
        #expect(viewModel.items.count == 3)
        #expect(viewModel.filteredItems.count == 3)
        #expect(viewModel.sortedFilteredItems.count == 3)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasData)
    }

    @Test("Should show loading state while loading")
    func testLoadingState() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)

        // Act - start loading (note: this will complete immediately with mocks)
        let loadTask = Task {
            await viewModel.loadData()
        }

        // Assert - after completion
        await loadTask.value
        #expect(!viewModel.isLoading)
    }

    @Test("Should load with full catalog data")
    func testLoadFullCatalog() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.fullCatalogWithInventory)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)

        // Act
        await viewModel.loadData()

        // Assert
        #expect(viewModel.items.count > 0)
        #expect(viewModel.filteredItems.count > 0)
        #expect(viewModel.hasData)
    }

    // MARK: - Search Tests

    @Test("Should filter by search text")
    func testSearchByText() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "254", name: "Red Rod", coe: 90)
            .withGlassItem(manufacturer: "spectrum", sku: "100", name: "Blue Sheet", coe: 96)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.searchText = "Clear"
        viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count >= 1)
        #expect(viewModel.filteredItems.contains { $0.glassItem.name.contains("Clear") })
    }

    @Test("Should filter by search text in all fields when searchTitlesOnly is false")
    func testSearchAllFields() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "special-001", name: "Red Rod", coe: 90)
            .withGlassItem(manufacturer: "spectrum", sku: "100", name: "Blue Sheet", coe: 96)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.searchTitlesOnly = false
        viewModel.searchText = "special"
        viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count >= 1)
        #expect(viewModel.filteredItems.contains { $0.glassItem.sku.contains("special") })
    }

    @Test("Should return all items when search text is empty")
    func testEmptySearch() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        let originalCount = viewModel.filteredItems.count

        // Act
        viewModel.searchText = ""
        viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count == originalCount)
    }

    // MARK: - Tag Filter Tests

    @Test("Should filter by single tag")
    func testFilterBySingleTag() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "254", name: "Red", coe: 90)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent"])
            .withTags(manufacturer: "bullseye", sku: "254", tags: ["opaque"])
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedTags = ["transparent"]
        viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count >= 1)
        #expect(viewModel.filteredItems.allSatisfy { item in
            item.allTags.contains("transparent")
        })
    }

    @Test("Should filter by multiple tags (OR logic)")
    func testFilterByMultipleTags() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "254", name: "Red", coe: 90)
            .withGlassItem(manufacturer: "spectrum", sku: "100", name: "Blue", coe: 96)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent"])
            .withTags(manufacturer: "bullseye", sku: "254", tags: ["opaque"])
            .withTags(manufacturer: "spectrum", sku: "100", tags: ["transparent"])
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedTags = ["transparent", "opaque"]
        viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count >= 2)
        #expect(viewModel.filteredItems.allSatisfy { item in
            !Set(item.allTags).isDisjoint(with: ["transparent", "opaque"])
        })
    }

    // MARK: - COE Filter Tests

    @Test("Should filter by single COE")
    func testFilterByCOE() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "spectrum", sku: "100", name: "Blue", coe: 96)
            .withGlassItem(manufacturer: "cim", sku: "874", name: "Adamantium", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedCOEs = [96]
        viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count >= 1)
        #expect(viewModel.filteredItems.allSatisfy { $0.glassItem.coe == 96 })
    }

    @Test("Should filter by multiple COEs")
    func testFilterByMultipleCOEs() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "spectrum", sku: "100", name: "Blue", coe: 96)
            .withGlassItem(manufacturer: "cim", sku: "874", name: "Adamantium", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedCOEs = [90, 96]
        viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count >= 2)
        #expect(viewModel.filteredItems.allSatisfy { [90, 96].contains($0.glassItem.coe) })
    }

    // MARK: - Manufacturer Filter Tests

    @Test("Should filter by single manufacturer")
    func testFilterByManufacturer() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.multiManufacturer)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedManufacturers = ["bullseye"]
        viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count >= 1)
        #expect(viewModel.filteredItems.allSatisfy { $0.glassItem.manufacturer == "bullseye" })
    }

    @Test("Should filter by multiple manufacturers")
    func testFilterByMultipleManufacturers() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.multiManufacturer)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.selectedManufacturers = ["bullseye", "spectrum"]
        viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count >= 2)
        #expect(viewModel.filteredItems.allSatisfy {
            ["bullseye", "spectrum"].contains($0.glassItem.manufacturer)
        })
    }

    // MARK: - Combined Filter Tests

    @Test("Should apply multiple filters together")
    func testCombinedFilters() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "254", name: "Red Rod", coe: 90)
            .withGlassItem(manufacturer: "spectrum", sku: "100", name: "Clear Sheet", coe: 96)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent"])
            .withTags(manufacturer: "spectrum", sku: "100", tags: ["transparent"])
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act - filter by COE 96 AND manufacturer bullseye (should be empty or limited)
        viewModel.selectedCOEs = [90]
        viewModel.selectedManufacturers = ["bullseye"]
        viewModel.selectedTags = ["transparent"]
        viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count >= 1)
        #expect(viewModel.filteredItems.allSatisfy { item in
            item.glassItem.coe == 90 &&
            item.glassItem.manufacturer == "bullseye" &&
            item.allTags.contains("transparent")
        })
    }

    // MARK: - Sort Tests

    @Test("Should sort by name")
    func testSortByName() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "003", name: "Zebra", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Apple", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "002", name: "Banana", coe: 90)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.sortOption = .name
        viewModel.applyFilters()

        // Assert
        let names = viewModel.sortedFilteredItems.map { $0.glassItem.name }
        #expect(names == names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    @Test("Should sort by manufacturer")
    func testSortByManufacturer() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "spectrum", sku: "001", name: "Item1", coe: 96)
            .withGlassItem(manufacturer: "bullseye", sku: "002", name: "Item2", coe: 90)
            .withGlassItem(manufacturer: "kokomo", sku: "003", name: "Item3", coe: 96)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Act
        viewModel.sortOption = .manufacturer
        viewModel.applyFilters()

        // Assert
        let manufacturers = viewModel.sortedFilteredItems.map { $0.glassItem.manufacturer }
        #expect(manufacturers == manufacturers.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    // MARK: - Computed Property Tests

    @Test("Should compute available tags correctly")
    func testAvailableTags() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "254", name: "Red", coe: 90)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent", "coe90"])
            .withTags(manufacturer: "bullseye", sku: "254", tags: ["opaque", "coe90"])
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.allAvailableTags.contains("transparent"))
        #expect(viewModel.allAvailableTags.contains("opaque"))
        #expect(viewModel.allAvailableTags.contains("coe90"))
        #expect(viewModel.allAvailableTags.sorted() == viewModel.allAvailableTags) // Should be sorted
    }

    @Test("Should compute available COEs correctly")
    func testAvailableCOEs() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "spectrum", sku: "100", name: "Blue", coe: 96)
            .withGlassItem(manufacturer: "cim", sku: "874", name: "Adamantium", coe: 104)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.allAvailableCOEs.contains(90))
        #expect(viewModel.allAvailableCOEs.contains(96))
        #expect(viewModel.allAvailableCOEs.contains(104))
        #expect(viewModel.allAvailableCOEs.sorted() == viewModel.allAvailableCOEs) // Should be sorted
    }

    @Test("Should compute available manufacturers correctly")
    func testAvailableManufacturers() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.multiManufacturer)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.availableManufacturers.contains("bullseye"))
        #expect(viewModel.availableManufacturers.contains("spectrum"))
        #expect(viewModel.availableManufacturers.contains("kokomo"))
        #expect(viewModel.availableManufacturers.contains("cim"))
    }

    @Test("Should compute manufacturer counts correctly")
    func testManufacturerCounts() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "254", name: "Red", coe: 90)
            .withGlassItem(manufacturer: "spectrum", sku: "100", name: "Blue", coe: 96)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.manufacturerCounts["bullseye"] == 2)
        #expect(viewModel.manufacturerCounts["spectrum"] == 1)
    }

    @Test("Should compute COE counts correctly")
    func testCOECounts() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "254", name: "Red", coe: 90)
            .withGlassItem(manufacturer: "spectrum", sku: "100", name: "Blue", coe: 96)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.coeCounts[90] == 2)
        #expect(viewModel.coeCounts[96] == 1)
    }

    @Test("Should compute tag counts correctly")
    func testTagCounts() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "254", name: "Red", coe: 90)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent", "coe90"])
            .withTags(manufacturer: "bullseye", sku: "254", tags: ["opaque", "coe90"])
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert
        #expect(viewModel.tagCounts["coe90"] == 2)
        #expect(viewModel.tagCounts["transparent"] == 1)
        #expect(viewModel.tagCounts["opaque"] == 1)
    }

    @Test("Should detect active filters")
    func testHasActiveFilters() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        // Assert - initially no filters
        #expect(!viewModel.hasActiveFilters)

        // Act - add search filter
        viewModel.searchText = "test"
        #expect(viewModel.hasActiveFilters)

        // Act - clear search, add tag filter
        viewModel.searchText = ""
        viewModel.selectedTags = ["transparent"]
        #expect(viewModel.hasActiveFilters)

        // Act - clear all filters
        viewModel.clearSearch()
        #expect(!viewModel.hasActiveFilters)
    }

    // MARK: - Clear Search Tests

    @Test("Should clear all search and filter criteria")
    func testClearSearch() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        viewModel.searchText = "test"
        viewModel.selectedTags = ["transparent"]
        viewModel.selectedCOEs = [96]
        viewModel.selectedManufacturers = ["bullseye"]

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedTags.isEmpty)
        #expect(viewModel.selectedCOEs.isEmpty)
        #expect(viewModel.selectedManufacturers.isEmpty)
        #expect(viewModel.searchClearedFeedback)
    }

    // MARK: - Empty State Message Tests

    @Test("Should generate correct empty state message for search")
    func testEmptyStateMessageWithSearch() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        viewModel.searchText = "nonexistent"
        viewModel.applyFilters()

        // Assert
        let message = viewModel.emptyStateMessage
        #expect(message.contains("nonexistent"))
    }

    @Test("Should generate correct empty state message for multiple filters")
    func testEmptyStateMessageWithMultipleFilters() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        viewModel.selectedTags = ["transparent"]
        viewModel.selectedCOEs = [96]
        viewModel.applyFilters()

        // Assert
        let message = viewModel.emptyStateMessage
        #expect(message.contains("tag") || message.contains("transparent"))
        #expect(message.contains("COE") || message.contains("96"))
    }

    // MARK: - Refresh Tests

    @Test("Should refresh data")
    func testRefreshData() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadData()

        let originalCount = viewModel.items.count

        // Act
        await viewModel.refreshData()

        // Assert
        #expect(viewModel.items.count == originalCount)
        #expect(!viewModel.isLoading)
    }
}
