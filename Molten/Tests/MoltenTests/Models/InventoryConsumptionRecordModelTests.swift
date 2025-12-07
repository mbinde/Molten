//
//  InventoryConsumptionRecordModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-12-04.
//  Tests for InventoryConsumptionRecordModel struct
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
@Suite("InventoryConsumptionRecordModel Tests")
struct InventoryConsumptionRecordModelTests {

    // MARK: - Initialization Tests

    @Test("Should initialize with all required fields")
    func testInitWithRequiredFields() {
        let storageLocationId = UUID()
        let record = InventoryConsumptionRecordModel(
            storageLocationId: storageLocationId,
            quantity: 5.0
        )

        #expect(record.storageLocationId == storageLocationId)
        #expect(record.quantity == 5.0)
        #expect(record.containerCount == nil)
        #expect(record.id != UUID())  // Should have generated an ID
    }

    @Test("Should initialize with custom ID")
    func testInitWithCustomId() {
        let customId = UUID()
        let record = InventoryConsumptionRecordModel(
            id: customId,
            storageLocationId: UUID(),
            quantity: 3.0
        )

        #expect(record.id == customId)
    }

    @Test("Should initialize with containerCount for weight-based consumption")
    func testInitWithContainerCount() {
        let record = InventoryConsumptionRecordModel(
            storageLocationId: UUID(),
            quantity: 250.0,
            containerCount: 2.0
        )

        #expect(record.quantity == 250.0)
        #expect(record.containerCount == 2.0)
    }

    @Test("Should default date to now")
    func testDefaultDate() {
        let before = Date()
        let record = InventoryConsumptionRecordModel(
            storageLocationId: UUID(),
            quantity: 1.0
        )
        let after = Date()

        #expect(record.date >= before)
        #expect(record.date <= after)
    }

    @Test("Should accept custom date")
    func testCustomDate() {
        let customDate = Date(timeIntervalSince1970: 1000000)
        let record = InventoryConsumptionRecordModel(
            storageLocationId: UUID(),
            quantity: 1.0,
            date: customDate
        )

        #expect(record.date == customDate)
    }

    // MARK: - Quantity Tests

    @Test("Should preserve zero quantity")
    func testZeroQuantity() {
        let record = InventoryConsumptionRecordModel(
            storageLocationId: UUID(),
            quantity: 0.0
        )

        #expect(record.quantity == 0.0)
    }

    @Test("Should preserve fractional quantity")
    func testFractionalQuantity() {
        let record = InventoryConsumptionRecordModel(
            storageLocationId: UUID(),
            quantity: 2.5
        )

        #expect(record.quantity == 2.5)
    }

    @Test("Should preserve large quantity")
    func testLargeQuantity() {
        let record = InventoryConsumptionRecordModel(
            storageLocationId: UUID(),
            quantity: 999999.99
        )

        #expect(record.quantity == 999999.99)
    }

    // MARK: - Container Count Tests

    @Test("Should allow nil containerCount")
    func testNilContainerCount() {
        let record = InventoryConsumptionRecordModel(
            storageLocationId: UUID(),
            quantity: 100.0
        )

        #expect(record.containerCount == nil)
    }

    @Test("Should preserve fractional containerCount")
    func testFractionalContainerCount() {
        let record = InventoryConsumptionRecordModel(
            storageLocationId: UUID(),
            quantity: 150.0,
            containerCount: 1.5
        )

        #expect(record.containerCount == 1.5)
    }

    @Test("Should preserve zero containerCount")
    func testZeroContainerCount() {
        let record = InventoryConsumptionRecordModel(
            storageLocationId: UUID(),
            quantity: 50.0,
            containerCount: 0.0
        )

        #expect(record.containerCount == 0.0)
    }

    // MARK: - Equatable Tests

    @Test("Should be equal when IDs match")
    func testEqualityById() {
        let id = UUID()
        let record1 = InventoryConsumptionRecordModel(
            id: id,
            storageLocationId: UUID(),
            quantity: 5.0
        )
        let record2 = InventoryConsumptionRecordModel(
            id: id,
            storageLocationId: UUID(),  // Different storage location
            quantity: 10.0  // Different quantity
        )

        #expect(record1 == record2)
    }

    @Test("Should not be equal when IDs differ")
    func testInequalityById() {
        let storageLocationId = UUID()
        let record1 = InventoryConsumptionRecordModel(
            storageLocationId: storageLocationId,
            quantity: 5.0
        )
        let record2 = InventoryConsumptionRecordModel(
            storageLocationId: storageLocationId,  // Same storage location
            quantity: 5.0  // Same quantity
        )

        #expect(record1 != record2)  // Different auto-generated IDs
    }

    // MARK: - Hashable Tests

    @Test("Should hash based on ID")
    func testHashableById() {
        let id = UUID()
        let record1 = InventoryConsumptionRecordModel(
            id: id,
            storageLocationId: UUID(),
            quantity: 5.0
        )
        let record2 = InventoryConsumptionRecordModel(
            id: id,
            storageLocationId: UUID(),
            quantity: 10.0
        )

        #expect(record1.hashValue == record2.hashValue)
    }

    @Test("Should work in Set")
    func testSetMembership() {
        let id = UUID()
        let record1 = InventoryConsumptionRecordModel(
            id: id,
            storageLocationId: UUID(),
            quantity: 5.0
        )
        let record2 = InventoryConsumptionRecordModel(
            id: id,
            storageLocationId: UUID(),
            quantity: 10.0
        )
        let record3 = InventoryConsumptionRecordModel(
            storageLocationId: UUID(),
            quantity: 5.0
        )

        var set = Set<InventoryConsumptionRecordModel>()
        set.insert(record1)
        set.insert(record2)  // Same ID, should not add
        set.insert(record3)  // Different ID, should add

        #expect(set.count == 2)
    }

    // MARK: - Identifiable Tests

    @Test("Should conform to Identifiable with id property")
    func testIdentifiable() {
        let id = UUID()
        let record = InventoryConsumptionRecordModel(
            id: id,
            storageLocationId: UUID(),
            quantity: 5.0
        )

        #expect(record.id == id)
    }

    // MARK: - Deduplication Key Tests

    @Test("Should track storage location for deduplication purposes")
    func testDeduplicationTracking() {
        let storageLocationId = UUID()
        let date = Date()

        let record1 = InventoryConsumptionRecordModel(
            storageLocationId: storageLocationId,
            quantity: 5.0,
            date: date
        )
        let record2 = InventoryConsumptionRecordModel(
            storageLocationId: storageLocationId,
            quantity: 3.0,
            date: date
        )

        // Both have same (storageLocationId, date) - service layer would dedupe these
        #expect(record1.storageLocationId == record2.storageLocationId)
        #expect(record1.date == record2.date)
    }
}
