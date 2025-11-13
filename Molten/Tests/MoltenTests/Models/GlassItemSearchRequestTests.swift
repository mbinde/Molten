//
//  GlassItemSearchRequestTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for GlassItemSearchRequest filtering business logic
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
@Suite("GlassItemSearchRequest Filtering Tests")
struct GlassItemSearchRequestTests {

    // MARK: - Test Helpers

    private func createItem(
        stableId: String,
        name: String,
        manufacturer: String,
        coe: Int32,
        status: String,
        tags: [String] = [],
        hasInventory: Bool = false
    ) -> CompleteInventoryItemModel {
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: name,
            sku: "001",
            manufacturer: manufacturer,
            mfr_notes: "Test",
            coe: coe,
            url: nil,
            mfr_status: status
        )

        let inventory: [InventoryModel] = hasInventory ? [
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 10.0)
        ] : []

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: tags,
            userTags: []
        )
    }

    // MARK: - Manufacturer Filter Tests

    @Test("Should filter by manufacturers")
    func testFilterByManufacturers() {
        let items = [
            createItem(stableId: "1", name: "Clear", manufacturer: "bullseye", coe: 90, status: "available"),
            createItem(stableId: "2", name: "Blue", manufacturer: "effetre", coe: 104, status: "available"),
            createItem(stableId: "3", name: "Red", manufacturer: "bullseye", coe: 90, status: "available")
        ]

        let request = GlassItemSearchRequest(manufacturers: ["bullseye"])
        let filtered = request.filter(items, itemsWithTags: { _ in [] }, itemsWithInventory: { _ in false })

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.glassItem.manufacturer == "bullseye" })
    }

    // MARK: - COE Filter Tests

    @Test("Should filter by COE values")
    func testFilterByCOE() {
        let items = [
            createItem(stableId: "1", name: "Clear", manufacturer: "bullseye", coe: 90, status: "available"),
            createItem(stableId: "2", name: "Blue", manufacturer: "effetre", coe: 104, status: "available"),
            createItem(stableId: "3", name: "Red", manufacturer: "zimmerman", coe: 96, status: "available")
        ]

        let request = GlassItemSearchRequest(coeValues: [90, 96])
        let filtered = request.filter(items, itemsWithTags: { _ in [] }, itemsWithInventory: { _ in false })

        #expect(filtered.count == 2)
        #expect(filtered.contains { $0.glassItem.coe == 90 })
        #expect(filtered.contains { $0.glassItem.coe == 96 })
    }

    // MARK: - Status Filter Tests

    @Test("Should filter by manufacturer status")
    func testFilterByStatus() {
        let items = [
            createItem(stableId: "1", name: "Clear", manufacturer: "bullseye", coe: 90, status: "available"),
            createItem(stableId: "2", name: "Blue", manufacturer: "effetre", coe: 104, status: "discontinued"),
            createItem(stableId: "3", name: "Red", manufacturer: "zimmerman", coe: 96, status: "available")
        ]

        let request = GlassItemSearchRequest(manufacturerStatuses: ["available"])
        let filtered = request.filter(items, itemsWithTags: { _ in [] }, itemsWithInventory: { _ in false })

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.glassItem.mfr_status == "available" })
    }

    // MARK: - Tags Filter Tests

    @Test("Should filter by tags using closure")
    func testFilterByTags() {
        let items = [
            createItem(stableId: "1", name: "Clear", manufacturer: "bullseye", coe: 90, status: "available", tags: ["transparent", "coe90"]),
            createItem(stableId: "2", name: "Blue", manufacturer: "effetre", coe: 104, status: "available", tags: ["opaque"]),
            createItem(stableId: "3", name: "Red", manufacturer: "bullseye", coe: 90, status: "available", tags: ["transparent"])
        ]

        // Mock closure that returns items with ALL requested tags
        let itemsWithTagsClosure: ([String]) -> [String] = { requestedTags in
            // Return stable_ids that have all requested tags
            items.filter { item in
                Set(requestedTags).isSubset(of: Set(item.tags))
            }.map { $0.glassItem.stable_id }
        }

        let request = GlassItemSearchRequest(tags: ["transparent"])
        let filtered = request.filter(items, itemsWithTags: itemsWithTagsClosure, itemsWithInventory: { _ in false })

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.tags.contains("transparent") })
    }

    // MARK: - Inventory Filter Tests

    @Test("Should filter by inventory presence")
    func testFilterByInventoryPresence() {
        let items = [
            createItem(stableId: "1", name: "Clear", manufacturer: "bullseye", coe: 90, status: "available", hasInventory: true),
            createItem(stableId: "2", name: "Blue", manufacturer: "effetre", coe: 104, status: "available", hasInventory: false),
            createItem(stableId: "3", name: "Red", manufacturer: "zimmerman", coe: 96, status: "available", hasInventory: true)
        ]

        let inventoryClosure: (String) -> Bool = { stableId in
            items.first { $0.glassItem.stable_id == stableId }?.hasInventory ?? false
        }

        let request = GlassItemSearchRequest(hasInventory: true)
        let filtered = request.filter(items, itemsWithTags: { _ in [] }, itemsWithInventory: inventoryClosure)

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.hasInventory })
    }

    // MARK: - Combined Filters Tests

    @Test("Should apply multiple filters together")
    func testCombinedFilters() {
        let items = [
            createItem(stableId: "1", name: "Clear", manufacturer: "bullseye", coe: 90, status: "available", hasInventory: true),
            createItem(stableId: "2", name: "Blue", manufacturer: "effetre", coe: 104, status: "available", hasInventory: true),
            createItem(stableId: "3", name: "Red", manufacturer: "bullseye", coe: 90, status: "discontinued", hasInventory: false),
            createItem(stableId: "4", name: "Green", manufacturer: "bullseye", coe: 90, status: "available", hasInventory: false)
        ]

        let inventoryClosure: (String) -> Bool = { stableId in
            items.first { $0.glassItem.stable_id == stableId }?.hasInventory ?? false
        }

        let request = GlassItemSearchRequest(
            manufacturers: ["bullseye"],
            coeValues: [90],
            manufacturerStatuses: ["available"],
            hasInventory: true
        )

        let filtered = request.filter(items, itemsWithTags: { _ in [] }, itemsWithInventory: inventoryClosure)

        // Only item 1 matches all criteria
        #expect(filtered.count == 1)
        #expect(filtered[0].glassItem.stable_id == "1")
    }

    // MARK: - Edge Cases

    @Test("Should return all items when no filters applied")
    func testNoFilters() {
        let items = [
            createItem(stableId: "1", name: "Clear", manufacturer: "bullseye", coe: 90, status: "available"),
            createItem(stableId: "2", name: "Blue", manufacturer: "effetre", coe: 104, status: "available")
        ]

        let request = GlassItemSearchRequest()
        let filtered = request.filter(items, itemsWithTags: { _ in [] }, itemsWithInventory: { _ in false })

        #expect(filtered.count == 2)
    }

    @Test("Should return empty array when no items match")
    func testNoMatches() {
        let items = [
            createItem(stableId: "1", name: "Clear", manufacturer: "bullseye", coe: 90, status: "available"),
            createItem(stableId: "2", name: "Blue", manufacturer: "effetre", coe: 104, status: "available")
        ]

        let request = GlassItemSearchRequest(manufacturers: ["zimmerman"])
        let filtered = request.filter(items, itemsWithTags: { _ in [] }, itemsWithInventory: { _ in false })

        #expect(filtered.isEmpty)
    }
}
