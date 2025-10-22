//
//  SimpleIsolatedTest.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Extremely simple test to isolate the Core Data issue
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

@Suite("Simple Isolated Test - Find Core Data Leak", .serialized)
@MainActor
struct SimpleIsolatedTest: MockOnlyTestSuite {
    
    // This will trigger Core Data prevention
    init() {
        ensureMockOnlyEnvironment()
    }
    
    @Test("Ultra simple test - just mock repository")
    func testUltraSimpleMockRepository() async throws {
        print("🔍 ULTRA SIMPLE TEST: Testing pure mock repository")
        
        // Create the simplest possible mock repository test
        let mockRepo = MockGlassItemRepository()
        mockRepo.clearAllData()
        
        // Add one item
        let testItem = GlassItemModel(
            natural_key: "ultra-simple-test",
            name: "Ultra Simple Test Item",
            sku: "simple",
            manufacturer: "test",
            mfr_notes: nil,
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        let _ = try await mockRepo.createItem(testItem)
        
        // Retrieve it
        let items = try await mockRepo.fetchItems(matching: nil)
        
        print("📊 Mock repository items: \(items.count)")
        for item in items {
            print("  - \(item.name) (\(item.natural_key)) by \(item.manufacturer)")
        }
        
        #expect(items.count == 1, "Should have exactly 1 item")
        #expect(items.first?.natural_key == "ultra-simple-test", "Should have correct item")
        
        print("✅ Ultra simple mock repository test passed")
    }
    
    @Test("Simple service test - minimal dependencies")
    func testSimpleServiceWithMinimalDeps() async throws {
        print("🔍 SIMPLE SERVICE TEST: Testing CatalogService with explicit mocks")
        
        // Create minimal mock dependencies
        let mockGlassItemRepo = MockGlassItemRepository()
        let mockInventoryRepo = MockInventoryRepository()
        let mockLocationRepo = MockLocationRepository()
        let mockItemTagsRepo = MockItemTagsRepository()
        let mockUserTagsRepo = MockUserTagsRepository()
        let mockItemMinimumRepo = MockItemMinimumRepository()

        // Clear all mocks
        mockGlassItemRepo.clearAllData()
        mockInventoryRepo.clearAllData()
        mockLocationRepo.clearAllData()
        mockItemTagsRepo.clearAllData()
        mockItemMinimumRepo.clearAllData()

        // Verify they're empty
        let initialGlassCount = await mockGlassItemRepo.getItemCount()
        print("📊 Initial mock glass item count: \(initialGlassCount)")
        #expect(initialGlassCount == 0, "Mock should start empty")

        // Create services with explicit injection
        let inventoryService = InventoryTrackingService(
            glassItemRepository: mockGlassItemRepo,
            inventoryRepository: mockInventoryRepo,
            locationRepository: mockLocationRepo,
            itemTagsRepository: mockItemTagsRepo
        )

        let shoppingListRepository = MockShoppingListRepository()
        let shoppingService = ShoppingListService(
            itemMinimumRepository: mockItemMinimumRepo,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: mockInventoryRepo,
            glassItemRepository: mockGlassItemRepo,
            itemTagsRepository: mockItemTagsRepo,
            userTagsRepository: mockUserTagsRepo
        )

        let catalogService = CatalogService(
            glassItemRepository: mockGlassItemRepo,
            inventoryTrackingService: inventoryService,
            shoppingListService: shoppingService,
            itemTagsRepository: mockItemTagsRepo,
            userTagsRepository: mockUserTagsRepo
        )
        
        // Test: Add item directly to mock repository
        let directItem = GlassItemModel(
            natural_key: "simple-direct-test",
            name: "Simple Direct Test",
            sku: "direct",
            manufacturer: "simple",
            mfr_notes: nil,
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        print("🔍 Adding item directly to mock repository")
        let _ = try await mockGlassItemRepo.createItem(directItem)
        
        // Check if catalog service sees it
        let serviceItems = try await catalogService.getAllGlassItems()
        let repositoryItems = try await mockGlassItemRepo.fetchItems(matching: nil)
        
        print("📊 Repository items: \(repositoryItems.count)")
        print("📊 Service items: \(serviceItems.count)")
        
        if repositoryItems.count != serviceItems.count {
            print("❌ PROBLEM FOUND: Service sees different items than repository!")
            print("❌ Repository has: \(repositoryItems.count) items")
            print("❌ Service has: \(serviceItems.count) items")
            print("❌ This indicates Core Data or another repository is being used")
        } else {
            print("✅ Service correctly uses injected mock repository")
        }
        
        #expect(repositoryItems.count == serviceItems.count, "Service should see same items as repository")
        #expect(repositoryItems.count == 1, "Should have exactly 1 item")
        
        print("✅ Simple service test passed")
    }
}
