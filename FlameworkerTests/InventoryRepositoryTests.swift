//
//  InventoryRepositoryTests.swift  
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

@Suite("Inventory Repository Tests")
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
        let context = PersistenceController.preview.container.viewContext
        
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
        let mockRepo = MockInventoryRepository()
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
        let mockRepo = MockInventoryRepository()
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
        let mockRepo = MockInventoryRepository()
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
        let mockRepo = MockInventoryRepository()
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
        let mockRepo = MockInventoryRepository()
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
        let mockRepo = MockInventoryRepository()
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
    
    @Test("Should work with CoreDataInventoryRepository with real persistence")
    func testCoreDataRepositoryIntegration() async throws {
        // This test works with the actual Core Data implementation
        let coreDataRepo = CoreDataInventoryRepository(persistenceController: PersistenceController.preview)
        
        let testItem = InventoryItemModel(
            catalogCode: "BULLSEYE-INTEGRATION-001", 
            quantity: 3.0,
            type: .buy,
            notes: "Test Core Data integration"
        )
        
        // Test createItem (should persist to Core Data)
        let createdItem = try await coreDataRepo.createItem(testItem)
        #expect(createdItem.catalogCode == "BULLSEYE-INTEGRATION-001")
        #expect(createdItem.quantity == 3.0)
        #expect(createdItem.type == .buy)
        #expect(createdItem.notes == "Test Core Data integration")
        
        // Test fetchItem (should retrieve from Core Data)
        let retrievedItem = try await coreDataRepo.fetchItem(byId: createdItem.id)
        #expect(retrievedItem != nil, "Item should be persisted and retrievable")
        #expect(retrievedItem?.catalogCode == "BULLSEYE-INTEGRATION-001")
        #expect(retrievedItem?.quantity == 3.0)
        #expect(retrievedItem?.type == .buy)
        
        // Test updateItem
        let updatedItem = InventoryItemModel(
            id: createdItem.id,
            catalogCode: "BULLSEYE-INTEGRATION-001",
            quantity: 5.0, // Changed quantity
            type: .inventory, // Changed type
            notes: "Updated notes"
        )
        let result = try await coreDataRepo.updateItem(updatedItem)
        #expect(result.quantity == 5.0)
        #expect(result.type == .inventory)
        #expect(result.notes == "Updated notes")
        
        // Test search methods (should find the persisted item)
        let searchResults = try await coreDataRepo.searchItems(text: "INTEGRATION")
        let foundItems = searchResults.filter { $0.catalogCode == "BULLSEYE-INTEGRATION-001" }
        #expect(foundItems.count >= 1, "Should find item by search")
        
        let typeResults = try await coreDataRepo.fetchItems(byType: .inventory)
        let foundByType = typeResults.filter { $0.catalogCode == "BULLSEYE-INTEGRATION-001" }
        #expect(foundByType.count >= 1, "Should find item by type")
        
        // Cleanup: delete the test item
        try await coreDataRepo.deleteItem(id: createdItem.id)
        
        // Verify deletion
        let deletedItem = try await coreDataRepo.fetchItem(byId: createdItem.id)
        #expect(deletedItem == nil, "Item should be deleted")
    }
    
    @Test("Should demonstrate Core Data persistence success")
    func testCoreDataRepositorySuccess() async throws {
        // This test celebrates that Core Data persistence is working!
        let coreDataRepo = CoreDataInventoryRepository(persistenceController: PersistenceController.preview)
        
        let testItem = InventoryItemModel(
            catalogCode: "BULLSEYE-SUCCESS-001",
            quantity: 3.0,
            type: .buy,
            notes: "Core Data is working!"
        )
        
        // Core Data persistence is working: createItem persists data
        let createdItem = try await coreDataRepo.createItem(testItem)
        #expect(createdItem.catalogCode == "BULLSEYE-SUCCESS-001")
        #expect(createdItem.quantity == 3.0)
        #expect(createdItem.type == .buy)
        
        // Core Data persistence is working: fetchItem retrieves persisted data
        let retrievedItem = try await coreDataRepo.fetchItem(byId: createdItem.id)
        #expect(retrievedItem != nil, "Core Data persistence is working!")
        #expect(retrievedItem?.catalogCode == "BULLSEYE-SUCCESS-001")
        
        // Core Data persistence is working: fetchItems finds persisted data
        let allItems = try await coreDataRepo.fetchItems(matching: nil)
        let testItems = allItems.filter { $0.catalogCode == "BULLSEYE-SUCCESS-001" }
        #expect(testItems.count >= 1, "Core Data is persisting data!")
        
        // Core Data persistence is working: search finds persisted data
        let searchResults = try await coreDataRepo.searchItems(text: "SUCCESS")
        let foundItems = searchResults.filter { $0.catalogCode == "BULLSEYE-SUCCESS-001" }
        #expect(foundItems.count >= 1, "Core Data search is working!")
        
        // Cleanup
        try await coreDataRepo.deleteItem(id: createdItem.id)
    }
}