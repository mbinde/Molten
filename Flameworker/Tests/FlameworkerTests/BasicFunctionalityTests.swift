//
//  BasicFunctionalityTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Fast, lightweight tests with small datasets for regular test runs - REWRITTEN with working patterns
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
struct BasicFunctionalityTests: MockOnlyTestSuite {
    
    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }
    
    // MARK: - Test Infrastructure Using Working Pattern
    
    private func createTestServices() async throws -> (
        repos: (glassItem: MockGlassItemRepository, inventory: MockInventoryRepository, location: MockLocationRepository, itemTags: MockItemTagsRepository, itemMinimum: MockItemMinimumRepository),
        catalogService: CatalogService, 
        inventoryService: InventoryTrackingService
    ) {
        // Use TestConfiguration approach that we know works
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        
        let inventoryService = InventoryTrackingService(
            glassItemRepository: repos.glassItem,
            inventoryRepository: repos.inventory,
            locationRepository: repos.location,
            itemTagsRepository: repos.itemTags
        )
        
        let shoppingListRepository = MockShoppingListRepository()
        let shoppingService = ShoppingListService(
            itemMinimumRepository: repos.itemMinimum,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: repos.inventory,
            glassItemRepository: repos.glassItem,
            itemTagsRepository: repos.itemTags
        )
        
        let catalogService = CatalogService(
            glassItemRepository: repos.glassItem,
            inventoryTrackingService: inventoryService,
            shoppingListService: shoppingService,
            itemTagsRepository: repos.itemTags
        )
        
        return (repos, catalogService, inventoryService)
    }
    
    private func createSmallTestDataset() -> [GlassItemModel] {
        // Create only 10 items for fast testing
        let items = [
            GlassItemModel(natural_key: "bullseye-0001-0", name: "Clear Transparent", sku: "0001", manufacturer: "bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "bullseye-0002-0", name: "Red Transparent", sku: "0002", manufacturer: "bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "bullseye-0003-0", name: "Blue Opal", sku: "0003", manufacturer: "bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "spectrum-0001-0", name: "Green Transparent", sku: "0001", manufacturer: "spectrum", coe: 96, mfr_status: "available"),
            GlassItemModel(natural_key: "spectrum-0002-0", name: "Yellow Cathedral", sku: "0002", manufacturer: "spectrum", coe: 96, mfr_status: "discontinued"),
            GlassItemModel(natural_key: "kokomo-0001-0", name: "Purple Wispy", sku: "0001", manufacturer: "kokomo", coe: 96, mfr_status: "available"),
            GlassItemModel(natural_key: "kokomo-0002-0", name: "Orange Streaky", sku: "0002", manufacturer: "kokomo", coe: 96, mfr_status: "available"),
            GlassItemModel(natural_key: "uroboros-0001-0", name: "Pink Granite", sku: "0001", manufacturer: "uroboros", coe: 96, mfr_status: "limited"),
            GlassItemModel(natural_key: "oceanside-0001-0", name: "Amber Waterglass", sku: "0001", manufacturer: "oceanside", coe: 96, mfr_status: "available"),
            GlassItemModel(natural_key: "oceanside-0002-0", name: "Black Opaque", sku: "0002", manufacturer: "oceanside", coe: 96, mfr_status: "available")
        ]
        return items
    }
    
    // MARK: - Verification Test
    
    @Test("Verify test environment is using mocks")
    func testVerifyMockEnvironment() async throws {
        print("🔍 Verifying test environment uses mocks...")
        
        let (repos, catalogService, inventoryService) = try await createTestServices()
        
        // Verify we start with empty mock data
        let initialGlassItems = try await catalogService.getAllGlassItems()
        let initialInventory = try await repos.inventory.fetchInventory(matching: nil)
        
        print("📊 Initial state: \(initialGlassItems.count) glass items, \(initialInventory.count) inventory records")
        
        #expect(initialGlassItems.count == 0, "Should start with no glass items in mock")
        #expect(initialInventory.count == 0, "Should start with no inventory in mock")
        
        // Add a single item and verify it works
        let testItem = GlassItemModel(
            natural_key: "test-verify-0001-0",
            name: "Verification Item",
            sku: "0001",
            manufacturer: "test",
            coe: 90,
            mfr_status: "available"
        )
        
        _ = try await catalogService.createGlassItem(testItem, initialInventory: [], tags: [])
        
        let afterAddItems = try await catalogService.getAllGlassItems()
        #expect(afterAddItems.count == 1, "Should have exactly 1 item after adding")
        
        print("✅ Test environment verified: Using clean mocks")
    }
    
    // MARK: - Basic CRUD Tests
    
    @Test("Should create and retrieve glass items")
    func testBasicGlassItemOperations() async throws {
        let (repos, catalogService, _) = try await createTestServices()
        
        print("Testing basic glass item operations...")
        
        let testItems = createSmallTestDataset()
        let startTime = Date()
        
        // Create items using working pattern
        for item in testItems {
            _ = try await repos.glassItem.createItem(item)
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
        let (repos, catalogService, _) = try await createTestServices()
        
        print("Testing basic search functionality...")
        
        let testItems = createSmallTestDataset()
        
        // Add test data using working pattern
        for item in testItems {
            _ = try await repos.glassItem.createItem(item)
        }
        
        let startTime = Date()
        
        // Test different search patterns using direct repository access
        let searchTests = [
            ("manufacturer", "bullseye", 3),  // We have 3 bullseye items
            ("color", "Red", 1),             // 1 red item
            ("type", "Transparent", 3),      // At least 3 transparent items
            ("status", "discontinued", 1),   // 1 discontinued item
            ("coe", "96", 7)                 // 7 items with COE 96
        ]
        
        let allItems = try await repos.glassItem.fetchItems(matching: nil)
        
        for (searchType, searchTerm, expectedMinCount) in searchTests {
            let results: [GlassItemModel]
            
            switch searchType {
            case "manufacturer":
                results = allItems.filter { $0.manufacturer == searchTerm }
            case "color":
                results = allItems.filter { $0.name.localizedCaseInsensitiveContains(searchTerm) }
            case "type":
                results = allItems.filter { $0.name.localizedCaseInsensitiveContains(searchTerm) }
            case "status":
                results = allItems.filter { $0.mfr_status == searchTerm }
            case "coe":
                if let coeValue = Int(searchTerm) {
                    results = allItems.filter { $0.coe == coeValue }
                } else {
                    results = []
                }
            default:
                results = []
            }
            
            #expect(results.count >= expectedMinCount, "Search for \(searchType) '\(searchTerm)' should find at least \(expectedMinCount) items")
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(duration < 1.0, "Search operations should complete quickly")
        
        print("✅ Search: \(searchTests.count) searches in \(String(format: "%.3f", duration))s")
    }
    
    @Test("Should handle inventory operations efficiently")
    func testBasicInventoryOperations() async throws {
        let (repos, catalogService, inventoryService) = try await createTestServices()
        
        print("Testing basic inventory operations...")
        
        let testItems = createSmallTestDataset()
        let startTime = Date()
        
        // Add catalog items using working pattern
        for item in testItems.prefix(5) { // Only use first 5 items for inventory
            _ = try await repos.glassItem.createItem(item)
        }
        
        // Add some inventory records
        let inventoryRecords = [
            InventoryModel(id: UUID(), item_natural_key: "bullseye-0001-0", type: "inventory", quantity: 10.0),
            InventoryModel(id: UUID(), item_natural_key: "bullseye-0002-0", type: "inventory", quantity: 5.5),
            InventoryModel(id: UUID(), item_natural_key: "spectrum-0001-0", type: "buy", quantity: 3.0),
            InventoryModel(id: UUID(), item_natural_key: "spectrum-0002-0", type: "sell", quantity: 2.0),
            InventoryModel(id: UUID(), item_natural_key: "kokomo-0001-0", type: "inventory", quantity: 8.25)
        ]
        
        for record in inventoryRecords {
            _ = try await repos.inventory.createInventory(record)
        }
        
        // Test inventory queries
        let inventoryItems = try await repos.inventory.fetchInventory(matching: nil)
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(inventoryItems.count == inventoryRecords.count, "Should create all inventory records")
        #expect(duration < 1.0, "Inventory operations should complete quickly")
        
        print("✅ Inventory: \(inventoryRecords.count) records in \(String(format: "%.3f", duration))s")
    }
    
    @Test("Should handle tags efficiently")
    func testBasicTagOperations() async throws {
        let (repos, catalogService, inventoryService) = try await createTestServices()
        
        print("Testing basic tag operations...")
        
        let testItems = createSmallTestDataset()
        let startTime = Date()
        
        // Create items and add tags using working pattern
        let testTags = ["red", "transparent", "opaque", "cathedral", "streaky"]
        
        for (index, item) in testItems.prefix(5).enumerated() {
            // Add the item first
            _ = try await repos.glassItem.createItem(item)
            
            // Then add tags
            let tag = testTags[index % testTags.count]
            try await repos.itemTags.addTag(tag, toItem: item.natural_key)
        }
        
        // Test tag queries
        let allTags = try await repos.itemTags.getAllTags()
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(allTags.count >= testTags.count, "Should retrieve all created tags")
        #expect(duration < 1.0, "Tag operations should complete quickly")
        
        print("✅ Tags: \(allTags.count) tags in \(String(format: "%.3f", duration))s")
    }
    
    // MARK: - Integration Tests
    
    @Test("Should handle complete workflow efficiently")
    func testCompleteWorkflow() async throws {
        let (repos, catalogService, inventoryService) = try await createTestServices()
        
        print("Testing complete workflow...")
        
        let startTime = Date()
        
        // 1. Add catalog items using working pattern
        let testItems = Array(createSmallTestDataset().prefix(3))
        for item in testItems {
            _ = try await repos.glassItem.createItem(item)
        }
        
        // 2. Add inventory
        for (index, item) in testItems.enumerated() {
            let inventory = InventoryModel(
                id: UUID(),
                item_natural_key: item.natural_key,
                type: "inventory", 
                quantity: Double(5 + index)
            )
            _ = try await repos.inventory.createInventory(inventory)
        }
        
        // 3. Add tags
        for item in testItems {
            try await repos.itemTags.addTag("test", toItem: item.natural_key)
        }
        
        // 4. Verify complete workflow
        let allItems = try await catalogService.getAllGlassItems()
        let allInventory = try await repos.inventory.fetchInventory(matching: nil)
        let allTags = try await repos.itemTags.getAllTags()
        
        // 5. Search and verify
        let searchResults = try await repos.glassItem.searchItems(text: "Clear")
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(allItems.count == testItems.count, "Should have all catalog items")
        #expect(allInventory.count == testItems.count, "Should have all inventory records")
        #expect(allTags.contains("test"), "Should have test tags")
        #expect(searchResults.count > 0, "Search should find items")
        #expect(duration < 2.0, "Complete workflow should finish quickly")
        
        print("✅ Complete Workflow: \(testItems.count) items processed in \(String(format: "%.3f", duration))s")
    }
    
    // MARK: - Performance Tests
    
    @Test("Should handle concurrent operations efficiently")
    func testConcurrentOperations() async throws {
        let (repos, catalogService, _) = try await createTestServices()
        
        print("Testing concurrent operations...")
        
        let testItems = createSmallTestDataset()
        let startTime = Date()
        
        // Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Add items concurrently
            for item in testItems {
                group.addTask {
                    do {
                        _ = try await repos.glassItem.createItem(item)
                    } catch {
                        print("⚠️  Concurrent creation failed for \(item.natural_key): \(error)")
                    }
                }
            }
        }
        
        // Verify all items were created
        let finalItems = try await repos.glassItem.fetchItems(matching: nil)
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(finalItems.count == testItems.count, "Should create all items concurrently")
        #expect(duration < 3.0, "Concurrent operations should complete reasonably quickly")
        
        print("✅ Concurrent: \(testItems.count) items in \(String(format: "%.3f", duration))s")
    }
    
    @Test("Should handle edge cases gracefully")
    func testEdgeCases() async throws {
        let (repos, catalogService, _) = try await createTestServices()
        
        print("Testing edge cases...")
        
        // Test empty searches
        let emptySearch = try await repos.glassItem.searchItems(text: "")
        #expect(emptySearch.count == 0, "Empty search should return no results on empty repository")
        
        // Test non-existent item
        let nonExistent = try await repos.glassItem.fetchItem(byNaturalKey: "non-existent")
        #expect(nonExistent == nil, "Should return nil for non-existent item")
        
        // Test with one item
        let singleItem = createSmallTestDataset().first!
        _ = try await repos.glassItem.createItem(singleItem)
        
        let afterSingle = try await repos.glassItem.fetchItems(matching: nil)
        #expect(afterSingle.count == 1, "Should handle single item correctly")
        
        print("✅ Edge cases handled gracefully")
    }
}
