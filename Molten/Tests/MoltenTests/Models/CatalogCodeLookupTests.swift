//
//  CatalogCodeLookupTests.swift
//  MoltenTests
//
//  Unit tests for CatalogCodeLookup utility
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
@Suite("CatalogCodeLookup Tests")
struct CatalogCodeLookupTests {

    // MARK: - preferredNaturalKey Tests

    @Test("preferredNaturalKey generates consistent hash")
    func testPreferredNaturalKeyConsistent() {
        let key1 = CatalogCodeLookup.preferredNaturalKey(sku: "001", manufacturer: "bullseye")
        let key2 = CatalogCodeLookup.preferredNaturalKey(sku: "001", manufacturer: "bullseye")

        #expect(key1 == key2)
        #expect(key1.count == 6)
    }

    @Test("preferredNaturalKey generates different hashes for different inputs")
    func testPreferredNaturalKeyDifferentInputs() {
        let key1 = CatalogCodeLookup.preferredNaturalKey(sku: "001", manufacturer: "bullseye")
        let key2 = CatalogCodeLookup.preferredNaturalKey(sku: "002", manufacturer: "bullseye")
        let key3 = CatalogCodeLookup.preferredNaturalKey(sku: "001", manufacturer: "cim")

        #expect(key1 != key2)
        #expect(key1 != key3)
        #expect(key2 != key3)
    }

    @Test("preferredNaturalKey always returns 6-character string")
    func testPreferredNaturalKeySixChars() {
        let keys = [
            CatalogCodeLookup.preferredNaturalKey(sku: "1", manufacturer: "a"),
            CatalogCodeLookup.preferredNaturalKey(sku: "12345", manufacturer: "bullseye"),
            CatalogCodeLookup.preferredNaturalKey(sku: "test", manufacturer: "manufacturer"),
        ]

        for key in keys {
            #expect(key.count == 6)
            #expect(key.allSatisfy { $0.isNumber })
        }
    }

    @Test("preferredNaturalKey handles empty strings")
    func testPreferredNaturalKeyEmptyStrings() {
        let key1 = CatalogCodeLookup.preferredNaturalKey(sku: "", manufacturer: "bullseye")
        let key2 = CatalogCodeLookup.preferredNaturalKey(sku: "001", manufacturer: "")
        let key3 = CatalogCodeLookup.preferredNaturalKey(sku: "", manufacturer: "")

        #expect(key1.count == 6)
        #expect(key2.count == 6)
        #expect(key3.count == 6)
    }

    @Test("preferredNaturalKey is deterministic")
    func testPreferredNaturalKeyDeterministic() {
        // Test that same inputs always produce same output
        let iterations = 10
        let expectedKey = CatalogCodeLookup.preferredNaturalKey(sku: "clear-001", manufacturer: "bullseye")

        for _ in 0..<iterations {
            let key = CatalogCodeLookup.preferredNaturalKey(sku: "clear-001", manufacturer: "bullseye")
            #expect(key == expectedKey)
        }
    }

    @Test("preferredNaturalKey handles special characters")
    func testPreferredNaturalKeySpecialChars() {
        let key1 = CatalogCodeLookup.preferredNaturalKey(sku: "001-A", manufacturer: "bull's eye")
        let key2 = CatalogCodeLookup.preferredNaturalKey(sku: "001/B", manufacturer: "cim & co")

        #expect(key1.count == 6)
        #expect(key2.count == 6)
        #expect(key1 != key2)
    }

    @Test("preferredNaturalKey is case-sensitive")
    func testPreferredNaturalKeyCaseSensitive() {
        let key1 = CatalogCodeLookup.preferredNaturalKey(sku: "Clear", manufacturer: "Bullseye")
        let key2 = CatalogCodeLookup.preferredNaturalKey(sku: "clear", manufacturer: "bullseye")
        let key3 = CatalogCodeLookup.preferredNaturalKey(sku: "CLEAR", manufacturer: "BULLSEYE")

        // Different cases should produce different hashes
        #expect(key1 != key2)
        #expect(key2 != key3)
        #expect(key1 != key3)
    }

    @Test("preferredNaturalKey with very long inputs")
    func testPreferredNaturalKeyLongInputs() {
        let longSku = String(repeating: "A", count: 1000)
        let longManufacturer = String(repeating: "B", count: 1000)

        let key = CatalogCodeLookup.preferredNaturalKey(sku: longSku, manufacturer: longManufacturer)

        #expect(key.count == 6)
        #expect(key.allSatisfy { $0.isNumber })
    }

    @Test("preferredNaturalKey with unicode characters")
    func testPreferredNaturalKeyUnicode() {
        let key1 = CatalogCodeLookup.preferredNaturalKey(sku: "café", manufacturer: "mañana")
        let key2 = CatalogCodeLookup.preferredNaturalKey(sku: "日本", manufacturer: "中国")

        #expect(key1.count == 6)
        #expect(key2.count == 6)
        #expect(key1 != key2)
    }

    // MARK: - Hash Distribution Tests

    @Test("preferredNaturalKey produces well-distributed hashes")
    func testPreferredNaturalKeyDistribution() {
        // Generate many keys and check they're reasonably distributed
        var keys = Set<String>()

        for i in 0..<100 {
            let sku = String(format: "%03d", i)
            let key = CatalogCodeLookup.preferredNaturalKey(sku: sku, manufacturer: "test")
            keys.insert(key)
        }

        // Should have no collisions for 100 sequential SKUs
        #expect(keys.count == 100)
    }

    @Test("preferredNaturalKey collisions are rare")
    func testPreferredNaturalKeyCollisions() {
        // Test various manufacturer/SKU combinations
        var keys = Set<String>()
        let manufacturers = ["bullseye", "cim", "ef", "oceanside", "kokomo"]
        let skus = ["001", "002", "003", "clear", "blue", "red", "transparent"]

        for manufacturer in manufacturers {
            for sku in skus {
                let key = CatalogCodeLookup.preferredNaturalKey(sku: sku, manufacturer: manufacturer)
                keys.insert(key)
            }
        }

        // Should have minimal collisions (at least 95% unique)
        let totalCombinations = manufacturers.count * skus.count
        let uniqueKeys = keys.count
        let uniquePercentage = Double(uniqueKeys) / Double(totalCombinations)

        #expect(uniquePercentage >= 0.95)
    }

    // MARK: - Edge Case Tests

    @Test("preferredNaturalKey with whitespace")
    func testPreferredNaturalKeyWhitespace() {
        let key1 = CatalogCodeLookup.preferredNaturalKey(sku: " 001 ", manufacturer: " bullseye ")
        let key2 = CatalogCodeLookup.preferredNaturalKey(sku: "001", manufacturer: "bullseye")

        // Whitespace is preserved (not trimmed), so hashes should differ
        #expect(key1 != key2)
        #expect(key1.count == 6)
    }

    @Test("preferredNaturalKey with newlines and tabs")
    func testPreferredNaturalKeyNewlinesAndTabs() {
        let key = CatalogCodeLookup.preferredNaturalKey(sku: "001\n", manufacturer: "bullseye\t")

        #expect(key.count == 6)
        #expect(key.allSatisfy { $0.isNumber })
    }

    @Test("preferredNaturalKey modulo ensures 6 digits")
    func testPreferredNaturalKeyModulo() {
        // Test that modulo 1000000 ensures result is always 6 digits max
        for _ in 0..<1000 {
            let sku = UUID().uuidString
            let manufacturer = UUID().uuidString
            let key = CatalogCodeLookup.preferredNaturalKey(sku: sku, manufacturer: manufacturer)

            let numericValue = Int(key)!
            #expect(numericValue >= 0)
            #expect(numericValue < 1000000)
        }
    }

    // MARK: - Real-World Scenario Tests

    @Test("preferredNaturalKey with realistic glass item data")
    func testPreferredNaturalKeyRealistic() {
        let scenarios = [
            ("001", "bullseye"),
            ("1101", "cim"),
            ("R-114", "ef"),
            ("clear-transparent", "bullseye"),
            ("0001-A", "oceanside"),
        ]

        for (sku, manufacturer) in scenarios {
            let key = CatalogCodeLookup.preferredNaturalKey(sku: sku, manufacturer: manufacturer)
            #expect(key.count == 6)
            #expect(key.allSatisfy { $0.isNumber })
        }
    }

    @Test("preferredNaturalKey format is zero-padded")
    func testPreferredNaturalKeyZeroPadded() {
        // Test that the result is zero-padded to 6 digits
        let key = CatalogCodeLookup.preferredNaturalKey(sku: "test", manufacturer: "test")

        // Should be exactly 6 characters
        #expect(key.count == 6)

        // Should start with '0' if numeric value is < 100000
        if let numericValue = Int(key), numericValue < 100000 {
            #expect(key.hasPrefix("0"))
        }
    }
}

// MARK: - Notes on Async Method Testing

/*
 The following methods require integration testing with a real or mock CatalogService:

 - findGlassItem(byCode:using:) - Async method that queries catalog service
 - findCatalogItem(byCode:using:) - Legacy wrapper for findGlassItem
 - searchByExactNaturalKey(_:in:) - Private method, tested via integration
 - searchByExactSKU(_:in:) - Private method, tested via integration
 - searchByManufacturerSKU(_:in:) - Private method, tested via integration
 - searchByNaturalKeyContains(_:in:) - Private method, tested via integration
 - searchByNameContains(_:in:) - Private method, tested via integration

 These methods should be tested in:
 - Integration tests with mock CatalogService
 - End-to-end tests with real catalog data
 - UI tests that exercise catalog lookup flows

 Testing strategy:
 1. Create MockCatalogService with known test data
 2. Test each search strategy independently
 3. Test fallback chain (exact -> SKU -> manufacturer-SKU -> contains -> name)
 4. Test edge cases (empty code, whitespace, case sensitivity)
 5. Test that method returns nil when no match found
 */
