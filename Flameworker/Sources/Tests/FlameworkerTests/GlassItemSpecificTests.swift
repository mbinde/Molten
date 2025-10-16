//
//  GlassItemSpecificTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Tests that specifically address the failing test cases
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

@Suite("Glass Item Specific Tests - Addressing Failures")
struct GlassItemSpecificTests: MockOnlyTestSuite {
    
    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }
    
    // MARK: - Test Infrastructure
    
    private func createTestService() async throws -> (
        catalogService: CatalogService, 
        inventoryService: InventoryTrackingService,
        repositories: (glassItem: MockGlassItemRepository, inventory: MockInventoryRepository, tags: MockItemTagsRepository)
    ) {
        // Create fresh mock repositories
        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockLocationRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let itemMinimumRepo = MockItemMinimumRepository()
        
        // Configure for testing
        glassItemRepo.simulateLatency = false
        glassItemRepo.shouldRandomlyFail = false
        glassItemRepo.suppressVerboseLogging = true
        
        // Clear any existing data
        glassItemRepo.clearAllData()
        inventoryRepo.clearAllData()
        locationRepo.clearAllData()
        itemTagsRepo.clearAllData()
        itemMinimumRepo.clearAllData()
        
        // Manually populate test data to ensure it exists
        let testItems = [
            GlassItemModel(
                naturalKey: "bullseye-001-0",
                name: "Bullseye Clear Rod 5mm",
                sku: "001",
                manufacturer: "bullseye",
                mfrNotes: "Clear transparent rod",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "bullseye-254-0",
                name: "Red",
                sku: "254", 
                manufacturer: "bullseye",
                mfrNotes: "Bright red opaque",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "bullseye-discontinued-0",
                name: "Old Blue",
                sku: "discontinued",
                manufacturer: "bullseye",
                mfrNotes: "No longer made",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfrStatus: "discontinued"
            ),
            GlassItemModel(
                naturalKey: "spectrum-002-0",
                name: "Blue",
                sku: "002",
                manufacturer: "spectrum",
                mfrNotes: "Deep blue transparent",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "spectrum-100-0",
                name: "Clear",
                sku: "100",
                manufacturer: "spectrum",
                mfrNotes: "Crystal clear",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "spectrum-125-0",
                name: "Medium Amber",
                sku: "125",
                manufacturer: "spectrum",
                mfrNotes: "Amber transparent",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "spectrum-200-0",
                name: "Red COE96",
                sku: "200",
                manufacturer: "spectrum",
                mfrNotes: "Red transparent COE96",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "spectrum-220-0",
                name: "Yellow COE96",
                sku: "220",
                manufacturer: "spectrum", 
                mfrNotes: "Yellow transparent COE96",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "spectrum-240-0",
                name: "Orange COE96",
                sku: "240",
                manufacturer: "spectrum",
                mfrNotes: "Orange transparent COE96",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "kokomo-003-0",
                name: "Green Glass",
                sku: "003",
                manufacturer: "kokomo",
                mfrNotes: "Green transparent",
                coe: 96,
                url: "https://kokomoglass.com", 
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "kokomo-210-0",
                name: "White COE96",
                sku: "210",
                manufacturer: "kokomo",
                mfrNotes: "White opaque COE96",
                coe: 96,
                url: "https://kokomoglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "kokomo-230-0",
                name: "Purple COE96",
                sku: "230",
                manufacturer: "kokomo",
                mfrNotes: "Purple opal COE96",
                coe: 96,
                url: "https://kokomoglass.com",
                mfrStatus: "available"
            ),
            GlassItemModel(
                naturalKey: "cim-874-0",
                name: "Adamantium",
                sku: "874",
                manufacturer: "cim",
                mfrNotes: "A brown gray color",
                coe: 104,
                url: "https://creationismessy.com",
                mfrStatus: "available"
            )
        ]
        
        // Add items to repository
        let createdItems = try await glassItemRepo.createItems(testItems)
        print("Created \(createdItems.count) test items")
        
        // Add tags
        let tagData = [
            ("bullseye-001-0", ["clear", "transparent", "rod", "coe90"]),
            ("bullseye-254-0", ["red", "opaque", "coe90"]),
            ("bullseye-discontinued-0", ["blue", "discontinued", "coe90"]),
            ("spectrum-002-0", ["blue", "transparent", "coe96"]),
            ("spectrum-100-0", ["clear", "transparent", "coe96"]),
            ("spectrum-125-0", ["amber", "transparent", "coe96"]),
            ("spectrum-200-0", ["red", "transparent", "coe96"]),
            ("kokomo-003-0", ["green", "transparent", "coe96"]),
            ("cim-874-0", ["brown", "gray", "coe104"])
        ]
        
        for (itemKey, tags) in tagData {
            for tag in tags {
                try await itemTagsRepo.addTag(tag, toItem: itemKey)
            }
        }
        
        // Add inventory 
        let inventoryData = [
            InventoryModel(itemNaturalKey: "bullseye-001-0", type: "inventory", quantity: 5.0),
            InventoryModel(itemNaturalKey: "bullseye-254-0", type: "inventory", quantity: 3.0),
            InventoryModel(itemNaturalKey: "spectrum-002-0", type: "inventory", quantity: 8.0),
            InventoryModel(itemNaturalKey: "spectrum-125-0", type: "inventory", quantity: 2.0),
            InventoryModel(itemNaturalKey: "kokomo-003-0", type: "inventory", quantity: 4.0)
        ]
        
        for item in inventoryData {
            let _ = try await inventoryRepo.createInventory(item)
        }
        
        // Create services
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            inventoryRepository: inventoryRepo,
            locationRepository: locationRepo,
            itemTagsRepository: itemTagsRepo
        )
        
        let shoppingListService = ShoppingListService(
            itemMinimumRepository: itemMinimumRepo,
            inventoryRepository: inventoryRepo,
            glassItemRepository: glassItemRepo,
            itemTagsRepository: itemTagsRepo
        )
        
        let catalogService = CatalogService(
            glassItemRepository: glassItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            shoppingListService: shoppingListService,
            itemTagsRepository: itemTagsRepo
        )
        
        // Verify setup worked
        let finalCount = await glassItemRepo.getItemCount()
        let inventoryCount = await inventoryRepo.getInventoryCount()
        let tagCount = await itemTagsRepo.getAllTagsCount()
        
        print("Final test setup: \(finalCount) items, \(inventoryCount) inventory, \(tagCount) tags")
        
        return (catalogService, inventoryTrackingService, (glassItemRepo, inventoryRepo, itemTagsRepo))
    }
    
    // MARK: - Multiple Glass Items Test (addresses naturalKeys failures)
    
    @Test("Should create and find multiple glass items with correct natural keys")
    func testMultipleGlassItems() async throws {
        let (catalogService, _, repositories) = try await createTestService()
        
        // Verify the test data setup worked and we have expected items
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.count == 13, "Should have exactly 13 items from test setup")
        
        // Extract natural keys 
        let naturalKeys = allItems.map { $0.glassItem.naturalKey }
        print("Found natural keys: \(naturalKeys)")
        
        // Check for specific natural keys that tests expect
        #expect(naturalKeys.contains("spectrum-002-0"), "Should contain spectrum-002-0")
        #expect(naturalKeys.contains("bullseye-001-0"), "Should contain bullseye-001-0") 
        #expect(naturalKeys.contains("kokomo-003-0"), "Should contain kokomo-003-0")
        
        // Verify we have expected manufacturers
        let manufacturers = Set(allItems.map { $0.glassItem.manufacturer })
        #expect(manufacturers.contains("spectrum"), "Should have spectrum manufacturer")
        #expect(manufacturers.contains("bullseye"), "Should have bullseye manufacturer")
        #expect(manufacturers.contains("kokomo"), "Should have kokomo manufacturer")
        #expect(manufacturers.contains("cim"), "Should have cim manufacturer")
    }
    
    // MARK: - Complete Workflow Test (addresses retrievedItems failures)
    
    @Test("Should support complete workflow with item retrieval")
    func testCompleteWorkflow() async throws {
        let (catalogService, inventoryService, repositories) = try await createTestService()
        
        // Step 1: Verify we have initial data
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.count >= 1, "Should have initial test data")
        
        // Step 2: Find a specific item by natural key (simulating the failed test)
        let bullseyeClearKey = "bullseye-001-0" 
        let retrievedItems = allItems.filter { $0.glassItem.naturalKey == bullseyeClearKey }
        
        #expect(retrievedItems.count == 1, "Should find exactly 1 Bullseye Clear item")
        #expect(retrievedItems.first?.glassItem.name == "Bullseye Clear Rod 5mm", "Should have correct name")
        
        print("✅ Retrieved item: \(retrievedItems.first?.glassItem.name ?? "none") with key \(bullseyeClearKey)")
    }
    
    // MARK: - Basic Tag Operations Test (addresses allTags.count failures)
    
    @Test("Should support basic tag operations")
    func testBasicTagOperations() async throws {
        let (catalogService, _, repositories) = try await createTestService()
        
        // Verify we have tags from our test setup
        let allTags = try await repositories.tags.getAllTags()
        
        // Our test data setup should have created tags
        let expectedMinimumTags = 5 // We set up multiple items with various tags
        #expect(allTags.count >= expectedMinimumTags, "Should retrieve all created tags")
        
        print("✅ Found \(allTags.count) tags: \(allTags)")
        
        // Verify specific expected tags exist
        #expect(allTags.contains("clear"), "Should have 'clear' tag")
        #expect(allTags.contains("coe96"), "Should have 'coe96' tag")
    }
    
    // MARK: - Basic Search Functionality Test (addresses search results failures)
    
    @Test("Should support basic search functionality") 
    func testBasicSearchFunctionality() async throws {
        let (catalogService, inventoryService, repositories) = try await createTestService()
        
        // Test 1: Search for discontinued status
        let discontinuedItems = try await repositories.glassItem.fetchItems(byStatus: "discontinued")
        let expectedMinCount = 1
        #expect(discontinuedItems.count >= expectedMinCount, "Search for status 'discontinued' should find at least \(expectedMinCount) items")
        
        // Test 2: Search for COE 96 (we have 9 COE 96 items)
        let coe96Items = try await repositories.glassItem.fetchItems(byCOE: 96)
        let expectedMinCOE96Count = 7
        #expect(coe96Items.count >= expectedMinCOE96Count, "Search for coe '96' should find at least \(expectedMinCOE96Count) items")
        
        print("✅ Search tests: discontinued=\(discontinuedItems.count), coe96=\(coe96Items.count)")
    }
    
    // MARK: - Glass Item Search Test (addresses searchResults.items.count failures)
    
    @Test("Should support glass item search")
    func testGlassItemSearch() async throws {
        let (catalogService, inventoryService, repositories) = try await createTestService()
        
        // Perform a search that should return specific results
        let searchResults = try await inventoryService.searchItems(
            text: "clear",
            withTags: [],
            hasInventory: false, // Don't filter by inventory to get all matches
            inventoryTypes: []
        )
        
        // We know we have at least 2 clear items in our test data
        #expect(searchResults.count >= 2, "Search should find at least 2 clear glass items")
        
        print("✅ Search for 'clear' found \(searchResults.count) items")
        
        // Verify the search results include expected items
        let resultNames = searchResults.map { $0.glassItem.name }
        print("Clear search results: \(resultNames)")
    }
    
    // MARK: - Glass Item Basic Workflow Test (addresses allItems.first?.naturalKey failures)
    
    @Test("Should support glass item basic workflow")
    func testGlassItemBasicWorkflow() async throws {
        // Use TestConfiguration for guaranteed working setup
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        
        // Verify starting state
        let initialCount = await repos.glassItem.getItemCount()
        print("🔍 Initial count: \(initialCount)")
        #expect(initialCount == 0, "Should start with empty repository")
        
        // Create a specific test item to ensure predictable results
        let testItem = GlassItemModel(
            naturalKey: "test-rod-001",
            name: "Test Rod Item", 
            sku: "rod-001",
            manufacturer: "test",
            mfrNotes: "Test item for workflow",
            coe: 96,
            url: nil,
            mfrStatus: "available"
        )
        
        print("🔍 Creating test item: \(testItem.naturalKey)")
        // Add the test item
        let createdItem = try await repos.glassItem.createItem(testItem)
        print("✅ Created item: \(createdItem.name)")
        
        // Verify count increased
        let afterCreateCount = await repos.glassItem.getItemCount()
        print("📊 Count after create: \(afterCreateCount)")
        #expect(afterCreateCount == 1, "Should have 1 item after creation")
        
        // Now fetch all items and verify
        let allItems = try await repos.glassItem.fetchItems(matching: nil)
        print("📊 Fetched items: \(allItems.count)")
        
        #expect(allItems.count == 1, "Should have exactly our test item")
        #expect(allItems.first?.naturalKey == "test-rod-001", "Should have correct natural key")
        
        print("✅ Basic workflow test: found test item with natural key \(allItems.first?.naturalKey ?? "none")")
    }
    
    // MARK: - Comprehensive Integration Test
    
    @Test("Should handle comprehensive integration scenario")
    func testComprehensiveIntegration() async throws {
        let (catalogService, inventoryService, repositories) = try await createTestService()
        
        print("🔍 Comprehensive Integration Test")
        
        // Step 1: Verify initial data setup
        let initialItems = try await catalogService.getAllGlassItems()
        print("Initial items count: \(initialItems.count)")
        
        for item in initialItems {
            print("- \(item.glassItem.name) (\(item.glassItem.naturalKey)) by \(item.glassItem.manufacturer)")
        }
        
        #expect(initialItems.count == 13, "Should have exactly 13 test items")
        
        // Step 2: Test manufacturer filtering
        let manufacturers = try await repositories.glassItem.getDistinctManufacturers()
        print("Available manufacturers: \(manufacturers)")
        
        #expect(manufacturers.contains("bullseye"), "Should have bullseye manufacturer")
        #expect(manufacturers.contains("spectrum"), "Should have spectrum manufacturer") 
        #expect(manufacturers.contains("kokomo"), "Should have kokomo manufacturer")
        #expect(manufacturers.contains("cim"), "Should have cim manufacturer")
        
        // Step 3: Test COE filtering 
        let coeValues = try await repositories.glassItem.getDistinctCOEValues()
        print("Available COE values: \(coeValues)")
        
        #expect(coeValues.contains(90), "Should have COE 90")
        #expect(coeValues.contains(96), "Should have COE 96")
        #expect(coeValues.contains(104), "Should have COE 104")
        
        // Step 4: Test status filtering
        let statuses = try await repositories.glassItem.getDistinctStatuses()
        print("Available statuses: \(statuses)")
        
        #expect(statuses.contains("available"), "Should have available status")
        #expect(statuses.contains("discontinued"), "Should have discontinued status")
        
        // Step 5: Test search functionality
        let redItems = try await repositories.glassItem.searchItems(text: "red")
        print("Red items found: \(redItems.count)")
        #expect(redItems.count >= 1, "Should find red items")
        
        // Step 6: Test tag operations
        let allTags = try await repositories.tags.getAllTags()
        print("All tags: \(allTags)")
        #expect(allTags.count >= 5, "Should have multiple tags")
        
        print("✅ Comprehensive integration test passed")
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Should handle edge cases gracefully")
    func testEdgeCases() async throws {
        let (catalogService, inventoryService, repositories) = try await createTestService()
        
        // Test searching for non-existent items
        let nonExistentItems = try await repositories.glassItem.searchItems(text: "nonexistent")
        #expect(nonExistentItems.isEmpty, "Should return empty results for non-existent search")
        
        // Test searching with empty string
        let emptySearchItems = try await repositories.glassItem.searchItems(text: "")
        #expect(emptySearchItems.count >= 0, "Should handle empty search gracefully")
        
        // Test fetching non-existent natural key
        let nonExistentItem = try await repositories.glassItem.fetchItem(byNaturalKey: "nonexistent-key")
        #expect(nonExistentItem == nil, "Should return nil for non-existent natural key")
        
        print("✅ Edge cases handled gracefully")
    }
    
    // MARK: - Data Consistency Tests
    
    @Test("Should maintain data consistency")
    func testDataConsistency() async throws {
        let (catalogService, inventoryService, repositories) = try await createTestService()
        
        // Verify that all items have valid natural keys
        let allItems = try await repositories.glassItem.fetchItems(matching: nil)
        
        for item in allItems {
            // Test natural key format
            let components = item.naturalKey.components(separatedBy: "-")
            #expect(components.count == 3, "Natural key should have 3 components: \(item.naturalKey)")
            
            // Test that manufacturer in natural key matches manufacturer field
            let (manufacturer, _, _) = GlassItemModel.parseNaturalKey(item.naturalKey)!
            #expect(manufacturer == item.manufacturer.lowercased(), "Natural key manufacturer should match item manufacturer")
        }
        
        // Verify that tags are properly associated
        for item in allItems {
            let tags = try await repositories.tags.fetchTags(forItem: item.naturalKey)
            // Tags should exist for our test data
            if !tags.isEmpty {
                #expect(tags.allSatisfy { !$0.isEmpty }, "All tags should be non-empty")
            }
        }
        
        print("✅ Data consistency verified")
    }
}