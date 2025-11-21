//
//  InventoryEmptyStateTransitionTests.swift
//  MoltenTests
//
//  Tests to ensure the inventory view correctly transitions from empty state to list view
//  when items are added.
//

import Foundation
import Testing
@testable import Molten

@Suite("Inventory Empty State Transition Tests")
@MainActor
struct InventoryEmptyStateTransitionTests {

    @Test("Adding first item transitions from empty state to list view")
    func testEmptyToListTransition() async throws {
        // Create test dependencies with empty inventory
        let deps = AppDependencies(persistenceController: .createTestController())
        let viewModel = InventoryViewModel(
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService
        )

        // Load initial data - should be empty
        await viewModel.loadInventoryItems()
        #expect(viewModel.completeItems.isEmpty, "Should start with empty inventory")

        // Create a test item
        let testItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "test", sku: "001"),
            name: "Test Glass Item",
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Test item",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )

        // Add inventory for this item
        let inventory = InventoryModel(
            stable_id: testItem.stable_id,
            locationName: "Studio A",
            quantity: 10
        )

        // Create the item through the catalog service (which also creates inventory)
        _ = try await deps.catalogService.createGlassItem(testItem, initialInventory: [inventory], tags: [])

        // Reload inventory - should now have one item
        await viewModel.loadInventoryItems()

        // Verify the item appears in completeItems
        #expect(!viewModel.completeItems.isEmpty, "Should have items after adding")
        #expect(viewModel.completeItems.count == 1, "Should have exactly one item")

        // Verify the item has inventory
        let item = try #require(viewModel.completeItems.first)
        #expect(item.totalQuantity > 0, "Item should have inventory quantity")
        #expect(item.glassItem.stable_id == testItem.stable_id, "Should be the correct item")
    }

    @Test("Adding item to non-empty inventory doesn't break refresh")
    func testAddingToExistingInventory() async throws {
        // Create test dependencies
        let deps = AppDependencies(persistenceController: .createTestController())
        let viewModel = InventoryViewModel(
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService
        )

        // Create first item
        let item1 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "test", sku: "001"),
            name: "First Item",
            sku: "001",
            manufacturer: "test",
            mfr_notes: "First test item",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        let inventory1 = InventoryModel(
            stable_id: item1.stable_id,
            locationName: "Studio A",
            quantity: 5
        )
        _ = try await deps.catalogService.createGlassItem(item1, initialInventory: [inventory1], tags: [])

        // Load and verify first item
        await viewModel.loadInventoryItems()
        #expect(viewModel.completeItems.count == 1, "Should have one item")

        // Create second item
        let item2 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "test", sku: "002"),
            name: "Second Item",
            sku: "002",
            manufacturer: "test",
            mfr_notes: "Second test item",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        let inventory2 = InventoryModel(
            stable_id: item2.stable_id,
            locationName: "Studio B",
            quantity: 3
        )
        _ = try await deps.catalogService.createGlassItem(item2, initialInventory: [inventory2], tags: [])

        // Reload and verify both items appear
        await viewModel.loadInventoryItems()
        #expect(viewModel.completeItems.count == 2, "Should have two items")

        // Verify both items have inventory
        for item in viewModel.completeItems {
            #expect(item.totalQuantity > 0, "Each item should have inventory")
        }
    }

    @Test("Deleting last item transitions back to empty state")
    func testListToEmptyTransition() async throws {
        // Create test dependencies
        let deps = AppDependencies(persistenceController: .createTestController())
        let viewModel = InventoryViewModel(
            inventoryTrackingService: deps.inventoryTrackingService,
            catalogService: deps.catalogService
        )

        // Create a test item with inventory
        let testItem = GlassItemModel(
            stable_id: generateStableId(manufacturer: "test", sku: "001"),
            name: "Test Item",
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Test item",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )
        let inventory = InventoryModel(
            stable_id: testItem.stable_id,
            locationName: "Studio A",
            quantity: 5
        )
        _ = try await deps.catalogService.createGlassItem(testItem, initialInventory: [inventory], tags: [])

        // Load and verify item exists
        await viewModel.loadInventoryItems()
        #expect(viewModel.completeItems.count == 1, "Should have one item")

        // Delete all inventory for this item
        try await deps.inventoryTrackingService.deleteAllInventoryForItem(testItem.stable_id)

        // Reload - should be empty again
        await viewModel.loadInventoryItems()

        // Verify inventory is empty (items with zero quantity are filtered out)
        let itemsWithInventory = viewModel.completeItems.filter { $0.totalQuantity > 0 }
        #expect(itemsWithInventory.isEmpty, "Should have no items with inventory after deletion")
    }
}
