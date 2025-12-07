//
//  InventoryMoveRecordModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-12-04.
//  Tests for InventoryMoveRecordModel struct
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
@Suite("InventoryMoveRecordModel Tests")
struct InventoryMoveRecordModelTests {

    // MARK: - Initialization Tests

    @Test("Should initialize with all required fields")
    func testInitWithRequiredFields() {
        let fromId = UUID()
        let toId = UUID()
        let record = InventoryMoveRecordModel(
            fromStorageLocationId: fromId,
            toStorageLocationId: toId,
            quantity: 5.0
        )

        #expect(record.fromStorageLocationId == fromId)
        #expect(record.toStorageLocationId == toId)
        #expect(record.quantity == 5.0)
        #expect(record.containerCount == nil)
        #expect(record.id != UUID())  // Should have generated an ID
    }

    @Test("Should initialize with custom ID")
    func testInitWithCustomId() {
        let customId = UUID()
        let record = InventoryMoveRecordModel(
            id: customId,
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 3.0
        )

        #expect(record.id == customId)
    }

    @Test("Should initialize with containerCount for weight-based moves")
    func testInitWithContainerCount() {
        let record = InventoryMoveRecordModel(
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 250.0,
            containerCount: 2.0
        )

        #expect(record.quantity == 250.0)
        #expect(record.containerCount == 2.0)
    }

    @Test("Should default date to now")
    func testDefaultDate() {
        let before = Date()
        let record = InventoryMoveRecordModel(
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 1.0
        )
        let after = Date()

        #expect(record.date >= before)
        #expect(record.date <= after)
    }

    @Test("Should accept custom date")
    func testCustomDate() {
        let customDate = Date(timeIntervalSince1970: 1000000)
        let record = InventoryMoveRecordModel(
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 1.0,
            date: customDate
        )

        #expect(record.date == customDate)
    }

    // MARK: - Quantity Tests

    @Test("Should preserve zero quantity")
    func testZeroQuantity() {
        let record = InventoryMoveRecordModel(
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 0.0
        )

        #expect(record.quantity == 0.0)
    }

    @Test("Should preserve fractional quantity")
    func testFractionalQuantity() {
        let record = InventoryMoveRecordModel(
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 2.5
        )

        #expect(record.quantity == 2.5)
    }

    @Test("Should preserve large quantity")
    func testLargeQuantity() {
        let record = InventoryMoveRecordModel(
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 999999.99
        )

        #expect(record.quantity == 999999.99)
    }

    // MARK: - Container Count Tests

    @Test("Should allow nil containerCount")
    func testNilContainerCount() {
        let record = InventoryMoveRecordModel(
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 100.0
        )

        #expect(record.containerCount == nil)
    }

    @Test("Should preserve fractional containerCount")
    func testFractionalContainerCount() {
        let record = InventoryMoveRecordModel(
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 150.0,
            containerCount: 1.5
        )

        #expect(record.containerCount == 1.5)
    }

    // MARK: - Equatable Tests

    @Test("Should be equal when IDs match")
    func testEqualityById() {
        let id = UUID()
        let record1 = InventoryMoveRecordModel(
            id: id,
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 5.0
        )
        let record2 = InventoryMoveRecordModel(
            id: id,
            fromStorageLocationId: UUID(),  // Different from/to IDs
            toStorageLocationId: UUID(),
            quantity: 10.0  // Different quantity
        )

        #expect(record1 == record2)
    }

    @Test("Should not be equal when IDs differ")
    func testInequalityById() {
        let fromId = UUID()
        let toId = UUID()
        let record1 = InventoryMoveRecordModel(
            fromStorageLocationId: fromId,
            toStorageLocationId: toId,
            quantity: 5.0
        )
        let record2 = InventoryMoveRecordModel(
            fromStorageLocationId: fromId,  // Same from/to
            toStorageLocationId: toId,
            quantity: 5.0  // Same quantity
        )

        #expect(record1 != record2)  // Different auto-generated IDs
    }

    // MARK: - Hashable Tests

    @Test("Should hash based on ID")
    func testHashableById() {
        let id = UUID()
        let record1 = InventoryMoveRecordModel(
            id: id,
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 5.0
        )
        let record2 = InventoryMoveRecordModel(
            id: id,
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 10.0
        )

        #expect(record1.hashValue == record2.hashValue)
    }

    @Test("Should work in Set")
    func testSetMembership() {
        let id = UUID()
        let record1 = InventoryMoveRecordModel(
            id: id,
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 5.0
        )
        let record2 = InventoryMoveRecordModel(
            id: id,
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 10.0
        )
        let record3 = InventoryMoveRecordModel(
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 5.0
        )

        var set = Set<InventoryMoveRecordModel>()
        set.insert(record1)
        set.insert(record2)  // Same ID, should not add
        set.insert(record3)  // Different ID, should add

        #expect(set.count == 2)
    }

    // MARK: - Identifiable Tests

    @Test("Should conform to Identifiable with id property")
    func testIdentifiable() {
        let id = UUID()
        let record = InventoryMoveRecordModel(
            id: id,
            fromStorageLocationId: UUID(),
            toStorageLocationId: UUID(),
            quantity: 5.0
        )

        #expect(record.id == id)
    }
}
