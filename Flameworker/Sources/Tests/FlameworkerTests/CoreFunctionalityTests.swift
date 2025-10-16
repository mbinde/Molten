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
struct CoreFunctionalityTests {
    
    // MARK: - Test Setup
    
    private func createCoreServices() async -> (CatalogService, InventoryTrackingService) {
        // Configure for testing with clean slate
        RepositoryFactory.configureForTesting()
        
        // Create the core services through factory
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        return (catalogService, inventoryTrackingService)
    }
    
    // MARK: - Core Repository Tests
    
    @Test("RepositoryFactory creates core repositories")
    func testCoreRepositoryCreation() async throws {
        RepositoryFactory.configureForTesting()
        
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let inventoryRepo = RepositoryFactory.createInventoryRepository()
        // Note: locationRepo and itemTagsRepo disabled for core focus
        
        // Core repositories should be created
        #expect(glassItemRepo is MockGlassItemRepository)
        #expect(inventoryRepo is MockInventoryRepository)
    }
    
    @Test("RepositoryFactory creates core services")
    func testCoreServiceCreation() async throws {
        let (catalogService, inventoryTrackingService) = await createCoreServices()
        
        // Services should be created successfully
        #expect(catalogService != nil)
        #expect(inventoryTrackingService != nil)
    }
    
    // MARK: - Glass Item Workflow Tests
    
    @Test("Create and retrieve glass item")
    func testGlassItemBasicWorkflow() async throws {
        let (catalogService, _) = await createCoreServices()
        
        // Create a simple glass item
        let testItem = GlassItemModel(
            naturalKey: "test-rod-001",
            name: "Test Rod",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfrStatus: "available"
        )
        
        // Create the item
        let createdItem = try await catalogService.createGlassItem(testItem, initialInventory: [], tags: [])
        #expect(createdItem.naturalKey == "test-rod-001")
        #expect(createdItem.name == "Test Rod")
        
        // Retrieve all items to verify creation
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.count == 1)
        #expect(allItems.first?.naturalKey == "test-rod-001")
    }
    
    @Test("Create multiple glass items")
    func testMultipleGlassItems() async throws {
        let (catalogService, _) = await createCoreServices()
        
        // Create multiple glass items
        let items = [
            GlassItemModel(naturalKey: "bullseye-001-0", name: "Clear Rod", sku: "001", manufacturer: "bullseye", coe: 90, mfrStatus: "available"),
            GlassItemModel(naturalKey: "spectrum-002-0", name: "Red Sheet", sku: "002", manufacturer: "spectrum", coe: 96, mfrStatus: "available"),
            GlassItemModel(naturalKey: "kokomo-003-0", name: "Blue Frit", sku: "003", manufacturer: "kokomo", coe: 96, mfrStatus: "discontinued")
        ]
        
        // Create all items
        for item in items {
            try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Verify all items were created
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.count == 3)
        
        // Verify specific items
        let naturalKeys = allItems.map { $0.naturalKey }
        #expect(naturalKeys.contains("bullseye-001-0"))
        #expect(naturalKeys.contains("spectrum-002-0"))
        #expect(naturalKeys.contains("kokomo-003-0"))
    }
    
    // MARK: - Inventory Workflow Tests
    
    @Test("Create and manage inventory")
    func testInventoryBasicWorkflow() async throws {
        let (catalogService, inventoryTrackingService) = await createCoreServices()
        
        // First create a glass item
        let glassItem = GlassItemModel(
            naturalKey: "inventory-test-item",
            name: "Inventory Test Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfrStatus: "available"
        )
        let createdItem = try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        // Create inventory for this item
        let inventory = InventoryModel(
            itemNaturalKey: createdItem.naturalKey,
            type: "rod",
            quantity: 10.5
        )
        
        let createdInventory = try await inventoryTrackingService.inventoryRepository.createInventory(inventory)
        #expect(createdInventory.quantity == 10.5)
        #expect(createdInventory.type == "rod")
        
        // Retrieve inventory
        let retrievedInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: createdItem.naturalKey)
        #expect(retrievedInventory.count == 1)
        #expect(retrievedInventory.first?.quantity == 10.5)
    }
    
    @Test("Manage multiple inventory types")
    func testMultipleInventoryTypes() async throws {
        let (catalogService, inventoryTrackingService) = await createCoreServices()
        
        // Create a glass item
        let glassItem = GlassItemModel(
            naturalKey: "multi-inventory-item",
            name: "Multi Type Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfrStatus: "available"
        )
        try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        // Create different inventory types for the same item
        let inventoryRecords = [
            InventoryModel(itemNaturalKey: glassItem.naturalKey, type: "rod", quantity: 5.0),
            InventoryModel(itemNaturalKey: glassItem.naturalKey, type: "sheet", quantity: 3.5),
            InventoryModel(itemNaturalKey: glassItem.naturalKey, type: "frit", quantity: 12.0)
        ]
        
        // Create all inventory records
        for inventory in inventoryRecords {
            try await inventoryTrackingService.inventoryRepository.createInventory(inventory)
        }
        
        // Retrieve all inventory for the item
        let allInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: glassItem.naturalKey)
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
        let (catalogService, inventoryTrackingService) = await createCoreServices()
        
        // Step 1: Create glass item
        let glassItem = GlassItemModel(
            naturalKey: "bullseye-clear-rod-5mm",
            name: "Bullseye Clear Rod 5mm",
            sku: "0001",
            manufacturer: "bullseye",
            coe: 90,
            mfrStatus: "available"
        )
        let createdItem = try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        // Step 2: Add initial inventory
        let inventory = InventoryModel(
            itemNaturalKey: createdItem.naturalKey,
            type: "rod",
            quantity: 25.0
        )
        try await inventoryTrackingService.inventoryRepository.createInventory(inventory)
        
        // Step 3: Verify everything is connected
        let retrievedItems = try await catalogService.getAllGlassItems()
        let retrievedInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: "bullseye-clear-rod-5mm")
        
        #expect(retrievedItems.count == 1)
        #expect(retrievedItems.first?.name == "Bullseye Clear Rod 5mm")
        #expect(retrievedInventory.count == 1)
        #expect(retrievedInventory.first?.quantity == 25.0)
        #expect(retrievedInventory.first?.type == "rod")
    }
    
    @Test("Inventory quantity updates")
    func testInventoryUpdates() async throws {
        let (catalogService, inventoryTrackingService) = await createCoreServices()
        
        // Create item and inventory
        let glassItem = GlassItemModel(
            naturalKey: "update-test-item",
            name: "Update Test Item", 
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfrStatus: "available"
        )
        try await catalogService.createGlassItem(glassItem, initialInventory: [], tags: [])
        
        let originalInventory = InventoryModel(
            itemNaturalKey: glassItem.naturalKey,
            type: "rod",
            quantity: 10.0
        )
        let createdInventory = try await inventoryTrackingService.inventoryRepository.createInventory(originalInventory)
        
        // Update the inventory quantity
        let updatedInventory = InventoryModel(
            id: createdInventory.id,
            itemNaturalKey: glassItem.naturalKey,
            type: "rod",
            quantity: 15.0
        )
        let result = try await inventoryTrackingService.inventoryRepository.updateInventory(updatedInventory)
        
        #expect(result.quantity == 15.0)
        
        // Verify the update persisted
        let retrievedInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: glassItem.naturalKey)
        #expect(retrievedInventory.first?.quantity == 15.0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle non-existent items gracefully")
    func testErrorHandling() async throws {
        let (_, inventoryTrackingService) = await createCoreServices()
        
        // Try to fetch inventory for non-existent item
        let inventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(forItem: "non-existent-item")
        #expect(inventory.isEmpty)
    }
    
    @Test("Handle empty inventory states")
    func testEmptyStates() async throws {
        let (catalogService, inventoryTrackingService) = await createCoreServices()
        
        // Initial state should be empty
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.isEmpty)
        
        let allInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        #expect(allInventory.isEmpty)
    }
    
    // MARK: - Search Tests
    
    @Test("Basic glass item search")
    func testGlassItemSearch() async throws {
        let (catalogService, _) = await createCoreServices()
        
        // Create test items
        let items = [
            GlassItemModel(naturalKey: "bullseye-red-001", name: "Red Transparent", sku: "001", manufacturer: "bullseye", coe: 90, mfrStatus: "available"),
            GlassItemModel(naturalKey: "bullseye-blue-002", name: "Blue Opaque", sku: "002", manufacturer: "bullseye", coe: 90, mfrStatus: "available"),
            GlassItemModel(naturalKey: "spectrum-green-001", name: "Green Cathedral", sku: "001", manufacturer: "spectrum", coe: 96, mfrStatus: "available")
        ]
        
        for item in items {
            try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Test search functionality
        let searchRequest = GlassItemSearchRequest(searchText: "bullseye")
        let searchResults = try await catalogService.searchGlassItems(request: searchRequest)
        
        #expect(searchResults.items.count == 2)
        
        // Verify all results are from bullseye
        let manufacturers = searchResults.items.map { $0.manufacturer }
        #expect(manufacturers.allSatisfy { $0 == "bullseye" })
    }
}