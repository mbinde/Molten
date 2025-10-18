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

    // MARK: - Subtype and Dimension Tests

    @Test("Create inventory with subtype")
    func createInventoryWithSubtype() async throws {
        let inventory = InventoryModel(
            item_natural_key: "test-item-subtype",
            type: "rod",
            subtype: "stringer",
            quantity: 5.0
        )

        let createdInventory = try await repository.createInventory(inventory)

        #expect(createdInventory.item_natural_key == "test-item-subtype")
        #expect(createdInventory.type == "rod")
        #expect(createdInventory.subtype == "stringer")
        #expect(createdInventory.subsubtype == nil)
        #expect(createdInventory.dimensions == nil)
        #expect(createdInventory.quantity == 5.0)
    }

    @Test("Create inventory with subtype and subsubtype")
    func createInventoryWithSubsubtype() async throws {
        let inventory = InventoryModel(
            item_natural_key: "test-item-subsubtype",
            type: "rod",
            subtype: "stringer",
            subsubtype: "fine",
            quantity: 3.0
        )

        let createdInventory = try await repository.createInventory(inventory)

        #expect(createdInventory.type == "rod")
        #expect(createdInventory.subtype == "stringer")
        #expect(createdInventory.subsubtype == "fine")
        #expect(createdInventory.quantity == 3.0)
    }

    @Test("Create inventory with dimensions")
    func createInventoryWithDimensions() async throws {
        let dimensions = ["diameter": 3.0, "length": 40.0]
        let inventory = InventoryModel(
            item_natural_key: "test-item-dimensions",
            type: "rod",
            subtype: "stringer",
            dimensions: dimensions,
            quantity: 5.0
        )

        let createdInventory = try await repository.createInventory(inventory)

        #expect(createdInventory.item_natural_key == "test-item-dimensions")
        #expect(createdInventory.type == "rod")
        #expect(createdInventory.subtype == "stringer")
        #expect(createdInventory.dimensions != nil)
        #expect(createdInventory.dimensions?["diameter"] == 3.0)
        #expect(createdInventory.dimensions?["length"] == 40.0)
        #expect(createdInventory.quantity == 5.0)
    }

    @Test("Create inventory with all optional fields")
    func createInventoryWithAllFields() async throws {
        let dimensions = ["diameter": 5.0, "length": 50.0]
        let inventory = InventoryModel(
            item_natural_key: "test-item-all-fields",
            type: "rod",
            subtype: "cane",
            subsubtype: "pulled",
            dimensions: dimensions,
            quantity: 10.0
        )

        let createdInventory = try await repository.createInventory(inventory)

        #expect(createdInventory.item_natural_key == "test-item-all-fields")
        #expect(createdInventory.type == "rod")
        #expect(createdInventory.subtype == "cane")
        #expect(createdInventory.subsubtype == "pulled")
        #expect(createdInventory.dimensions != nil)
        #expect(createdInventory.dimensions?["diameter"] == 5.0)
        #expect(createdInventory.dimensions?["length"] == 50.0)
        #expect(createdInventory.quantity == 10.0)
    }

    @Test("Round-trip persistence of dimensions (JSON serialization)")
    func roundTripDimensionsPersistence() async throws {
        // Create inventory with dimensions
        let originalDimensions = [
            "diameter": 3.5,
            "length": 42.0,
            "weight": 125.7
        ]
        let inventory = InventoryModel(
            item_natural_key: "test-roundtrip",
            type: "rod",
            dimensions: originalDimensions,
            quantity: 7.0
        )

        // Save to Core Data
        let createdInventory = try await repository.createInventory(inventory)
        let savedId = createdInventory.id

        // Fetch back from Core Data
        let fetchedInventory = try await repository.fetchInventory(byId: savedId)
        let unwrappedInventory = try #require(fetchedInventory, "Inventory should be found")

        // Verify dimensions survived round-trip (JSON serialization/deserialization)
        #expect(unwrappedInventory.dimensions != nil)
        #expect(unwrappedInventory.dimensions?["diameter"] == 3.5)
        #expect(unwrappedInventory.dimensions?["length"] == 42.0)
        #expect(unwrappedInventory.dimensions?["weight"] == 125.7)
    }

    @Test("Backward compatibility - inventory without new fields")
    func backwardCompatibility() async throws {
        // Create inventory without subtype or dimensions (legacy format)
        let inventory = InventoryModel(
            item_natural_key: "test-legacy",
            type: "frit",
            quantity: 15.0
        )

        let createdInventory = try await repository.createInventory(inventory)

        // Verify it works without new fields
        #expect(createdInventory.item_natural_key == "test-legacy")
        #expect(createdInventory.type == "frit")
        #expect(createdInventory.subtype == nil)
        #expect(createdInventory.subsubtype == nil)
        #expect(createdInventory.dimensions == nil)
        #expect(createdInventory.quantity == 15.0)

        // Fetch and verify
        let fetchedInventory = try await repository.fetchInventory(byId: createdInventory.id)
        let unwrappedInventory = try #require(fetchedInventory)
        #expect(unwrappedInventory.subtype == nil)
        #expect(unwrappedInventory.dimensions == nil)
    }

    @Test("Update inventory with new fields")
    func updateInventoryWithNewFields() async throws {
        // Create basic inventory
        let inventory = InventoryModel(
            item_natural_key: "test-update",
            type: "rod",
            quantity: 5.0
        )

        let createdInventory = try await repository.createInventory(inventory)

        // Update with new fields
        let dimensions = ["diameter": 4.0, "length": 45.0]
        let updatedInventory = InventoryModel(
            id: createdInventory.id,
            item_natural_key: createdInventory.item_natural_key,
            type: "rod",
            subtype: "stringer",
            subsubtype: "fine",
            dimensions: dimensions,
            quantity: 7.0,
            date_added: createdInventory.date_added,
            date_modified: Date()
        )

        try await repository.updateInventory(updatedInventory)

        // Fetch and verify update
        let fetchedInventory = try await repository.fetchInventory(byId: createdInventory.id)
        let unwrappedInventory = try #require(fetchedInventory)

        #expect(unwrappedInventory.subtype == "stringer")
        #expect(unwrappedInventory.subsubtype == "fine")
        #expect(unwrappedInventory.dimensions?["diameter"] == 4.0)
        #expect(unwrappedInventory.dimensions?["length"] == 45.0)
        #expect(unwrappedInventory.quantity == 7.0)
    }

    @Test("Empty dimensions are stored as nil")
    func emptyDimensionsStoredAsNil() async throws {
        // Create inventory with empty dimensions
        let inventory = InventoryModel(
            item_natural_key: "test-empty-dimensions",
            type: "rod",
            dimensions: [:],  // Empty dictionary
            quantity: 5.0
        )

        let createdInventory = try await repository.createInventory(inventory)

        // Fetch and verify empty dimensions become nil
        let fetchedInventory = try await repository.fetchInventory(byId: createdInventory.id)
        let unwrappedInventory = try #require(fetchedInventory)

        #expect(unwrappedInventory.dimensions == nil)
    }

    @Test("Sheet type with sheet-specific dimensions")
    func sheetTypeWithDimensions() async throws {
        let sheetDimensions = [
            "thickness": 3.0,
            "width": 30.0,
            "height": 40.0
        ]
        let inventory = InventoryModel(
            item_natural_key: "test-sheet",
            type: "sheet",
            subtype: "transparent",
            dimensions: sheetDimensions,
            quantity: 2.0
        )

        let createdInventory = try await repository.createInventory(inventory)

        #expect(createdInventory.type == "sheet")
        #expect(createdInventory.subtype == "transparent")
        #expect(createdInventory.dimensions?["thickness"] == 3.0)
        #expect(createdInventory.dimensions?["width"] == 30.0)
        #expect(createdInventory.dimensions?["height"] == 40.0)
    }
}
