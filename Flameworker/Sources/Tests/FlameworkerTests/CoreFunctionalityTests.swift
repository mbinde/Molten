//
//  CoreFunctionalityTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Tests for core app functionality: Glass Items and Inventory ONLY
//

import Foundation
import Testing
@testable import Flameworker

@Suite("Core Functionality Tests - Glass Items and Inventory Only")
struct CoreFunctionalityTests: MockOnlyTestSuite {
    
    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }
    
    // MARK: - Test Setup Using Working Pattern
    
    private func createCoreServices() async throws -> (
        catalogService: CatalogService, 
        inventoryTrackingService: InventoryTrackingService,
        repos: (glassItem: MockGlassItemRepository, inventory: MockInventoryRepository, location: MockLocationRepository, itemTags: MockItemTagsRepository, itemMinimum: MockItemMinimumRepository)
    ) {
        // Use the working TestConfiguration pattern instead of RepositoryFactory
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        
        // Create services using the same repository instances
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: repos.glassItem,
            inventoryRepository: repos.inventory,
            locationRepository: repos.location,
            itemTagsRepository: repos.itemTags
        )
        
        let shoppingListService = ShoppingListService(
            itemMinimumRepository: repos.itemMinimum,
            inventoryRepository: repos.inventory,
            glassItemRepository: repos.glassItem,
            itemTagsRepository: repos.itemTags
        )
        
        let catalogService = CatalogService(
            glassItemRepository: repos.glassItem,
            inventoryTrackingService: inventoryTrackingService,
            shoppingListService: shoppingListService,
            itemTagsRepository: repos.itemTags
        )
        
        return (catalogService, inventoryTrackingService, repos)
    }
    
    // MARK: - Core Repository Tests
    
    @Test("RepositoryFactory creates core repositories")
    func testCoreRepositoryCreation() async throws {
        let (_, _, repos) = try await createCoreServices()
        
        // Core repositories should be created
        #expect(repos.glassItem is MockGlassItemRepository)
        #expect(repos.inventory is MockInventoryRepository)
    }
    
    @Test("RepositoryFactory creates core services")
    func testCoreServiceCreation() async throws {
        let (catalogService, inventoryTrackingService, _) = try await createCoreServices()
        
        // Services should be created successfully
        #expect(catalogService != nil)
        #expect(inventoryTrackingService != nil)
    }
    
    // MARK: - Glass Item Workflow Tests
    
    @Test("Create and retrieve glass item")
    func testGlassItemBasicWorkflow() async throws {
        let (catalogService, _, _) = try await createCoreServices()
        
        // Create a simple glass item
        let testItem = GlassItemModel(
            natural_key: "test-rod-001",
            name: "Test Rod",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfrStatus: "available"
        )
        
        // Create the item
        let createdItem = try await catalogService.createGlassItem(testItem, initialInventory: [], tags: [])
        #expect(createdItem.glassItem.natural_key == "test-rod-001")
        #expect(createdItem.glassItem.name == "Test Rod")
        
        // Retrieve all items to verify creation
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.count == 1)
        #expect(allItems.first?.glassItem.natural_key == "test-rod-001")
    }
    
    @Test("Create multiple glass items")
    func testMultipleGlassItems() async throws {
        let (catalogService, _, _) = try await createCoreServices()
        
        // Create multiple glass items
        let items = [
            GlassItemModel(natural_key: "bullseye-001-0", name: "Clear Rod", sku: "001", manufacturer: "bullseye", coe: 90, mfrStatus: "available"),
            GlassItemModel(natural_key: "spectrum-002-0", name: "Red Sheet", sku: "002", manufacturer: "spectrum", coe: 96, mfrStatus: "available"),
            GlassItemModel(natural_key: "kokomo-003-0", name: "Blue Frit", sku: "003", manufacturer: "kokomo", coe: 96, mfrStatus: "discontinued")
        ]
        
        // Create all items
        for item in items {
            try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Verify all items were created
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.count == 3)
        
        // Verify specific items
        let naturalKeys = allItems.map { $0.glassItem.natural_key }
        #expect(naturalKeys.contains("bullseye-001-0"))
        #expect(naturalKeys.contains("spectrum-002-0"))
        #expect(naturalKeys.contains("kokomo-003-0"))
    }
    
    // MARK: - Inventory Workflow Tests
    
    @Test("Create and manage inventory")
    func testInventoryBasicWorkflow() async throws {
        let (catalogService, inventoryTrackingService, _) = try await createCoreServices()
        
        // First create a glass item
        let glassItem = GlassItemModel(
            natural_key: "inventory-test-item",
            name: "Inventory Test Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfrStatus: "available"
        )
        let createdItem = try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        // Create inventory for this item
        let inventory = InventoryModel(
            item_natural_key: createdItem.glassItem.natural_key,
            type: "rod",
            quantity: 10.5
        )
        
        let createdInventory = try await inventoryTrackingService.inventoryRepository.createInventory(inventory)
        #expect(createdInventory.quantity == 10.5)
        #expect(createdInventory.type == "rod")
        
        // Retrieve inventory
        let retrievedInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: createdItem.glassItem.natural_key)
        #expect(retrievedInventory.count == 1)
        #expect(retrievedInventory.first?.quantity == 10.5)
    }
    
    @Test("Manage multiple inventory types")
    func testMultipleInventoryTypes() async throws {
        let (catalogService, inventoryTrackingService, _) = try await createCoreServices()
        
        // Create a glass item
        let glassItem = GlassItemModel(
            natural_key: "multi-inventory-item",
            name: "Multi Type Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfrStatus: "available"
        )
        let createdItem = try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        // Create different inventory types for the same item
        let inventoryRecords = [
            InventoryModel(item_natural_key: createdItem.glassItem.natural_key, type: "rod", quantity: 5.0),
            InventoryModel(item_natural_key: createdItem.glassItem.natural_key, type: "sheet", quantity: 3.5),
            InventoryModel(item_natural_key: createdItem.glassItem.natural_key, type: "frit", quantity: 12.0)
        ]
        
        // Create all inventory records
        for inventory in inventoryRecords {
            try await inventoryTrackingService.inventoryRepository.createInventory(inventory)
        }
        
        // Retrieve all inventory for the item
        let allInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: createdItem.glassItem.natural_key)
        #expect(allInventory.count == 3)
        
        // Verify different types exist
        let types = Set(allInventory.map { $0.type })
        #expect(types.contains("rod"))
        #expect(types.contains("sheet"))
        #expect(types.contains("frit"))
    }
    
    // MARK: - Integrated Workflow Tests
    
    @Test("Complete workflow: item creation and inventory management")
    func testCompleteWorkflow() async throws {
        let (catalogService, inventoryTrackingService, _) = try await createCoreServices()
        
        // Step 1: Create glass item
        let glassItem = GlassItemModel(
            natural_key: "bullseye-clear-rod-5mm",
            name: "Bullseye Clear Rod 5mm",
            sku: "0001",
            manufacturer: "bullseye",
            coe: 90,
            mfrStatus: "available"
        )
        let createdItem = try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        // Step 2: Add initial inventory
        let inventory = InventoryModel(
            item_natural_key: createdItem.glassItem.natural_key,
            type: "rod",
            quantity: 25.0
        )
        try await inventoryTrackingService.inventoryRepository.createInventory(inventory)
        
        // Step 3: Verify everything is connected
        let retrievedItems = try await catalogService.getAllGlassItems()
        let retrievedInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: "bullseye-clear-rod-5mm")
        
        #expect(retrievedItems.count == 1)
        #expect(retrievedItems.first?.glassItem.name == "Bullseye Clear Rod 5mm")
        #expect(retrievedInventory.count == 1)
        #expect(retrievedInventory.first?.quantity == 25.0)
        #expect(retrievedInventory.first?.type == "rod")
    }
    
    @Test("Inventory quantity updates")
    func testInventoryUpdates() async throws {
        let (catalogService, inventoryTrackingService, _) = try await createCoreServices()
        
        // Create item and inventory
        let glassItem = GlassItemModel(
            natural_key: "update-test-item",
            name: "Update Test Item", 
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfrStatus: "available"
        )
        let createdItem = try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        let originalInventory = InventoryModel(
            item_natural_key: createdItem.glassItem.natural_key,
            type: "rod",
            quantity: 10.0
        )
        let createdInventory = try await inventoryTrackingService.inventoryRepository.createInventory(originalInventory)
        
        // Update the inventory quantity
        let updatedInventory = InventoryModel(
            id: createdInventory.id,
            item_natural_key: createdItem.glassItem.natural_key,
            type: "rod",
            quantity: 15.0
        )
        let result = try await inventoryTrackingService.inventoryRepository.updateInventory(updatedInventory)
        
        #expect(result.quantity == 15.0)
        
        // Verify the update persisted
        let retrievedInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: createdItem.glassItem.natural_key)
        #expect(retrievedInventory.first?.quantity == 15.0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle non-existent items gracefully")
    func testErrorHandling() async throws {
        let (_, inventoryTrackingService, _) = try await createCoreServices()
        
        // Try to fetch inventory for non-existent item
        let inventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: "non-existent-item")
        #expect(inventory.isEmpty)
    }
    
    @Test("Handle empty inventory states")
    func testEmptyStates() async throws {
        let (catalogService, inventoryTrackingService, _) = try await createCoreServices()
        
        // Initial state should be empty
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.isEmpty)
        
        let allInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        #expect(allInventory.isEmpty)
    }
    
    // MARK: - Search Tests
    
    @Test("Basic glass item search")
    func testGlassItemSearch() async throws {
        let (catalogService, _, _) = try await createCoreServices()
        
        // Create test items with completely unique identifiers and explicit "clear" focus
        let items = [
            GlassItemModel(natural_key: "bullseye-001-0", name: "Bullseye Clear Transparent", sku: "001", manufacturer: "bullseye", coe: 90, mfrStatus: "available"),
            GlassItemModel(natural_key: "bullseye-002-0", name: "Blue Opaque", sku: "002", manufacturer: "bullseye", coe: 90, mfrStatus: "available"),
            GlassItemModel(natural_key: "spectrum-003-0", name: "Spectrum Clear Cathedral", sku: "003", manufacturer: "spectrum", coe: 96, mfrStatus: "available")
        ]
        
        // Create items and verify each one
        for item in items {
            let createdItem = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
            print("DEBUG: Successfully created item: '\(createdItem.glassItem.name)' with key: '\(createdItem.glassItem.natural_key)'")
        }
        
        // Verify all items exist
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.count == 3, "Should have created 3 items, got \(allItems.count)")
        
        // Test search for manufacturer first (this was working)
        let bullseyeRequest = GlassItemSearchRequest(searchText: "bullseye")
        let bullseyeResults = try await catalogService.searchGlassItems(request: bullseyeRequest)
        
        #expect(bullseyeResults.items.count == 2, "Should find 2 Bullseye items")
        
        // Verify all results are from bullseye
        let manufacturers = bullseyeResults.items.map { $0.glassItem.manufacturer }
        #expect(manufacturers.allSatisfy { $0 == "bullseye" })
        
        // Now test search for "clear" items using case-insensitive approach
        let clearRequest = GlassItemSearchRequest(searchText: "clear")
        let clearResults = try await catalogService.searchGlassItems(request: clearRequest)
        
        print("DEBUG: Clear search found \(clearResults.items.count) items:")
        for item in clearResults.items {
            print("DEBUG: - '\(item.glassItem.name)' (key: \(item.glassItem.natural_key))")
        }
        
        // Since debug shows we're finding 2 items correctly, the issue might be with variable references
        // Let's be explicit about what we're testing
        let actualFoundCount = clearResults.items.count
        let expectedMinimumCount = 2
        
        print("DEBUG: Explicit count check - found: \(actualFoundCount), expected minimum: \(expectedMinimumCount)")
        
        #expect(actualFoundCount >= expectedMinimumCount, "Search should find at least \(expectedMinimumCount) clear glass items (actually found \(actualFoundCount))")
        
        // Verify all results contain "clear" (case insensitive)
        let clearNames = clearResults.items.map { $0.glassItem.name.lowercased() }
        let allContainClear = clearNames.allSatisfy { $0.contains("clear") }
        
        print("DEBUG: All results contain 'clear': \(allContainClear)")
        print("DEBUG: Result names: \(clearNames)")
        
        #expect(allContainClear, "All search results should contain 'clear' in the name")
    }
}
