//
//  InventoryViewModelTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Phase 1 Testing Improvements: ViewModel Implementation and Testing
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

@Suite("InventoryViewModel Comprehensive Tests")
struct InventoryViewModelTests {
    
    // MARK: - Test Data Factory
    
    private func createMockServices() -> (InventoryService, CatalogService) {
        let mockInventoryRepo = MockInventoryRepository()
        let mockCatalogRepo = MockCatalogRepository()
        
        let inventoryService = InventoryService(repository: mockInventoryRepo)
        let catalogService = CatalogService(repository: mockCatalogRepo)
        
        return (inventoryService, catalogService)
    }
    
    private func createTestCatalogItems() -> [CatalogItemModel] {
        return [
            CatalogItemModel(name: "Bullseye Red", rawCode: "BULLSEYE-RGR-001", manufacturer: "Bullseye Glass"),
            CatalogItemModel(name: "Spectrum Blue", rawCode: "SPECTRUM-BGS-002", manufacturer: "Spectrum Glass"),
            CatalogItemModel(name: "Uroboros Green", rawCode: "UROBOROS-GRN-003", manufacturer: "Uroboros")
        ]
    }
    
    private func createTestInventoryItems() -> [InventoryItemModel] {
        return [
            InventoryItemModel(catalogCode: "BULLSEYE-RGR-001", quantity: 5, type: .inventory),
            InventoryItemModel(catalogCode: "BULLSEYE-RGR-001", quantity: 2, type: .buy),
            InventoryItemModel(catalogCode: "SPECTRUM-BGS-002", quantity: 3, type: .inventory),
            InventoryItemModel(catalogCode: "SPECTRUM-BGS-002", quantity: 1, type: .sell),
            InventoryItemModel(catalogCode: "UROBOROS-GRN-003", quantity: 0, type: .inventory)
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
            #expect(viewModel.allInventoryItems.isEmpty)
            #expect(viewModel.consolidatedItems.isEmpty)
            #expect(viewModel.filteredItems.isEmpty)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.currentError == nil)
            #expect(viewModel.searchText.isEmpty)
        }
    }
    
    @Test("Should load inventory items and catalog data correctly")
    func testLoadInventoryItems() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Add test data to services
        let catalogItems = createTestCatalogItems()
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
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
            #expect(viewModel.allInventoryItems.count == 5)
            #expect(viewModel.catalogItems.count == 3)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.currentError == nil)
        }
    }
    
    // MARK: - Consolidation Logic Tests
    
    @Test("Should consolidate inventory items correctly")
    func testInventoryConsolidation() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Add test data
        let catalogItems = createTestCatalogItems()
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
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
            #expect(viewModel.consolidatedItems.count == 3) // 3 unique catalog codes
            
            // Test Bullseye consolidation (5 inventory + 2 buy)
            let bullseyeItem = viewModel.consolidatedItems.first { $0.catalogCode == "BULLSEYE-RGR-001" }
            #expect(bullseyeItem != nil)
            #expect(bullseyeItem?.totalInventoryCount == 5)
            #expect(bullseyeItem?.totalBuyCount == 2)
            #expect(bullseyeItem?.totalSellCount == 0)
            #expect(bullseyeItem?.catalogName == "Bullseye Red")
            #expect(bullseyeItem?.manufacturer == "Bullseye Glass")
            
            // Test Spectrum consolidation (3 inventory + 1 sell)
            let spectrumItem = viewModel.consolidatedItems.first { $0.catalogCode == "SPECTRUM-BGS-002" }
            #expect(spectrumItem != nil)
            #expect(spectrumItem?.totalInventoryCount == 3)
            #expect(spectrumItem?.totalBuyCount == 0)
            #expect(spectrumItem?.totalSellCount == 1)
            
            // Test Uroboros consolidation (0 inventory only)
            let uroborosItem = viewModel.consolidatedItems.first { $0.catalogCode == "UROBOROS-GRN-003" }
            #expect(uroborosItem != nil)
            #expect(uroborosItem?.totalInventoryCount == 0)
            #expect(uroborosItem?.totalBuyCount == 0)
            #expect(uroborosItem?.totalSellCount == 0)
        }
    }
    
    @Test("Should handle items without catalog matches")
    func testConsolidationWithMissingCatalogItems() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Add inventory items without matching catalog items
        let inventoryItems = [
            InventoryItemModel(catalogCode: "UNKNOWN-ITEM-001", quantity: 3, type: .inventory),
            InventoryItemModel(catalogCode: "UNKNOWN-ITEM-002", quantity: 1, type: .buy)
        ]
        
        for item in inventoryItems {
            _ = try await inventoryService.createItem(item)
        }
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        await MainActor.run {
            #expect(viewModel.consolidatedItems.count == 2)
            
            let unknownItem1 = viewModel.consolidatedItems.first { $0.catalogCode == "UNKNOWN-ITEM-001" }
            #expect(unknownItem1 != nil)
            #expect(unknownItem1?.catalogName == "Unknown Item")
            #expect(unknownItem1?.manufacturer == "Unknown")
            
            let unknownItem2 = viewModel.consolidatedItems.first { $0.catalogCode == "UNKNOWN-ITEM-002" }
            #expect(unknownItem2 != nil)
            #expect(unknownItem2?.catalogName == "Unknown Item")
            #expect(unknownItem2?.manufacturer == "Unknown")
        }
    }
    
    // MARK: - Search and Filter Tests
    
    @Test("Should search inventory items correctly")
    func testSearchFunctionality() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Set up test data
        let catalogItems = createTestCatalogItems()
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        let inventoryItems = createTestInventoryItems()
        for item in inventoryItems {
            _ = try await inventoryService.createItem(item)
        }
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        // Test search by catalog code
        await viewModel.searchItems(searchText: "BULLSEYE")
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.catalogCode == "BULLSEYE-RGR-001")
        }
        
        // Test search by catalog name
        await viewModel.searchItems(searchText: "Blue")
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.catalogName == "Spectrum Blue")
        }
        
        // Test search by manufacturer
        await viewModel.searchItems(searchText: "Spectrum")
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.manufacturer == "Spectrum Glass")
        }
        
        // Test case-insensitive search
        await viewModel.searchItems(searchText: "bullseye")
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.catalogCode == "BULLSEYE-RGR-001")
        }
        
        // Test empty search returns all items
        await viewModel.searchItems(searchText: "")
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 3)
        }
    }
    
    @Test("Should filter by inventory type correctly")
    func testTypeFiltering() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Set up test data
        let catalogItems = createTestCatalogItems()
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        let inventoryItems = createTestInventoryItems()
        for item in inventoryItems {
            _ = try await inventoryService.createItem(item)
        }
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        // Test filter by inventory type - should show items that have inventory entries
        await viewModel.filterItems(byType: .inventory)
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 3) // All 3 catalog codes have inventory entries
        }
        
        // Test filter by buy type - should show only items with buy entries
        await viewModel.filterItems(byType: .buy)
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.catalogCode == "BULLSEYE-RGR-001")
        }
        
        // Test filter by sell type - should show only items with sell entries
        await viewModel.filterItems(byType: .sell)
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.catalogCode == "SPECTRUM-BGS-002")
        }
        
        // Test clear filter
        await viewModel.filterItems(byType: nil)
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 3)
        }
    }
    
    @Test("Should filter by low quantity threshold")
    func testLowQuantityFiltering() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Set up test data
        let catalogItems = createTestCatalogItems()
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        let inventoryItems = createTestInventoryItems()
        for item in inventoryItems {
            _ = try await inventoryService.createItem(item)
        }
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        // Filter for items with less than 4 inventory
        await viewModel.filterByLowQuantity(threshold: 4)
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 2) // Spectrum (3) and Uroboros (0)
            let filteredCodes = Set(viewModel.filteredItems.map { $0.catalogCode })
            #expect(filteredCodes.contains("SPECTRUM-BGS-002"))
            #expect(filteredCodes.contains("UROBOROS-GRN-003"))
        }
        
        // Filter for items with less than 1 inventory (should show only Uroboros with 0)
        await viewModel.filterByLowQuantity(threshold: 1)
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.catalogCode == "UROBOROS-GRN-003")
        }
    }
    
    @Test("Should combine search and filter operations")
    func testCombinedSearchAndFilter() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Set up test data
        let catalogItems = createTestCatalogItems()
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        let inventoryItems = createTestInventoryItems()
        for item in inventoryItems {
            _ = try await inventoryService.createItem(item)
        }
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        // Search for "Glass" (matches Bullseye Glass and Spectrum Glass)
        viewModel.searchText = "Glass"
        await viewModel.filterItems(byType: .buy) // Only show items with buy entries
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1) // Only Bullseye has both "Glass" and buy entries
            #expect(viewModel.filteredItems.first?.catalogCode == "BULLSEYE-RGR-001")
        }
    }
    
    @Test("Should clear all filters correctly")
    func testClearAllFilters() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Set up test data
        let catalogItems = createTestCatalogItems()
        for item in catalogItems {
            _ = try await catalogService.createItem(item)
        }
        
        let inventoryItems = createTestInventoryItems()
        for item in inventoryItems {
            _ = try await inventoryService.createItem(item)
        }
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        // Apply multiple filters
        viewModel.searchText = "BULLSEYE"
        await viewModel.filterItems(byType: .inventory)
        await viewModel.filterByLowQuantity(threshold: 10)
        
        await MainActor.run {
            #expect(!viewModel.searchText.isEmpty)
            #expect(viewModel.typeFilter != nil)
            #expect(viewModel.lowQuantityThreshold != nil)
        }
        
        // Clear all filters
        await viewModel.clearFilters()
        
        await MainActor.run {
            #expect(viewModel.searchText.isEmpty)
            #expect(viewModel.typeFilter == nil)
            #expect(viewModel.lowQuantityThreshold == nil)
            #expect(viewModel.filteredItems.count == 3) // Should show all items
        }
    }
    
    // MARK: - Inventory Operations Tests
    
    @Test("Should create inventory item and refresh data")
    func testCreateInventoryItem() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        let newItem = InventoryItemModel(catalogCode: "NEW-ITEM-001", quantity: 10, type: .inventory)
        try await viewModel.createInventoryItem(newItem)
        
        await MainActor.run {
            #expect(viewModel.allInventoryItems.count == 1)
            #expect(viewModel.consolidatedItems.count == 1)
            #expect(viewModel.consolidatedItems.first?.catalogCode == "NEW-ITEM-001")
            #expect(viewModel.consolidatedItems.first?.totalInventoryCount == 10)
        }
    }
    
    @Test("Should update inventory item and refresh data")
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
        
        await MainActor.run {
            #expect(viewModel.consolidatedItems.first?.totalInventoryCount == 5)
        }
        
        // Update the item
        var updatedItem = savedItem
        updatedItem.quantity = 15
        try await viewModel.updateInventoryItem(updatedItem)
        
        await MainActor.run {
            #expect(viewModel.consolidatedItems.first?.totalInventoryCount == 15)
        }
    }
    
    @Test("Should delete inventory item and refresh data")
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
            #expect(viewModel.allInventoryItems.count == 1)
            #expect(viewModel.consolidatedItems.count == 1)
        }
        
        // Delete the item
        try await viewModel.deleteInventoryItem(withId: savedItem.id)
        
        await MainActor.run {
            #expect(viewModel.allInventoryItems.count == 0)
            #expect(viewModel.consolidatedItems.count == 0)
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
            #expect(viewModel.allInventoryItems.count == 3)
            #expect(viewModel.consolidatedItems.count == 3)
        }
        
        // Delete first two items
        let idsToDelete = Array(savedItems.prefix(2)).map { $0.id }
        try await viewModel.deleteInventoryItems(withIds: idsToDelete)
        
        await MainActor.run {
            #expect(viewModel.allInventoryItems.count == 1)
            #expect(viewModel.consolidatedItems.count == 1)
            #expect(viewModel.consolidatedItems.first?.catalogCode == "BULK-DELETE-003")
        }
    }
    
    // MARK: - Loading State and Error Handling Tests
    
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
        
        // Start loading (we can't easily test the intermediate loading state due to async/await speed)
        let loadTask = Task {
            await viewModel.loadInventoryItems()
        }
        
        await loadTask.value
        
        await MainActor.run {
            #expect(viewModel.isLoading == false) // Should be false after completion
            #expect(viewModel.currentError == nil) // Should be no error on successful load
        }
    }
    
    @Test("Should refresh data correctly")
    func testRefreshData() async throws {
        let (inventoryService, catalogService) = createMockServices()
        
        // Add initial data
        let item1 = InventoryItemModel(catalogCode: "REFRESH-001", quantity: 5, type: .inventory)
        _ = try await inventoryService.createItem(item1)
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        await viewModel.loadInventoryItems()
        
        await MainActor.run {
            #expect(viewModel.allInventoryItems.count == 1)
        }
        
        // Add more data directly to service (simulating external changes)
        let item2 = InventoryItemModel(catalogCode: "REFRESH-002", quantity: 3, type: .buy)
        _ = try await inventoryService.createItem(item2)
        
        // Refresh should pick up the new data
        await viewModel.refreshData()
        
        await MainActor.run {
            #expect(viewModel.allInventoryItems.count == 2)
            #expect(viewModel.consolidatedItems.count == 2)
        }
    }
}