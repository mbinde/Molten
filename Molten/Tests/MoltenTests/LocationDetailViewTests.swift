//
//  LocationDetailViewTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/24/25.
//  Tests for location detail view logic
//

import Testing
import Foundation
@testable import Molten

/// Tests for LocationDetailView grouping and calculation logic
@Suite("LocationDetailView Tests")
struct LocationDetailViewTests {

    // MARK: - Grouping Logic Tests

    @Test("Group inventory records by location")
    func testGroupingByLocation() async throws {
        // Create test inventory records with different locations
        let records = [
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 5.0,
                location: "Studio"
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 3.0,
                location: "Studio"
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 2.0,
                location: "Storage"
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 1.0,
                location: nil  // No location
            )
        ]

        // Group by location (mimic the view logic)
        var grouped: [String: [InventoryModel]] = [:]
        for record in records {
            let locationKey = record.location ?? "No location"
            grouped[locationKey, default: []].append(record)
        }

        // Verify grouping
        #expect(grouped.keys.count == 3)
        #expect(grouped["Studio"]?.count == 2)
        #expect(grouped["Storage"]?.count == 1)
        #expect(grouped["No location"]?.count == 1)
    }

    @Test("Calculate total quantity for location")
    func testLocationQuantityCalculation() async throws {
        let records = [
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 5.5,
                location: "Studio"
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 3.0,
                location: "Studio"
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 2.0,
                location: "Studio"
            )
        ]

        let total = records.reduce(0.0) { $0 + $1.quantity }

        #expect(total == 10.5)
    }

    @Test("Calculate total quantity across all locations")
    func testTotalQuantityCalculation() async throws {
        let records = [
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 5.0,
                location: "Studio"
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 3.0,
                location: "Storage"
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 2.0,
                location: nil
            )
        ]

        let total = records.reduce(0.0) { $0 + $1.quantity }

        #expect(total == 10.0)
    }

    @Test("Filter records by type")
    func testFilterByType() async throws {
        let allRecords = [
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 5.0
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "sheet",
                quantity: 3.0
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 2.0
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "frit",
                quantity: 1.0
            )
        ]

        let rodRecords = allRecords.filter { $0.type == "rod" }

        #expect(rodRecords.count == 2)
        #expect(rodRecords.allSatisfy { $0.type == "rod" })
    }

    // MARK: - Deletion Logic Tests

    @Test("Remove record from grouped list")
    func testRecordRemoval() async throws {
        let record1 = InventoryModel(
            id: UUID(),
            item_stable_id: "test-001",
            type: "rod",
            quantity: 5.0,
            location: "Studio"
        )
        let record2 = InventoryModel(
            id: UUID(),
            item_stable_id: "test-001",
            type: "rod",
            quantity: 3.0,
            location: "Studio"
        )
        let record3 = InventoryModel(
            id: UUID(),
            item_stable_id: "test-001",
            type: "rod",
            quantity: 2.0,
            location: "Storage"
        )

        var records = [record1, record2, record3]

        // Remove record2
        records.removeAll { $0.id == record2.id }

        #expect(records.count == 2)
        #expect(records.contains { $0.id == record1.id })
        #expect(!records.contains { $0.id == record2.id })
        #expect(records.contains { $0.id == record3.id })
    }

    @Test("Regroup after deletion")
    func testRegroupAfterDeletion() async throws {
        let record1 = InventoryModel(
            id: UUID(),
            item_stable_id: "test-001",
            type: "rod",
            quantity: 5.0,
            location: "Studio"
        )
        let record2 = InventoryModel(
            id: UUID(),
            item_stable_id: "test-001",
            type: "rod",
            quantity: 3.0,
            location: "Studio"
        )
        let record3 = InventoryModel(
            id: UUID(),
            item_stable_id: "test-001",
            type: "rod",
            quantity: 2.0,
            location: "Storage"
        )

        var records = [record1, record2, record3]

        // Initial grouping
        var grouped: [String: [InventoryModel]] = [:]
        for record in records {
            let locationKey = record.location ?? "No location"
            grouped[locationKey, default: []].append(record)
        }

        #expect(grouped["Studio"]?.count == 2)
        #expect(grouped["Storage"]?.count == 1)

        // Delete record2 and regroup
        records.removeAll { $0.id == record2.id }
        grouped = [:]
        for record in records {
            let locationKey = record.location ?? "No location"
            grouped[locationKey, default: []].append(record)
        }

        #expect(grouped["Studio"]?.count == 1)
        #expect(grouped["Storage"]?.count == 1)
    }

    @Test("Empty location after deleting all records")
    func testEmptyLocationAfterDeletion() async throws {
        let record1 = InventoryModel(
            id: UUID(),
            item_stable_id: "test-001",
            type: "rod",
            quantity: 5.0,
            location: "Studio"
        )
        let record2 = InventoryModel(
            id: UUID(),
            item_stable_id: "test-001",
            type: "rod",
            quantity: 3.0,
            location: "Storage"
        )

        var records = [record1, record2]

        // Delete the only Studio record
        records.removeAll { $0.id == record1.id }

        // Regroup
        var grouped: [String: [InventoryModel]] = [:]
        for record in records {
            let locationKey = record.location ?? "No location"
            grouped[locationKey, default: []].append(record)
        }

        // Studio should not be in the grouped dict anymore
        #expect(grouped["Studio"] == nil)
        #expect(grouped["Storage"]?.count == 1)
    }

    // MARK: - Location Key Tests

    @Test("Handle nil location as 'No location'")
    func testNilLocationHandling() async throws {
        let records = [
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 5.0,
                location: nil
            ),
            InventoryModel(
                id: UUID(),
                item_stable_id: "test-001",
                type: "rod",
                quantity: 3.0,
                location: nil
            )
        ]

        var grouped: [String: [InventoryModel]] = [:]
        for record in records {
            let locationKey = record.location ?? "No location"
            grouped[locationKey, default: []].append(record)
        }

        #expect(grouped["No location"]?.count == 2)
        #expect(grouped.keys.count == 1)
    }

    @Test("Sort location keys alphabetically")
    func testLocationKeySorting() async throws {
        let locationKeys = ["Studio", "No location", "Storage", "Shelf A"]
        let sorted = locationKeys.sorted()

        // Verify alphabetical order
        #expect(sorted[0] == "No location")
        #expect(sorted[1] == "Shelf A")
        #expect(sorted[2] == "Storage")
        #expect(sorted[3] == "Studio")
    }
}
