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

@Suite("DefaultUnits Tests")
struct DefaultUnitsTests {

    // MARK: - Raw Value Tests

    @Test("pounds has correct raw value")
    func testPoundsRawValue() {
        #expect(DefaultUnits.pounds.rawValue == "Pounds")
    }

    @Test("kilograms has correct raw value")
    func testKilogramsRawValue() {
        #expect(DefaultUnits.kilograms.rawValue == "Kilograms")
    }

    @Test("DefaultUnits can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(DefaultUnits(rawValue: "Pounds") == .pounds)
        #expect(DefaultUnits(rawValue: "Kilograms") == .kilograms)
    }

    @Test("DefaultUnits returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(DefaultUnits(rawValue: "invalid") == nil)
        #expect(DefaultUnits(rawValue: "") == nil)
        #expect(DefaultUnits(rawValue: "pounds") == nil) // Case-sensitive
        #expect(DefaultUnits(rawValue: "kg") == nil)
    }

    // MARK: - Display Name Tests

    @Test("pounds has correct display name")
    func testPoundsDisplayName() {
        #expect(DefaultUnits.pounds.displayName == "Pounds")
    }

    @Test("kilograms has correct display name")
    func testKilogramsDisplayName() {
        #expect(DefaultUnits.kilograms.displayName == "Kilograms")
    }

    @Test("Display name matches raw value")
    func testDisplayNameMatchesRawValue() {
        for unit in DefaultUnits.allCases {
            #expect(unit.displayName == unit.rawValue)
        }
    }

    // MARK: - Symbol Tests

    @Test("pounds has correct symbol")
    func testPoundsSymbol() {
        #expect(DefaultUnits.pounds.symbol == "lb")
    }

    @Test("kilograms has correct symbol")
    func testKilogramsSymbol() {
        #expect(DefaultUnits.kilograms.symbol == "kg")
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

    @Test("pounds has correct system image")
    func testPoundsSystemImage() {
        #expect(DefaultUnits.pounds.systemImage == "scalemass")
    }

    @Test("kilograms has correct system image")
    func testKilogramsSystemImage() {
        #expect(DefaultUnits.kilograms.systemImage == "scalemass.fill")
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
        #expect(allCases.contains(.pounds))
        #expect(allCases.contains(.kilograms))
    }

    @Test("allCases order is consistent")
    func testAllCasesOrder() {
        let allCases = DefaultUnits.allCases

        #expect(allCases[0] == .pounds)
        #expect(allCases[1] == .kilograms)
    }

    // MARK: - Equatable Tests

    @Test("DefaultUnits equality works correctly")
    func testEquality() {
        #expect(DefaultUnits.pounds == DefaultUnits.pounds)
        #expect(DefaultUnits.pounds != DefaultUnits.kilograms)
        #expect(DefaultUnits.kilograms == DefaultUnits.kilograms)
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

    @Test("Pounds for imperial/US measurements")
    func testPoundsForImperial() {
        let unit = DefaultUnits.pounds

        #expect(unit.symbol == "lb")
        #expect(unit.displayName.contains("Pounds"))
    }

    @Test("Kilograms for metric measurements")
    func testKilogramsForMetric() {
        let unit = DefaultUnits.kilograms

        #expect(unit.symbol == "kg")
        #expect(unit.displayName.contains("Kilograms"))
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
