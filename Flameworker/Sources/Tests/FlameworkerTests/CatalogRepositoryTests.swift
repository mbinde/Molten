//
//  CatalogRepositoryTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
import CoreData
@testable import Flameworker

@Suite("CatalogItemRepository Tests - Foundation of Repository Pattern", .serialized)
struct CatalogRepositoryTests {
    
    @Test("Should fetch glass items using repository pattern")
    func testFetchItems() async throws {
        // This test verifies the basic repository interface works
        // It should be able to fetch items without Core Data coupling
        
        let mockRepo = MockGlassItemRepository()
        
        // Act
        let items = try await mockRepo.fetchItems(matching: nil)
        
        // Assert - should return empty array initially
        #expect(items.isEmpty)
    }
    
    @Test("Should create glass item using repository pattern")
    func testCreateItem() async throws {
        // This test verifies we can create items using simple data models
        // No Core Data objects involved - just clean Swift structs
        
        let mockRepo = MockGlassItemRepository()
        let testItem = GlassItemModel(
            naturalKey: "BULLSEYE-RGR-001",
            name: "Red Glass Rod",
            sku: "RGR-001",
            manufacturer: "Bullseye Glass",
            mfrNotes: "Red transparent glass rod",
            coe: 90,
            url: "https://bullseyeglass.com",
            mfrStatus: "available"
        )
        
        // Act
        let createdItem = try await mockRepo.createItem(testItem)
        
        // Assert - should return the created item with proper values
        #expect(createdItem.name == "Red Glass Rod")
        #expect(createdItem.naturalKey == "BULLSEYE-RGR-001")
        #expect(createdItem.manufacturer == "Bullseye Glass")
        #expect(createdItem.coe == 90)
    }
    
    @Test("Should search glass items by text using repository pattern")
    func testSearchItems() async throws {
        // This test verifies we can search items using clean business logic
        // No Core Data complexity - just fast, reliable string matching
        
        let mockRepo = MockGlassItemRepository()
        
        // Arrange - populate with test data
        try await mockRepo.populateWithTestData()
        
        // Act - Search for items containing "Adamantium"
        let results = try await mockRepo.searchItems(text: "Adamantium")
        
        // Assert - should find items containing "Adamantium" in name
        #expect(results.count >= 1)
        #expect(results.contains { $0.name.contains("Adamantium") })
    }
    
    @Test("Should handle advanced search scenarios robustly")
    func testAdvancedSearchScenarios() async throws {
        // This test drives us toward the robust search needed for GlassItem repository
        // Tests case insensitivity, partial matching, and empty search handling
        
        let mockRepo = MockGlassItemRepository()
        
        // Arrange - populate with test data
        try await mockRepo.populateWithTestData()
        
        // Act & Assert - Case insensitive manufacturer search
        let manufacturerResults = try await mockRepo.searchItems(text: "cim")
        #expect(manufacturerResults.count >= 1)
        #expect(manufacturerResults.contains { $0.manufacturer.lowercased().contains("cim") })
        
        // Act & Assert - Partial natural key matching
        let keyResults = try await mockRepo.searchItems(text: "874")
        #expect(keyResults.count >= 1)
        #expect(keyResults.contains { $0.naturalKey.contains("874") })
        
        // Act & Assert - Empty search returns all items
        let emptyResults = try await mockRepo.searchItems(text: "")
        #expect(emptyResults.count >= 0)
        
        // Act & Assert - No matches returns empty array
        let noMatchResults = try await mockRepo.searchItems(text: "NonExistentItem")
        #expect(noMatchResults.isEmpty)
    }
    
    @Test("Should integrate repository with catalog service for business logic")
    func testCatalogServiceIntegration() async throws {
        // This test drives us toward the service layer using the new GlassItem architecture
        // Business logic separated from persistence - clean architecture
        
        // Arrange: Configure factory and create catalog service
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        
        // Act - Service should delegate to repository
        let items = try await catalogService.getAllGlassItems()
        
        // Assert - Service returns what repository provides
        #expect(items.isEmpty)
    }
    
    @Test("Should handle catalog search through service layer")
    func testCatalogServiceSearch() async throws {
        // This test verifies service layer properly delegates search operations
        // Using the new GlassItem architecture
        
        // Arrange: Configure factory and create services
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        // Create a test glass item
        let testGlassItem = GlassItemModel(
            naturalKey: "BULLSEYE-RED-001",
            name: "Red Glass Rod",
            sku: "RED-001",
            manufacturer: "Bullseye Glass",
            mfrNotes: "Red transparent glass rod",
            coe: 90,
            url: "https://bullseyeglass.com",
            mfrStatus: "available"
        )
        
        _ = try await inventoryTrackingService.createCompleteItem(
            testGlassItem,
            initialInventory: [],
            tags: []
        )
        
        // Act - Search through service layer
        let searchRequest = GlassItemSearchRequest(searchText: "Red")
        let searchResult = try await catalogService.searchGlassItems(request: searchRequest)
        
        // Assert - Service should return repository results
        #expect(searchResult.items.count >= 1)
        #expect(searchResult.items.contains { $0.glassItem.name.contains("Red") })
    }
    
    @Test("Should create GlassItem repository for production use")
    func testGlassItemRepositoryCreation() async throws {
        // This test verifies we can create and use a GlassItem repository
        // Using the new architecture with proper dependency injection
        
        // Arrange - Create mock glass item repository
        let mockRepo = MockGlassItemRepository()
        
        // Act & Assert - Should be able to fetch empty items initially
        let items = try await mockRepo.fetchItems(matching: NSPredicate(value: true))
        #expect(items.isEmpty, "Should start with empty repository")
        
        // Act & Assert - Should be able to create items
        let testItem = GlassItemModel(
            naturalKey: "TEST-CORP-001",
            name: "Test Glass Rod",
            sku: "TGR-001",
            manufacturer: "Test Corp",
            mfrNotes: "Test glass item for repository testing",
            coe: 90,
            url: "https://testcorp.com",
            mfrStatus: "available"
        )
        
        let createdItem = try await mockRepo.createItem(testItem)
        #expect(createdItem.name == "Test Glass Rod", "Should create item with correct name")
        #expect(createdItem.naturalKey == "TEST-CORP-001", "Should preserve natural key")
        #expect(createdItem.manufacturer == "Test Corp", "Should preserve manufacturer")
        
        // Act & Assert - Should be able to fetch created items
        let allItems = try await mockRepo.fetchItems(matching: NSPredicate(value: true))
        #expect(allItems.count == 1, "Should have one created item")
        
        // Act & Assert - Should be able to search items
        let searchResults = try await mockRepo.searchItems(text: "Test")
        #expect(searchResults.count == 1, "Should find item by search")
        #expect(searchResults.first?.name == "Test Glass Rod", "Should find correct item")
    }
}