//
//  DiagnosticTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Diagnostic tests to understand why our test setup is failing
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

@Suite("Diagnostic Tests - Understanding Test Failures")
struct DiagnosticTests: MockOnlyTestSuite {
    
    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }
    
    @Test("Verify basic mock repository functionality")
    func testBasicMockRepositoryFunctionality() async throws {
        print("🔍 DIAGNOSTIC: Testing basic mock repository functionality")
        
        // Create a completely isolated mock repository
        let mockRepo = MockGlassItemRepository()
        mockRepo.simulateLatency = false
        mockRepo.shouldRandomlyFail = false
        
        // Clear any existing data
        mockRepo.clearAllData()
        
        // Verify it starts empty
        let initialCount = await mockRepo.getItemCount()
        print("📊 Initial count: \(initialCount)")
        #expect(initialCount == 0, "Mock repository should start empty")
        
        // Create a single test item
        let testItem = GlassItemModel(
            natural_key: "diagnostic-test-001-0",
            name: "Diagnostic Test Item",
            sku: "001", 
            manufacturer: "diagnostic",
            mfr_notes: "Test item for diagnostics",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        print("📝 Creating test item with natural key: \(testItem.natural_key)")
        let createdItem = try await mockRepo.createItem(testItem)
        print("✅ Created item: \(createdItem.name)")
        
        // Verify it was created
        let afterCreateCount = await mockRepo.getItemCount()
        print("📊 Count after create: \(afterCreateCount)")
        #expect(afterCreateCount == 1, "Should have 1 item after creation")
        
        // Retrieve all items
        let allItems = try await mockRepo.fetchItems(matching: nil)
        print("📊 Fetched items count: \(allItems.count)")
        #expect(allItems.count == 1, "Should fetch 1 item")
        #expect(allItems.first?.natural_key == "diagnostic-test-001-0", "Should have correct natural key")
        
        print("✅ DIAGNOSTIC: Basic mock repository functionality works correctly")
    }
    
    @Test("Verify service creation with TestConfiguration")
    func testServiceCreationWithTestConfiguration() async throws {
        print("🔍 DIAGNOSTIC: Testing service creation with TestConfiguration")
        
        // Use TestConfiguration to create completely isolated mock repositories
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        
        // Verify they're empty
        let initialGlassCount = await repos.glassItem.getItemCount()
        let initialInventoryCount = await repos.inventory.getInventoryCount()
        print("📊 Initial counts - Glass: \(initialGlassCount), Inventory: \(initialInventoryCount)")
        
        #expect(initialGlassCount == 0, "Glass item repository should start empty")
        #expect(initialInventoryCount == 0, "Inventory repository should start empty")
        
        // Create services with TestConfiguration repositories
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
        
        // Test that services use the injected repositories
        let catalogItems = try await catalogService.getAllGlassItems()
        print("📊 Catalog items from service: \(catalogItems.count)")
        #expect(catalogItems.count == 0, "Catalog service should show empty repository")
        
        // Add an item through the service
        let testItem = GlassItemModel(
            natural_key: "service-test-001-0",
            name: "Service Test Item",
            sku: "001",
            manufacturer: "service",
            mfr_notes: "Test item via service",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        print("📝 Creating item through catalog service")
        let createdCompleteItem = try await catalogService.createGlassItem(testItem, initialInventory: [], tags: ["test"])
        print("✅ Created via service: \(createdCompleteItem.glassItem.name)")
        
        // Verify it appears in both the repository and service
        let finalRepoCount = await repos.glassItem.getItemCount()
        let finalServiceCount = (try await catalogService.getAllGlassItems()).count
        
        print("📊 Final counts - Repo: \(finalRepoCount), Service: \(finalServiceCount)")
        #expect(finalRepoCount == 1, "Repository should have 1 item")
        #expect(finalServiceCount == 1, "Service should show 1 item")
        
        print("✅ DIAGNOSTIC: Service creation with TestConfiguration works correctly")
    }
    
    @Test("Verify test data isolation between tests")  
    func testDataIsolationBetweenTests() async throws {
        print("🔍 DIAGNOSTIC: Testing data isolation between tests")
        
        // Use TestConfiguration for guaranteed isolation
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        
        let initialCount = await repos.glassItem.getItemCount()
        print("📊 Initial count in isolation test: \(initialCount)")
        
        if initialCount != 0 {
            print("⚠️  WARNING: Repository not isolated! Found \(initialCount) existing items")
            let existingItems = try await repos.glassItem.fetchItems(matching: nil)
            for item in existingItems {
                print("   - Existing item: \(item.name) (\(item.natural_key))")
            }
        }
        
        #expect(initialCount == 0, "Repository should be isolated and start empty")
        
        print("✅ DIAGNOSTIC: Data isolation test completed")
    }
    
    @Test("Verify TestDataSetup functionality")
    func testDataSetupFunctionality() async throws {
        print("🔍 DIAGNOSTIC: Testing TestDataSetup functionality")
        
        // Test the TestDataSetup methods directly
        let testItems = TestDataSetup.createStandardTestGlassItems()
        print("📊 TestDataSetup created \(testItems.count) glass items")
        
        let testTags = TestDataSetup.createStandardTestTags()
        print("📊 TestDataSetup created tags for \(testTags.count) items")
        
        let testInventory = TestDataSetup.createStandardTestInventory()
        print("📊 TestDataSetup created \(testInventory.count) inventory records")
        
        #expect(testItems.count > 0, "Should create test glass items")
        #expect(testTags.count > 0, "Should create test tags")
        #expect(testInventory.count > 0, "Should create test inventory")
        
        // Verify the items have the expected natural keys
        let naturalKeys = testItems.map { $0.natural_key }
        print("📝 Natural keys created: \(naturalKeys)")
        
        let expectedKeys = ["bullseye-001-0", "spectrum-002-0", "kokomo-003-0"]
        for expectedKey in expectedKeys {
            let found = naturalKeys.contains(expectedKey)
            print("🔍 Looking for \(expectedKey): \(found ? "✅ Found" : "❌ Missing")")
            #expect(found, "Should create expected natural key: \(expectedKey)")
        }
        
        print("✅ DIAGNOSTIC: TestDataSetup functionality works correctly")
    }
}
