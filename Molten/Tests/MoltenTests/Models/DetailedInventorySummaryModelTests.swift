//
//  DetailedInventorySummaryModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for DetailedInventorySummaryModel aggregation business logic
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@MainActor
@Suite("DetailedInventorySummaryModel Tests")
struct DetailedInventorySummaryModelTests {

    // MARK: - Test Helpers

    private func createSummary(itemStableId: String, inventories: [InventoryModel]) -> InventorySummaryModel {
        return InventorySummaryModel(
            item_stable_id: itemStableId,
            inventories: inventories
        )
    }

    private func createInventory(
        stableId: String,
        type: String,
        quantity: Double,
        location: String?
    ) -> InventoryModel {
        return InventoryModel(
            item_stable_id: stableId,
            type: type,
            quantity: quantity,
            location: location
        )
    }

    // MARK: - Factory Method Tests

    @Test("Should aggregate inventory by type and location")
    func testAggregateByTypeAndLocation() {
        let inventories = [
            createInventory(stableId: "test-001-0", type: "rod", quantity: 5.0, location: "Shelf A"),
            createInventory(stableId: "test-001-0", type: "rod", quantity: 3.0, location: "Shelf B"),
            createInventory(stableId: "test-001-0", type: "frit", quantity: 2.0, location: "Bin 1")
        ]

        let summary = createSummary(itemStableId: "test-001-0", inventories: inventories)
        let detailed = DetailedInventorySummaryModel.from(summary: summary, inventory: inventories)

        // Should have 2 types in locationDetails
        #expect(detailed.locationDetails.keys.count == 2)
        #expect(detailed.locationDetails["rod"]?.count == 2)
        #expect(detailed.locationDetails["frit"]?.count == 1)

        // Verify rod locations
        let rodLocations = detailed.locationDetails["rod"]!
        #expect(rodLocations.contains { $0.location == "Shelf A" && $0.quantity == 5.0 })
        #expect(rodLocations.contains { $0.location == "Shelf B" && $0.quantity == 3.0 })

        // Verify frit location
        let fritLocations = detailed.locationDetails["frit"]!
        #expect(fritLocations.first?.location == "Bin 1")
        #expect(fritLocations.first?.quantity == 2.0)
    }

    @Test("Should handle inventory with no locations (empty locationDetails)")
    func testNoLocations() {
        let inventories = [
            createInventory(stableId: "test-001-0", type: "rod", quantity: 5.0, location: nil),
            createInventory(stableId: "test-001-0", type: "frit", quantity: 2.0, location: nil)
        ]

        let summary = createSummary(itemStableId: "test-001-0", inventories: inventories)
        let detailed = DetailedInventorySummaryModel.from(summary: summary, inventory: inventories)

        // locationDetails should be empty (only tracks inventory WITH locations)
        #expect(detailed.locationDetails.isEmpty)
    }

    @Test("Should handle mixed inventory (some with locations, some without)")
    func testMixedLocations() {
        let inventories = [
            createInventory(stableId: "test-001-0", type: "rod", quantity: 5.0, location: "Shelf A"),
            createInventory(stableId: "test-001-0", type: "rod", quantity: 3.0, location: nil),
            createInventory(stableId: "test-001-0", type: "frit", quantity: 2.0, location: nil)
        ]

        let summary = createSummary(itemStableId: "test-001-0", inventories: inventories)
        let detailed = DetailedInventorySummaryModel.from(summary: summary, inventory: inventories)

        // Should only track the rod with location
        #expect(detailed.locationDetails.keys.count == 1)
        #expect(detailed.locationDetails["rod"]?.count == 1)
        #expect(detailed.locationDetails["rod"]?.first?.location == "Shelf A")
        #expect(detailed.locationDetails["rod"]?.first?.quantity == 5.0)
    }

    @Test("Should handle empty inventory (empty locationDetails)")
    func testEmptyInventory() {
        let inventories: [InventoryModel] = []

        let summary = createSummary(itemStableId: "test-001-0", inventories: inventories)
        let detailed = DetailedInventorySummaryModel.from(summary: summary, inventory: inventories)

        #expect(detailed.locationDetails.isEmpty)
        #expect(detailed.summary.item_stable_id == "test-001-0")
    }

    @Test("Should handle multiple locations for same type")
    func testMultipleLocationsForSameType() {
        let inventories = [
            createInventory(stableId: "test-001-0", type: "rod", quantity: 5.0, location: "Shelf A"),
            createInventory(stableId: "test-001-0", type: "rod", quantity: 3.0, location: "Shelf B"),
            createInventory(stableId: "test-001-0", type: "rod", quantity: 2.0, location: "Shelf C")
        ]

        let summary = createSummary(itemStableId: "test-001-0", inventories: inventories)
        let detailed = DetailedInventorySummaryModel.from(summary: summary, inventory: inventories)

        // Should have all 3 locations tracked for "rod"
        #expect(detailed.locationDetails["rod"]?.count == 3)

        let rodLocations = detailed.locationDetails["rod"]!
        #expect(rodLocations.contains { $0.location == "Shelf A" && $0.quantity == 5.0 })
        #expect(rodLocations.contains { $0.location == "Shelf B" && $0.quantity == 3.0 })
        #expect(rodLocations.contains { $0.location == "Shelf C" && $0.quantity == 2.0 })
    }

    @Test("Should preserve summary reference")
    func testPreserveSummary() {
        let inventories = [
            createInventory(stableId: "test-001-0", type: "rod", quantity: 5.0, location: "Shelf A")
        ]

        let summary = createSummary(itemStableId: "test-001-0", inventories: inventories)
        let detailed = DetailedInventorySummaryModel.from(summary: summary, inventory: inventories)

        // Should preserve the summary
        #expect(detailed.summary.item_stable_id == "test-001-0")
        #expect(detailed.summary.totalQuantity == 5.0)
    }
}
