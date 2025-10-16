//
//  CoreDataRepositoryTests.swift  
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//
// Target: RepositoryTests


import Testing
import CoreData
@testable import Flameworker

@Suite("Core Data Repository Integration Tests")
struct CoreDataRepositoryTests {
    
    let persistentContainer: NSPersistentContainer
    let mockGlassItemRepo: MockGlassItemRepository
    let mockInventoryRepo: MockInventoryRepository
    
    init() throws {
        // Create in-memory Core Data stack for testing
        persistentContainer = NSPersistentContainer(name: "Flameworker")
        
        // Use in-memory store for testing
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
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
        
        // Create mock repositories for testing
        mockGlassItemRepo = MockGlassItemRepository()
        mockInventoryRepo = MockInventoryRepository()
    }
    
    @Test("Service integration with mocks")
    func testServiceIntegrationWithMocks() async throws {
        // Pre-populate mock with test data
        let testGlassItem = GlassItemModel(
            natural_key: "cim-001-0",
            name: "Service Test Glass",
            sku: "001",
            manufacturer: "cim",
            mfrNotes: nil,
            coe: 96,
            url: nil,
            mfrStatus: "available"
        )
        
        // Add test item to mock repository
        _ = try await mockGlassItemRepo.createItem(testGlassItem)
        
        // Test basic repository operations
        let allItems = try await mockGlassItemRepo.fetchItems(matching: nil)
        #expect(!allItems.isEmpty, "Should have glass items")
        
        let foundItem = try await mockGlassItemRepo.fetchItem(byNaturalKey: "cim-001-0")
        #expect(foundItem != nil, "Should find our created item")
        #expect(foundItem?.name == "Service Test Glass", "Should have correct name")
    }
    
    @Test("Mock repository operations work correctly")
    func testMockRepositoryOperations() async throws {
        // Test with empty repository initially
        let emptyItems = try await mockGlassItemRepo.fetchItems(matching: nil)
        #expect(emptyItems.isEmpty, "Empty repository should return empty results")
        
        // Add multiple test items
        let testItems = [
            GlassItemModel(natural_key: "corp1-g1-0", name: "Glass One", sku: "g1", manufacturer: "corp1", coe: 96, mfrStatus: "available"),
            GlassItemModel(natural_key: "corp1-g2-0", name: "Glass Two", sku: "g2", manufacturer: "corp1", coe: 104, mfrStatus: "available"),
            GlassItemModel(natural_key: "corp2-g3-0", name: "Glass Three", sku: "g3", manufacturer: "corp2", coe: 96, mfrStatus: "discontinued")
        ]
        
        for item in testItems {
            _ = try await mockGlassItemRepo.createItem(item)
        }
        
        // Test fetching all items
        let allItems = try await mockGlassItemRepo.fetchItems(matching: nil)
        #expect(allItems.count == 3, "Should have all 3 test items")
        
        // Test fetching specific item
        let specificItem = try await mockGlassItemRepo.fetchItem(byNaturalKey: "corp1-g2-0")
        #expect(specificItem != nil, "Should find specific item")
        #expect(specificItem?.name == "Glass Two", "Should have correct name")
        #expect(specificItem?.sku == "g2", "Should have correct SKU")
        
        // Test searching by manufacturer
        let corp1Items = try await mockGlassItemRepo.fetchItems(byManufacturer: "corp1")
        #expect(corp1Items.count == 2, "Should find 2 items from corp1")
        
        // Test searching by COE
        let coe96Items = try await mockGlassItemRepo.fetchItems(byCOE: 96)
        #expect(coe96Items.count == 2, "Should find 2 items with COE 96")
        
        // Test searching by status
        let availableItems = try await mockGlassItemRepo.fetchItems(byStatus: "available")
        #expect(availableItems.count == 2, "Should find 2 available items")
    }
    
    @Test("Inventory repository operations work correctly")
    func testInventoryRepositoryOperations() async throws {
        // Test inventory operations
        let testInventory = InventoryModel(
            item_natural_key: "test-item-1",
            type: "rod",
            quantity: 5.0
        )
        
        let createdInventory = try await mockInventoryRepo.createInventory(testInventory)
        #expect(createdInventory.item_natural_key == "test-item-1", "Should have correct item natural key")
        #expect(createdInventory.type == "rod", "Should have correct type")
        #expect(createdInventory.quantity == 5.0, "Should have correct quantity")
        
        // Test fetching inventory
        let fetchedInventories = try await mockInventoryRepo.fetchInventory(forItem: "test-item-1")
        #expect(!fetchedInventories.isEmpty, "Should find inventory for item")
        #expect(fetchedInventories.first?.type == "rod", "Should have correct type")
    }
    
    @Test("Natural key generation works correctly")
    func testNaturalKeyGeneration() async throws {
        // Test natural key parsing with valid format
        let parsed = GlassItemModel.parseNaturalKey("cim-123-0")
        #expect(parsed != nil, "Should parse valid natural key")
        
        if let parsedComponents = parsed {
            #expect(parsedComponents.manufacturer == "cim", "Should extract manufacturer")
            #expect(parsedComponents.sku == "123", "Should extract SKU") 
            #expect(parsedComponents.sequence == 0, "Should extract sequence")
        }
        
        // Test natural key creation
        let created = GlassItemModel.createNaturalKey(manufacturer: "bullseye", sku: "001", sequence: 0)
        #expect(created == "bullseye-001-0", "Should create correct natural key format")
        
        // Test parsing invalid formats
        let invalidParsed = GlassItemModel.parseNaturalKey("invalid-format")
        #expect(invalidParsed == nil, "Should return nil for invalid format")
        
        let tooFewComponents = GlassItemModel.parseNaturalKey("only-two")
        #expect(tooFewComponents == nil, "Should return nil for too few components")
    }
}
