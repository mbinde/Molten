//
//  ViewUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/9/25.
//

import Foundation
import SwiftUI
import CoreData
import Testing
@testable import Flameworker

@Suite("ViewUtilities Tests") 
struct ViewUtilitiesTests {
    
    @Test("Should manage loading state during async operation")
    func testAsyncOperationHandlerLoadingState() async throws {
        // Arrange - Create completely isolated state
        var isLoading = false
        let loadingBinding = Binding(
            get: { isLoading },
            set: { isLoading = $0 }
        )
        
        var operationExecuted = false
        
        // Ensure clean initial state
        #expect(isLoading == false)
        #expect(operationExecuted == false)
        
        let testOperation: () async throws -> Void = {
            // Add longer delay to ensure timing is predictable
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            operationExecuted = true
        }
        
        // Act
        let task = AsyncOperationHandler.performForTesting(
            operation: testOperation,
            operationName: "Test Operation \(UUID().uuidString)", // Unique operation name
            loadingState: loadingBinding
        )
        
        // Longer delay to ensure loading state is set
        try await Task.sleep(nanoseconds: 25_000_000) // 25ms
        
        // Assert - Should be loading
        #expect(isLoading == true)
        
        // Wait for completion
        await task.value
        
        // Assert - Operation completed and loading reset
        #expect(operationExecuted == true)
        #expect(isLoading == false)
    }
    
    @Test("Should safely delete items with animation and error handling")
    func testCoreDataOperationsDeleteItems() async throws {
        // Arrange - Create isolated test context
        let testController = PersistenceController.createTestController()
        let context = testController.container.viewContext
        let service = BaseCoreDataService<CatalogItem>(entityName: "CatalogItem")
        
        // Create test items with predictable sorting
        let item1 = service.create(in: context)
        item1.name = "Item A"
        item1.code = "DELETE-001"
        
        let item2 = service.create(in: context)
        item2.name = "Item B"
        item2.code = "DELETE-002"
        
        let item3 = service.create(in: context)
        item3.name = "Item C"
        item3.code = "DELETE-003"
        
        // Save items
        try CoreDataHelpers.safeSave(context: context, description: "Delete test items")
        
        // Fetch items in sorted order
        let allItems = try service.fetch(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)], 
            in: context
        )
        #expect(allItems.count == 3)
        
        // Delete only the first item (index 0 = Item A)
        let offsets = IndexSet([0])
        
        // Act - Delete items using CoreDataOperations utility
        CoreDataOperations.deleteItems(allItems, at: offsets, in: context)
        
        // Brief delay to allow deletion to complete
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Assert - Should have 2 items remaining (Item B and Item C)
        let finalCount = try service.count(in: context)
        #expect(finalCount == 2)
        
        let remainingItems = try service.fetch(
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
            in: context
        )
        #expect(remainingItems.count == 2)
        
        // Check that Item A was deleted and Item B, C remain
        let remainingCodes = remainingItems.map { $0.code }
        #expect(remainingCodes.contains("DELETE-002"))  // Item B should remain
        #expect(remainingCodes.contains("DELETE-003"))  // Item C should remain
        #expect(!remainingCodes.contains("DELETE-001")) // Item A should be deleted
    }
}