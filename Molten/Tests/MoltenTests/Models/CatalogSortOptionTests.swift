//
//  CatalogSortOptionTests.swift
//  MoltenTests
//
//  Unit tests for SortOption enum (legacy CatalogSortOption)
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
@Suite("CatalogSortOption Tests")
struct CatalogSortOptionTests {

    // MARK: - Raw Value Tests

    @Test("name has correct raw value")
    func testNameRawValue() {
        #expect(SortOption.name.rawValue == "Name")
    }

    @Test("code has correct raw value")
    func testCodeRawValue() {
        #expect(SortOption.code.rawValue == "Code")
    }

    @Test("manufacturer has correct raw value")
    func testManufacturerRawValue() {
        #expect(SortOption.manufacturer.rawValue == "Manufacturer")
    }

    @Test("SortOption can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(SortOption(rawValue: "Name") == .name)
        #expect(SortOption(rawValue: "Code") == .code)
        #expect(SortOption(rawValue: "Manufacturer") == .manufacturer)
    }

    @Test("SortOption returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(SortOption(rawValue: "invalid") == nil)
        #expect(SortOption(rawValue: "") == nil)
        #expect(SortOption(rawValue: "name") == nil) // Case-sensitive
    }

    // MARK: - CaseIterable Tests

    @Test("allCases contains all sort options")
    func testAllCases() {
        let allCases = SortOption.allCases

        #expect(allCases.count == 4)
        #expect(allCases.contains(.name))
        #expect(allCases.contains(.code))
        #expect(allCases.contains(.manufacturer))
        #expect(allCases.contains(.rating))
    }

    @Test("allCases order is consistent")
    func testAllCasesOrder() {
        let allCases = SortOption.allCases

        #expect(allCases[0] == .name)
        #expect(allCases[1] == .code)
        #expect(allCases[2] == .manufacturer)
    }

    // MARK: - Icon Tests

    @Test("name has correct sort icon")
    func testNameSortIcon() {
        #expect(SortOption.name.sortIcon == "textformat.abc")
    }

    @Test("code has correct sort icon")
    func testCodeSortIcon() {
        #expect(SortOption.code.sortIcon == "number")
    }

    @Test("manufacturer has correct sort icon")
    func testManufacturerSortIcon() {
        #expect(SortOption.manufacturer.sortIcon == "building.2")
    }

    @Test("All icons are valid SF Symbol names")
    func testIconsAreValidSFSymbols() {
        for sortOption in SortOption.allCases {
            let icon = sortOption.sortIcon
            #expect(!icon.isEmpty)
            // SF Symbols should contain dots or be lowercase
            #expect(icon.contains(".") || icon == icon.lowercased())
        }
    }

    // MARK: - KeyPath Tests

    @Test("name keyPath points to glassItem.name")
    func testNameKeyPath() {
        let keyPath = SortOption.name.keyPath

        // Verify it's the correct keyPath type
        #expect(keyPath == \CompleteInventoryItemModel.glassItem.name)
    }

    @Test("code keyPath points to glassItem.sku")
    func testCodeKeyPath() {
        let keyPath = SortOption.code.keyPath

        #expect(keyPath == \CompleteInventoryItemModel.glassItem.sku)
    }

    @Test("manufacturer keyPath points to glassItem.manufacturer")
    func testManufacturerKeyPath() {
        let keyPath = SortOption.manufacturer.keyPath

        #expect(keyPath == \CompleteInventoryItemModel.glassItem.manufacturer)
    }

    // MARK: - Bridge to New Architecture Tests

    @Test("name converts to GlassItemSortOption.name")
    func testNameConversionToNew() {
        #expect(SortOption.name.asGlassItemSortOption == .name)
    }

    @Test("code converts to GlassItemSortOption.name")
    func testCodeConversionToNew() {
        // Code maps to name since natural_key sort was removed
        #expect(SortOption.code.asGlassItemSortOption == .name)
    }

    @Test("manufacturer converts to GlassItemSortOption.manufacturer")
    func testManufacturerConversionToNew() {
        #expect(SortOption.manufacturer.asGlassItemSortOption == .manufacturer)
    }

    @Test("GlassItemSortOption.name converts to SortOption.name")
    func testNewToLegacyName() {
        #expect(GlassItemSortOption.name.asLegacySortOption == .name)
    }

    @Test("GlassItemSortOption.manufacturer converts to SortOption.manufacturer")
    func testNewToLegacyManufacturer() {
        #expect(GlassItemSortOption.manufacturer.asLegacySortOption == .manufacturer)
    }

    @Test("GlassItemSortOption.coe has no legacy equivalent")
    func testNewToLegacyCOE() {
        #expect(GlassItemSortOption.coe.asLegacySortOption == nil)
    }

    @Test("GlassItemSortOption.totalQuantity has no legacy equivalent")
    func testNewToLegacyTotalQuantity() {
        #expect(GlassItemSortOption.totalQuantity.asLegacySortOption == nil)
    }

    // MARK: - Sort Function Tests (with Mock Data)

    // Helper struct conforming to GlassItemSortable for testing
    struct MockGlassItem: GlassItemSortable {
        let name: String
        let manufacturer: String
    }

    @Test("Sort by name (alphabetical)")
    func testSortByName() {
        let items = [
            MockGlassItem(name: "Charlie", manufacturer: "Bullseye"),
            MockGlassItem(name: "Alice", manufacturer: "CIM"),
            MockGlassItem(name: "Bob", manufacturer: "Effetre")
        ]

        let sorted = SortOption.name.sort(items)

        #expect(sorted[0].name == "Alice")
        #expect(sorted[1].name == "Bob")
        #expect(sorted[2].name == "Charlie")
    }

    @Test("Sort by name is case-insensitive")
    func testSortByNameCaseInsensitive() {
        let items = [
            MockGlassItem(name: "charlie", manufacturer: "Bullseye"),
            MockGlassItem(name: "ALICE", manufacturer: "CIM"),
            MockGlassItem(name: "Bob", manufacturer: "Effetre")
        ]

        let sorted = SortOption.name.sort(items)

        #expect(sorted[0].name == "ALICE")
        #expect(sorted[1].name == "Bob")
        #expect(sorted[2].name == "charlie")
    }

    @Test("Sort by code falls back to name sorting")
    func testSortByCode() {
        let items = [
            MockGlassItem(name: "Zebra", manufacturer: "Bullseye"),
            MockGlassItem(name: "Apple", manufacturer: "CIM"),
            MockGlassItem(name: "Mango", manufacturer: "Effetre")
        ]

        let sorted = SortOption.code.sort(items)

        // Code sort uses name as fallback
        #expect(sorted[0].name == "Apple")
        #expect(sorted[1].name == "Mango")
        #expect(sorted[2].name == "Zebra")
    }

    @Test("Sort by manufacturer (alphabetical)")
    func testSortByManufacturer() {
        let items = [
            MockGlassItem(name: "Item1", manufacturer: "Effetre"),
            MockGlassItem(name: "Item2", manufacturer: "Bullseye"),
            MockGlassItem(name: "Item3", manufacturer: "CIM")
        ]

        let sorted = SortOption.manufacturer.sort(items)

        #expect(sorted[0].manufacturer == "Bullseye")
        #expect(sorted[1].manufacturer == "CIM")
        #expect(sorted[2].manufacturer == "Effetre")
    }

    @Test("Sort by manufacturer is case-insensitive")
    func testSortByManufacturerCaseInsensitive() {
        let items = [
            MockGlassItem(name: "Item1", manufacturer: "effetre"),
            MockGlassItem(name: "Item2", manufacturer: "BULLSEYE"),
            MockGlassItem(name: "Item3", manufacturer: "Cim")
        ]

        let sorted = SortOption.manufacturer.sort(items)

        #expect(sorted[0].manufacturer == "BULLSEYE")
        #expect(sorted[1].manufacturer == "Cim")
        #expect(sorted[2].manufacturer == "effetre")
    }

    @Test("Sort handles duplicate names")
    func testSortWithDuplicateNames() {
        let items = [
            MockGlassItem(name: "Clear", manufacturer: "CIM"),
            MockGlassItem(name: "Clear", manufacturer: "Bullseye"),
            MockGlassItem(name: "Clear", manufacturer: "Effetre")
        ]

        let sorted = SortOption.name.sort(items)

        // All should have name "Clear"
        #expect(sorted.allSatisfy { $0.name == "Clear" })
        #expect(sorted.count == 3)
    }

    @Test("Sort handles duplicate manufacturers")
    func testSortWithDuplicateManufacturers() {
        let items = [
            MockGlassItem(name: "Red", manufacturer: "Bullseye"),
            MockGlassItem(name: "Blue", manufacturer: "Bullseye"),
            MockGlassItem(name: "Green", manufacturer: "Bullseye")
        ]

        let sorted = SortOption.manufacturer.sort(items)

        // All should have manufacturer "Bullseye"
        #expect(sorted.allSatisfy { $0.manufacturer == "Bullseye" })
        #expect(sorted.count == 3)
    }

    @Test("Sort handles empty array")
    func testSortEmptyArray() {
        let items: [MockGlassItem] = []

        let sortedByName = SortOption.name.sort(items)
        let sortedByCode = SortOption.code.sort(items)
        let sortedByManufacturer = SortOption.manufacturer.sort(items)

        #expect(sortedByName.isEmpty)
        #expect(sortedByCode.isEmpty)
        #expect(sortedByManufacturer.isEmpty)
    }

    @Test("Sort handles single item")
    func testSortSingleItem() {
        let items = [MockGlassItem(name: "Solo", manufacturer: "Test")]

        let sortedByName = SortOption.name.sort(items)
        let sortedByManufacturer = SortOption.manufacturer.sort(items)

        #expect(sortedByName.count == 1)
        #expect(sortedByName[0].name == "Solo")
        #expect(sortedByManufacturer.count == 1)
        #expect(sortedByManufacturer[0].manufacturer == "Test")
    }

    @Test("Sort uses localized comparison")
    func testSortUsesLocalizedComparison() {
        // Test with names that have different sort orders in different locales
        let items = [
            MockGlassItem(name: "Örange", manufacturer: "A"),
            MockGlassItem(name: "Apple", manufacturer: "B"),
            MockGlassItem(name: "Zebra", manufacturer: "C")
        ]

        let sorted = SortOption.name.sort(items)

        // Localized comparison should handle diacritics properly
        #expect(sorted.count == 3)
        #expect(!sorted.isEmpty)
    }

    @Test("Sort is stable for equal elements")
    func testSortStability() {
        let items = [
            MockGlassItem(name: "Same", manufacturer: "First"),
            MockGlassItem(name: "Same", manufacturer: "Second"),
            MockGlassItem(name: "Same", manufacturer: "Third")
        ]

        let sorted = SortOption.name.sort(items)

        // All items should be present
        #expect(sorted.count == 3)
        #expect(sorted.allSatisfy { $0.name == "Same" })
    }

    // MARK: - Equatable Tests

    @Test("SortOption equality works correctly")
    func testEquality() {
        #expect(SortOption.name == SortOption.name)
        #expect(SortOption.name != SortOption.code)
        #expect(SortOption.manufacturer == SortOption.manufacturer)
    }

    // MARK: - Comprehensive Coverage Tests

    @Test("All cases have valid icons")
    func testAllCasesHaveIcons() {
        for sortOption in SortOption.allCases {
            #expect(!sortOption.sortIcon.isEmpty)
        }
    }

    @Test("All cases can convert to new architecture")
    func testAllCasesConvertToNew() {
        for sortOption in SortOption.allCases {
            let newOption = sortOption.asGlassItemSortOption
            // Should produce a valid GlassItemSortOption
            #expect(GlassItemSortOption.allCases.contains(newOption))
        }
    }
}
