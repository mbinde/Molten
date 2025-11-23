//
//  CoreDataLeakDiagnostic.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Diagnostic test to identify Core Data leakage in service layer
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

@Suite("Core Data Leak Diagnostic")
@MainActor
struct CoreDataLeakDiagnostic {

    @Test("Verify mock repository isolation")
    func testMockRepositoryIsolation() async throws {
        
        // Create a completely isolated mock repository
        let mockGlassItemRepo = MockGlassItemRepository()
        mockGlassItemRepo.simulateLatency = false
        mockGlassItemRepo.shouldRandomlyFail = false
        mockGlassItemRepo.clearAllData()
        
        // Verify it starts empty
        let initialCount = await mockGlassItemRepo.getItemCount()
        #expect(initialCount == 0, "Mock repository should start empty")
        
        // Add a test item directly to the mock
        let testItem = GlassItemModel(
            stable_id: "AUTO_ID",
            name: "Mock Test Item",
            sku: "mock",
            manufacturer: "diagnostic",
            mfr_notes: "Direct mock test",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        let _ = try await mockGlassItemRepo.createItem(testItem)
        
        // Verify it was added
        let afterCount = await mockGlassItemRepo.getItemCount()
        #expect(afterCount == 1, "Mock repository should have 1 item")
        
        // Retrieve and verify
        let allItems = try await mockGlassItemRepo.fetchItems(matching: nil)
        #expect(allItems.count == 1, "Should retrieve 1 item")

        // Verify it's the test item we created (check by manufacturer and SKU since stable_id is auto-generated)
        let retrievedItem = allItems.first
        #expect(retrievedItem?.manufacturer == "diagnostic", "Should have correct manufacturer")
        #expect(retrievedItem?.sku == "mock", "Should have correct SKU")
        
    }
    
    @Test("Verify service uses injected mock repository")
    func testServiceUsesInjectedMock() async throws {
        
        // Create isolated mock repositories
        let mockGlassItemRepo = MockGlassItemRepository()
        let mockInventoryRepo = MockInventoryRepository()
        let mockLocationRepo = MockStorageLocationRepository()
        let mockItemTagsRepo = MockItemTagsRepository()
        let mockUserTagsRepo = MockUserTagsRepository()
        let mockItemMinimumRepo = MockItemMinimumRepository()

        // Configure and clear
        mockGlassItemRepo.simulateLatency = false
        mockGlassItemRepo.shouldRandomlyFail = false
        mockGlassItemRepo.clearAllData()
        mockInventoryRepo.clearAllData()
        mockLocationRepo.clearAllData()
        mockItemTagsRepo.clearAllData()
        mockItemMinimumRepo.clearAllData()

        // Verify all start empty
        let initialGlassCount = await mockGlassItemRepo.getItemCount()
        let initialInventoryCount = await mockInventoryRepo.getInventoryCount()

        #expect(initialGlassCount == 0, "Glass repo should start empty")
        #expect(initialInventoryCount == 0, "Inventory repo should start empty")

        // Create services with explicit dependency injection
        let shoppingListRepository = MockShoppingListRepository()
        let coatingItemRepo = MockCoatingItemRepository()
        let toolItemRepo = MockToolItemRepository()

        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: mockGlassItemRepo,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryRepository: mockInventoryRepo,
            itemTagsRepository: mockItemTagsRepo
        )

        let catalogService = CatalogService(
            glassItemRepository: mockGlassItemRepo,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: mockItemMinimumRepo,
            itemTagsRepository: mockItemTagsRepo,
            userTagsRepository: mockUserTagsRepo,
            ratingService: AppDependencies.shared.ratingService
        )

        let shoppingListService = ShoppingListService(
            itemMinimumRepository: mockItemMinimumRepo,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: mockInventoryRepo,
            glassItemRepository: mockGlassItemRepo,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            itemTagsRepository: mockItemTagsRepo,
            userTagsRepository: mockUserTagsRepo
        )
        
        // TEST 1: Add item directly to mock repository
        let directTestItem = GlassItemModel(
            stable_id: "AUTO_ID",
            name: "Direct Test Item",
            sku: "direct",
            manufacturer: "diagnostic",
            mfr_notes: "Added directly to mock",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        print("🔍 Adding item directly to mock repository...")
        let _ = try await mockGlassItemRepo.createItem(directTestItem)
        
        // TEST 2: Check if catalog service sees the same item
        let catalogServiceItems = try await catalogService.getAllGlassItems()
        let directRepositoryItems = try await mockGlassItemRepo.fetchItems(matching: nil)
                
        // If these don't match, the service is NOT using our mock
        if directRepositoryItems.count != catalogServiceItems.count {
            print("❌ CORE DATA LEAK DETECTED!")
            print("❌ Service count (\(catalogServiceItems.count)) != Repository count (\(directRepositoryItems.count))")
            print("❌ This means CatalogService is using a different repository (probably Core Data)")
            
            print("🔍 Direct repository items:")
            for item in directRepositoryItems {
                print("  - \(item.name) (\(item.stable_id))")
            }
            
            print("🔍 Catalog service items:")
            for item in catalogServiceItems {
                print("  - \(item.glassItem.name) (\(item.glassItem.stable_id))")
            }
        }
        
        #expect(directRepositoryItems.count == catalogServiceItems.count, 
                "Service should use injected mock repository, not Core Data")
        
        // TEST 3: Add item through service and verify it appears in mock
        let serviceTestItem = GlassItemModel(
            stable_id: "AUTO_ID",
            name: "Service Test Item",
            sku: "service",
            manufacturer: "diagnostic",
            mfr_notes: "Added through service",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        let _ = try await catalogService.createGlassItem(serviceTestItem, initialInventory: [], tags: [])
        
        // Check if it appears in both
        let finalRepositoryItems = try await mockGlassItemRepo.fetchItems(matching: nil)
        let finalServiceItems = try await catalogService.getAllGlassItems()
        
        #expect(finalRepositoryItems.count == finalServiceItems.count,
                "After service operations, counts should still match")
        #expect(finalRepositoryItems.count == 2, "Should have 2 items total")
        
    }
}
