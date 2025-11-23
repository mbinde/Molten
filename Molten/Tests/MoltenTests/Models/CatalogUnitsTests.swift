//
//  CatalogUnitsTests.swift
//  MoltenTests
//
//  Unit tests for CatalogUnits enum
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
@Suite("CatalogUnits Tests")
struct CatalogUnitsTests {

    // MARK: - Raw Value Tests

    @Test("pounds has correct raw value")
    func testPoundsRawValue() {
        #expect(CatalogUnits.ounces.rawValue == 0)
    }

    @Test("kilograms has correct raw value")
    func testKilogramsRawValue() {
        #expect(CatalogUnits.grams.rawValue == 1)
    }

    @Test("shorts has correct raw value")
    func testShortsRawValue() {
        #expect(CatalogUnits.shorts.rawValue == 2)
    }

    @Test("rods has correct raw value")
    func testRodsRawValue() {
        #expect(CatalogUnits.rods.rawValue == 3)
    }

    @Test("CatalogUnits can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(CatalogUnits(rawValue: 0) == .ounces)
        #expect(CatalogUnits(rawValue: 1) == .grams)
        #expect(CatalogUnits(rawValue: 2) == .shorts)
        #expect(CatalogUnits(rawValue: 3) == .rods)
    }

    @Test("CatalogUnits returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(CatalogUnits(rawValue: -1) == nil)
        #expect(CatalogUnits(rawValue: 4) == nil)
        #expect(CatalogUnits(rawValue: 100) == nil)
    }

    // MARK: - Custom Init Tests

    @Test("Custom init with valid Decoder returns correct case")
    func testCustomInitValid() throws {
        let jsonData = "0".data(using: .utf8)!
        let decoder = JSONDecoder()
        let unit = try decoder.decode(CatalogUnits.self, from: jsonData)

        #expect(unit == .ounces)
    }

    @Test("Custom init with invalid value falls back to pounds")
    func testCustomInitFallback() throws {
        let jsonData = "999".data(using: .utf8)!
        let decoder = JSONDecoder()
        let unit = try decoder.decode(CatalogUnits.self, from: jsonData)

        #expect(unit == .ounces)  // Fallback to default
    }

    // MARK: - Display Name Tests

    @Test("pounds has correct display name")
    func testPoundsDisplayName() {
        #expect(CatalogUnits.ounces.displayName == "lbs")
    }

    @Test("kilograms has correct display name")
    func testKilogramsDisplayName() {
        #expect(CatalogUnits.grams.displayName == "kg")
    }

    @Test("shorts has correct display name")
    func testShortsDisplayName() {
        #expect(CatalogUnits.shorts.displayName == "shorts")
    }

    @Test("rods has correct display name")
    func testRodsDisplayName() {
        #expect(CatalogUnits.rods.displayName == "rods")
    }

    @Test("All display names are lowercase or abbreviated")
    func testDisplayNamesLowercaseOrAbbreviated() {
        for unit in CatalogUnits.allCases {
            #expect(!unit.displayName.isEmpty)
            // Display names should be short and user-friendly
            #expect(unit.displayName.count <= 10)
        }
    }

    // MARK: - Full Name Tests

    @Test("pounds has correct full name")
    func testPoundsFullName() {
        #expect(CatalogUnits.ounces.fullName == "Pounds")
    }

    @Test("kilograms has correct full name")
    func testKilogramsFullName() {
        #expect(CatalogUnits.grams.fullName == "Kilograms")
    }

    @Test("shorts has correct full name")
    func testShortsFullName() {
        #expect(CatalogUnits.shorts.fullName == "Shorts")
    }

    @Test("rods has correct full name")
    func testRodsFullName() {
        #expect(CatalogUnits.rods.fullName == "Rods")
    }

    @Test("All full names are capitalized")
    func testFullNamesCapitalized() {
        for unit in CatalogUnits.allCases {
            #expect(!unit.fullName.isEmpty)
            #expect(unit.fullName.first?.isUppercase == true)
        }
    }

    @Test("Full names are longer than display names (or equal)")
    func testFullNamesLongerOrEqual() {
        for unit in CatalogUnits.allCases {
            #expect(unit.fullName.count >= unit.displayName.count)
        }
    }

    // MARK: - isWeightUnit Tests

    @Test("pounds is a weight unit")
    func testPoundsIsWeight() {
        #expect(CatalogUnits.ounces.isWeightUnit == true)
    }

    @Test("kilograms is a weight unit")
    func testKilogramsIsWeight() {
        #expect(CatalogUnits.grams.isWeightUnit == true)
    }

    @Test("shorts is not a weight unit")
    func testShortsIsNotWeight() {
        #expect(CatalogUnits.shorts.isWeightUnit == false)
    }

    @Test("rods is not a weight unit")
    func testRodsIsNotWeight() {
        #expect(CatalogUnits.rods.isWeightUnit == false)
    }

    @Test("Weight units and count units are mutually exclusive")
    func testWeightAndCountMutuallyExclusive() {
        let weightUnits = CatalogUnits.allCases.filter { $0.isWeightUnit }
        let countUnits = CatalogUnits.allCases.filter { !$0.isWeightUnit }

        #expect(weightUnits.count == 2)  // pounds, kilograms
        #expect(countUnits.count == 2)   // shorts, rods
        #expect(weightUnits.count + countUnits.count == CatalogUnits.allCases.count)
    }

    // MARK: - CaseIterable Tests

    @Test("allCases contains all units")
    func testAllCases() {
        let allCases = CatalogUnits.allCases

        #expect(allCases.count == 4)
        #expect(allCases.contains(.ounces))
        #expect(allCases.contains(.grams))
        #expect(allCases.contains(.shorts))
        #expect(allCases.contains(.rods))
    }

    @Test("allCases order is consistent")
    func testAllCasesOrder() {
        let allCases = CatalogUnits.allCases

        #expect(allCases[0] == .ounces)
        #expect(allCases[1] == .grams)
        #expect(allCases[2] == .shorts)
        #expect(allCases[3] == .rods)
    }

    // MARK: - Identifiable Tests

    @Test("pounds has correct ID")
    func testPoundsID() {
        #expect(CatalogUnits.ounces.id == 0)
    }

    @Test("kilograms has correct ID")
    func testKilogramsID() {
        #expect(CatalogUnits.grams.id == 1)
    }

    @Test("shorts has correct ID")
    func testShortsID() {
        #expect(CatalogUnits.shorts.id == 2)
    }

    @Test("rods has correct ID")
    func testRodsID() {
        #expect(CatalogUnits.rods.id == 3)
    }

    @Test("ID matches raw value")
    func testIDMatchesRawValue() {
        for unit in CatalogUnits.allCases {
            #expect(unit.id == unit.rawValue)
        }
    }

    @Test("All IDs are unique")
    func testUniqueIDs() {
        let ids = CatalogUnits.allCases.map { $0.id }
        let uniqueIDs = Set(ids)

        #expect(ids.count == uniqueIDs.count)
    }

    // MARK: - Equatable Tests

    @Test("CatalogUnits equality works correctly")
    func testEquality() {
        #expect(CatalogUnits.ounces == CatalogUnits.ounces)
        #expect(CatalogUnits.ounces != CatalogUnits.grams)
        #expect(CatalogUnits.shorts == CatalogUnits.shorts)
        #expect(CatalogUnits.rods != CatalogUnits.shorts)
    }

    // MARK: - Codable Tests

    @Test("CatalogUnits can be encoded")
    func testEncoding() throws {
        let unit = CatalogUnits.ounces
        let encoder = JSONEncoder()
        let data = try encoder.encode(unit)

        #expect(!data.isEmpty)
    }

    @Test("CatalogUnits can be decoded")
    func testDecoding() throws {
        let jsonData = "1".data(using: .utf8)!  // kilograms
        let decoder = JSONDecoder()
        let unit = try decoder.decode(CatalogUnits.self, from: jsonData)

        #expect(unit == .grams)
    }

    @Test("CatalogUnits round-trip encoding works")
    func testRoundTripEncoding() throws {
        for originalUnit in CatalogUnits.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(originalUnit)

            let decoder = JSONDecoder()
            let decodedUnit = try decoder.decode(CatalogUnits.self, from: data)

            #expect(decodedUnit == originalUnit)
        }
    }

    // MARK: - Comprehensive Coverage Tests

    @Test("All cases have valid display names")
    func testAllCasesHaveDisplayNames() {
        for unit in CatalogUnits.allCases {
            #expect(!unit.displayName.isEmpty)
        }
    }

    @Test("All cases have valid full names")
    func testAllCasesHaveFullNames() {
        for unit in CatalogUnits.allCases {
            #expect(!unit.fullName.isEmpty)
        }
    }

    @Test("Each unit has unique display name")
    func testUniqueDisplayNames() {
        let names = CatalogUnits.allCases.map { $0.displayName }
        let uniqueNames = Set(names)

        #expect(names.count == uniqueNames.count)
    }

    @Test("Each unit has unique full name")
    func testUniqueFullNames() {
        let names = CatalogUnits.allCases.map { $0.fullName }
        let uniqueNames = Set(names)

        #expect(names.count == uniqueNames.count)
    }

    // MARK: - Real-World Usage Tests

    @Test("Weight units for inventory tracking")
    func testWeightUnitsInventory() {
        let weightUnits = CatalogUnits.allCases.filter { $0.isWeightUnit }

        #expect(weightUnits.contains(.ounces))
        #expect(weightUnits.contains(.grams))
        #expect(weightUnits.count == 2)
    }

    @Test("Count units for discrete items")
    func testCountUnitsDiscrete() {
        let countUnits = CatalogUnits.allCases.filter { !$0.isWeightUnit }

        #expect(countUnits.contains(.shorts))
        #expect(countUnits.contains(.rods))
        #expect(countUnits.count == 2)
    }

    @Test("Display name suitable for UI labels")
    func testDisplayNameForUI() {
        // Display names should be short, suitable for inline display
        for unit in CatalogUnits.allCases {
            #expect(unit.displayName.count <= 10)
            #expect(!unit.displayName.contains(" "))
        }
    }

    @Test("Full name suitable for settings/descriptions")
    func testFullNameForSettings() {
        // Full names should be more descriptive
        for unit in CatalogUnits.allCases {
            #expect(unit.fullName.count >= 3)
            #expect(unit.fullName.first?.isUppercase == true)
        }
    }

    @Test("Units can be used in pickers")
    func testUIPickerCompatibility() {
        // Identifiable + CaseIterable = perfect for SwiftUI pickers
        for unit in CatalogUnits.allCases {
            _ = unit.id  // Has ID
            _ = unit.displayName  // Has display text
        }

        #expect(CatalogUnits.allCases.count > 0)
    }

    @Test("Units can be stored in UserDefaults")
    func testUserDefaultsCompatibility() {
        // Raw value Int16 is suitable for UserDefaults
        for unit in CatalogUnits.allCases {
            let rawValue = unit.rawValue
            let restored = CatalogUnits(rawValue: rawValue)

            #expect(restored == unit)
        }
    }

    // MARK: - Edge Cases

    @Test("Raw values are sequential")
    func testRawValuesSequential() {
        let rawValues = CatalogUnits.allCases.map { $0.rawValue }

        #expect(rawValues == [0, 1, 2, 3])
    }

    @Test("Raw values start at zero")
    func testRawValuesStartAtZero() {
        let minRawValue = CatalogUnits.allCases.map { $0.rawValue }.min()

        #expect(minRawValue == 0)
    }

    @Test("Display names match expected abbreviations")
    func testDisplayNameAbbreviations() {
        #expect(CatalogUnits.ounces.displayName == "lbs")  // Standard abbreviation
        #expect(CatalogUnits.grams.displayName == "kg")  // Standard abbreviation
    }

    @Test("Decoding handles out of bounds gracefully")
    func testDecodingOutOfBounds() throws {
        // Custom init should fall back to .ounces for invalid values
        let invalidJSONData = "999".data(using: .utf8)!
        let decoder = JSONDecoder()
        let unit = try decoder.decode(CatalogUnits.self, from: invalidJSONData)

        #expect(unit == .ounces)  // Fallback behavior
    }

    @Test("Decoding handles negative values gracefully")
    func testDecodingNegativeValue() throws {
        let negativeJSONData = "-1".data(using: .utf8)!
        let decoder = JSONDecoder()
        let unit = try decoder.decode(CatalogUnits.self, from: negativeJSONData)

        #expect(unit == .ounces)  // Fallback behavior
    }

    @Test("Weight vs count categorization is logical")
    func testWeightCountCategorization() {
        // Weight units are for measuring mass
        #expect(CatalogUnits.ounces.isWeightUnit == true)
        #expect(CatalogUnits.grams.isWeightUnit == true)

        // Count units are for discrete items
        #expect(CatalogUnits.shorts.isWeightUnit == false)
        #expect(CatalogUnits.rods.isWeightUnit == false)
    }
}
