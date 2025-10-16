//
//  CoreDataInventoryRepositoryTests.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//
// Target: RepositoryTests


import Testing
import CoreData
@testable import Flameworker

@Suite("CoreDataInventoryRepository Tests")
struct CoreDataInventoryRepositoryTests {
    
    let repository: CoreDataInventoryRepository
    let persistentContainer: NSPersistentContainer
    
    init() throws {
        // Create in-memory Core Data stack for testing - ISOLATED from production
        persistentContainer = NSPersistentContainer(name: "Flameworker")
        
        // Use in-memory store for testing - completely isolated
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        persistentContainer.persistentStoreDescriptions = [description]
        
        // Load persistent store synchronously for test setup
        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        
        persistentContainer.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = loadError {
            throw error
        }
        
        // Create repository with isolated container
        repository = CoreDataInventoryRepository(persistentContainer: persistentContainer)
        
        // Clean up any existing data to ensure clean test state
        try cleanupExistingData()
    }
    
    private func cleanupExistingData() throws {
        let context = persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
        let existingItems = try context.fetch(fetchRequest)
        
        for item in existingItems {
            context.delete(item)
        }
        
        if context.hasChanges {
            try context.save()
        }
    }
    
    @Test("Basic inventory creation")
    func basicInventoryCreation() async throws {
        // Test basic inventory creation
        let inventory = InventoryModel(
            item_natural_key: "test-item-1",
            type: "rod",
            quantity: 5.0
        )
        
        let createdInventory = try await repository.createInventory(inventory)
        
        #expect(createdInventory.item_natural_key == "test-item-1")
        #expect(createdInventory.type == "rod")
        #expect(createdInventory.quantity == 5.0)
        #expect(createdInventory.id != inventory.id) // Should get new ID when saved
    }
    
    @Test("Fetch inventory by ID")
    func fetchInventoryById() async throws {
        // Create test inventory
        let inventory = InventoryModel(
            item_natural_key: "test-item-2",
            type: "frit",
            quantity: 10.0
        )
        
        let createdInventory = try await repository.createInventory(inventory)
        
        // Fetch by ID
        let fetchedInventory = try await repository.fetchInventory(byId: createdInventory.id)
        
        let unwrappedInventory = try #require(fetchedInventory, "Inventory should be found")
        #expect(unwrappedInventory.item_natural_key == "test-item-2")
        #expect(unwrappedInventory.type == "frit")
        #expect(unwrappedInventory.quantity == 10.0)
    }
    
    @Test("Compilation verification")
    func compilationVerification() {
        // This test exists primarily to verify that the CoreDataInventoryRepository compiles correctly
        #expect(repository != nil)
        #expect(persistentContainer != nil)
    }
    
    @Test("Get distinct types")
    func getDistinctTypes() async throws {
        // Create test inventory items with specific types
        let testInventories = [
            InventoryModel(item_natural_key: "item1", type: "rod", quantity: 1.0),
            InventoryModel(item_natural_key: "item2", type: "frit", quantity: 2.0),
            InventoryModel(item_natural_key: "item3", type: "sheet", quantity: 3.0)
        ]
        
        // Create the inventory items
        for inventory in testInventories {
            _ = try await repository.createInventory(inventory)
        }
        
        // Get distinct types
        let distinctTypes = try await repository.getDistinctTypes()
        
        // Should have exactly 3 types
        #expect(distinctTypes.count == 3, "Should have exactly 3 distinct types")
        #expect(distinctTypes.contains("rod"), "Should contain 'rod' type")
        #expect(distinctTypes.contains("frit"), "Should contain 'frit' type")
        #expect(distinctTypes.contains("sheet"), "Should contain 'sheet' type")
    }
}
