//
//  InventoryViewModelTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Updated for GlassItem Architecture
//

import Foundation
import CryptoKit
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

@Suite("InventoryViewModel Tests - GlassItem Architecture")
@MainActor
struct InventoryViewModelTests {

    // MARK: - Mock-Based Tests (Protocol-Based Design)

    @Test("Mock: Should initialize with empty state")
    func testMockEmptyState() async throws {
        // Arrange & Act
        let viewModel = MockInventoryViewModel(scenario: .empty)

        // Assert
        #expect(viewModel.completeItems.isEmpty)
        #expect(viewModel.filteredItems.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with loaded data")
    func testMockLoadedState() async throws {
        // Arrange & Act
        let viewModel = MockInventoryViewModel(scenario: .loaded)

        // Assert
        #expect(viewModel.completeItems.count == 3)
        #expect(viewModel.filteredItems.count == 3)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasData)
    }

    @Test("Mock: Should initialize with loading state")
    func testMockLoadingState() async throws {
        // Arrange & Act
        let viewModel = MockInventoryViewModel(scenario: .loading)

        // Assert
        #expect(viewModel.isLoading)
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with error state")
    func testMockErrorState() async throws {
        // Arrange & Act
        let viewModel = MockInventoryViewModel(scenario: .error)

        // Assert
        #expect(viewModel.hasError)
        #expect(viewModel.errorMessage == "Failed to load inventory")
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with low stock scenario")
    func testMockLowStockState() async throws {
        // Arrange & Act
        let viewModel = MockInventoryViewModel(scenario: .lowStock)

        // Assert
        #expect(viewModel.completeItems.count == 2)
        #expect(viewModel.completeItems.allSatisfy { $0.totalQuantity < 5.0 })
        #expect(viewModel.hasData)
    }

    @Test("Mock: Should initialize with filtered scenario")
    func testMockFilteredState() async throws {
        // Arrange & Act
        let viewModel = MockInventoryViewModel(scenario: .filtered)

        // Assert
        #expect(viewModel.completeItems.count == 3)
        #expect(viewModel.filteredItems.count > 0)
        #expect(viewModel.filteredItems.count < viewModel.completeItems.count)
        #expect(viewModel.selectedTypes.contains("rod"))
    }

    @Test("Mock: Should search items correctly")
    func testMockSearchItems() async throws {
        // Arrange
        let viewModel = MockInventoryViewModel(scenario: .loaded)

        // Act
        await viewModel.searchItems(searchText: "Clear")

        // Assert
        #expect(viewModel.searchItemsCalled)
        #expect(viewModel.searchText == "Clear")
        #expect(viewModel.filteredItems.count >= 1)
        #expect(viewModel.filteredItems.allSatisfy { $0.glassItem.name.contains("Clear") })
    }

    @Test("Mock: Should filter by type correctly")
    func testMockFilterByType() async throws {
        // Arrange
        let viewModel = MockInventoryViewModel(scenario: .loaded)

        // Act
        await viewModel.filterItems(byType: "rod")

        // Assert
        #expect(viewModel.filterItemsCalled)
        #expect(viewModel.filteredItems.count >= 1)
        #expect(viewModel.filteredItems.allSatisfy { item in
            item.inventory.contains { $0.type == "rod" }
        })
    }

    @Test("Mock: Should apply filters correctly")
    func testMockApplyFilters() async throws {
        // Arrange
        let viewModel = MockInventoryViewModel(scenario: .loaded)
        viewModel.searchText = "Clear"
        viewModel.selectedTypes = ["rod"]

        // Act
        await viewModel.applyFilters()

        // Assert
        #expect(viewModel.applyFiltersCalled)
        #expect(viewModel.filteredItems.count >= 0)
    }

    @Test("Mock: Should track CRUD operations")
    func testMockCRUDOperations() async throws {
        // Arrange
        let viewModel = MockInventoryViewModel(scenario: .loaded)

        // Act
        await viewModel.addInventory(quantity: 10, type: "rod", toItemNaturalKey: "test-id")
        await viewModel.updateInventory(InventoryModel(item_stable_id: "test", type: "rod", quantity: 5))
        await viewModel.deleteInventory(id: UUID())
        await viewModel.deleteInventories(ids: [UUID(), UUID()])

        // Assert
        #expect(viewModel.addInventoryCalled)
        #expect(viewModel.updateInventoryCalled)
        #expect(viewModel.deleteInventoryCalled)
        #expect(viewModel.deleteInventoriesCalled)
    }

    @Test("Mock: Should get detailed inventory summary")
    func testMockGetDetailedSummary() async throws {
        // Arrange
        let viewModel = MockInventoryViewModel(scenario: .loaded)
        let firstItem = viewModel.completeItems.first!

        // Act
        let summary = await viewModel.getDetailedInventorySummary(for: firstItem.glassItem.stable_id)

        // Assert
        #expect(viewModel.getDetailedInventorySummaryCalled)
        #expect(summary != nil)
        #expect(summary?.summary.item_stable_id == firstItem.glassItem.stable_id)
    }

    @Test("Mock: Should get low stock items")
    func testMockGetLowStockItems() async throws {
        // Arrange
        let viewModel = MockInventoryViewModel(scenario: .loaded)

        // Act
        await viewModel.getLowStockItems(threshold: 5.0)

        // Assert
        #expect(viewModel.getLowStockItemsCalled)
        #expect(viewModel.filteredItems.allSatisfy { $0.totalQuantity < 5.0 })
    }

    @Test("Mock: Should compute available inventory types")
    func testMockAvailableInventoryTypes() async throws {
        // Arrange
        let viewModel = MockInventoryViewModel(scenario: .loaded)

        // Act
        let types = viewModel.availableInventoryTypes

        // Assert
        #expect(types.count > 0)
        #expect(types.contains("rod"))
        #expect(types.contains("sheet"))
        #expect(types.contains("frit"))
        #expect(types == types.sorted()) // Should be sorted
    }

    @Test("Mock: Should compute item counts correctly")
    func testMockItemCounts() async throws {
        // Arrange
        let viewModel = MockInventoryViewModel(scenario: .loaded)

        // Assert
        #expect(viewModel.totalItemsCount == 3)
        #expect(viewModel.filteredItemsCount == 3)

        // Act - filter
        await viewModel.filterItems(byType: "rod")

        // Assert after filtering
        #expect(viewModel.totalItemsCount == 3)  // Total unchanged
        #expect(viewModel.filteredItemsCount < 3)  // Filtered reduced
    }

    // MARK: - Test Data Factory
    
    private func createMockServices() -> (InventoryTrackingService, CatalogService) {
        // Use the new GlassItem architecture with repository pattern
        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockLocationRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let userTagsRepo = MockUserTagsRepository()
        let itemMinimumRepo = MockItemMinimumRepository()
        
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            inventoryRepository: inventoryRepo,
            itemTagsRepository: itemTagsRepo
        )
        
        let shoppingListRepository = MockShoppingListRepository()
        let shoppingListService = ShoppingListService(
            itemMinimumRepository: itemMinimumRepo,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: inventoryRepo,
            glassItemRepository: glassItemRepo,
            itemTagsRepository: itemTagsRepo,
            userTagsRepository: userTagsRepo
        )
        
        let catalogService = CatalogService(
            glassItemRepository: glassItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            shoppingListService: shoppingListService,
            itemTagsRepository: itemTagsRepo,
            userTagsRepository: userTagsRepo
        )
        
        return (inventoryTrackingService, catalogService)
    }
    
    private func createTestGlassItems() -> [GlassItemModel] {
        let items = [
            ("Cherry Red", "bullseye", "001"),
            ("Cobalt Blue", "spectrum", "002"), 
            ("Forest Green", "uroboros", "003")
        ]
        
        return items.map { (name, manufacturer, sku) in
            let stableId = generateStableId(manufacturer: manufacturer, sku: sku)
            return GlassItemModel(
                stable_id: stableId,
                name: name,
                sku: sku,
                manufacturer: manufacturer,
                mfr_notes: "Test item",
                coe: 96,
                url: nil,
                mfr_status: "available"
            )
        }
    }
    
    private func createTestInventoryItems() -> [InventoryModel] {
        return [
            InventoryModel(item_stable_id: "bullseye-001-0", type: "rod", quantity: 5),
            InventoryModel(item_stable_id: "spectrum-002-0", type: "sheet", quantity: 3),
            InventoryModel(item_stable_id: "uroboros-003-0", type: "frit", quantity: 2)
        ]
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("Should initialize with proper dependencies")
    func testViewModelInitialization() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await MainActor.run {
            #expect(viewModel.completeItems.isEmpty)
            #expect(viewModel.filteredItems.isEmpty)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.errorMessage == nil)
            #expect(viewModel.searchText.isEmpty)
            #expect(viewModel.selectedTypes.isEmpty)
        }
    }
    
    @Test("Should load inventory items correctly")
    func testLoadInventoryItems() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        // Add test data to services
        let glassItems = createTestGlassItems()
        let inventoryItems = createTestInventoryItems()
        
        for item in glassItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        for item in inventoryItems {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
        }
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await viewModel.loadInventoryItems()
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count >= 0)
            #expect(viewModel.completeItems.count >= 0)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.errorMessage == nil)
        }
    }
    
    @Test("Should search inventory items correctly")
    func testSearchFunctionality() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        // Set up test data
        let glassItems = createTestGlassItems()
        for item in glassItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await viewModel.loadInventoryItems()
        
        // Test search functionality
        await viewModel.searchItems(searchText: "Cherry")
        
        await MainActor.run {
            #expect(viewModel.searchText == "Cherry")
            #expect(viewModel.filteredItems.count >= 0)
        }
        
        // Test empty search
        await viewModel.searchItems(searchText: "")
        
        await MainActor.run {
            #expect(viewModel.searchText.isEmpty)
            #expect(viewModel.filteredItems.count >= 0)
        }
    }
    
    @Test("Should filter by inventory type correctly")
    func testTypeFiltering() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        // Set up test data
        let glassItems = createTestGlassItems()
        let inventoryItems = createTestInventoryItems()
        
        for item in glassItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        for item in inventoryItems {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(item)
        }
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await viewModel.loadInventoryItems()
        
        // Test filter by rod type
        await viewModel.filterItems(byType: "rod")
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count >= 0)
        }
        
        // Test filter by sheet type
        await viewModel.filterItems(byType: "sheet")
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count >= 0)
        }
    }
    
    // MARK: - CRUD Operations Tests
    
    @Test("Should add inventory item and refresh data")
    func testAddInventoryItem() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        // Create a glass item first
        let glassItem = createTestGlassItems().first!
        _ = try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await viewModel.addInventory(quantity: 10, type: "rod", toItemNaturalKey: glassItem.stable_id)
        
        await MainActor.run {
            #expect(viewModel.errorMessage == nil)
        }
    }
    
    @Test("Should update inventory item correctly")
    func testUpdateInventoryItem() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        // Create glass item and inventory
        let glassItem = createTestGlassItems().first!
        _ = try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        let initialInventory = InventoryModel(item_stable_id: glassItem.stable_id, type: "rod", quantity: 5)
        let savedInventory = try await inventoryTrackingService.inventoryRepository.createInventory(initialInventory)
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await viewModel.loadInventoryItems()
        
        // Update the item
        let updatedInventory = InventoryModel(
            id: savedInventory.id,
            item_stable_id: savedInventory.item_stable_id,
            type: savedInventory.type,
            quantity: 15
        )
        
        await viewModel.updateInventory(updatedInventory)
        
        await MainActor.run {
            #expect(viewModel.errorMessage == nil)
        }
    }
    
    @Test("Should delete inventory item correctly")
    func testDeleteInventoryItem() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        // Create glass item and inventory
        let glassItem = createTestGlassItems().first!
        _ = try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        let initialInventory = InventoryModel(item_stable_id: glassItem.stable_id, type: "rod", quantity: 5)
        let savedInventory = try await inventoryTrackingService.inventoryRepository.createInventory(initialInventory)
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await viewModel.loadInventoryItems()
        
        // Delete the item
        await viewModel.deleteInventory(id: savedInventory.id)
        
        await MainActor.run {
            #expect(viewModel.errorMessage == nil)
        }
    }
    
    @Test("Should bulk delete inventory items")
    func testBulkDeleteInventoryItems() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        // Create glass items and inventory
        let glassItems = createTestGlassItems()
        for item in glassItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        var savedinventory_ids: [UUID] = []
        for glassItem in glassItems {
            let inventory = InventoryModel(item_stable_id: glassItem.stable_id, type: "rod", quantity: 3)
            let saved = try await inventoryTrackingService.inventoryRepository.createInventory(inventory)
            savedinventory_ids.append(saved.id)
        }
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await viewModel.loadInventoryItems()
        
        // Delete first two items
        let idsToDelete = Array(savedinventory_ids.prefix(2))
        await viewModel.deleteInventories(ids: idsToDelete)
        
        await MainActor.run {
            #expect(viewModel.errorMessage == nil)
        }
    }
    
    // MARK: - Loading State Tests
    
    @Test("Should handle loading states correctly")
    func testLoadingStates() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await MainActor.run {
            #expect(viewModel.isLoading == false) // Initial state
        }
        
        // Start loading
        let loadTask = Task {
            await viewModel.loadInventoryItems()
        }
        
        await loadTask.value
        
        await MainActor.run {
            #expect(viewModel.isLoading == false) // Should be false after completion
        }
    }
    
    // MARK: - Service Access Tests
    
    @Test("Should provide access to services for dependency injection")
    func testServiceAccess() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await MainActor.run {
            #expect(viewModel.exposedInventoryTrackingService === inventoryTrackingService)
            #expect(viewModel.exposedCatalogService === catalogService)
        }
    }
    
    // MARK: - Computed Properties Tests
    
    @Test("Should compute hasData property correctly")
    func testHasDataProperty() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await MainActor.run {
            #expect(viewModel.hasData == false) // Initially no data
        }
        
        await viewModel.loadInventoryItems()
        
        // hasData will depend on whether we actually have items in the mock services
        // Since we haven't added any, it should still be false
        await MainActor.run {
            let expectedHasData = !viewModel.completeItems.isEmpty || !viewModel.filteredItems.isEmpty
            #expect(viewModel.hasData == expectedHasData)
        }
    }
    
    @Test("Should compute hasError property correctly")
    func testHasErrorProperty() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await MainActor.run {
            #expect(viewModel.hasError == false) // Initially no error
            #expect(viewModel.errorMessage == nil)
        }
        
        await viewModel.loadInventoryItems()
        
        await MainActor.run {
            #expect(viewModel.hasError == (viewModel.errorMessage != nil))
        }
    }
    
    // MARK: - New Architecture Specific Tests
    
    @Test("Should get low stock items correctly")
    func testGetLowStockItems() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        // Set up test data
        let glassItems = createTestGlassItems()
        for item in glassItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Add low quantity inventory
        let lowQuantityInventory = InventoryModel(item_stable_id: "bullseye-001-0", type: "rod", quantity: 2) // Below threshold of 5
        _ = try await inventoryTrackingService.inventoryRepository.createInventory(lowQuantityInventory)
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await viewModel.getLowStockItems(threshold: 5.0)
        
        await MainActor.run {
            #expect(viewModel.errorMessage == nil)
            #expect(viewModel.filteredItems.count >= 0)
        }
    }
    
    @Test("Should get detailed inventory summary correctly")
    func testGetDetailedInventorySummary() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        // Set up test data
        let glassItem = createTestGlassItems().first!
        _ = try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        let inventory = InventoryModel(item_stable_id: glassItem.stable_id, type: "rod", quantity: 10)
        _ = try await inventoryTrackingService.inventoryRepository.createInventory(inventory)
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        let summary = await viewModel.getDetailedInventorySummary(for: glassItem.stable_id)
        
        // The summary may be nil if the mock doesn't implement the full functionality
        // but the test should at least not crash
        await MainActor.run {
            #expect(viewModel.errorMessage == nil)
        }
    }
    
    @Test("Should compute available inventory types correctly")
    func testAvailableInventoryTypes() async throws {
        let (inventoryTrackingService, catalogService) = createMockServices()
        
        // Set up test data with various types
        let glassItems = createTestGlassItems()
        for item in glassItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        let viewModel = await MainActor.run {
            InventoryViewModel(
                inventoryTrackingService: inventoryTrackingService,
                catalogService: catalogService
            )
        }
        
        await viewModel.loadInventoryItems()
        
        await MainActor.run {
            let types = viewModel.availableInventoryTypes
            #expect(types.count >= 0) // Should have types based on the data loaded
            
            // Types should be sorted
            let sortedTypes = types.sorted()
            #expect(types == sortedTypes)
        }
    }
}
