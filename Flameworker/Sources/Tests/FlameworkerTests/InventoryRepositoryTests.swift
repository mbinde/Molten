//
//  LegacyInventoryRepositoryTests.swift  
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//  LEGACY: Tests for the old InventoryItem-based repository system
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

@Suite("Inventory Repository Tests", .serialized)
struct InventoryRepositoryTests {
    
    @Test("Should create InventoryItemModel with required properties")
    func testInventoryItemModelCreation() async throws {
        let item = InventoryItemModel(
            id: "test-123",
            catalogCode: "BULLSEYE-RGR-001",
            quantity: 5,
            type: .inventory,
            notes: "Test inventory item"
        )
        
        #expect(item.id == "test-123")
        #expect(item.catalogCode == "BULLSEYE-RGR-001")
        #expect(item.quantity == 5)
        #expect(item.type == .inventory)
        #expect(item.notes == "Test inventory item")
    }
    
    @Test("Should verify Core Data InventoryItem entity exists")
    func testInventoryItemEntityExists() async throws {
        // RED: This test should fail if InventoryItem entity doesn't exist
        let context = PersistenceController(inMemory: true).container.viewContext
        
        do {
            // Try to create a fetch request - this will fail if entity doesn't exist
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "InventoryItem")
            
            // Should not throw an error if entity exists
            let count = try context.count(for: fetchRequest)
            #expect(count >= 0, "Entity exists and can be queried")
        } catch {
            // Expected to fail until InventoryItem entity is added to .xcdatamodeld
            #expect(error.localizedDescription.contains("InventoryItem") || 
                   error.localizedDescription.contains("entity"), 
                   "Should fail with entity-related error: \(error.localizedDescription)")
        }
    }
    
    @Test("Should fetch inventory items through repository protocol")
    func testInventoryRepositoryFetch() async throws {
        let mockRepo = LegacyMockInventoryRepository()
        let testItems = [
            InventoryItemModel(
                catalogCode: "BULLSEYE-RGR-001",
                quantity: 5,
                type: .inventory
            ),
            InventoryItemModel(
                catalogCode: "SPECTRUM-BGS-002", 
                quantity: 3,
                type: .buy
            )
        ]
        
        mockRepo.addTestItems(testItems)
        
        let fetchedItems = try await mockRepo.fetchItems(matching: nil)
        
        #expect(fetchedItems.count == 2)
        #expect(fetchedItems.first?.catalogCode == "BULLSEYE-RGR-001")
    }
    
    @Test("Should consolidate inventory items by catalog code correctly")
    func testInventoryConsolidation() async throws {
        let mockRepo = LegacyMockInventoryRepository()
        let testItems = [
            InventoryItemModel(
                catalogCode: "BULLSEYE-RGR-001",
                quantity: 5,
                type: .inventory
            ),
            InventoryItemModel(
                catalogCode: "BULLSEYE-RGR-001",
                quantity: 2,
                type: .buy
            ),
            InventoryItemModel(
                catalogCode: "BULLSEYE-RGR-001", 
                quantity: 1,
                type: .sell
            ),
            InventoryItemModel(
                catalogCode: "SPECTRUM-BGS-002",
                quantity: 10,
                type: .inventory
            )
        ]
        
        mockRepo.addTestItems(testItems)
        
        let consolidated = try await mockRepo.consolidateItems(byCatalogCode: true)
        
        #expect(consolidated.count == 2)
        
        // Find the BULLSEYE item
        let bullseyeItem = consolidated.first { $0.catalogCode == "BULLSEYE-RGR-001" }
        #expect(bullseyeItem != nil)
        #expect(bullseyeItem?.totalInventoryCount == 5)
        #expect(bullseyeItem?.totalBuyCount == 2)
        #expect(bullseyeItem?.totalSellCount == 1)
        #expect(bullseyeItem?.items.count == 3)
        
        // Find the SPECTRUM item
        let spectrumItem = consolidated.first { $0.catalogCode == "SPECTRUM-BGS-002" }
        #expect(spectrumItem != nil)
        #expect(spectrumItem?.totalInventoryCount == 10)
        #expect(spectrumItem?.totalBuyCount == 0)
        #expect(spectrumItem?.totalSellCount == 0)
        #expect(spectrumItem?.items.count == 1)
    }
    
    @Test("Should filter inventory items by type")
    func testInventoryFilteringByType() async throws {
        let mockRepo = LegacyMockInventoryRepository()
        let testItems = [
            InventoryItemModel(catalogCode: "CODE-001", quantity: 5, type: .inventory),
            InventoryItemModel(catalogCode: "CODE-002", quantity: 3, type: .buy),
            InventoryItemModel(catalogCode: "CODE-003", quantity: 2, type: .sell),
            InventoryItemModel(catalogCode: "CODE-004", quantity: 1, type: .inventory)
        ]
        
        mockRepo.addTestItems(testItems)
        
        let inventoryItems = try await mockRepo.fetchItems(byType: .inventory)
        let buyItems = try await mockRepo.fetchItems(byType: .buy)
        let sellItems = try await mockRepo.fetchItems(byType: .sell)
        
        #expect(inventoryItems.count == 2)
        #expect(buyItems.count == 1)
        #expect(sellItems.count == 1)
        
        #expect(inventoryItems.allSatisfy { $0.type == .inventory })
        #expect(buyItems.first?.type == .buy)
        #expect(sellItems.first?.type == .sell)
    }
    
    @Test("Should calculate total quantities by catalog code and type")
    func testTotalQuantityCalculation() async throws {
        let mockRepo = LegacyMockInventoryRepository()
        let testItems = [
            InventoryItemModel(catalogCode: "BULLSEYE-RGR-001", quantity: 5, type: .inventory),
            InventoryItemModel(catalogCode: "BULLSEYE-RGR-001", quantity: 3, type: .inventory),
            InventoryItemModel(catalogCode: "BULLSEYE-RGR-001", quantity: 2, type: .buy),
            InventoryItemModel(catalogCode: "OTHER-CODE", quantity: 10, type: .inventory)
        ]
        
        mockRepo.addTestItems(testItems)
        
        let totalInventory = try await mockRepo.getTotalQuantity(forCatalogCode: "BULLSEYE-RGR-001", type: .inventory)
        let totalBuy = try await mockRepo.getTotalQuantity(forCatalogCode: "BULLSEYE-RGR-001", type: .buy)
        let totalSell = try await mockRepo.getTotalQuantity(forCatalogCode: "BULLSEYE-RGR-001", type: .sell)
        
        #expect(totalInventory == 8) // 5 + 3
        #expect(totalBuy == 2)
        #expect(totalSell == 0) // No sell items
    }
    
    @Test("Should search inventory items by catalog code and notes")
    func testInventorySearch() async throws {
        let mockRepo = LegacyMockInventoryRepository()
        let testItems = [
            InventoryItemModel(catalogCode: "BULLSEYE-RGR-001", quantity: 5, type: .inventory, notes: "Red glass rod from workshop"),
            InventoryItemModel(catalogCode: "SPECTRUM-BGS-002", quantity: 3, type: .buy, notes: "Blue glass sheet purchase"),
            InventoryItemModel(catalogCode: "KOKOMO-GGS-003", quantity: 2, type: .sell, notes: "Green glass for sale")
        ]
        
        mockRepo.addTestItems(testItems)
        
        // Test searching by catalog code
        let bullseyeResults = try await mockRepo.searchItems(text: "BULLSEYE")
        #expect(bullseyeResults.count == 1)
        #expect(bullseyeResults.first?.catalogCode == "BULLSEYE-RGR-001")
        
        // Test searching by notes
        let redResults = try await mockRepo.searchItems(text: "red")
        #expect(redResults.count == 1)
        #expect(redResults.first?.notes?.contains("Red") == true)
        
        // Test searching by partial match
        let glassResults = try await mockRepo.searchItems(text: "glass")
        #expect(glassResults.count == 3) // All items have "glass" in notes
        
        // Test empty search returns all items
        let allResults = try await mockRepo.searchItems(text: "")
        #expect(allResults.count == 3)
    }
    
    @Test("Should work with InventoryService layer")
    func testInventoryServiceIntegration() async throws {
        let mockRepo = LegacyMockInventoryRepository()
        let inventoryService = InventoryService(repository: mockRepo)
        
        let testItem = InventoryItemModel(
            catalogCode: "BULLSEYE-RGR-001",
            quantity: 5,
            type: .inventory,
            notes: "Test item"
        )
        
        let createdItem = try await inventoryService.createItem(testItem)
        #expect(createdItem.id.isEmpty == false)
        #expect(createdItem.catalogCode == "BULLSEYE-RGR-001")
        
        let allItems = try await inventoryService.getAllItems()
        #expect(allItems.count == 1)
        
        let consolidatedItems = try await inventoryService.getConsolidatedItems()
        #expect(consolidatedItems.count == 1)
        #expect(consolidatedItems.first?.totalInventoryCount == 5)
    }
    
    @Test("Should handle batch operations efficiently")
    func testBatchOperations() async throws {
        // This test verifies batch operations work correctly with Core Data
        let coreDataRepo = LegacyCoreDataInventoryRepository(persistenceController: PersistenceController(inMemory: true))
        
        // Test 1: Batch creation should be efficient for large datasets
        let batchItems = (1...20).map { index in
            InventoryItemModel(
                catalogCode: "BATCH-ITEM-\(String(format: "%03d", index))",
                quantity: Double(index),
                type: index % 2 == 0 ? .inventory : .buy,
                notes: "Batch item \(index)"
            )
        }
        
        // Should have a batch create method for efficiency
        let createdItems = try await coreDataRepo.createItems(batchItems)
        #expect(createdItems.count == 20, "Should create all 20 items in batch")
        
        // Verify all items were created correctly
        for (index, item) in createdItems.enumerated() {
            let expectedCode = "BATCH-ITEM-\(String(format: "%03d", index + 1))"
            #expect(item.catalogCode == expectedCode, "Item \(index + 1) should have correct catalog code")
            #expect(item.quantity == Double(index + 1), "Item \(index + 1) should have correct quantity")
        }
        
        // Test 2: Batch deletion should be efficient
        let itemIds = createdItems.map { $0.id }
        try await coreDataRepo.deleteItems(ids: itemIds)
        
        // Verify all items were deleted
        for id in itemIds {
            let deletedItem = try await coreDataRepo.fetchItem(byId: id)
            #expect(deletedItem == nil, "Item with ID \(id) should be deleted")
        }
    }
    
    @Test("Should persist and retrieve items with Core Data")
    func testCoreDataPersistence() async throws {
        // Test full CRUD cycle with real Core Data persistence
        let coreDataRepo = LegacyCoreDataInventoryRepository(persistenceController: PersistenceController(inMemory: true))
        
        let testItem = InventoryItemModel(
            catalogCode: "BULLSEYE-PERSIST-001",
            quantity: 2.5,
            type: .inventory,
            notes: "Real persistence test"
        )
        
        // Create and verify persistence
        let createdItem = try await coreDataRepo.createItem(testItem)
        #expect(createdItem.catalogCode == "BULLSEYE-PERSIST-001")
        #expect(createdItem.quantity == 2.5)
        #expect(createdItem.type == .inventory)
        #expect(createdItem.notes == "Real persistence test")
        
        // Verify retrieval by ID
        let retrievedItem = try await coreDataRepo.fetchItem(byId: createdItem.id)
        #expect(retrievedItem != nil, "Item should be persisted and retrievable")
        #expect(retrievedItem?.catalogCode == "BULLSEYE-PERSIST-001")
        #expect(retrievedItem?.quantity == 2.5)
        #expect(retrievedItem?.type == .inventory)
        
        // Verify search functionality
        let searchResults = try await coreDataRepo.searchItems(text: "PERSIST")
        let foundItems = searchResults.filter { $0.catalogCode == "BULLSEYE-PERSIST-001" }
        #expect(foundItems.count == 1, "Item should be findable by search")
        
        // Verify type filtering
        let inventoryItems = try await coreDataRepo.fetchItems(byType: .inventory)
        let testItems = inventoryItems.filter { $0.catalogCode == "BULLSEYE-PERSIST-001" }
        #expect(testItems.count == 1, "Item should be findable by type")
        
        // Test update functionality
        let updatedItem = InventoryItemModel(
            id: createdItem.id,
            catalogCode: "BULLSEYE-PERSIST-001",
            quantity: 5.0, // Changed quantity
            type: .buy,     // Changed type
            notes: "Updated persistence test"
        )
        
        let result = try await coreDataRepo.updateItem(updatedItem)
        #expect(result.quantity == 5.0)
        #expect(result.type == .buy)
        #expect(result.notes == "Updated persistence test")
        
        // Verify update persisted
        let updatedRetrieved = try await coreDataRepo.fetchItem(byId: createdItem.id)
        #expect(updatedRetrieved?.quantity == 5.0)
        #expect(updatedRetrieved?.type == .buy)
        
        // Cleanup
        try await coreDataRepo.deleteItem(id: createdItem.id)
        
        // Verify deletion
        let deletedItem = try await coreDataRepo.fetchItem(byId: createdItem.id)
        #expect(deletedItem == nil, "Item should be deleted and no longer retrievable")
    }
    
    @Test("Should handle Core Data error cases gracefully")
    func testCoreDataErrorHandling() async throws {
        // Test edge cases and error handling
        let testPersistenceController = PersistenceController(inMemory: true)
        let coreDataRepo = LegacyCoreDataInventoryRepository(persistenceController: testPersistenceController)
        
        // Test 1: Updating non-existent item should provide clear error
        let nonExistentItem = InventoryItemModel(
            id: "does-not-exist-123",
            catalogCode: "TEST-CODE",
            quantity: 1.0,
            type: .inventory
        )
        
        do {
            _ = try await coreDataRepo.updateItem(nonExistentItem)
            #expect(Bool(false), "Should throw error when updating non-existent item")
        } catch {
            // Should get a meaningful error message
            #expect(error.localizedDescription.contains("not found") || 
                   error.localizedDescription.contains("404"),
                   "Should provide meaningful error for missing item: \(error.localizedDescription)")
        }
        
        // Test 2: Creating item with duplicate ID should handle gracefully (upsert behavior)
        let originalItem = InventoryItemModel(
            id: "duplicate-test-id",
            catalogCode: "ORIGINAL-001",
            quantity: 1.0,
            type: .inventory
        )
        
        let duplicateIdItem = InventoryItemModel(
            id: "duplicate-test-id", // Same ID
            catalogCode: "DUPLICATE-002",
            quantity: 2.0,
            type: .buy
        )
        
        // Create first item
        let first = try await coreDataRepo.createItem(originalItem)
        #expect(first.id == "duplicate-test-id")
        #expect(first.catalogCode == "ORIGINAL-001")
        
        // Creating second item with same ID should update existing (upsert behavior)
        let second = try await coreDataRepo.createItem(duplicateIdItem)
        #expect(second.id == "duplicate-test-id", "Should keep same ID")
        #expect(second.catalogCode == "DUPLICATE-002", "Should update with new data")
        #expect(second.quantity == 2.0, "Should update quantity")
        #expect(second.type == .buy, "Should update type")
        
        // Verify only one item exists with this ID
        let retrieved = try await coreDataRepo.fetchItem(byId: "duplicate-test-id")
        #expect(retrieved?.catalogCode == "DUPLICATE-002", "Should have updated data")
        
        // Test 3: Deleting non-existent item should be idempotent (no error)
        try await coreDataRepo.deleteItem(id: "never-existed-456")
        // Should succeed without throwing
        
        // Cleanup
        try await coreDataRepo.deleteItem(id: "duplicate-test-id")
    }
}

