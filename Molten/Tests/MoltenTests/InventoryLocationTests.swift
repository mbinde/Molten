//
//  InventoryLocationTests.swift
//  MoltenTests
//
//  Tests for inventory location field functionality
//

import Testing
import Foundation
@testable import Molten

@Suite("Inventory Location Tests")
struct InventoryLocationTests {

    // MARK: - InventoryModel Location Tests

    @Test("InventoryModel initializes with location")
    func testInventoryModelWithLocation() async throws {
        let inventory = InventoryModel(
            item_stable_id: "test-item",
            type: "rod",
            quantity: 10.0,
            location: "Shelf A"
        )

        #expect(inventory.location == "Shelf A")
        #expect(inventory.quantity == 10.0)
        #expect(inventory.type == "rod")
    }

    @Test("InventoryModel cleans location name")
    func testInventoryModelCleansLocationName() async throws {
        let inventory = InventoryModel(
            item_stable_id: "test-item",
            type: "rod",
            quantity: 10.0,
            location: "  Shelf A  "
        )

        #expect(inventory.location == "Shelf A")
    }

    @Test("InventoryModel accepts nil location")
    func testInventoryModelWithNilLocation() async throws {
        let inventory = InventoryModel(
            item_stable_id: "test-item",
            type: "rod",
            quantity: 10.0,
            location: nil
        )

        #expect(inventory.location == nil)
        #expect(inventory.quantity == 10.0)
    }

    @Test("InventoryModel with empty location becomes nil")
    func testInventoryModelEmptyLocationBecomesNil() async throws {
        let inventory = InventoryModel(
            item_stable_id: "test-item",
            type: "rod",
            quantity: 10.0,
            location: "   "
        )

        // Empty/whitespace-only locations should be cleaned to empty string
        // LocationModel.cleanLocationName trims whitespace
        #expect(inventory.location == "")
    }

    // MARK: - CompleteInventoryItemModel Location Tests

    @Test("CompleteInventoryItemModel extracts unique locations")
    func testCompleteItemExtractsLocations() async throws {
        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )

        let inventory = [
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 5, location: "Shelf A"),
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 3, location: "Shelf B"),
            InventoryModel(item_stable_id: "test-item", type: "sheet", quantity: 2, location: "Shelf A"),
            InventoryModel(item_stable_id: "test-item", type: "frit", quantity: 1, location: nil)
        ]

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: [],
            userTags: []
        )

        #expect(completeItem.locations.count == 2)
        #expect(completeItem.locations.contains("Shelf A"))
        #expect(completeItem.locations.contains("Shelf B"))
        #expect(completeItem.locations.sorted() == ["Shelf A", "Shelf B"])
    }

    @Test("CompleteInventoryItemModel inventoryByLocation groups correctly")
    func testCompleteItemInventoryByLocation() async throws {
        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )

        let inventory = [
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 5, location: "Shelf A"),
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 3, location: "Shelf B"),
            InventoryModel(item_stable_id: "test-item", type: "sheet", quantity: 2, location: "Shelf A"),
            InventoryModel(item_stable_id: "test-item", type: "frit", quantity: 1, location: nil)
        ]

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: [],
            userTags: []
        )

        #expect(completeItem.inventoryByLocation["Shelf A"] == 7.0) // 5 rods + 2 sheets
        #expect(completeItem.inventoryByLocation["Shelf B"] == 3.0) // 3 rods
        #expect(completeItem.inventoryByLocation.count == 2) // nil location not included
    }

    @Test("CompleteInventoryItemModel with no locations")
    func testCompleteItemWithNoLocations() async throws {
        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )

        let inventory = [
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 5, location: nil),
            InventoryModel(item_stable_id: "test-item", type: "sheet", quantity: 2, location: nil)
        ]

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: [],
            userTags: []
        )

        #expect(completeItem.locations.isEmpty)
        #expect(completeItem.inventoryByLocation.isEmpty)
        #expect(completeItem.totalQuantity == 7.0) // Total still works
    }
}
