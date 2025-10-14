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
    
    @Test("Should fetch items using repository pattern")
    func testFetchItems() async throws {
        // This test verifies the basic repository interface works
        // It should be able to fetch items without Core Data coupling
        
        let mockRepo = MockCatalogRepository()
        
        // Act
        let items = try await mockRepo.fetchItems(matching: nil)
        
        // Assert - should return empty array initially
        #expect(items.isEmpty)
    }
    
    @Test("Should create item using repository pattern")
    func testCreateItem() async throws {
        // This test verifies we can create items using simple data models
        // No Core Data objects involved - just clean Swift structs
        
        let mockRepo = MockCatalogRepository()
        let testItem = CatalogItemModel(
            name: "Red Glass Rod",
            rawCode: "RGR-001", 
            manufacturer: "Bullseye Glass"
        )
        
        // Act
        let createdItem = try await mockRepo.createItem(testItem)
        
        // Assert - should return the created item with proper values
        #expect(createdItem.name == "Red Glass Rod")
        #expect(createdItem.code == "BULLSEYE GLASS-RGR-001")  // Updated expected value
        #expect(createdItem.manufacturer == "Bullseye Glass")
        #expect(!createdItem.id.isEmpty) // Should have generated an ID
    }
    
    @Test("Should search items by text using repository pattern")
    func testSearchItems() async throws {
        // This test verifies we can search items using clean business logic
        // No Core Data complexity - just fast, reliable string matching
        
        let mockRepo = MockCatalogRepository()
        
        // Arrange - populate with test data
        mockRepo.addTestItems([
            CatalogItemModel(name: "Red Glass Rod", rawCode: "RGR-001", manufacturer: "Bullseye Glass"),
            CatalogItemModel(name: "Blue Glass Sheet", rawCode: "BGS-002", manufacturer: "Spectrum Glass"),
            CatalogItemModel(name: "Clear Rod", rawCode: "CR-003", manufacturer: "Bullseye Glass")
        ])
        
        // Act
        let results = try await mockRepo.searchItems(text: "Red")
        
        // Assert - should find items containing "Red" in name, code, or manufacturer
        #expect(results.count == 1)
        #expect(results.first?.name == "Red Glass Rod")
    }
    
    @Test("Should handle advanced search scenarios robustly")
    func testAdvancedSearchScenarios() async throws {
        // This test drives us toward the robust search needed for CatalogItemManager replacement
        // Tests case insensitivity, partial matching, and empty search handling
        
        let mockRepo = MockCatalogRepository()
        
        // Arrange - populate with diverse test data
        mockRepo.addTestItems([
            CatalogItemModel(name: "Red Glass Rod", rawCode: "RGR-001", manufacturer: "bullseye glass"),
            CatalogItemModel(name: "Blue Sheet", rawCode: "SPECTRUM-002", manufacturer: "Spectrum Glass"),
            CatalogItemModel(name: "Clear Tube", rawCode: "CT-003", manufacturer: "BOROSILICATE WORKS")
        ])
        
        // Act & Assert - Case insensitive manufacturer search
        let manufacturerResults = try await mockRepo.searchItems(text: "BULLSEYE")
        #expect(manufacturerResults.count == 1)
        #expect(manufacturerResults.first?.name == "Red Glass Rod")
        
        // Act & Assert - Partial code matching
        let codeResults = try await mockRepo.searchItems(text: "SPECTRUM")
        #expect(codeResults.count == 1)
        #expect(codeResults.first?.name == "Blue Sheet")
        
        // Act & Assert - Empty search returns all items
        let emptyResults = try await mockRepo.searchItems(text: "")
        #expect(emptyResults.count == 3)
        
        // Act & Assert - No matches returns empty array
        let noMatchResults = try await mockRepo.searchItems(text: "NonExistentItem")
        #expect(noMatchResults.isEmpty)
    }
    
    @Test("Should integrate repository with catalog service for business logic")
    func testCatalogServiceIntegration() async throws {
        // This test drives us toward the service layer that will replace CatalogItemManager
        // Business logic separated from persistence - clean architecture
        
        let mockRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockRepo)
        
        // Act - Service should delegate to repository
        let items = try await catalogService.getAllItems()
        
        // Assert - Service returns what repository provides
        #expect(items.isEmpty)
    }
    
    @Test("Should handle catalog search through service layer")
    func testCatalogServiceSearch() async throws {
        // This test verifies service layer properly delegates search operations
        // This is the business logic that CatalogItemManager currently handles
        
        let mockRepo = MockCatalogRepository()
        mockRepo.addTestItems([
            CatalogItemModel(name: "Red Glass Rod", rawCode: "RGR-001", manufacturer: "Bullseye Glass")
        ])
        
        let catalogService = CatalogService(repository: mockRepo)
        
        // Act - Search through service layer
        let searchResults = try await catalogService.searchItems(searchText: "Red")
        
        // Assert - Service should return repository results
        #expect(searchResults.count == 1)
        #expect(searchResults.first?.name == "Red Glass Rod")
    }
    
    @Test("Should create CoreDataCatalogRepository for production use")
    func testCoreDataRepositoryCreation() async throws {
        // Arrange - Create isolated test Core Data context
        let testPersistenceController = PersistenceController(inMemory: true)
        let context = testPersistenceController.container.viewContext
        let coreDataRepo = CoreDataCatalogRepository(context: context)
        
        // Act & Assert - Should be able to fetch empty items initially
        let items = try await coreDataRepo.fetchItems(matching: nil)
        #expect(items.isEmpty, "Should start with empty repository")
        
        // Act & Assert - Should be able to create items
        let testItem = CatalogItemModel(
            name: "Test Glass Rod",
            rawCode: "TGR-001", 
            manufacturer: "Test Corp"
        )
        
        let createdItem = try await coreDataRepo.createItem(testItem)
        #expect(createdItem.name == "Test Glass Rod", "Should create item with correct name")
        #expect(createdItem.code == "TEST CORP-TGR-001", "Should apply business logic to code")
        #expect(createdItem.manufacturer == "Test Corp", "Should preserve manufacturer")
        
        // Act & Assert - Should be able to fetch created items
        let allItems = try await coreDataRepo.fetchItems(matching: nil)
        #expect(allItems.count == 1, "Should have one created item")
        
        // Act & Assert - Should be able to search items
        let searchResults = try await coreDataRepo.searchItems(text: "Test")
        #expect(searchResults.count == 1, "Should find item by search")
        #expect(searchResults.first?.name == "Test Glass Rod", "Should find correct item")
    }
    
    @Test("Should construct full product codes following business rules")
    func testProductCodeConstruction() async throws {
        // This test drives us to extract the complex code construction logic from CatalogItemManager
        // This is critical business logic that determines how product codes are formatted
        
        let mockRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockRepo)
        
        // Test cases covering the business rules from CatalogItemManager.constructFullCode
        let testCases = [
            // Standard case - should prefix with manufacturer
            (name: "Red Glass Rod", code: "RGR-001", manufacturer: "Bullseye Glass", expected: "BULLSEYE GLASS-RGR-001"),
            
            // Already has correct prefix - should NOT double-prefix  
            (name: "Blue Rod", code: "EFFETRE-BLU-002", manufacturer: "Effetre", expected: "EFFETRE-BLU-002"),
            
            // Code with hyphen that's NOT a manufacturer separator - should still prefix
            (name: "Special Rod", code: "TTL-8623", manufacturer: "Thompson", expected: "THOMPSON-TTL-8623"),
            
            // Manufacturer with spaces - should normalize to uppercase
            (name: "Clear Sheet", code: "CS-001", manufacturer: "Spectrum Glass", expected: "SPECTRUM GLASS-CS-001")
        ]
        
        for testCase in testCases {
            // Act - Create item with rawCode to apply business rules
            let item = CatalogItemModel(
                name: testCase.name,
                rawCode: testCase.code, // Use rawCode constructor to apply business logic
                manufacturer: testCase.manufacturer
            )
            
            let createdItem = try await catalogService.createItem(item)
            
            // Assert - Should have properly formatted code according to business rules
            #expect(createdItem.code == testCase.expected, 
                   "Code construction for '\(testCase.code)' with manufacturer '\(testCase.manufacturer)' should result in '\(testCase.expected)' but got '\(createdItem.code)'")
        }
    }
    
    @Test("Should handle tag management following business rules")
    func testTagManagement() async throws {
        // This test drives us to extract the tag management logic from CatalogItemManager
        // The createTagsString() method has specific rules about tag formatting
        
        let mockRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockRepo)
        
        // Test cases covering tag management business rules from CatalogItemManager.createTagsString
        let testCases = [
            // Basic tag array - should preserve as provided
            (name: "Red Rod", rawCode: "RR-001", manufacturer: "Bullseye", tags: ["red", "transparent", "rod"], expectedTags: ["red", "transparent", "rod"]),
            
            // Empty tags - should result in empty array
            (name: "Blue Rod", rawCode: "BR-002", manufacturer: "Effetre", tags: [String](), expectedTags: [String]()),
            
            // Tags with duplicates - should preserve duplicates (business rule)
            (name: "Green Rod", rawCode: "GR-003", manufacturer: "Vetrofond", tags: ["green", "rod", "green"], expectedTags: ["green", "rod", "green"]),
            
            // Mixed case tags - should preserve original case
            (name: "Clear Sheet", rawCode: "CS-004", manufacturer: "Spectrum", tags: ["Clear", "SHEET", "transparent"], expectedTags: ["Clear", "SHEET", "transparent"])
        ]
        
        for testCase in testCases {
            // Act - Create item with tags through service
            let item = CatalogItemModel(
                name: testCase.name,
                rawCode: testCase.rawCode, 
                manufacturer: testCase.manufacturer,
                tags: testCase.tags
            )
            
            let createdItem = try await catalogService.createItem(item)
            
            // Assert - Should have properly managed tags according to business rules  
            #expect(createdItem.tags == testCase.expectedTags,
                   "Tag management for \(testCase.tags) should result in \(testCase.expectedTags) but got \(createdItem.tags)")
        }
    }
    
    @Test("Should handle JSON data loading through repository pattern")
    func testJSONDataLoadingThroughRepository() async throws {
        // This test drives us to migrate DataLoadingService from CatalogItemManager to repository pattern
        // DataLoadingService currently has tight Core Data coupling that should be abstracted away
        
        let mockRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockRepo)
        
        // Simulate JSON data that would come from DataLoadingService
        let jsonDataItems = [
            CatalogItemModel(name: "JSON Item 1", rawCode: "JI-001", manufacturer: "JSON Corp", tags: ["imported", "glass"]),
            CatalogItemModel(name: "JSON Item 2", rawCode: "JI-002", manufacturer: "JSON Corp", tags: ["imported", "rod"])
        ]
        
        // Act - Load data through service layer (this should replace DataLoadingService.loadCatalogFromJSON)
        for item in jsonDataItems {
            _ = try await catalogService.createItem(item)
        }
        
        let loadedItems = try await catalogService.getAllItems()
        
        // Assert - Should have loaded all JSON items through repository pattern
        #expect(loadedItems.count == 2, "Should load all items from JSON data")
        #expect(loadedItems.contains { $0.name == "JSON Item 1" }, "Should contain first JSON item")
        #expect(loadedItems.contains { $0.name == "JSON Item 2" }, "Should contain second JSON item")
        
        // Assert - Should preserve code formatting business logic
        #expect(loadedItems.allSatisfy { $0.code.hasPrefix("JSON CORP-") }, "All items should have properly formatted codes")
        
        // Assert - Should preserve tags
        let firstItem = loadedItems.first { $0.name == "JSON Item 1" }
        #expect(firstItem?.tags.contains("imported") == true, "Should preserve imported tag")
        #expect(firstItem?.tags.contains("glass") == true, "Should preserve glass tag")
    }
    
    @Test("Should handle JSON data merging with existing items using repository pattern")
    func testJSONDataMergingThroughRepository() async throws {
        // This test drives us to extract the complex merge logic from CatalogItemManager/DataLoadingService
        // The shouldUpdateExistingItem logic needs to be migrated to repository pattern
        
        let mockRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockRepo)
        
        // Arrange - Create existing item in repository
        let existingItem = CatalogItemModel(
            name: "Original Glass Rod", 
            rawCode: "OGR-001", 
            manufacturer: "Original Corp",
            tags: ["existing", "rod"]
        )
        let createdItem = try await catalogService.createItem(existingItem)
        
        // Act - Try to "update" with new data (this should trigger merge logic)
        let updatedData = CatalogItemModel(
            id: createdItem.id, // Same ID to trigger update  
            name: "Updated Glass Rod",
            rawCode: "OGR-001", // Same code
            manufacturer: "Original Corp", // Same manufacturer
            tags: ["updated", "rod", "premium"] // Different tags
        )
        
        // Update the item using the service layer
        let mergedItem = try await catalogService.updateItem(updatedData)
        
        // Assert - Should have merged the data according to business rules
        #expect(mergedItem.name == "Updated Glass Rod", "Should update name")
        #expect(mergedItem.code == "ORIGINAL CORP-OGR-001", "Should preserve formatted code")
        #expect(mergedItem.manufacturer == "Original Corp", "Should preserve manufacturer")
        #expect(mergedItem.tags == ["updated", "rod", "premium"], "Should update tags")
        
        // Assert - Should only have one item (updated, not duplicated)
        let allItems = try await catalogService.getAllItems()
        #expect(allItems.count == 1, "Should have exactly one item (merged, not duplicated)")
    }
    
    @Test("CatalogView should use repository pattern")
    func testCatalogViewRepositoryIntegration() async throws {
        // Test that service properly integrates with repository pattern
        let mockRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: mockRepo)
        
        // Arrange - Add test data to repository
        mockRepo.addTestItems([
            CatalogItemModel(name: "Red Glass Rod", rawCode: "RGR-001", manufacturer: "Bullseye Glass"),
            CatalogItemModel(name: "Blue Glass Sheet", rawCode: "BGS-002", manufacturer: "Spectrum Glass")
        ])
        
        // Act - Load items through service/repository
        let loadedItems = try await catalogService.getAllItems()
        
        // Assert - Should load items through repository pattern
        #expect(loadedItems.count == 2, "Should load items through repository pattern")
        #expect(loadedItems.contains { $0.name == "Red Glass Rod" }, "Should contain first test item")
        #expect(loadedItems.contains { $0.name == "Blue Glass Sheet" }, "Should contain second test item")
        
        // Act & Assert - Should search items correctly
        let searchResults = try await catalogService.searchItems(searchText: "Red")
        #expect(searchResults.count == 1, "Should find items by search through repository")
        
        // Act & Assert - Should get all manufacturers correctly  
        let allItems = try await catalogService.getAllItems()
        let manufacturers = Set(allItems.map { $0.manufacturer })
        #expect(manufacturers.contains("Bullseye Glass"), "Should get Bullseye manufacturer")
        #expect(manufacturers.contains("Spectrum Glass"), "Should get Spectrum manufacturer")
        #expect(manufacturers.count == 2, "Should have exactly 2 manufacturers")
    }

}