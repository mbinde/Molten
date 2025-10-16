//
//  RepositoryIdentityTest.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Test to verify repository identity and catch Core Data leaks
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

@Suite("Repository Identity Test - Catch Core Data Leaks", .serialized)
struct RepositoryIdentityTest: MockOnlyTestSuite {
    
    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }
    
    @Test("Test repository instance identity")
    func testRepositoryInstanceIdentity() async throws {
        print("🔍 IDENTITY TEST: Verifying repository instances are the same")
        
        // Use the enhanced test configuration to ensure proper setup
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        let mockRepo = repos.glassItem
        
        // Add a "marker" item that should only exist in our specific mock instance
        let markerItem = GlassItemModel(
            natural_key: "identity-marker-12345",
            name: "Identity Marker Item",
            sku: "marker",
            manufacturer: "identity",
            mfr_notes: "This item should ONLY exist in our mock repository",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        print("🔍 Adding marker item to mock repository")
        let _ = try await mockRepo.createItem(markerItem)
        
        // Verify the marker exists in our mock
        let directCheck = try await mockRepo.fetchItems(matching: nil)
        print("📊 Direct check - items in mock: \(directCheck.count)")
        let hasMarker = directCheck.contains { $0.natural_key == "identity-marker-12345" }
        print("📊 Marker found in mock: \(hasMarker)")
        
        #expect(directCheck.count == 1, "Mock should have exactly 1 item")
        #expect(hasMarker, "Mock should contain our marker item")
        
        // Now create services using the repositories from TestConfiguration
        let otherMockRepos = (
            inventory: repos.inventory,
            location: repos.location,
            itemTags: repos.itemTags,
            itemMinimum: repos.itemMinimum
        )
        
        let inventoryService = InventoryTrackingService(
            glassItemRepository: mockRepo, // Use the SAME instance
            inventoryRepository: otherMockRepos.inventory,
            locationRepository: otherMockRepos.location,
            itemTagsRepository: otherMockRepos.itemTags
        )
        
        let shoppingService = ShoppingListService(
            itemMinimumRepository: otherMockRepos.itemMinimum,
            inventoryRepository: otherMockRepos.inventory,
            glassItemRepository: mockRepo, // Use the SAME instance
            itemTagsRepository: otherMockRepos.itemTags
        )
        
        let catalogService = CatalogService(
            glassItemRepository: mockRepo, // Use the SAME instance
            inventoryTrackingService: inventoryService,
            shoppingListService: shoppingService,
            itemTagsRepository: otherMockRepos.itemTags
        )
        
        // Test if catalog service sees our marker item
        print("🔍 Checking if catalog service sees marker item")
        let serviceItems = try await catalogService.getAllGlassItems()
        print("📊 Service items count: \(serviceItems.count)")
        
        let serviceHasMarker = serviceItems.contains { $0.glassItem.natural_key == "identity-marker-12345" }
        print("📊 Service found marker: \(serviceHasMarker)")
        
        if !serviceHasMarker {
            print("❌ CORE DATA LEAK DETECTED!")
            print("❌ Catalog service does NOT see our marker item")
            print("❌ This means it's using a different repository instance (probably Core Data)")
            
            print("🔍 Items in service:")
            for item in serviceItems {
                print("  - Service: \(item.glassItem.name) (\(item.glassItem.natural_key))")
            }
            
            print("🔍 Items in mock repository:")
            for item in directCheck {
                print("  - Mock: \(item.name) (\(item.natural_key))")
            }
        }
        
        #expect(serviceHasMarker, "Service should see marker item if using injected mock repository")
        #expect(serviceItems.count == 1, "Service should see exactly 1 item (our marker)")
        
        print("✅ Repository identity test passed - services use injected mocks")
    }
    
    @Test("Test multiple operations on same repository instance")
    func testMultipleOperationsOnSameInstance() async throws {
        print("🔍 MULTIPLE OPERATIONS TEST: Testing repository consistency")
        
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        let mockRepo = repos.glassItem
        
        // Add multiple items one by one and verify count grows
        let testItems = [
            ("test-1", "Test Item 1"),
            ("test-2", "Test Item 2"), 
            ("test-3", "Test Item 3")
        ]
        
        for (i, (key, name)) in testItems.enumerated() {
            let item = GlassItemModel(
                natural_key: key,
                name: name,
                sku: "test",
                manufacturer: "test",
                mfr_notes: nil,
                coe: 96,
                url: nil,
                mfr_status: "available"
            )
            
            let _ = try await mockRepo.createItem(item)
            
            let currentCount = await mockRepo.getItemCount()
            let expectedCount = i + 1
            
            print("📊 After adding item \(i + 1): count = \(currentCount)")
            #expect(currentCount == expectedCount, "Count should be \(expectedCount) after adding \(i + 1) items")
        }
        
        // Final verification
        let finalItems = try await mockRepo.fetchItems(matching: nil)
        print("📊 Final items: \(finalItems.count)")
        
        #expect(finalItems.count == 3, "Should have exactly 3 items at the end")
        
        for item in finalItems {
            print("  - \(item.name) (\(item.natural_key))")
        }
    }
    
    @Test("Test async timing and repository consistency")
    func testAsyncTimingAndConsistency() async throws {
        print("🔍 ASYNC TIMING TEST: Testing for async/timing issues")
        
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        let mockRepo = repos.glassItem
        
        // Add item and immediately check count
        let item = GlassItemModel(
            natural_key: "timing-test-item",
            name: "Timing Test Item",
            sku: "timing",
            manufacturer: "test",
            mfr_notes: nil,
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        print("🔍 Adding item...")
        let createdItem = try await mockRepo.createItem(item)
        print("📊 Created item: \(createdItem.name)")
        
        // Immediate count check
        let immediateCount = await mockRepo.getItemCount()
        print("📊 Immediate count: \(immediateCount)")
        
        // Small delay and recheck
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        let delayedCount = await mockRepo.getItemCount()
        print("📊 Delayed count: \(delayedCount)")
        
        // Fetch items and count
        let fetchedItems = try await mockRepo.fetchItems(matching: nil)
        print("📊 Fetched items count: \(fetchedItems.count)")
        
        // All counts should be the same
        #expect(immediateCount == 1, "Immediate count should be 1")
        #expect(delayedCount == 1, "Delayed count should be 1")
        #expect(fetchedItems.count == 1, "Fetched count should be 1")
        
        #expect(immediateCount == delayedCount, "Counts should be consistent over time")
        #expect(delayedCount == fetchedItems.count, "Count and fetch should match")
        
        print("✅ Async timing test passed - no timing issues detected")
    }
}
