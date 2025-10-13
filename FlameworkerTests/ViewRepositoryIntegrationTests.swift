//
//  ViewRepositoryIntegrationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import CoreData
// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("View Repository Integration Tests")
struct ViewRepositoryIntegrationTests {
    
    @Test("Should support InventoryViewModel with repository pattern")
    func testInventoryViewModelIntegration() async throws {
        // This test will fail - InventoryViewModel with repository pattern doesn't exist yet
        let mockInventoryRepo = MockInventoryRepository()
        let mockCatalogRepo = MockCatalogRepository()
        
        let inventoryService = InventoryService(repository: mockInventoryRepo)
        let catalogService = CatalogService(repository: mockCatalogRepo)
        
        let viewModel = await InventoryViewModel(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        // Add test data
        let catalogItem = CatalogItemModel(name: "Test Glass", rawCode: "TG-001", manufacturer: "TestCorp")
        let savedCatalog = try await catalogService.createItem(catalogItem)
        
        let inventoryItem = InventoryItemModel(
            catalogCode: savedCatalog.code,
            quantity: 5,
            type: .inventory
        )
        try await inventoryService.createItem(inventoryItem)
        
        // Test view model functionality - all MainActor operations
        await viewModel.loadInventoryItems()
        
        await MainActor.run {
            #expect(viewModel.consolidatedItems.count == 1)
            #expect(viewModel.consolidatedItems.first?.catalogCode == savedCatalog.code)
            #expect(viewModel.consolidatedItems.first?.totalInventoryCount == 5)
            #expect(viewModel.isLoading == false)
        }
    }
    
    @Test("Should handle search functionality through repository pattern")
    func testInventoryViewModelSearch() async throws {
        let mockInventoryRepo = MockInventoryRepository()
        let inventoryService = InventoryService(repository: mockInventoryRepo)
        
        let viewModel = await InventoryViewModel(inventoryService: inventoryService)
        
        // Add test data
        let testItems = [
            InventoryItemModel(catalogCode: "BULLSEYE-RGR-001", quantity: 5, type: .inventory),
            InventoryItemModel(catalogCode: "SPECTRUM-BGS-002", quantity: 3, type: .buy)
        ]
        
        for item in testItems {
            try await inventoryService.createItem(item)
        }
        
        // Test search functionality
        await viewModel.searchItems(searchText: "BULLSEYE")
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.catalogCode.contains("BULLSEYE") == true)
        }
    }
    
    @Test("Should support filter operations through repository pattern")
    func testInventoryViewModelFiltering() async throws {
        let mockInventoryRepo = MockInventoryRepository()
        let inventoryService = InventoryService(repository: mockInventoryRepo)
        
        let viewModel = await InventoryViewModel(inventoryService: inventoryService)
        
        // Add test data with different types
        let testItems = [
            InventoryItemModel(catalogCode: "ITEM-001", quantity: 5, type: .inventory),
            InventoryItemModel(catalogCode: "ITEM-002", quantity: 3, type: .buy),
            InventoryItemModel(catalogCode: "ITEM-003", quantity: 2, type: .sell)
        ]
        
        for item in testItems {
            try await inventoryService.createItem(item)
        }
        
        // Test filtering by type
        await viewModel.filterItems(byType: .inventory)
        
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.type == .inventory)
        }
        
        await viewModel.filterItems(byType: .buy)
        await MainActor.run {
            #expect(viewModel.filteredItems.count == 1)
            #expect(viewModel.filteredItems.first?.type == .buy)
        }
    }
    
    @Test("Should provide InventoryView with repository-based InventoryViewModel")
    func testInventoryViewRepositoryIntegration() async throws {
        // This test will fail initially - need to create InventoryView that uses InventoryViewModel
        let mockInventoryRepo = MockInventoryRepository()
        let mockCatalogRepo = MockCatalogRepository()
        
        let inventoryService = InventoryService(repository: mockInventoryRepo)
        let catalogService = CatalogService(repository: mockCatalogRepo)
        
        // Test that we can create InventoryView with repository-based dependencies
        let inventoryView = await InventoryView(
            inventoryService: inventoryService,
            catalogService: catalogService
        )
        
        // Basic test that the view can be created and configured
        #expect(inventoryView != nil)
        
        // The view should be using InventoryViewModel internally instead of @FetchRequest
        // This verifies the migration from Core Data to repository pattern
    }
}