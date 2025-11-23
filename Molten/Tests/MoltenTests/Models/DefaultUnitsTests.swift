//
//  DefaultUnitsTests.swift
//  MoltenTests
//
//  Unit tests for DefaultUnits enum
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
@Suite("DefaultUnits Tests")
struct DefaultUnitsTests {

    // MARK: - Raw Value Tests

    @Test("ounces has correct raw value")
    func testOuncesRawValue() {
        #expect(DefaultUnits.ounces.rawValue == "Ounces")
    }

    @Test("grams has correct raw value")
    func testGramsRawValue() {
        #expect(DefaultUnits.grams.rawValue == "Grams")
    }

    @Test("DefaultUnits can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(DefaultUnits(rawValue: "Ounces") == .ounces)
        #expect(DefaultUnits(rawValue: "Grams") == .grams)
    }

    @Test("DefaultUnits returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(DefaultUnits(rawValue: "invalid") == nil)
        #expect(DefaultUnits(rawValue: "") == nil)
        #expect(DefaultUnits(rawValue: "ounces") == nil) // Case-sensitive
        #expect(DefaultUnits(rawValue: "kg") == nil)
    }

    // MARK: - Display Name Tests

    @Test("ounces has correct display name")
    func testOuncesDisplayName() {
        #expect(DefaultUnits.ounces.displayName == "Ounces")
    }

    @Test("grams has correct display name")
    func testGramsDisplayName() {
        #expect(DefaultUnits.grams.displayName == "Grams")
    }

    @Test("Display name matches raw value")
    func testDisplayNameMatchesRawValue() {
        for unit in DefaultUnits.allCases {
            #expect(unit.displayName == unit.rawValue)
        }
    }

    // MARK: - Symbol Tests

    @Test("ounces has correct symbol")
    func testOuncesSymbol() {
        #expect(DefaultUnits.ounces.symbol == "lb")
    }

    @Test("grams has correct symbol")
    func testGramsSymbol() {
        #expect(DefaultUnits.grams.symbol == "kg")
    }

    @Test("Symbols are short abbreviations")
    func testSymbolsAreShort() {
        for unit in DefaultUnits.allCases {
            #expect(unit.symbol.count <= 3)
            #expect(!unit.symbol.isEmpty)
        }
    }

    @Test("Symbols are lowercase")
    func testSymbolsAreLowercase() {
        for unit in DefaultUnits.allCases {
            #expect(unit.symbol == unit.symbol.lowercased())
        }
    }

    // MARK: - System Image Tests

    @Test("ounces has correct system image")
    func testOuncesSystemImage() {
        #expect(DefaultUnits.ounces.systemImage == "scalemass")
    }

    @Test("grams has correct system image")
    func testGramsSystemImage() {
        #expect(DefaultUnits.grams.systemImage == "scalemass.fill")
    }

    @Test("All system images are valid SF Symbol names")
    func testSystemImagesAreValidSFSymbols() {
        for unit in DefaultUnits.allCases {
            let image = unit.systemImage
            #expect(!image.isEmpty)
            // SF Symbols should contain dots or be lowercase
            #expect(image.contains(".") || image == image.lowercased())
        }
    }

    @Test("System images are related to mass/weight")
    func testSystemImagesRelatedToMass() {
        for unit in DefaultUnits.allCases {
            #expect(unit.systemImage.contains("scalemass"))
        }
    }

    // MARK: - CaseIterable Tests

    @Test("allCases contains all units")
    func testAllCases() {
        let allCases = DefaultUnits.allCases

        #expect(allCases.count == 2)
        #expect(allCases.contains(.ounces))
        #expect(allCases.contains(.grams))
    }

    @Test("allCases order is consistent")
    func testAllCasesOrder() {
        let allCases = DefaultUnits.allCases

        #expect(allCases[0] == .ounces)
        #expect(allCases[1] == .grams)
    }

    // MARK: - Equatable Tests

    @Test("DefaultUnits equality works correctly")
    func testEquality() {
        #expect(DefaultUnits.ounces == DefaultUnits.ounces)
        #expect(DefaultUnits.ounces != DefaultUnits.grams)
        #expect(DefaultUnits.grams == DefaultUnits.grams)
    }

    // MARK: - Comprehensive Coverage Tests

    @Test("All cases have valid display names")
    func testAllCasesHaveDisplayNames() {
        for unit in DefaultUnits.allCases {
            #expect(!unit.displayName.isEmpty)
        }
    }

    @Test("All cases have valid symbols")
    func testAllCasesHaveSymbols() {
        for unit in DefaultUnits.allCases {
            #expect(!unit.symbol.isEmpty)
        }
    }

    @Test("All cases have valid system images")
    func testAllCasesHaveSystemImages() {
        for unit in DefaultUnits.allCases {
            #expect(!unit.systemImage.isEmpty)
        }
    }

    @Test("Each unit has unique symbol")
    func testUniqueSymbols() {
        let symbols = DefaultUnits.allCases.map { $0.symbol }
        let uniqueSymbols = Set(symbols)

        #expect(symbols.count == uniqueSymbols.count)
    }

    @Test("Each unit has unique display name")
    func testUniqueDisplayNames() {
        let names = DefaultUnits.allCases.map { $0.displayName }
        let uniqueNames = Set(names)

        #expect(names.count == uniqueNames.count)
    }

    // MARK: - Real-World Usage Tests

    @Test("Ounces for imperial/US measurements")
    func testOuncesForImperial() {
        let unit = DefaultUnits.ounces

        #expect(unit.symbol == "lb")
        #expect(unit.displayName.contains("Ounces"))
    }

    @Test("Grams for metric measurements")
    func testGramsForMetric() {
        let unit = DefaultUnits.grams

        #expect(unit.symbol == "kg")
        #expect(unit.displayName.contains("Grams"))
    }

    @Test("Units can be used in UserDefaults storage")
    func testUserDefaultsCompatibility() {
        // Raw values are suitable for UserDefaults
        for unit in DefaultUnits.allCases {
            let rawValue = unit.rawValue
            let restored = DefaultUnits(rawValue: rawValue)

            #expect(restored == unit)
        }
    }

    @Test("Units can be used in UI pickers")
    func testUIPickerCompatibility() {
        // Display names are user-friendly
        for unit in DefaultUnits.allCases {
            #expect(unit.displayName.first?.isUppercase == true)
            #expect(!unit.displayName.contains("_"))
            #expect(!unit.displayName.contains("-"))
        }
    }

    @Test("Symbols are suitable for inline display")
    func testSymbolsForInlineDisplay() {
        // Symbols should be short and not contain spaces
        for unit in DefaultUnits.allCases {
            #expect(!unit.symbol.contains(" "))
            #expect(unit.symbol.count < unit.displayName.count)
        }
    }

    // MARK: - Edge Cases

    @Test("Display names are capitalized")
    func testDisplayNamesCapitalized() {
        for unit in DefaultUnits.allCases {
            #expect(unit.displayName == unit.displayName.capitalized)
        }
    }

    @Test("Symbols are distinct from display names")
    func testSymbolsDistinctFromDisplayNames() {
        for unit in DefaultUnits.allCases {
            #expect(unit.symbol != unit.displayName)
            #expect(unit.symbol != unit.displayName.lowercased())
        }
    }

    @Test("Raw values are suitable for persistence")
    func testRawValuesForPersistence() {
        // Raw values should be stable and descriptive
        for unit in DefaultUnits.allCases {
            #expect(!unit.rawValue.isEmpty)
            #expect(unit.rawValue.first?.isLetter == true)
            #expect(!unit.rawValue.contains(" "))
        }
    }
}
