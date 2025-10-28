//
//  ShoppingListViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Tests for ShoppingListViewModel presentation logic
//

import Foundation
import Testing
@testable import Molten

/// Tests for ShoppingListViewModel presentation logic
///
/// Tests cover: loading, filtering, searching, sorting, CRUD operations
@Suite("ShoppingListViewModel Tests")
struct ShoppingListViewModelTests {

    // MARK: - Loading Tests

    @Test("Should load shopping list items") @MainActor
    func testLoadItems() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.shoppingListScenario)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )

        // Act
        await viewModel.loadItems()

        // Assert
        #expect(viewModel.items.count >= 1)
        #expect(viewModel.isLoading == false)
    }

    @Test("Should set loading state during fetch") @MainActor
    func testLoadingState() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.empty)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )

        // Assert initial state
        #expect(viewModel.isLoading == false)

        // Act
        await viewModel.loadItems()

        // Assert final state
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Search Tests

    @Test("Should filter items by search text") @MainActor
    func testSearchFilter() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black", coe: 90)
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .withMinimum(manufacturer: "bullseye", sku: "100", minimum: 5.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        // Act
        viewModel.searchText = "Clear"

        // Assert
        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.glassItem.name == "Clear")
    }

    @Test("Should search in titles only when enabled") @MainActor
    func testSearchTitlesOnly() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod", coe: 90)
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        // Act - search in titles only
        viewModel.searchTitlesOnly = true
        viewModel.searchText = "Clear"

        // Assert
        #expect(viewModel.filteredItems.count == 1)
    }

    @Test("Should clear search") @MainActor
    func testClearSearch() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.shoppingListScenario)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()
        viewModel.searchText = "test query"

        // Act
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.searchText.isEmpty)
    }

    // MARK: - Filter Tests

    @Test("Should filter by manufacturer") @MainActor
    func testFilterByManufacturer() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .withMinimum(manufacturer: "cim", sku: "001", minimum: 5.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        // Act
        viewModel.selectedManufacturers = ["bullseye"]

        // Assert
        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.glassItem.manufacturer == "bullseye")
    }

    @Test("Should filter by COE") @MainActor
    func testFilterByCOE() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .withMinimum(manufacturer: "cim", sku: "001", minimum: 5.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        // Act
        viewModel.selectedCOEs = [90]

        // Assert
        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.glassItem.coe == 90)
    }

    @Test("Should filter by tags") @MainActor
    func testFilterByTags() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent", "coe90"])
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        // Act
        viewModel.selectedTags = ["transparent"]

        // Assert
        #expect(viewModel.filteredItems.count == 1)
    }

    // MARK: - Sorting Tests

    @Test("Should sort by name") @MainActor
    func testSortByName() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Zebra", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "002", name: "Apple", coe: 90)
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .withMinimum(manufacturer: "bullseye", sku: "002", minimum: 5.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        // Act
        viewModel.sortOption = .name

        // Assert
        #expect(viewModel.sortedFilteredItems.first?.glassItem.name == "Apple")
        #expect(viewModel.sortedFilteredItems.last?.glassItem.name == "Zebra")
    }

    @Test("Should sort by needed quantity") @MainActor
    func testSortByNeededQuantity() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Item A", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "002", name: "Item B", coe: 90)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 2.0, type: "rod")
            .withInventory(manufacturer: "bullseye", sku: "002", quantity: 8.0, type: "rod")
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .withMinimum(manufacturer: "bullseye", sku: "002", minimum: 10.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        // Act
        viewModel.sortOption = .neededQuantity

        // Assert
        // Item A needs 8 units (10 min - 2 current), Item B needs 2 units (10 min - 8 current)
        // Descending order, so Item A (needs more) should come first
        #expect(viewModel.sortedFilteredItems.first?.glassItem.name == "Item A")
    }

    @Test("Should sort by manufacturer") @MainActor
    func testSortByManufacturer() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "zimmerman", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withMinimum(manufacturer: "zimmerman", sku: "001", minimum: 10.0)
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 5.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        // Act
        viewModel.sortOption = .manufacturer

        // Assert
        #expect(viewModel.sortedFilteredItems.first?.glassItem.manufacturer == "bullseye")
        #expect(viewModel.sortedFilteredItems.last?.glassItem.manufacturer == "zimmerman")
    }

    // MARK: - CRUD Operations Tests

    @Test("Should update minimum quantity") @MainActor
    func testUpdateMinimum() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        let item = viewModel.items.first!

        // Act
        await viewModel.updateMinimum(for: item.glassItem.stable_id, newMinimum: 20.0)

        // Assert - reload to verify persistence
        await viewModel.loadItems()
        let updatedItem = viewModel.items.first { $0.glassItem.stable_id == item.glassItem.stable_id }
        #expect(updatedItem?.minimumQuantity == 20.0)
    }

    @Test("Should delete minimum") @MainActor
    func testDeleteMinimum() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        let initialCount = viewModel.items.count
        let item = viewModel.items.first!

        // Act
        await viewModel.deleteMinimum(for: item.glassItem.stable_id)

        // Assert
        await viewModel.loadItems()
        #expect(viewModel.items.count == initialCount - 1)
    }

    // MARK: - Computed Properties Tests

    @Test("Should compute available manufacturers") @MainActor
    func testAvailableManufacturers() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .withMinimum(manufacturer: "cim", sku: "001", minimum: 5.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

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
            .withMinimum(manufacturer: "bullseye", sku: "001", minimum: 10.0)
            .withMinimum(manufacturer: "cim", sku: "001", minimum: 5.0)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        // Assert
        #expect(viewModel.availableCOEs.count == 2)
        #expect(viewModel.availableCOEs.contains(90))
        #expect(viewModel.availableCOEs.contains(104))
    }

    @Test("Should detect active filters") @MainActor
    func testHasActiveFilters() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.shoppingListScenario)
            .build()

        let viewModel = ShoppingListViewModel(
            shoppingListService: builder.shoppingListService,
            catalogService: builder.catalogService
        )
        await viewModel.loadItems()

        // Assert initial state
        #expect(viewModel.hasActiveFilters == false)

        // Act - add filter
        viewModel.searchText = "test"

        // Assert
        #expect(viewModel.hasActiveFilters == true)

        // Act - clear filters
        viewModel.clearSearch()

        // Assert
        #expect(viewModel.hasActiveFilters == false)
    }
}
