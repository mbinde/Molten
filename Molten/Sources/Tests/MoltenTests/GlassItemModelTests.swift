//
//  GlassItemModelTests.swift
//  MoltenTests
//
//  Tests for GlassItemModel including stable_id functionality
//

import Testing
import Foundation
import CryptoKit
@testable import Molten

@Suite("GlassItemModel Tests")
@MainActor
struct GlassItemModelTests {

    // MARK: - Initialization Tests

    @Test("Initialize with all parameters including stable_id")
    func initializeWithAllParameters() {
        let item = GlassItemModel(
            stable_id: "abc123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            mfr_notes: "High quality clear glass",
            coe: 90,
            url: "https://example.com/001",
            mfr_status: "available",
            image_url: "https://example.com/001.jpg",
            image_path: "/images/001.jpg"
        )

        #expect(item.stable_id == "bullseye-001-001")
        #expect(item.stable_id == "abc123")
        #expect(item.name == "Clear Rod")
        #expect(item.sku == "001")
        #expect(item.manufacturer == "bullseye")
        #expect(item.mfr_notes == "High quality clear glass")
        #expect(item.coe == 90)
        #expect(item.url == "https://example.com/001")
        #expect(item.mfr_status == "available")
        #expect(item.image_url == "https://example.com/001.jpg")
        #expect(item.image_path == "/images/001.jpg")
        #expect(item.uri == "moltenglass:item?bullseye-001-001")
        #expect(item.id == "bullseye-001-001")
    }

    @Test("Initialize with natural_key optional")
    func initializeWithOptionalNaturalKey() {
        let stableId = generateStableId(manufacturer: "bullseye", sku: "001")
        let item = GlassItemModel(
            stable_id: stableId,
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        #expect(item.stable_id == nil)
        #expect(item.stable_id == stableId)
        #expect(item.name == "Clear Rod")
        #expect(item.sku == "001")
    }

    @Test("Initialize with generated stable_id")
    func initializeWithGeneratedStableId() {
        let stableId = generateStableId(manufacturer: "bullseye", sku: "001")
        let item = GlassItemModel(
            stable_id: stableId,
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        #expect(item.stable_id == "bullseye-001-001")
        #expect(item.stable_id == stableId)
    }

    @Test("Initialize with 6-character stable_id")
    func initializeWith6CharStableId() {
        let item = GlassItemModel(
            stable_id: "3DyUbA",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        #expect(item.stable_id == "3DyUbA")
        #expect(item.stable_id.count == 6)
    }

    // MARK: - Identifiable Tests

    @Test("id property returns natural_key")
    func idPropertyReturnsNaturalKey() {
        let item = GlassItemModel(
            stable_id: "abc123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        #expect(item.id == "bullseye-001-001")
        #expect(item.id == item.stable_id)
    }

    // MARK: - URI Tests

    @Test("URI is computed from natural_key")
    func uriComputedFromNaturalKey() {
        let item = GlassItemModel(
            stable_id: generateStableId(manufacturer: "bullseye", sku: "001"),
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        #expect(item.uri == "moltenglass:item?bullseye-001-001")
    }

    // MARK: - Natural Key Tests (REMOVED - natural_key deprecated)

    // MARK: - Equatable Tests

    @Test("Items with same natural_key are equal")
    func equalityWithSameNaturalKey() {
        let item1 = GlassItemModel(
            stable_id: "abc123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            stable_id: "xyz789",  // Different stable_id
            name: "Different Name",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        #expect(item1 == item2)  // Equal because natural_key is the same
    }

    @Test("Items with different natural_key are not equal")
    func inequalityWithDifferentNaturalKey() {
        let item1 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "bullseye", sku: "001"),
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            stable_id: generateStableId(manufacturer: "bullseye", sku: "002"),
            name: "Clear Rod",
            sku: "002",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        #expect(item1 != item2)
    }

    // MARK: - Hashable Tests

    @Test("Items are hashable")
    func hashability() {
        let item = GlassItemModel(
            stable_id: "abc123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        var set = Set<GlassItemModel>()
        set.insert(item)

        #expect(set.contains(item))
    }

    @Test("Items with same natural_key hash to same value")
    func hashingBySameNaturalKey() {
        let item1 = GlassItemModel(
            stable_id: "abc123",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            stable_id: "xyz789",  // Different stable_id
            name: "Different Name",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        var set = Set<GlassItemModel>()
        set.insert(item1)
        set.insert(item2)

        // Should only contain one item since they have same natural_key
        #expect(set.count == 1)
    }

    // MARK: - Stable ID Specific Tests

    @Test("Stable ID is required")
    func stableIdRequired() {
        // Test that items must be created with stable_id
        let itemWithStableId = GlassItemModel(
            stable_id: "abc123",
            name: "Blue Rod",
            sku: "002",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        #expect(itemWithStableId.stable_id == "abc123")
    }

    @Test("Stable ID does not affect equality")
    func stableIdDoesNotAffectEquality() {
        // Items with same natural_key but different stable_id should be equal
        let item1 = GlassItemModel(
            stable_id: "aaa111",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            stable_id: "bbb222",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        #expect(item1 == item2)
    }

    @Test("Stable ID does not affect hashing")
    func stableIdDoesNotAffectHashing() {
        // Items with same natural_key but different stable_id should hash the same
        let item1 = GlassItemModel(
            stable_id: "aaa111",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            stable_id: "bbb222",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        var hasher1 = Hasher()
        item1.hash(into: &hasher1)
        let hash1 = hasher1.finalize()

        var hasher2 = Hasher()
        item2.hash(into: &hasher2)
        let hash2 = hasher2.finalize()

        #expect(hash1 == hash2)
    }
}
