//
//  LowStockReportModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for LowStockReportModel aggregation business logic
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
@Suite("LowStockReportModel Tests")
struct LowStockReportModelTests {

    // MARK: - Test Helpers

    private func createDetailedItem(
        stableId: String,
        type: String,
        store: String,
        shortfall: Double
    ) -> DetailedLowStockItemModel {
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: "Test Item",
            sku: "001",
            manufacturer: "test",
            mfr_notes: "Test",
            coe: 96,
            url: nil,
            mfr_status: "available"
        )

        let lowStockItem = LowStockItemModel(
            item_stable_id: stableId,
            type: type,
            minimumQuantity: 10.0,
            currentQuantity: 10.0 - shortfall,
            shortfall: shortfall,
            store: store
        )

        return DetailedLowStockItemModel(
            lowStockItem: lowStockItem,
            glassItem: glassItem,
            tags: []
        )
    }

    // MARK: - Factory Method Tests

    @Test("Should group items by store")
    func testGroupByStore() {
        let items = [
            createDetailedItem(stableId: "test-001-0", type: "rod", store: "Store A", shortfall: 5.0),
            createDetailedItem(stableId: "test-002-0", type: "rod", store: "Store A", shortfall: 3.0),
            createDetailedItem(stableId: "test-003-0", type: "rod", store: "Store B", shortfall: 2.0)
        ]

        let report = LowStockReportModel.from(items: items)

        // Should have 2 stores in groupedByStore
        #expect(report.groupedByStore.keys.count == 2)
        #expect(report.groupedByStore["Store A"]?.count == 2)
        #expect(report.groupedByStore["Store B"]?.count == 1)
    }

    @Test("Should calculate total items low")
    func testCalculateTotalItemsLow() {
        let items = [
            createDetailedItem(stableId: "test-001-0", type: "rod", store: "Store A", shortfall: 5.0),
            createDetailedItem(stableId: "test-002-0", type: "rod", store: "Store A", shortfall: 3.0),
            createDetailedItem(stableId: "test-003-0", type: "rod", store: "Store B", shortfall: 2.0)
        ]

        let report = LowStockReportModel.from(items: items)

        #expect(report.totalItemsLow == 3)
    }

    @Test("Should calculate total shortfall")
    func testCalculateTotalShortfall() {
        let items = [
            createDetailedItem(stableId: "test-001-0", type: "rod", store: "Store A", shortfall: 5.0),
            createDetailedItem(stableId: "test-002-0", type: "rod", store: "Store A", shortfall: 3.0),
            createDetailedItem(stableId: "test-003-0", type: "rod", store: "Store B", shortfall: 2.0)
        ]

        let report = LowStockReportModel.from(items: items)

        // Total shortfall: 5.0 + 3.0 + 2.0 = 10.0
        #expect(report.totalShortfall == 10.0)
    }

    @Test("Should calculate stores affected")
    func testCalculateStoresAffected() {
        let items = [
            createDetailedItem(stableId: "test-001-0", type: "rod", store: "Store A", shortfall: 5.0),
            createDetailedItem(stableId: "test-002-0", type: "rod", store: "Store A", shortfall: 3.0),
            createDetailedItem(stableId: "test-003-0", type: "rod", store: "Store B", shortfall: 2.0),
            createDetailedItem(stableId: "test-004-0", type: "rod", store: "Store C", shortfall: 1.0)
        ]

        let report = LowStockReportModel.from(items: items)

        // 3 unique stores (A, B, C)
        #expect(report.storesAffected == 3)
    }

    @Test("Should handle empty items list")
    func testEmptyItems() {
        let items: [DetailedLowStockItemModel] = []

        let report = LowStockReportModel.from(items: items)

        #expect(report.totalItemsLow == 0)
        #expect(report.totalShortfall == 0.0)
        #expect(report.storesAffected == 0)
        #expect(report.groupedByStore.isEmpty)
    }

    @Test("Should handle single store")
    func testSingleStore() {
        let items = [
            createDetailedItem(stableId: "test-001-0", type: "rod", store: "Store A", shortfall: 5.0),
            createDetailedItem(stableId: "test-002-0", type: "rod", store: "Store A", shortfall: 3.0)
        ]

        let report = LowStockReportModel.from(items: items)

        #expect(report.storesAffected == 1)
        #expect(report.groupedByStore.keys.count == 1)
        #expect(report.groupedByStore["Store A"]?.count == 2)
    }

    @Test("Should preserve all items in report")
    func testPreserveItems() {
        let items = [
            createDetailedItem(stableId: "test-001-0", type: "rod", store: "Store A", shortfall: 5.0),
            createDetailedItem(stableId: "test-002-0", type: "rod", store: "Store B", shortfall: 3.0)
        ]

        let report = LowStockReportModel.from(items: items)

        #expect(report.items.count == 2)
        #expect(report.items[0].lowStockItem.item_stable_id == "test-001-0")
        #expect(report.items[1].lowStockItem.item_stable_id == "test-002-0")
    }

    @Test("Should set generatedAt timestamp")
    func testGeneratedAtTimestamp() {
        let items = [
            createDetailedItem(stableId: "test-001-0", type: "rod", store: "Store A", shortfall: 5.0)
        ]

        let beforeGeneration = Date()
        let report = LowStockReportModel.from(items: items)
        let afterGeneration = Date()

        // generatedAt should be between before and after timestamps
        #expect(report.generatedAt >= beforeGeneration)
        #expect(report.generatedAt <= afterGeneration)
    }
}
