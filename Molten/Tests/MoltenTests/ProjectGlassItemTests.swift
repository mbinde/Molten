//
//  ProjectGlassItemTests.swift
//  FlameworkerTests
//
//  Tests for ProjectGlassItem model (fractional glass quantities for projects)
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Molten

@Suite("ProjectGlassItem Tests")
@MainActor
struct ProjectGlassItemTests {

    @Test("Initialize with all properties")
    func testInitialization() {
        let item = ProjectGlassItem(
            id: UUID(),
            stableId: "bullseye-clear-0",
            quantity: 0.5,
            unit: "rods",
            notes: "for the body"
        )

        #expect(item.stableId == "bullseye-clear-0")
        #expect(item.quantity == 0.5)
        #expect(item.unit == "rods")
        #expect(item.notes == "for the body")
    }

    @Test("Initialize with defaults")
    func testDefaultInitialization() {
        let item = ProjectGlassItem(
            stableId: "cim-511-0",
            quantity: 1.0
        )

        #expect(item.stableId == "cim-511-0")
        #expect(item.quantity == 1.0)
        #expect(item.unit == "rods")  // Default unit
        #expect(item.notes == nil)
    }

    @Test("Supports fractional quantities")
    func testFractionalQuantities() {
        let item1 = ProjectGlassItem(stableId: "test-1", quantity: 0.5)
        let item2 = ProjectGlassItem(stableId: "test-2", quantity: 2.3)
        let item3 = ProjectGlassItem(stableId: "test-3", quantity: 0.25)

        #expect(item1.quantity == 0.5)
        #expect(item2.quantity == 2.3)
        #expect(item3.quantity == 0.25)
    }

    @Test("Codable encode and decode")
    func testCodable() throws {
        let original = ProjectGlassItem(
            id: UUID(),
            stableId: "northstar-ns33-0",
            quantity: 1.5,
            unit: "oz",
            notes: "accent color"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProjectGlassItem.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.stableId == original.stableId)
        #expect(decoded.quantity == original.quantity)
        #expect(decoded.unit == original.unit)
        #expect(decoded.notes == original.notes)
    }

    @Test("Codable with array of items")
    func testCodableArray() throws {
        let items = [
            ProjectGlassItem(stableId: "clear-0", quantity: 0.5),
            ProjectGlassItem(stableId: "blue-1", quantity: 0.25, unit: "grams"),
            ProjectGlassItem(stableId: "red-2", quantity: 1.0, notes: "for dots")
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(items)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([ProjectGlassItem].self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded[0].stableId == "clear-0")
        #expect(decoded[1].unit == "grams")
        #expect(decoded[2].notes == "for dots")
    }

    @Test("Different units supported")
    func testDifferentUnits() {
        let rods = ProjectGlassItem(stableId: "test", quantity: 1.0, unit: "rods")
        let grams = ProjectGlassItem(stableId: "test", quantity: 50.0, unit: "grams")
        let ounces = ProjectGlassItem(stableId: "test", quantity: 2.5, unit: "oz")

        #expect(rods.unit == "rods")
        #expect(grams.unit == "grams")
        #expect(ounces.unit == "oz")
    }

    @Test("Identifiable protocol conformance")
    func testIdentifiable() {
        let item1 = ProjectGlassItem(stableId: "test", quantity: 1.0)
        let item2 = ProjectGlassItem(stableId: "test", quantity: 1.0)

        // Each item should have a unique ID
        #expect(item1.id != item2.id)
    }

    @Test("Zero quantity is valid")
    func testZeroQuantity() {
        let item = ProjectGlassItem(stableId: "test", quantity: 0.0)
        #expect(item.quantity == 0.0)
    }

    @Test("Very precise decimal quantities")
    func testPreciseDecimals() {
        let item = ProjectGlassItem(stableId: "test", quantity: Decimal(string: "0.123456")!)
        #expect(item.quantity == Decimal(string: "0.123456")!)
    }
}
