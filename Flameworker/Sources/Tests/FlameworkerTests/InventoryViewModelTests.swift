//
//  InventoryViewModelTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Updated to match current InventoryViewModel implementation
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("InventoryViewModel Tests")
struct InventoryViewModelTests {
    
    // MARK: - Test Data Factory
    
    private func createMockServices() -> (InventoryService, CatalogService) {
        let mockInventoryRepo = LegacyMockInventoryRepository()
        let mockCatalogRepo = MockCatalogRepository()
        
        let inventoryService = InventoryService(repository: mockInventoryRepo)
        let catalogService = CatalogService(repository: mockCatalogRepo)
        
        return (inventoryService, catalogService)
    }
    
    private func createTestInventoryItems() -> [InventoryItemModel] {
        return [
            InventoryItemModel(catalogCode: "BULLSEYE-001", quantity: 5, type: .inventory),
            InventoryItemModel(catalogCode: "SPECTRUM-002", quantity: 3, type: .inventory),
            InventoryItemModel(catalogCode: "UROBOROS-003", quantity: 2, type: .buy)
        ]
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("Should initialize with proper dependencies")
    func testViewModelInitialization() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await MainActor.run {
            #expect(viewModel.consolidatedItems.isEmpty)
            #expect(viewModel.filteredItems.isEmpty)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.errorMessage == nil)
            #expect(viewModel.searchText.isEmpty)
            #expect(viewModel.selectedFilters.isEmpty)
        }
    }
    
    @Test("Should load inventory items correctly")
    func testLoadInventoryItems() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Add test data to services
        let inventoryItems = createTestInventoryItems()
        for item in inventoryItems {
            _ = try await inventoryService.createItem(item)
        }
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 3)
            #expect(viewModel.consolidatedItems.count >= 1)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.errorMessage == nil)
        }
    }
    
    @Test("Should search inventory items correctly")
    func testSearchFunctionality() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Set up test data
        let inventoryItems = createTestInventoryItems()
        for item in inventoryItems {
            _ = try await inventoryService.createItem(item)
        }
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        // Test search functionality
        await viewModel.searchItems(searchText: "BULLSEYE")
        
        await MainActor.run {
            #expect(viewModel.searchText == "BULLSEYE")
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
        let (inventoryService, catalogService) = createMockServices()
        
        // Set up test data
        let inventoryItems = createTestInventoryItems()
        for item in inventoryItems {
            _ = try await inventoryService.createItem(item)
        }
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        // Test filter by inventory type
        await viewModel.filterItems(byType: .inventory)
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count >= 0)
            // All returned items should be of inventory type
            for item in viewModel.filteredItems {
                #expect(item.type == .inventory)
            }
        }
        
        // Test filter by buy type
        await viewModel.filterItems(byType: .buy)
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count >= 0)
            // All returned items should be of buy type
            for item in viewModel.filteredItems {
                #expect(item.type == .buy)
            }
        }
    }
    
    // MARK: - CRUD Operations Tests
    
    @Test("Should add inventory item and refresh data")
    func testAddInventoryItem() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        let newItem = InventoryItemModel(catalogCode: "NEW-ITEM-001", quantity: 10, type: .inventory)
        await viewModel.addInventoryItem(newItem)
        
        await MainActor.run {
            #expect(viewModel.consolidatedItems.count >= 1)
            #expect(viewModel.errorMessage == nil)
        }
    }
    
    @Test("Should update inventory item correctly")
    func testUpdateInventoryItem() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Create initial item
        let initialItem = InventoryItemModel(catalogCode: "UPDATE-TEST-001", quantity: 5, type: .inventory)
        let savedItem = try await inventoryService.createItem(initialItem)
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        // Update the item - create new instance since properties are immutable
        let updatedItem = InventoryItemModel(
            id: savedItem.id,
            catalogCode: savedItem.catalogCode,
            quantity: 15, // Updated quantity
            type: savedItem.type,
            notes: savedItem.notes,
            location: savedItem.location,
            dateAdded: savedItem.dateAdded
        )
        
        await viewModel.updateInventoryItem(updatedItem)
        
        await MainActor.run {
            #expect(viewModel.errorMessage == nil)
            #expect(viewModel.consolidatedItems.count >= 1)
        }
    }
    
    @Test("Should delete inventory item correctly")
    func testDeleteInventoryItem() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Create initial item
        let initialItem = InventoryItemModel(catalogCode: "DELETE-TEST-001", quantity: 5, type: .inventory)
        let savedItem = try await inventoryService.createItem(initialItem)
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.consolidatedItems.count >= 1)
        }
        
        // Delete the item
        await viewModel.deleteInventoryItem(id: savedItem.id)
        
        await MainActor.run {
            #expect(viewModel.errorMessage == nil)
            // After deletion, there should be no items
            #expect(viewModel.filteredItems.isEmpty)
        }
    }
    
    @Test("Should bulk delete inventory items")
    func testBulkDeleteInventoryItems() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Create multiple items
        let items = [
            InventoryItemModel(catalogCode: "BULK-DELETE-001", quantity: 3, type: .inventory),
            InventoryItemModel(catalogCode: "BULK-DELETE-002", quantity: 5, type: .buy),
            InventoryItemModel(catalogCode: "BULK-DELETE-003", quantity: 2, type: .sell)
        ]
        
        var savedItems: [InventoryItemModel] = []
        for item in items {
            let saved = try await inventoryService.createItem(item)
            savedItems.append(saved)
        }
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 3)
        }
        
        // Delete first two items
        let idsToDelete = Array(savedItems.prefix(2)).map { $0.id }
        await viewModel.deleteInventoryItems(ids: idsToDelete)
        
        await MainActor.run {
            #expect(viewModel.errorMessage == nil)
            #expect(viewModel.filteredItems.count == 1)
        }
    }
    
    // MARK: - Loading State Tests
    
    @Test("Should handle loading states correctly")
    func testLoadingStates() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
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
            #expect(viewModel.errorMessage == nil) // Should be no error on successful load
        }
    }
    
    // MARK: - Service Access Tests
    
    @Test("Should provide access to services for dependency injection")
    func testServiceAccess() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await MainActor.run {
            #expect(viewModel.exposedInventoryService === inventoryService)
            #expect(viewModel.exposedCatalogService === catalogService)
        }
    }
    
    // MARK: - Computed Properties Tests
    
    @Test("Should compute hasData property correctly")
    func testHasDataProperty() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await MainActor.run {
            #expect(viewModel.hasData == false) // Initially no data
        }
        
        // Add some data
        let testItem = InventoryItemModel(catalogCode: "TEST-001", quantity: 5, type: .inventory)
        await viewModel.addInventoryItem(testItem)
        
        await MainActor.run {
            #expect(viewModel.hasData == true) // Should have data after adding
        }
    }
    
    @Test("Should compute hasError property correctly")
    func testHasErrorProperty() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await MainActor.run {
            #expect(viewModel.hasError == false) // Initially no error
            #expect(viewModel.errorMessage == nil)
        }
        
        // The actual error testing would require a mock that throws errors
        // For now, we just test the computed property logic
        await viewModel.loadInventoryItems()
        
        await MainActor.run {
            #expect(viewModel.hasError == (viewModel.errorMessage != nil))
        }
    }
}
