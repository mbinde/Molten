//
//  MockRepositoryDebugTest.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Debug test to isolate mock repository issues
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

@Suite("Mock Repository Debug Test")
struct MockRepositoryDebugTest: MockOnlyTestSuite {
    
    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }
    
    @Test("Debug: Test basic mock repository operations step by step")
    func testMockRepositoryBasicOperations() async throws {
        print("🔍 MOCK REPOSITORY DEBUG: Testing basic operations")
        
        // Create a completely fresh mock repository 
        let mockRepo = MockGlassItemRepository()
        print("📊 Repository created")
        
        // Clear any existing data explicitly
        mockRepo.clearAllData()
        print("📊 Data cleared")
        
        // Check initial count
        let initialCount = await mockRepo.getItemCount()
        print("📊 Initial count: \(initialCount)")
        #expect(initialCount == 0, "Should start with 0 items")
        
        // Create a simple test item
        let testItem = GlassItemModel(
            naturalKey: "debug-test-001",
            name: "Debug Test Item",
            sku: "001",
            manufacturer: "debug",
            mfrNotes: "Simple test",
            coe: 96,
            url: nil,
            mfrStatus: "available"
        )
        
        print("📝 Created test item model: \(testItem.naturalKey)")
        
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
                print("  - \(item.name) (\(item.naturalKey))")
            }
        }
        
        // Try to fetch by natural key
        print("📝 Calling fetchItem by natural key...")
        let fetchedByKey = try await mockRepo.fetchItem(byNaturalKey: "debug-test-001")
        
        if fetchedByKey == nil {
            print("❌ PROBLEM: fetchItem by natural key returned nil!")
        } else {
            print("✅ fetchItem by natural key returned: \(fetchedByKey!.name)")
        }
        
        // Final assertions based on what we learned
        #expect(afterCreateCount == 1, "Count should be 1 after createItem")
        #expect(fetchedItems.count == 1, "fetchItems should return 1 item")
        #expect(fetchedByKey != nil, "fetchItem by natural key should find the item")
        
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
            naturalKey: "config-test-001",
            name: "Config Test Item",
            sku: "001",
            manufacturer: "config",
            mfrNotes: "TestConfiguration test",
            coe: 96,
            url: nil,
            mfrStatus: "available"
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