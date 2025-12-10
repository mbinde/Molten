//
//  InventorySnapshotTests.swift
//  MoltenTests
//
//  Tests for InventorySnapshot - serializes and signs inventory data for sharing
//  Uses Ed25519 signatures for authenticity (no encryption - data not confidential)
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif
import Foundation
import CryptoKit
@testable import Molten

@Suite("InventorySnapshot Tests")
@MainActor
struct InventorySnapshotTests {

    // MARK: - Test Lifecycle

    init() {
        // Clean up any existing test keys
        KeyPairManager.deleteAllTestKeys()
    }

    // MARK: - Serialization Tests

    @Test("Should serialize empty inventory")
    func testSerializeEmptyInventory() throws {
        let manager = KeyPairManager()
        let keyPair = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let data = try snapshot.serialize(items: [], publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)

        #expect(!data.isEmpty, "Serialized data should not be empty")
    }

    @Test("Should serialize inventory with single item")
    func testSerializeSingleItem() throws {
        let manager = KeyPairManager()
        let keyPair = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let item = InventoryItemSnapshot(
            stableId: "bullseye-001-0",
            manufacturer: "be",
            sku: "001",
            quantity: 5.0,
            unit: "rod",
            location: "Studio A"
        )

        let data = try snapshot.serialize(items: [item], publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)

        #expect(!data.isEmpty)
    }

    @Test("Should serialize inventory with multiple items")
    func testSerializeMultipleItems() throws {
        let manager = KeyPairManager()
        let keyPair = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: "Studio A"),
            InventoryItemSnapshot(stableId: "cim-023-0", manufacturer: "cim", sku: "023", quantity: 3.5, unit: "tube", location: "Studio B"),
            InventoryItemSnapshot(stableId: "ef-451-0", manufacturer: "ef", sku: "451", quantity: 2.0, unit: "frit", location: "Storage")
        ]

        let data = try snapshot.serialize(items: items, publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)

        #expect(!data.isEmpty)
    }

    // MARK: - Deserialization Tests

    @Test("Should deserialize empty inventory")
    func testDeserializeEmptyInventory() throws {
        let manager = KeyPairManager()
        let keyPair = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let data = try snapshot.serialize(items: [], publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)
        let result = try snapshot.deserialize(data: data, publicKey: keyPair.publicKey)

        #expect(result.items.isEmpty)
        #expect(result.isValid, "Signature should be valid")
    }

    @Test("Should deserialize inventory with single item")
    func testDeserializeSingleItem() throws {
        let manager = KeyPairManager()
        let keyPair = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let item = InventoryItemSnapshot(
            stableId: "bullseye-001-0",
            manufacturer: "be",
            sku: "001",
            quantity: 5.0,
            unit: "rod",
            location: "Studio A"
        )

        let data = try snapshot.serialize(items: [item], publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)
        let result = try snapshot.deserialize(data: data, publicKey: keyPair.publicKey)

        #expect(result.items.count == 1)
        #expect(result.items[0].stableId == "bullseye-001-0")
        #expect(result.items[0].quantity == 5.0)
        #expect(result.isValid)
    }

    @Test("Should deserialize inventory with multiple items")
    func testDeserializeMultipleItems() throws {
        let manager = KeyPairManager()
        let keyPair = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let items = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.0, unit: "rod", location: "Studio A"),
            InventoryItemSnapshot(stableId: "cim-023-0", manufacturer: "cim", sku: "023", quantity: 3.5, unit: "tube", location: "Studio B"),
            InventoryItemSnapshot(stableId: "ef-451-0", manufacturer: "ef", sku: "451", quantity: 2.0, unit: "frit", location: "Storage")
        ]

        let data = try snapshot.serialize(items: items, publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)
        let result = try snapshot.deserialize(data: data, publicKey: keyPair.publicKey)

        #expect(result.items.count == 3)
        #expect(result.items[0].stableId == "bullseye-001-0")
        #expect(result.items[1].stableId == "cim-023-0")
        #expect(result.items[2].stableId == "ef-451-0")
        #expect(result.isValid)
    }

    // MARK: - Signature Verification Tests

    @Test("Should detect invalid signature")
    func testDetectInvalidSignature() throws {
        let manager = KeyPairManager()
        let keyPair1 = try manager.generateKeyPair()
        let keyPair2 = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let item = InventoryItemSnapshot(
            stableId: "bullseye-001-0",
            manufacturer: "be",
            sku: "001",
            quantity: 5.0,
            unit: "rod",
            location: "Studio A"
        )

        // Sign with keyPair1
        let data = try snapshot.serialize(items: [item], publicKey: keyPair1.publicKey, privateKey: keyPair1.privateKey)

        // Verify with keyPair2 (different key)
        let result = try snapshot.deserialize(data: data, publicKey: keyPair2.publicKey)

        #expect(!result.isValid, "Signature should be invalid with wrong public key")
    }

    @Test("Should detect tampered data")
    func testDetectTamperedData() throws {
        let manager = KeyPairManager()
        let keyPair = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let item = InventoryItemSnapshot(
            stableId: "bullseye-001-0",
            manufacturer: "be",
            sku: "001",
            quantity: 5.0,
            unit: "rod",
            location: "Studio A"
        )

        var data = try snapshot.serialize(items: [item], publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)

        // Tamper with signature (flip a byte in the signature, last 64 bytes)
        let signatureIndex = data.count - 32 // Middle of signature
        data[signatureIndex] ^= 0xFF

        let result = try snapshot.deserialize(data: data, publicKey: keyPair.publicKey)

        #expect(!result.isValid, "Signature should be invalid for tampered data")
    }

    // MARK: - Metadata Tests

    @Test("Should include timestamp in snapshot")
    func testIncludeTimestamp() throws {
        let manager = KeyPairManager()
        let keyPair = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let beforeTime = Date().addingTimeInterval(-1.0) // 1 second before
        let data = try snapshot.serialize(items: [], publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)
        let afterTime = Date().addingTimeInterval(1.0) // 1 second after

        let result = try snapshot.deserialize(data: data, publicKey: keyPair.publicKey)

        #expect(result.timestamp >= beforeTime)
        #expect(result.timestamp <= afterTime)
    }

    @Test("Should include version in snapshot")
    func testIncludeVersion() throws {
        let manager = KeyPairManager()
        let keyPair = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let data = try snapshot.serialize(items: [], publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)
        let result = try snapshot.deserialize(data: data, publicKey: keyPair.publicKey)

        #expect(result.version == "1.0", "Should have version number")
    }

    // MARK: - Error Handling Tests

    @Test("Should throw error for invalid data format")
    func testInvalidDataFormat() {
        let manager = KeyPairManager()
        let snapshot = InventorySnapshot()

        let invalidData = Data([0x00, 0x01, 0x02, 0x03])

        #expect(throws: SnapshotError.self) {
            _ = try snapshot.deserialize(data: invalidData, publicKey: Data(count: 32))
        }
    }

    @Test("Should throw error for corrupted JSON")
    func testCorruptedJSON() {
        let snapshot = InventorySnapshot()

        let corruptedJSON = "{invalid json}".data(using: .utf8)!

        #expect(throws: SnapshotError.self) {
            _ = try snapshot.deserialize(data: corruptedJSON, publicKey: Data(count: 32))
        }
    }

    // MARK: - Round-trip Tests

    @Test("Should preserve all item data through round-trip")
    func testRoundTripPreservesData() throws {
        let manager = KeyPairManager()
        let keyPair = try manager.generateKeyPair()
        let snapshot = InventorySnapshot()

        let originalItems = [
            InventoryItemSnapshot(stableId: "bullseye-001-0", manufacturer: "be", sku: "001", quantity: 5.5, unit: "rod", location: "Studio A"),
            InventoryItemSnapshot(stableId: "cim-023-0", manufacturer: "cim", sku: "023", quantity: 3.25, unit: "tube", location: "Studio B"),
            InventoryItemSnapshot(stableId: "ef-451-0", manufacturer: "ef", sku: "451", quantity: 2.75, unit: "frit", location: "Storage")
        ]

        let data = try snapshot.serialize(items: originalItems, publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)
        let result = try snapshot.deserialize(data: data, publicKey: keyPair.publicKey)

        #expect(result.items.count == originalItems.count)

        for (index, item) in result.items.enumerated() {
            #expect(item.stableId == originalItems[index].stableId)
            #expect(item.manufacturer == originalItems[index].manufacturer)
            #expect(item.sku == originalItems[index].sku)
            #expect(item.quantity == originalItems[index].quantity)
            #expect(item.unit == originalItems[index].unit)
            #expect(item.location == originalItems[index].location)
        }
    }
}
