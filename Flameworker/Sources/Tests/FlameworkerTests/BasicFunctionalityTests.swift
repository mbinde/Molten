//
//  BasicFunctionalityTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Fast, lightweight tests with small datasets for regular test runs
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("Basic Functionality Tests - Fast & Lightweight")
struct BasicFunctionalityTests {
    
    // MARK: - Test Infrastructure
    
    private func createTestServices() async -> (CatalogService, InventoryTrackingService) {
        // Create fresh mock repositories directly to avoid any Core Data contamination
        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockLocationRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let itemMinimumRepo = MockItemMinimumRepository()
        
        // Clear any existing test data
        await glassItemRepo.clearAllData()
        await inventoryRepo.clearAllData()
        await locationRepo.clearAllData()
        await itemTagsRepo.clearAllData()
        await itemMinimumRepo.clearAllData()
        
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            inventoryRepository: inventoryRepo,
            locationRepository: locationRepo,
            itemTagsRepository: itemTagsRepo
        )
        
        // Create a temporary ShoppingListService for CatalogService compatibility
        let tempShoppingListService = ShoppingListService(
            itemMinimumRepository: itemMinimumRepo,
            inventoryRepository: inventoryRepo,
            glassItemRepository: glassItemRepo,
            itemTagsRepository: itemTagsRepo
        )
        
        let catalogService = CatalogService(
            glassItemRepository: glassItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            shoppingListService: tempShoppingListService,
            itemTagsRepository: itemTagsRepo
        )
        
        return (catalogService, inventoryTrackingService)
    }
    
    // MARK: - Verification Test
    
    @Test("Verify test environment is using mocks")
    func testVerifyMockEnvironment() async throws {
        print("🔍 Verifying test environment uses mocks...")
        
        let (catalogService, inventoryTrackingService) = await createTestServices()
        
        // Verify we start with empty mock data
        let initialGlassItems = try await catalogService.getAllGlassItems()
        let initialInventory = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        
        print("📊 Initial state: \(initialGlassItems.count) glass items, \(initialInventory.count) inventory records")
        
        #expect(initialGlassItems.count == 0, "Should start with no glass items in mock")
        #expect(initialInventory.count == 0, "Should start with no inventory in mock")
        
        // Add a single item and verify it works
        let testItem = GlassItemModel(
            naturalKey: "test-verify-0001-0",
            name: "Verification Item",
            sku: "0001",
            manufacturer: "test",
            coe: 90,
            mfrStatus: "available"
        )
        
        _ = try await catalogService.createGlassItem(testItem, initialInventory: [], tags: [])
        
        let afterAddItems = try await catalogService.getAllGlassItems()
        #expect(afterAddItems.count == 1, "Should have exactly 1 item after adding")
        
        print("✅ Test environment verified: Using clean mocks")
    }
    
    private func createSmallTestDataset() -> [GlassItemModel] {
        // Create only 10 items for fast testing
        let items = [
            GlassItemModel(naturalKey: "bullseye-0001-0", name: "Clear Transparent", sku: "0001", manufacturer: "bullseye", coe: 90, mfrStatus: "available"),
            GlassItemModel(naturalKey: "bullseye-0002-0", name: "Red Transparent", sku: "0002", manufacturer: "bullseye", coe: 90, mfrStatus: "available"),
            GlassItemModel(naturalKey: "bullseye-0003-0", name: "Blue Opal", sku: "0003", manufacturer: "bullseye", coe: 90, mfrStatus: "available"),
            GlassItemModel(naturalKey: "spectrum-0001-0", name: "Green Transparent", sku: "0001", manufacturer: "spectrum", coe: 96, mfrStatus: "available"),
            GlassItemModel(naturalKey: "spectrum-0002-0", name: "Yellow Cathedral", sku: "0002", manufacturer: "spectrum", coe: 96, mfrStatus: "discontinued"),
            GlassItemModel(naturalKey: "kokomo-0001-0", name: "Purple Wispy", sku: "0001", manufacturer: "kokomo", coe: 96, mfrStatus: "available"),
            GlassItemModel(naturalKey: "kokomo-0002-0", name: "Orange Streaky", sku: "0002", manufacturer: "kokomo", coe: 96, mfrStatus: "available"),
            GlassItemModel(naturalKey: "uroboros-0001-0", name: "Pink Granite", sku: "0001", manufacturer: "uroboros", coe: 96, mfrStatus: "limited"),
            GlassItemModel(naturalKey: "oceanside-0001-0", name: "Amber Waterglass", sku: "0001", manufacturer: "oceanside", coe: 96, mfrStatus: "available"),
            GlassItemModel(naturalKey: "oceanside-0002-0", name: "Black Opaque", sku: "0002", manufacturer: "oceanside", coe: 96, mfrStatus: "available")
        ]
        return items
    }
    
    // MARK: - Basic CRUD Tests
    
    @Test("Should create and retrieve glass items")
    func testBasicGlassItemOperations() async throws {
        let (catalogService, _) = await createTestServices()
        
        print("Testing basic glass item operations...")
        
        let testItems = createSmallTestDataset()
        let startTime = Date()
        
        // Create items
        for item in testItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Retrieve all items
        let retrievedItems = try await catalogService.getAllGlassItems()
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(retrievedItems.count == testItems.count, "Should retrieve all created items")
        #expect(duration < 2.0, "Basic operations should complete quickly")
        
        print("✅ Basic CRUD: \(testItems.count) items in \(String(format: "%.3f", duration))s")
    }
    
    @Test("Should search glass items efficiently") 
    func testBasicSearchFunctionality() async throws {
        let (catalogService, _) = await createTestServices()
        
        print("Testing basic search functionality...")
        
        let testItems = createSmallTestDataset()
        
        // Add test data
        for item in testItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        let startTime = Date()
        
        // Test different search patterns
        let searchTests = [
            ("manufacturer", "bullseye", 2),
            ("color", "Red", 1),
            ("type", "Transparent", 3),
            ("status", "discontinued", 1),
            ("coe", "96", 7)  // Items with COE 96
        ]
        
        for (searchType, searchTerm, expectedMinCount) in searchTests {
            let searchRequest = GlassItemSearchRequest(searchText: searchTerm)
            let searchResult = try await catalogService.searchGlassItems(request: searchRequest)
            let results = searchResult.items
            
            #expect(results.count >= expectedMinCount, "Search for \(searchType) '\(searchTerm)' should find at least \(expectedMinCount) items")
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(duration < 1.0, "Search operations should complete quickly")
        
        print("✅ Search: \(searchTests.count) searches in \(String(format: "%.3f", duration))s")
    }
    
    @Test("Should handle inventory operations efficiently")
    func testBasicInventoryOperations() async throws {
        let (catalogService, inventoryTrackingService) = await createTestServices()
        
        print("Testing basic inventory operations...")
        
        let testItems = createSmallTestDataset()
        let startTime = Date()
        
        // Add catalog items
        for item in testItems.prefix(5) { // Only use first 5 items for inventory
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Add some inventory records
        let inventoryRecords = [
            InventoryModel(id: UUID(), itemNaturalKey: "bullseye-0001-0", type: "inventory", quantity: 10.0),
            InventoryModel(id: UUID(), itemNaturalKey: "bullseye-0002-0", type: "inventory", quantity: 5.5),
            InventoryModel(id: UUID(), itemNaturalKey: "spectrum-0001-0", type: "purchase", quantity: 3.0),
            InventoryModel(id: UUID(), itemNaturalKey: "spectrum-0002-0", type: "sale", quantity: 2.0),
            InventoryModel(id: UUID(), itemNaturalKey: "kokomo-0001-0", type: "inventory", quantity: 8.25)
        ]
        
        for record in inventoryRecords {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(record)
        }
        
        // Test inventory queries
        let inventoryItems = try await inventoryTrackingService.inventoryRepository.fetchInventory(matching: nil)
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(inventoryItems.count == inventoryRecords.count, "Should create all inventory records")
        #expect(duration < 1.0, "Inventory operations should complete quickly")
        
        print("✅ Inventory: \(inventoryRecords.count) records in \(String(format: "%.3f", duration))s")
    }
    
    @Test("Should handle tags efficiently")
    func testBasicTagOperations() async throws {
        let (catalogService, inventoryTrackingService) = await createTestServices()
        
        print("Testing basic tag operations...")
        
        let testItems = createSmallTestDataset()
        let startTime = Date()
        
        // Create items with tags
        let testTags = ["red", "transparent", "opaque", "cathedral", "streaky"]
        
        // Get the item tags repository from the inventory tracking service
        let itemTagsRepo = inventoryTrackingService.itemTagsRepository
        
        for (index, item) in testItems.prefix(5).enumerated() {
            let itemTags = [testTags[index % testTags.count]]
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: itemTags)
        }
        
        // Test tag queries using the same repository the service uses
        let allTags = try await itemTagsRepo.getAllTags()
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(allTags.count >= testTags.count, "Should retrieve all created tags")
        #expect(duration < 1.0, "Tag operations should complete quickly")
        
        print("✅ Tags: \(allTags.count) tags in \(String(format: "%.3f", duration))s")
    }
    
    /* DISABLED - ItemMinimum feature abandoned
    @Test("Should handle minimums and shopping lists efficiently")
    func testBasicMinimumOperations() async throws {
        let (catalogService, inventoryTrackingService, shoppingListService) = await createTestServices()
        
        print("Testing basic minimum/shopping list operations...")
        
        let testItems = createSmallTestDataset()
        let startTime = Date()
        
        // Add catalog items
        for item in testItems.prefix(3) {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Add inventory
        let inventoryRecords = [
            InventoryModel(id: UUID(), itemNaturalKey: "bullseye-0001-0", type: "inventory", quantity: 5.0),
            InventoryModel(id: UUID(), itemNaturalKey: "bullseye-0002-0", type: "inventory", quantity: 2.0),
            InventoryModel(id: UUID(), itemNaturalKey: "spectrum-0001-0", type: "inventory", quantity: 8.0)
        ]
        
        for record in inventoryRecords {
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(record)
        }
        
        // Set minimums
        let minimumRepo = RepositoryFactory.createItemMinimumRepository()
        
        let minimums = [
            ItemMinimumModel(id: UUID(), itemNaturalKey: "bullseye-0001-0", quantity: 10.0, type: "rod"),
            ItemMinimumModel(id: UUID(), itemNaturalKey: "bullseye-0002-0", quantity: 5.0, type: "sheet"),
            ItemMinimumModel(id: UUID(), itemNaturalKey: "spectrum-0001-0", quantity: 15.0, type: "rod")
        ]
        
        for minimum in minimums {
            _ = try await minimumRepo.createMinimum(minimum)
        }
        
        // Generate shopping list
        let shoppingList = try await shoppingListService.generateShoppingList(forStore: "test-store")
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(shoppingList.items.count > 0, "Should generate shopping list items")
        #expect(duration < 1.0, "Shopping list operations should complete quickly")
        
        print("✅ Shopping List: \(shoppingList.items.count) items in \(String(format: "%.3f", duration))s")
    }
    */ // End disabled ItemMinimum test
    
    // MARK: - Integration Tests
    
    /* DISABLED - Uses ShoppingListService which was abandoned
    @Test("Should handle complete workflow efficiently")
    func testCompleteWorkflow() async throws {
        let (catalogService, inventoryTrackingService, shoppingListService) = await createTestServices()
        
        print("Testing complete workflow...")
        
        let startTime = Date()
        
        // 1. Add catalog items
        let testItems = createSmallTestDataset().prefix(3)
        for item in testItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: ["test"])
        }
        
        // 2. Add inventory
        for (index, item) in testItems.enumerated() {
            let inventory = InventoryModel(
                id: UUID(),
                itemNaturalKey: item.naturalKey,
                type: "inventory", quantity: Double(5 + index)
            )
            _ = try await inventoryTrackingService.inventoryRepository.createInventory(inventory)
        }
        
        // 3. Set minimums
        let minimumRepo = RepositoryFactory.createItemMinimumRepository()
        for item in testItems {
            let minimum = ItemMinimumModel(
                id: UUID(),
                itemNaturalKey: item.naturalKey,
                quantity: 10.0, type: "rod"
            )
            _ = try await minimumRepo.createMinimum(minimum)
        }
        
        // 4. Generate shopping list
        let shoppingList = try await shoppingListService.generateShoppingList(forStore: "workflow-store")
        
        // 5. Search and verify
        let searchRequest = GlassItemSearchRequest(searchText: "test")
        let searchResult = try await catalogService.searchGlassItems(request: searchRequest)
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(shoppingList.items.count > 0, "Complete workflow should produce shopping list")
        #expect(searchResult.items.count == testItems.count, "Search should find all test items")
        #expect(duration < 2.0, "Complete workflow should finish quickly")
        
        print("✅ Complete Workflow: \(testItems.count) items processed in \(String(format: "%.3f", duration))s")
    }
    */ // End disabled workflow test
}

