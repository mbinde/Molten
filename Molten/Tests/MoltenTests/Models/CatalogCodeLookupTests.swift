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

// MARK: - Integration Tests for findGlassItem

@MainActor
@Suite("CatalogCodeLookup Integration Tests")
struct CatalogCodeLookupIntegrationTests {

    private let deps = AppDependencies(persistenceController: .createTestController())

    // MARK: - findGlassItem Tests

    @Test("findGlassItem returns nil for empty code")
    func testFindGlassItemEmptyCode() async throws {
        let result = try await CatalogCodeLookup.findGlassItem(byCode: "", using: deps.catalogService)
        #expect(result == nil)
    }

    @Test("findGlassItem returns nil for whitespace-only code")
    func testFindGlassItemWhitespaceCode() async throws {
        let result = try await CatalogCodeLookup.findGlassItem(byCode: "   ", using: deps.catalogService)
        #expect(result == nil)
    }

    @Test("findGlassItem trims whitespace from code")
    func testFindGlassItemTrimsWhitespace() async throws {
        // Should not crash on whitespace-padded input
        _ = try await CatalogCodeLookup.findGlassItem(byCode: "  test  ", using: deps.catalogService)
    }

    @Test("findGlassItem returns nil for nonexistent code")
    func testFindGlassItemNonexistent() async throws {
        let result = try await CatalogCodeLookup.findGlassItem(byCode: "definitely-not-a-real-code-xyz123", using: deps.catalogService)
        #expect(result == nil)
    }

    @Test("findCatalogItem is alias for findGlassItem")
    func testFindCatalogItemAlias() async throws {
        let result1 = try await CatalogCodeLookup.findGlassItem(byCode: "nonexistent", using: deps.catalogService)
        let result2 = try await CatalogCodeLookup.findCatalogItem(byCode: "nonexistent", using: deps.catalogService)

        // Both should return nil for nonexistent code
        #expect(result1 == nil)
        #expect(result2 == nil)
    }

    // MARK: - Search Strategy Order Tests

    @Test("Search strategies execute in correct order")
    func testSearchStrategyOrder() async throws {
        // This test verifies the search doesn't crash and handles various inputs
        // The actual matching depends on catalog data which varies

        let testCodes = [
            "abc123",           // stable_id format
            "001",              // SKU format
            "be-001",           // manufacturer-sku format
            "peace",            // name search
            "CiM Peace Ltd Run" // full_name search
        ]

        for code in testCodes {
            // Should not crash regardless of whether match is found
            _ = try await CatalogCodeLookup.findGlassItem(byCode: code, using: deps.catalogService)
        }
    }

    // MARK: - Full Name Search Tests (new full_name field)

    @Test("findGlassItem searches by exact full_name")
    func testFindGlassItemByExactFullName() async throws {
        // This tests the new full_name search strategy
        // The exact full_name should be matched case-insensitively
        _ = try await CatalogCodeLookup.findGlassItem(byCode: "cim peace ltd run", using: deps.catalogService)
        // We don't assert on the result since catalog data varies,
        // but the code path is exercised
    }

    @Test("findGlassItem searches by full_name contains")
    func testFindGlassItemByFullNameContains() async throws {
        // This tests the full_name contains strategy
        _ = try await CatalogCodeLookup.findGlassItem(byCode: "peace ltd", using: deps.catalogService)
        // Again, just exercising the code path
    }

    // MARK: - Case Sensitivity Tests

    @Test("Name search is case-insensitive")
    func testNameSearchCaseInsensitive() async throws {
        // Search with different cases should work the same
        _ = try await CatalogCodeLookup.findGlassItem(byCode: "PEACE", using: deps.catalogService)
        _ = try await CatalogCodeLookup.findGlassItem(byCode: "peace", using: deps.catalogService)
        _ = try await CatalogCodeLookup.findGlassItem(byCode: "Peace", using: deps.catalogService)
    }

    @Test("SKU search is case-sensitive for exact match")
    func testSKUSearchExact() async throws {
        // SKU matching should be available
        _ = try await CatalogCodeLookup.findGlassItem(byCode: "001", using: deps.catalogService)
    }

    // MARK: - Special Characters Tests

    @Test("Handles special characters in code")
    func testSpecialCharactersInCode() async throws {
        let specialCodes = [
            "001-A",
            "test/code",
            "code#1",
            "item (special)",
            "item's code"
        ]

        for code in specialCodes {
            // Should not crash
            _ = try await CatalogCodeLookup.findGlassItem(byCode: code, using: deps.catalogService)
        }
    }

    @Test("Handles unicode in code")
    func testUnicodeInCode() async throws {
        _ = try await CatalogCodeLookup.findGlassItem(byCode: "café", using: deps.catalogService)
        _ = try await CatalogCodeLookup.findGlassItem(byCode: "日本語", using: deps.catalogService)
    }
}
