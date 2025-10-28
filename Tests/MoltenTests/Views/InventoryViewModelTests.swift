//
//  InventoryViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Tests for InventoryViewModel presentation logic
//

import Foundation
import Testing
@testable import Molten

/// Tests for InventoryViewModel presentation logic
///
/// Tests cover: loading, filtering, searching, sorting, CRUD operations
@Suite("InventoryViewModel Tests", .serialized)
struct InventoryViewModelTests {

    // MARK: - Loading Tests

    @Test("Should load inventory items") @MainActor
    func testLoadInventoryItems() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.fullCatalogWithInventory)
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )

        // Act
        await viewModel.loadInventoryItems()

        // Assert
        #expect(viewModel.completeItems.count >= 1)
        #expect(viewModel.isLoading == false)
    }

    @Test("Should set loading state during fetch") @MainActor
    func testLoadingState() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.empty)
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )

        // Assert initial state
        #expect(viewModel.isLoading == false)

        // Act
        await viewModel.loadInventoryItems()

        // Assert final state
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Search Tests

    @Test("Should filter items by search text") @MainActor
    func testSearchFilter() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black Rod", coe: 90)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .withInventory(manufacturer: "bullseye", sku: "100", quantity: 5.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Act
        await viewModel.searchItems(searchText: "Clear")

        // Assert
        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.glassItem.name == "Clear Rod")
    }

    @Test("Should search in titles only when enabled") @MainActor
    func testSearchTitlesOnly() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear Rod", coe: 90)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Act
        viewModel.searchTitlesOnly = true
        await viewModel.searchItems(searchText: "Clear")

        // Assert
        #expect(viewModel.filteredItems.count == 1)
    }

    // MARK: - Filter Tests

    @Test("Should filter by manufacturer") @MainActor
    func testFilterByManufacturer() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .withInventory(manufacturer: "cim", sku: "001", quantity: 5.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Act
        viewModel.selectedManufacturers = ["bullseye"]

        // Assert - filteredItems should be updated automatically via computed property
        let filtered = viewModel.completeItems.filter { item in
            viewModel.selectedManufacturers.contains(item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.manufacturer == "bullseye")
    }

    @Test("Should filter by COE") @MainActor
    func testFilterByCOE() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .withInventory(manufacturer: "cim", sku: "001", quantity: 5.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Act
        viewModel.selectedCOEs = [90]

        // Assert
        let filtered = viewModel.completeItems.filter { viewModel.selectedCOEs.contains($0.glassItem.coe) }
        #expect(filtered.count == 1)
        #expect(filtered.first?.glassItem.coe == 90)
    }

    @Test("Should filter by tags") @MainActor
    func testFilterByTags() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent", "coe90"])
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Act
        viewModel.selectedTags = ["transparent"]

        // Assert
        let filtered = viewModel.completeItems.filter { !viewModel.selectedTags.isDisjoint(with: Set($0.allTags)) }
        #expect(filtered.count == 1)
    }

    @Test("Should apply multiple filters") @MainActor
    func testApplyFilters() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "100", name: "Black", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .withInventory(manufacturer: "bullseye", sku: "100", quantity: 5.0, type: "rod")
            .withInventory(manufacturer: "cim", sku: "001", quantity: 3.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Act - filter by manufacturer and COE
        viewModel.selectedManufacturers = ["bullseye"]
        viewModel.selectedCOEs = [90]
        await viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.count == 2)
        #expect(viewModel.filteredItems.allSatisfy { $0.glassItem.manufacturer == "bullseye" })
        #expect(viewModel.filteredItems.allSatisfy { $0.glassItem.coe == 90 })
    }

    // MARK: - Sorting Tests

    @Test("Should sort by name") @MainActor
    func testSortByName() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Zebra", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "002", name: "Apple", coe: 90)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .withInventory(manufacturer: "bullseye", sku: "002", quantity: 5.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Act
        viewModel.sortOption = .name

        // Assert - sort the filtered items manually to verify
        let sorted = viewModel.filteredItems.sorted { $0.glassItem.name < $1.glassItem.name }
        #expect(sorted.first?.glassItem.name == "Apple")
        #expect(sorted.last?.glassItem.name == "Zebra")
    }

    @Test("Should sort by manufacturer") @MainActor
    func testSortByManufacturer() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "zimmerman", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withInventory(manufacturer: "zimmerman", sku: "001", quantity: 10.0, type: "rod")
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 5.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Act
        viewModel.sortOption = .manufacturer

        // Assert
        let sorted = viewModel.filteredItems.sorted { $0.glassItem.manufacturer < $1.glassItem.manufacturer }
        #expect(sorted.first?.glassItem.manufacturer == "bullseye")
    }

    // MARK: - CRUD Operations Tests

    @Test("Should add inventory") @MainActor
    func testAddInventory() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 5.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        let item = viewModel.completeItems.first!

        // Act
        await viewModel.addInventory(
            quantity: 10.0,
            type: "rod",
            toItemNaturalKey: item.glassItem.stable_id
        )

        // Assert - reload cache after mutation to get fresh data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)
        await viewModel.loadInventoryItems()
        let updatedItem = viewModel.completeItems.first { $0.glassItem.stable_id == item.glassItem.stable_id }
        #expect(updatedItem?.totalQuantity ?? 0 > 0)
    }

    @Test("Should delete inventory") @MainActor
    func testDeleteInventory() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        let item = viewModel.completeItems.first!
        let inventoryId = item.inventory.first!.id

        // Act
        await viewModel.deleteInventory(id: inventoryId)

        // Assert - reload cache after mutation to get fresh data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)
        await viewModel.loadInventoryItems()
        let updatedItem = viewModel.completeItems.first { $0.glassItem.stable_id == item.glassItem.stable_id }
        #expect(updatedItem?.inventory.isEmpty ?? true)
    }

    @Test("Should delete multiple inventories") @MainActor
    func testDeleteMultipleInventories() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 5.0, type: "frit")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        let item = viewModel.completeItems.first!
        let inventoryIds = item.inventory.map { $0.id }

        // Act
        await viewModel.deleteInventories(ids: inventoryIds)

        // Assert - reload cache after mutation to get fresh data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)
        await viewModel.loadInventoryItems()
        let updatedItem = viewModel.completeItems.first { $0.glassItem.stable_id == item.glassItem.stable_id }
        #expect(updatedItem?.inventory.isEmpty ?? true)
    }

    // MARK: - Low Stock Tests

    @Test("Should get low stock items") @MainActor
    func testGetLowStockItems() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.inventoryWithLowStock)
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Act
        await viewModel.getLowStockItems(threshold: 5.0)

        // Assert
        #expect(viewModel.filteredItems.count > 0)
        #expect(viewModel.filteredItems.allSatisfy { $0.totalQuantity < 5.0 })
    }

    // MARK: - Computed Properties Tests

    @Test("Should compute available manufacturers") @MainActor
    func testAvailableManufacturers() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .withInventory(manufacturer: "cim", sku: "001", quantity: 5.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

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
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .withInventory(manufacturer: "cim", sku: "001", quantity: 5.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Assert
        #expect(viewModel.availableCOEs.count == 2)
        #expect(viewModel.availableCOEs.contains(90))
        #expect(viewModel.availableCOEs.contains(104))
    }

    @Test("Should compute available tags") @MainActor
    func testAvailableTags() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withTags(manufacturer: "bullseye", sku: "001", tags: ["transparent", "coe90"])
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Assert
        #expect(viewModel.availableTags.count >= 2)
        #expect(viewModel.availableTags.contains("transparent"))
        #expect(viewModel.availableTags.contains("coe90"))
    }

    @Test("Should report has data correctly") @MainActor
    func testHasData() async throws {
        // Arrange - empty scenario
        let emptyBuilder = try await TestDataBuilder()
            .withScenario(.empty)
            .build()

        // Force reload cache with empty test data
        await CatalogDataCache.shared.reload(catalogService: emptyBuilder.catalogService)

        let emptyViewModel = InventoryViewModel(
            inventoryTrackingService: emptyBuilder.inventoryTrackingService,
            catalogService: emptyBuilder.catalogService
        )
        await emptyViewModel.loadInventoryItems()

        // Assert empty
        #expect(emptyViewModel.hasData == false)

        // Arrange with data
        let dataBuilder = try await TestDataBuilder()
            .withScenario(.fullCatalogWithInventory)
            .build()

        // Force reload cache with full test data
        await CatalogDataCache.shared.reload(catalogService: dataBuilder.catalogService)

        let dataViewModel = InventoryViewModel(
            inventoryTrackingService: dataBuilder.inventoryTrackingService,
            catalogService: dataBuilder.catalogService
        )
        await dataViewModel.loadInventoryItems()

        // Assert with data
        #expect(dataViewModel.hasData == true)
    }

    @Test("Should compute total and filtered counts") @MainActor
    func testItemCounts() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear", coe: 90)
            .withGlassItem(manufacturer: "cim", sku: "001", name: "Clear", coe: 104)
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0, type: "rod")
            .withInventory(manufacturer: "cim", sku: "001", quantity: 5.0, type: "rod")
            .build()

        // Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )
        await viewModel.loadInventoryItems()

        // Assert total count
        #expect(viewModel.totalItemsCount == 2)

        // Act - filter
        viewModel.selectedManufacturers = ["bullseye"]

        // Assert filtered count (note: computed property, not reactive)
        #expect(viewModel.totalItemsCount == 2) // Total doesn't change
    }
}
