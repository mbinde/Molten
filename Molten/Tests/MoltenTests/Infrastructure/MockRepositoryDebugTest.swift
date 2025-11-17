//
//  MockRepositoryDebugTest.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Debug test to isolate mock repository issues
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

@Suite("Mock Repository Debug Test")
@MainActor
struct MockRepositoryDebugTest: MockOnlyTestSuite {

    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }

    @Test("Debug: Test basic mock repository operations step by step")
    func testMockRepositoryBasicOperations() async throws {
        
        // Create a completely fresh mock repository 
        let mockRepo = MockGlassItemRepository()
        
        // Clear any existing data explicitly
        mockRepo.clearAllData()
        
        // Check initial count
        let initialCount = await mockRepo.getItemCount()
        #expect(initialCount == 0, "Should start with 0 items")
        
        // Create a simple test item
        let testItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "debug", sku: "001"),
            name: "Debug Test Item",
            sku: "001",
            manufacturer: "debug",
            mfr_notes: "Simple test",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )

        print("📝 Created test item model: \(testItem.stable_id)")
        
        // Add it to the repository
        print("📝 Calling createItem...")
        let createdItem = try await mockRepo.createItem(testItem)
        print("✅ createItem returned: \(createdItem.name)")
        
        // Check count after creation
        let afterCreateCount = await mockRepo.getItemCount()
        print("📊 Count after createItem: \(afterCreateCount)")
        
        if afterCreateCount == 0 {
            print("❌ PROBLEM: createItem did not increase count!")
        } else {
            print("✅ Count increased correctly")
        }
        
        // Try to fetch all items
        print("📝 Calling fetchItems...")
        let fetchedItems = try await mockRepo.fetchItems(matching: nil)
        print("📊 fetchItems returned \(fetchedItems.count) items")
        
        if fetchedItems.isEmpty {
            print("❌ PROBLEM: fetchItems returned empty array!")
        } else {
            print("✅ fetchItems returned data:")
            for item in fetchedItems {
                print("  - \(item.name) (\(item.stable_id))")
            }
        }
        
        // Try to fetch by stable ID
        print("📝 Calling fetchItem by stable ID...")
        let stableId = generateStableId(manufacturer: "debug", sku: "001")
        let fetchedByKey = try await mockRepo.fetchItem(byStableId: stableId)

        if fetchedByKey == nil {
            print("❌ PROBLEM: fetchItem by stable ID returned nil!")
        } else {
            print("✅ fetchItem by stable ID returned: \(fetchedByKey!.name)")
        }
        
        // Final assertions based on what we learned
        #expect(afterCreateCount == 1, "Count should be 1 after createItem")
        #expect(fetchedItems.count == 1, "fetchItems should return 1 item")
        #expect(fetchedByKey != nil, "fetchItem by stable ID should find the item")
        
        print("🎯 MOCK REPOSITORY DEBUG: Test completed")
    }
    
    @Test("Debug: Test TestConfiguration setup")
    func testTestConfigurationSetup() async throws {
        print("🔍 TEST CONFIGURATION DEBUG: Testing TestConfiguration setup")
        
        // Use TestConfiguration
        let repos = TestConfiguration.setupMockOnlyTestEnvironment()
        print("📊 TestConfiguration created repositories")
        
        // Check initial state
        let initialCount = await repos.glassItem.getItemCount()
        print("📊 Initial count from TestConfiguration: \(initialCount)")
        #expect(initialCount == 0, "Should start empty")
        
        // Create and add an item
        let testItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "config", sku: "001"),
            name: "Config Test Item",
            sku: "001",
            manufacturer: "config",
            mfr_notes: "TestConfiguration test",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        
        print("📝 Adding item through TestConfiguration repository...")
        let createdItem = try await repos.glassItem.createItem(testItem)
        print("✅ Item created: \(createdItem.name)")
        
        // Verify it's there
        let finalCount = await repos.glassItem.getItemCount()
        let allItems = try await repos.glassItem.fetchItems(matching: nil)
        
        print("📊 Final count: \(finalCount)")
        print("📊 Fetched items: \(allItems.count)")
        
        if finalCount == 0 || allItems.isEmpty {
            print("❌ PROBLEM: TestConfiguration repositories not working!")
        } else {
            print("✅ TestConfiguration repositories working correctly")
        }
        
        #expect(finalCount == 1, "TestConfiguration repository should work")
        #expect(allItems.count == 1, "Should fetch the created item")
        
        print("🎯 TEST CONFIGURATION DEBUG: Test completed")
    }
}
