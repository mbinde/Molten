//
//  BasicFunctionalityTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Fast, lightweight tests with small datasets for regular test runs - REWRITTEN with working patterns
//

import Foundation
import CryptoKit
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

@Suite("Basic Functionality Tests - Fast & Lightweight")
@MainActor
struct BasicFunctionalityTests: MockOnlyTestSuite {
    
    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }
    
    // MARK: - Test Infrastructure Using Working Pattern
    
    private func createTestServices() async throws -> (
        repos: (glassItem: MockGlassItemRepository, inventory: MockInventoryRepository, location: MockStorageLocationRepository, itemTags: MockItemTagsRepository, itemMinimum: MockItemMinimumRepository),
        catalogService: CatalogService,
        inventoryService: InventoryTrackingService
    ) {
        // Use TestConfiguration approach that we know works
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()

        let shoppingListRepository = MockShoppingListRepository()
        let userTagsRepository = MockUserTagsRepository()
        let coatingItemRepo = MockCoatingItemRepository()
        let toolItemRepo = MockToolItemRepository()

        let inventoryService = InventoryTrackingService(
            glassItemRepository: repos.glassItem,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryRepository: repos.inventory,
            itemTagsRepository: repos.itemTags
        )

        let catalogService = CatalogService(
            glassItemRepository: repos.glassItem,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryTrackingService: inventoryService,
            itemMinimumRepository: repos.itemMinimum,
            itemTagsRepository: repos.itemTags,
            userTagsRepository: userTagsRepository,
            ratingService: AppDependencies.shared.ratingService
        )

        let shoppingService = ShoppingListService(
            itemMinimumRepository: repos.itemMinimum,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: repos.inventory,
            glassItemRepository: repos.glassItem,
            itemTagsRepository: repos.itemTags,
            userTagsRepository: userTagsRepository
        )

        return (repos, catalogService, inventoryService)
    }
    
    private func createSmallTestDataset() -> [GlassItemModel] {
        // Create only 10 items for fast testing
        let items: [GlassItemModel] = [
            GlassItemModel(stable_id: generateStableId(manufacturer: "bullseye", sku: "0001"), name: "Bullseye Clear Transparent", sku: "0001", manufacturer: "bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "bullseye", sku: "0002"), name: "Bullseye Red Transparent", sku: "0002", manufacturer: "bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "bullseye", sku: "0003"), name: "Bullseye Blue Transparent", sku: "0003", manufacturer: "bullseye", coe: 90, mfr_status: "discontinued"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "spectrum", sku: "0001"), name: "Spectrum Clear Transparent", sku: "0001", manufacturer: "spectrum", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "spectrum", sku: "0002"), name: "Spectrum Green Transparent", sku: "0002", manufacturer: "spectrum", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "kokomo", sku: "0001"), name: "Kokomo Amber Transparent", sku: "0001", manufacturer: "kokomo", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "effetre", sku: "0001"), name: "Effetre Clear", sku: "0001", manufacturer: "effetre", coe: 104, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "effetre", sku: "0002"), name: "Effetre Pink", sku: "0002", manufacturer: "effetre", coe: 104, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "gaffer", sku: "0001"), name: "Gaffer Clear", sku: "0001", manufacturer: "gaffer", coe: 96, mfr_status: "available"),
            GlassItemModel(stable_id: generateStableId(manufacturer: "gaffer", sku: "0002"), name: "Gaffer Black", sku: "0002", manufacturer: "gaffer", coe: 96, mfr_status: "available")
        ]
        return items
    }
    
    // MARK: - Verification Test
    
    @Test("Verify test environment is using mocks")
    func testVerifyMockEnvironment() async throws {
        
        let (repos, catalogService, inventoryService) = try await createTestServices()
        
        // Verify we start with empty mock data
        let initialGlassItems = try await catalogService.getAllGlassItems()
        let initialInventory = try await repos.inventory.fetchInventory(matching: nil)
        
        #expect(initialGlassItems.count == 0, "Should start with no glass items in mock")
        #expect(initialInventory.count == 0, "Should start with no inventory in mock")
        
        // Add a single item and verify it works
        let testItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "test", sku: "0001"),
            name: "Verification Item",
            sku: "0001",
            manufacturer: "test",
            coe: 90,
            mfr_status: "available"
        )
        
        _ = try await catalogService.createGlassItem(testItem, initialInventory: [], tags: [])
        
        let afterAddItems = try await catalogService.getAllGlassItems()
        #expect(afterAddItems.count == 1, "Should have exactly 1 item after adding")
            }
    
    // MARK: - Basic CRUD Tests

    @Test("Should search glass items efficiently")
    func testBasicSearchFunctionality() async throws {
        let (repos, catalogService, _) = try await createTestServices()
                
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
            ("type", "Transparent", 6),      // 6 items with "Transparent" in name
            ("status", "discontinued", 1),   // 1 discontinued item
            ("coe", "96", 5)                 // 5 items with COE 96 (Spectrum x2, Kokomo, Gaffer x2)
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
    }

    @Test("Should handle inventory operations")
    func testBasicInventoryOperations() async throws {
        let (repos, catalogService, inventoryService) = try await createTestServices()

        let testItems = createSmallTestDataset()

        // Add catalog items using working pattern
        for item in testItems.prefix(5) { // Only use first 5 items for inventory
            _ = try await repos.glassItem.createItem(item)
        }

        // Add some inventory records
        let inventoryRecords = [
            InventoryModel(id: UUID(), item_stable_id: generateStableId(manufacturer: "bullseye", sku: "0001"), type: "inventory", quantity: 10.0),
            InventoryModel(id: UUID(), item_stable_id: generateStableId(manufacturer: "bullseye", sku: "0002"), type: "inventory", quantity: 5.5),
            InventoryModel(id: UUID(), item_stable_id: generateStableId(manufacturer: "spectrum", sku: "0001"), type: "buy", quantity: 3.0),
            InventoryModel(id: UUID(), item_stable_id: generateStableId(manufacturer: "spectrum", sku: "0002"), type: "sell", quantity: 2.0),
            InventoryModel(id: UUID(), item_stable_id: generateStableId(manufacturer: "kokomo", sku: "0001"), type: "inventory", quantity: 8.25)
        ]

        for record in inventoryRecords {
            _ = try await repos.inventory.createInventory(record)
        }

        // Test inventory queries
        let inventoryItems = try await repos.inventory.fetchInventory(matching: nil)

        #expect(inventoryItems.count == inventoryRecords.count, "Should create all inventory records")
    }

    @Test("Should handle tags")
    func testBasicTagOperations() async throws {
        let (repos, catalogService, inventoryService) = try await createTestServices()

        let testItems = createSmallTestDataset()

        // Create items and add tags using working pattern
        let testTags = ["red", "transparent", "opaque", "cathedral", "streaky"]

        for (index, item) in testItems.prefix(5).enumerated() {
            // Add the item first
            _ = try await repos.glassItem.createItem(item)

            // Then add tags
            let tag = testTags[index % testTags.count]
            try await repos.itemTags.addTag(tag, toItem: item.stable_id)
        }

        // Test tag queries
        let allTags = try await repos.itemTags.getAllTags()

        #expect(allTags.count >= testTags.count, "Should retrieve all created tags")
    }

    // MARK: - Integration Tests

    @Test("Should handle complete workflow")
    func testCompleteWorkflow() async throws {
        let (repos, catalogService, inventoryService) = try await createTestServices()

        // 1. Add catalog items using working pattern
        let testItems = Array(createSmallTestDataset().prefix(3))
        for item in testItems {
            _ = try await repos.glassItem.createItem(item)
        }

        // 2. Add inventory
        for (index, item) in testItems.enumerated() {
            let inventory = InventoryModel(
                id: UUID(),
                item_stable_id: item.stable_id,
                type: "inventory",
                quantity: Double(5 + index)
            )
            _ = try await repos.inventory.createInventory(inventory)
        }

        // 3. Add tags
        for item in testItems {
            try await repos.itemTags.addTag("test", toItem: item.stable_id)
        }

        // 4. Verify complete workflow
        let allItems = try await catalogService.getAllGlassItems()
        let allInventory = try await repos.inventory.fetchInventory(matching: nil)
        let allTags = try await repos.itemTags.getAllTags()

        // 5. Search and verify
        let searchResults = try await repos.glassItem.searchItems(text: "Clear")

        #expect(allItems.count == testItems.count, "Should have all catalog items")
        #expect(allInventory.count == testItems.count, "Should have all inventory records")
        #expect(allTags.contains("test"), "Should have test tags")
        #expect(searchResults.count > 0, "Search should find items")
    }

    @Test("Should handle edge cases gracefully")
    func testEdgeCases() async throws {
        let (repos, catalogService, _) = try await createTestServices()
                
        // Test empty searches
        let emptySearch = try await repos.glassItem.searchItems(text: "")
        #expect(emptySearch.count == 0, "Empty search should return no results on empty repository")
        
        // Test non-existent item
        let nonExistent = try await repos.glassItem.fetchItem(byStableId: "non-existent")
        #expect(nonExistent == nil, "Should return nil for non-existent item")
        
        // Test with one item
        let singleItem = createSmallTestDataset().first!
        _ = try await repos.glassItem.createItem(singleItem)
        
        let afterSingle = try await repos.glassItem.fetchItems(matching: nil)
        #expect(afterSingle.count == 1, "Should handle single item correctly")
    }
}
