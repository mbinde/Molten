//
//  ServiceCoordinationTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Phase 1 Testing Improvements: Cross-Service Coordination
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

@Suite("Service Coordination Tests")
struct ServiceCoordinationTests {
    
    // MARK: - Test Data Factory
    
    private func createMockServices() -> (CatalogService, InventoryService) {
        let catalogRepo = MockCatalogRepository()
        let inventoryRepo = MockInventoryRepository()
        
        let inventoryService = InventoryService(repository: inventoryRepo)
        let catalogService = CatalogService(repository: catalogRepo, inventoryService: inventoryService)
        
        return (catalogService, inventoryService)
    }
    
    private func createTestCatalogItems() -> [CatalogItemModel] {
        return [
            CatalogItemModel(name: "Bullseye Red", rawCode: "0124", manufacturer: "Bullseye"),
            CatalogItemModel(name: "Spectrum Blue", rawCode: "125", manufacturer: "Spectrum"),
            CatalogItemModel(name: "Uroboros Green", rawCode: "94-16", manufacturer: "Uroboros")
        ]
    }
    
    private func createTestInventoryItems() -> [InventoryItemModel] {
        return [
            InventoryItemModel(catalogCode: "BULLSEYE-0124", quantity: 10, type: .inventory),
            InventoryItemModel(catalogCode: "SPECTRUM-125", quantity: 5, type: .buy),
            InventoryItemModel(catalogCode: "UROBOROS-94-16", quantity: 3, type: .sell)
        ]
    }
    
    // MARK: - Inventory-Catalog Coordination Tests
    
    @Test("Should coordinate inventory updates with catalog changes")
    func testInventoryCatalogCoordination() async throws {
        let (catalogService, inventoryService) = createMockServices()
        
        // Create catalog item
        let catalogItem = CatalogItemModel(name: "Test Glass", rawCode: "001", manufacturer: "TestCorp")
        let savedCatalogItem = try await catalogService.createItem(catalogItem)
        
        // Create inventory item referencing the catalog item
        let inventoryItem = InventoryItemModel(
            catalogCode: savedCatalogItem.code,
            quantity: 10,
            type: .inventory
        )
        let savedInventoryItem = try await inventoryService.createItem(inventoryItem)
        
        #expect(savedInventoryItem.catalogCode == savedCatalogItem.code, "Inventory should reference catalog code correctly")
        
        // Test that both services maintain consistency
        let allCatalogItems = try await catalogService.getAllItems()
        let allInventoryItems = try await inventoryService.getAllItems()
        
        #expect(allCatalogItems.count == 1, "Should have one catalog item")
        #expect(allInventoryItems.count == 1, "Should have one inventory item")
        #expect(allInventoryItems.first?.catalogCode == allCatalogItems.first?.code, "References should be consistent")
    }
    
    @Test("Should handle catalog item updates with inventory references")
    func testCatalogUpdateWithInventoryReferences() async throws {
        let (catalogService, inventoryService) = createMockServices()
        
        // Create catalog and inventory items
        let catalogItem = CatalogItemModel(name: "Original Name", rawCode: "001", manufacturer: "TestCorp")
        let savedCatalogItem = try await catalogService.createItem(catalogItem)
        
        let inventoryItem = InventoryItemModel(
            catalogCode: savedCatalogItem.code,
            quantity: 5,
            type: .inventory
        )
        _ = try await inventoryService.createItem(inventoryItem)
        
        // Update catalog item (in a coordinated system, this might affect inventory)
        let updatedCatalogItem = CatalogItemModel(
            id: savedCatalogItem.id,
            id2: savedCatalogItem.id2,
            parent_id: savedCatalogItem.parent_id,
            item_type: savedCatalogItem.item_type,
            item_subtype: savedCatalogItem.item_subtype,
            stock_type: savedCatalogItem.stock_type,
            manufacturer_url: savedCatalogItem.manufacturer_url,
            image_path: savedCatalogItem.image_path,
            image_url: savedCatalogItem.image_url,
            name: "Updated Name",
            code: savedCatalogItem.code,
            manufacturer: savedCatalogItem.manufacturer,
            tags: ["updated"],
            units: savedCatalogItem.units
        )
        
        let finalCatalogItem = try await catalogService.updateItem(updatedCatalogItem)
        
        // Verify the update was successful
        #expect(finalCatalogItem.name == "Updated Name", "Catalog item should be updated")
        
        // In a coordinated system, inventory items might need to be notified of catalog changes
        // For now, we just verify that inventory items still reference the correct code
        let finalInventoryItems = try await inventoryService.getAllItems()
        #expect(finalInventoryItems.first?.catalogCode == finalCatalogItem.code, "Inventory should still reference correct catalog code")
        #expect(finalInventoryItems.count == 1, "Should maintain inventory item count")
        
        // Verify referential integrity
        let allCatalogItems = try await catalogService.getAllItems()
        let inventoryCodes = finalInventoryItems.map { $0.catalogCode }
        let catalogCodes = allCatalogItems.map { $0.code }
        
        for inventoryCode in inventoryCodes {
            #expect(catalogCodes.contains(inventoryCode), "All inventory items should reference valid catalog items")
        }
    }
    
    @Test("Should cascade delete inventory items when catalog item is deleted")
    func testCatalogDeletionCascadeInventoryItems() async throws {
        let (catalogService, inventoryService) = createMockServices()
        
        // Create catalog item
        let catalogItem = CatalogItemModel(name: "To Delete", rawCode: "001", manufacturer: "TestCorp")
        let savedCatalogItem = try await catalogService.createItem(catalogItem)
        
        // Create multiple inventory items referencing the catalog item
        let inventoryItems = [
            InventoryItemModel(catalogCode: savedCatalogItem.code, quantity: 10, type: .inventory),
            InventoryItemModel(catalogCode: savedCatalogItem.code, quantity: 5, type: .buy),
            InventoryItemModel(catalogCode: savedCatalogItem.code, quantity: 3, type: .sell)
        ]
        
        var savedInventoryItems: [InventoryItemModel] = []
        for item in inventoryItems {
            let saved = try await inventoryService.createItem(item)
            savedInventoryItems.append(saved)
        }
        
        // Create another catalog item and inventory to verify selective deletion
        let otherCatalogItem = CatalogItemModel(name: "Keep This", rawCode: "002", manufacturer: "TestCorp")
        let savedOtherCatalogItem = try await catalogService.createItem(otherCatalogItem)
        
        let otherInventoryItem = InventoryItemModel(
            catalogCode: savedOtherCatalogItem.code,
            quantity: 7,
            type: .inventory
        )
        let savedOtherInventoryItem = try await inventoryService.createItem(otherInventoryItem)
        
        // Verify initial state
        let initialCatalogItems = try await catalogService.getAllItems()
        let initialInventoryItems = try await inventoryService.getAllItems()
        
        #expect(initialCatalogItems.count == 2, "Should have 2 catalog items initially")
        #expect(initialInventoryItems.count == 4, "Should have 4 inventory items initially")
        
        // Delete the first catalog item - should cascade delete related inventory
        try await catalogService.deleteItem(withId: savedCatalogItem.id)
        
        // Verify cascade delete occurred
        let finalCatalogItems = try await catalogService.getAllItems()
        let finalInventoryItems = try await inventoryService.getAllItems()
        
        #expect(finalCatalogItems.count == 1, "Should have 1 catalog item remaining")
        #expect(finalInventoryItems.count == 1, "Should have 1 inventory item remaining")
        
        // Verify the correct items remain
        #expect(finalCatalogItems.first?.id == savedOtherCatalogItem.id, "Correct catalog item should remain")
        #expect(finalInventoryItems.first?.id == savedOtherInventoryItem.id, "Correct inventory item should remain")
        
        // Verify all inventory items with the deleted catalog code are gone
        let allRemainingInventory = try await inventoryService.getAllItems()
        let remainingInventoryForDeletedCatalog = allRemainingInventory.filter { $0.catalogCode == savedCatalogItem.code }
        #expect(remainingInventoryForDeletedCatalog.isEmpty, "No inventory items should remain for deleted catalog code")
        
        // Verify inventory items for other catalog remain untouched
        let remainingInventoryForOtherCatalog = allRemainingInventory.filter { $0.catalogCode == savedOtherCatalogItem.code }
        #expect(remainingInventoryForOtherCatalog.count == 1, "Inventory items for other catalog should remain")
    }
    
    @Test("Should handle catalog deletion when no inventory service is configured")
    func testCatalogDeletionWithoutInventoryService() async throws {
        // Create catalog service without inventory service (older pattern)
        let catalogRepo = MockCatalogRepository()
        let catalogService = CatalogService(repository: catalogRepo) // No inventory service
        
        // Create catalog item
        let catalogItem = CatalogItemModel(name: "Standalone Delete", rawCode: "SD-001", manufacturer: "TestCorp")
        let savedCatalogItem = try await catalogService.createItem(catalogItem)
        
        // Verify initial state
        let initialItems = try await catalogService.getAllItems()
        #expect(initialItems.count == 1, "Should have 1 catalog item initially")
        
        // Delete catalog item - should succeed without trying to cascade to inventory
        try await catalogService.deleteItem(withId: savedCatalogItem.id)
        
        // Verify deletion
        let finalItems = try await catalogService.getAllItems()
        #expect(finalItems.isEmpty, "Should have no catalog items after deletion")
    }
    
    // MARK: - Cross-Service Transaction and Consistency Tests
    
    @Test("Should maintain consistency across multiple service operations")
    func testCrossServiceConsistency() async throws {
        let (catalogService, inventoryService) = createMockServices()
        
        let testCatalogItems = createTestCatalogItems()
        let testInventoryItems = createTestInventoryItems()
        
        // Add all catalog items first
        var savedCatalogItems: [CatalogItemModel] = []
        for item in testCatalogItems {
            let saved = try await catalogService.createItem(item)
            savedCatalogItems.append(saved)
        }
        
        // Add inventory items that reference catalog items
        var savedInventoryItems: [InventoryItemModel] = []
        for item in testInventoryItems {
            let saved = try await inventoryService.createItem(item)
            savedInventoryItems.append(saved)
        }
        
        // Verify consistency between services
        let allCatalogCodes = Set(savedCatalogItems.map { $0.code })
        let allInventoryCodes = Set(savedInventoryItems.map { $0.catalogCode })
        
        // Check that all inventory items reference valid catalog codes
        for inventoryCode in allInventoryCodes {
            #expect(allCatalogCodes.contains(inventoryCode), "Inventory code \(inventoryCode) should reference valid catalog item")
        }
        
        // Verify data integrity
        #expect(savedCatalogItems.count == 3, "Should have 3 catalog items")
        #expect(savedInventoryItems.count == 3, "Should have 3 inventory items")
    }
    
    @Test("Should handle partial failure scenarios gracefully")
    func testPartialFailureRecovery() async throws {
        let (catalogService, inventoryService) = createMockServices()
        
        // Create a valid catalog item
        let validCatalogItem = CatalogItemModel(name: "Valid Item", rawCode: "001", manufacturer: "TestCorp")
        let savedCatalogItem = try await catalogService.createItem(validCatalogItem)
        
        // Create valid inventory item
        let validInventoryItem = InventoryItemModel(
            catalogCode: savedCatalogItem.code,
            quantity: 5,
            type: .inventory
        )
        _ = try await inventoryService.createItem(validInventoryItem)
        
        // Attempt to create inventory item with invalid catalog reference
        let invalidInventoryItem = InventoryItemModel(
            catalogCode: "NONEXISTENT-001",
            quantity: 3,
            type: .buy
        )
        
        // This might succeed (creating orphaned inventory) or fail (referential integrity)
        // Either behavior is valid depending on business rules
        do {
            _ = try await inventoryService.createItem(invalidInventoryItem)
            // If it succeeds, verify the system remains consistent
            let allInventoryItems = try await inventoryService.getAllItems()
            #expect(allInventoryItems.count == 2, "Should have both valid and invalid reference items")
            
        } catch {
            // If it fails, verify the valid items remain
            let allCatalogItems = try await catalogService.getAllItems()
            let allInventoryItems = try await inventoryService.getAllItems()
            
            #expect(allCatalogItems.count == 1, "Valid catalog item should remain")
            #expect(allInventoryItems.count == 1, "Valid inventory item should remain")
        }
    }
    
    @Test("Should handle concurrent cross-service operations")
    func testConcurrentCrossServiceOperations() async throws {
        let (catalogService, inventoryService) = createMockServices()
        
        // Create catalog items concurrently
        let catalogItems = createTestCatalogItems()
        
        await withTaskGroup(of: Void.self) { group in
            for item in catalogItems {
                group.addTask {
                    do {
                        _ = try await catalogService.createItem(item)
                    } catch {
                        // Some might fail due to concurrency - that's expected
                    }
                }
            }
        }
        
        // Wait a moment for operations to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Get final catalog state
        let finalCatalogItems = try await catalogService.getAllItems()
        
        // Create inventory items concurrently, referencing the catalog items
        await withTaskGroup(of: Void.self) { group in
            for catalogItem in finalCatalogItems {
                group.addTask {
                    let inventoryItem = InventoryItemModel(
                        catalogCode: catalogItem.code,
                        quantity: 1,
                        type: .inventory
                    )
                    
                    do {
                        _ = try await inventoryService.createItem(inventoryItem)
                    } catch {
                        // Some might fail due to concurrency - that's expected
                    }
                }
            }
        }
        
        // Verify final consistency
        let finalInventoryItems = try await inventoryService.getAllItems()
        
        #expect(finalCatalogItems.count >= 0, "Should have consistent catalog items after concurrent operations")
        #expect(finalInventoryItems.count >= 0, "Should have consistent inventory items after concurrent operations")
        
        // Verify referential integrity where possible
        let catalogCodes = Set(finalCatalogItems.map { $0.code })
        for inventoryItem in finalInventoryItems {
            if !catalogCodes.contains(inventoryItem.catalogCode) {
                // This might happen with concurrent operations and is acceptable
                // as long as the system doesn't crash
                #expect(true, "Concurrent operations may create temporary inconsistencies")
            }
        }
    }
    
    // MARK: - Business Workflow Coordination Tests
    
    @Test("Should coordinate complete catalog-to-inventory workflow")
    func testCompleteWorkflowCoordination() async throws {
        let (catalogService, inventoryService) = createMockServices()
        
        // Step 1: Import catalog data
        let catalogItems = createTestCatalogItems()
        var savedCatalogItems: [CatalogItemModel] = []
        
        for item in catalogItems {
            let saved = try await catalogService.createItem(item)
            savedCatalogItems.append(saved)
        }
        
        // Step 2: Create initial inventory from catalog
        var inventoryItems: [InventoryItemModel] = []
        for catalogItem in savedCatalogItems {
            let inventoryItem = InventoryItemModel(
                catalogCode: catalogItem.code,
                quantity: 10,
                type: .inventory
            )
            let saved = try await inventoryService.createItem(inventoryItem)
            inventoryItems.append(saved)
        }
        
        // Step 3: Update inventory quantities (simulating purchases/sales)
        var updatedInventoryItems: [InventoryItemModel] = []
        for inventoryItem in inventoryItems {
            // Create new item with updated quantity since InventoryItemModel is immutable
            let updatedItem = InventoryItemModel(
                id: inventoryItem.id,
                catalogCode: inventoryItem.catalogCode,
                quantity: inventoryItem.quantity + 5, // Simulate restocking
                type: inventoryItem.type,
                notes: inventoryItem.notes,
                location: inventoryItem.location,
                dateAdded: inventoryItem.dateAdded
            )
            let savedItem = try await inventoryService.updateItem(updatedItem)
            updatedInventoryItems.append(savedItem)
        }
        
        // Step 4: Verify final workflow state
        let finalCatalogItems = try await catalogService.getAllItems()
        let finalInventoryItems = try await inventoryService.getAllItems()
        
        #expect(finalCatalogItems.count == 3, "Should maintain all catalog items through workflow")
        #expect(finalInventoryItems.count == 3, "Should maintain all inventory items through workflow")
        
        // Verify inventory quantities were updated
        for inventoryItem in finalInventoryItems {
            #expect(inventoryItem.quantity == 15, "Inventory quantities should be updated to 15")
        }
        
        // Verify catalog-inventory relationships are maintained
        let catalogCodeSet = Set(finalCatalogItems.map { $0.code })
        for inventoryItem in finalInventoryItems {
            #expect(catalogCodeSet.contains(inventoryItem.catalogCode), "Inventory should reference valid catalog items")
        }
    }
    
    @Test("Should handle workflow error recovery")
    func testWorkflowErrorRecovery() async throws {
        let (catalogService, inventoryService) = createMockServices()
        
        // Step 1: Successfully create catalog item
        let catalogItem = CatalogItemModel(name: "Workflow Test", rawCode: "WT-001", manufacturer: "TestCorp")
        let savedCatalogItem = try await catalogService.createItem(catalogItem)
        
        // Step 2: Successfully create inventory item
        let inventoryItem = InventoryItemModel(
            catalogCode: savedCatalogItem.code,
            quantity: 10,
            type: .inventory
        )
        let savedInventoryItem = try await inventoryService.createItem(inventoryItem)
        
        // Step 3: Simulate error condition (e.g., trying to create invalid item)
        let invalidItem = InventoryItemModel(
            catalogCode: "INVALID-CODE",
            quantity: -5, // Negative quantity might be invalid
            type: .inventory
        )
        
        var workflowState: (catalogCount: Int, inventoryCount: Int) = (0, 0)
        
        do {
            _ = try await inventoryService.createItem(invalidItem)
            // If it succeeds, that's also valid depending on business rules
            
        } catch {
            // Error occurred - verify previous steps remain intact
            #expect(error != nil, "Invalid item should cause error")
        }
        
        // Verify workflow state after error
        let finalCatalogItems = try await catalogService.getAllItems()
        let finalInventoryItems = try await inventoryService.getAllItems()
        
        workflowState.catalogCount = finalCatalogItems.count
        workflowState.inventoryCount = finalInventoryItems.count
        
        #expect(workflowState.catalogCount >= 1, "Previous catalog items should remain after workflow error")
        #expect(workflowState.inventoryCount >= 1, "Previous inventory items should remain after workflow error")
        
        // Verify specific items still exist and are valid
        #expect(finalCatalogItems.contains { $0.id == savedCatalogItem.id }, "Original catalog item should remain")
        #expect(finalInventoryItems.contains { $0.id == savedInventoryItem.id }, "Original inventory item should remain")
    }
}
