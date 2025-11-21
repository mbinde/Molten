//
//  DiagnosticTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Diagnostic tests to understand why our test setup is failing
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

@Suite("Diagnostic Tests - Understanding Test Failures")
@MainActor
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
            stable_id: generateStableId(manufacturer: "diagnostic", sku: "001"),
            name: "Diagnostic Test Item",
            sku: "001",
            manufacturer: "diagnostic",
            mfr_notes: "Test item for diagnostics",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        print("📝 Creating test item with natural key: \(testItem.stable_id)")
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
        #expect(allItems.first?.stable_id == generateStableId(manufacturer: "diagnostic", sku: "001"), "Should have correct stable_id")
        
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

        // Create services directly with mock repositories (don't use AppDependencies)
        let userTagsRepo = MockUserTagsRepository()
        let ratingRepo = MockRatingRepository()
        let mockLogger = MockLogger()
        let ratingService = RatingService(repository: ratingRepo, logger: LoggingService(backends: [mockLogger]))

        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: repos.glassItem,
            coatingItemRepository: repos.coating,
            toolItemRepository: repos.tool,
            inventoryRepository: repos.inventory,
            itemTagsRepository: repos.itemTags
        )

        let catalogService = CatalogService(
            glassItemRepository: repos.glassItem,
            coatingItemRepository: repos.coating,
            toolItemRepository: repos.tool,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: repos.itemMinimum,
            itemTagsRepository: repos.itemTags,
            userTagsRepository: userTagsRepo,
            ratingService: ratingService
        )

        // Test that services use the injected repositories
        let catalogItems = try await catalogService.getAllGlassItems()
        print("📊 Catalog items from service: \(catalogItems.count)")
        #expect(catalogItems.count == 0, "Catalog service should show empty repository")

        // Add an item through the service
        let testItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "service", sku: "001"),
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
                print("   - Existing item: \(item.name) (\(item.stable_id))")
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
        
        // Verify the items have the expected stable_ids (using manufacturer+SKU check)
        let naturalKeys = testItems.map { $0.stable_id }
        print("📝 Stable IDs created: \(naturalKeys)")

        // Check for expected items by manufacturer and SKU, not hardcoded stable_id strings
        let expectedItems = [
            ("bullseye", "001"),
            ("spectrum", "002"),
            ("kokomo", "003")
        ]
        for (manufacturer, sku) in expectedItems {
            let found = testItems.contains { $0.manufacturer == manufacturer && $0.sku == sku }
            print("🔍 Looking for \(manufacturer)-\(sku): \(found ? "✅ Found" : "❌ Missing")")
            #expect(found, "Should create expected item: \(manufacturer)-\(sku)")
        }
        
        print("✅ DIAGNOSTIC: TestDataSetup functionality works correctly")
    }
}
