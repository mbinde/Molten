//
//  WeightUnitTests.swift
//  MoltenTests
//
//  Unit tests for WeightUnit enum
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
@Suite("WeightUnit Tests")
struct WeightUnitTests {

    // MARK: - Raw Value Tests

    @Test("ounces has correct raw value")
    func testOuncesRawValue() {
        #expect(WeightUnit.ounces.rawValue == "ounces")
    }

    @Test("grams has correct raw value")
    func testGramsRawValue() {
        #expect(WeightUnit.grams.rawValue == "grams")
    }

    @Test("WeightUnit can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(WeightUnit(rawValue: "ounces") == .ounces)
        #expect(WeightUnit(rawValue: "grams") == .grams)
    }

    @Test("WeightUnit returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(WeightUnit(rawValue: "invalid") == nil)
        #expect(WeightUnit(rawValue: "") == nil)
        #expect(WeightUnit(rawValue: "oz") == nil)
        #expect(WeightUnit(rawValue: "g") == nil)
    }

    // MARK: - CaseIterable Tests

    @Test("allCases contains all weight units")
    func testAllCases() {
        let allCases = WeightUnit.allCases

        #expect(allCases.count == 2)
        #expect(allCases.contains(.ounces))
        #expect(allCases.contains(.grams))
    }

    @Test("allCases order is consistent")
    func testAllCasesOrder() {
        let allCases = WeightUnit.allCases

        #expect(allCases[0] == .ounces)
        #expect(allCases[1] == .grams)
    }

    // MARK: - Identifiable Tests

    @Test("ounces has correct ID")
    func testOuncesID() {
        #expect(WeightUnit.ounces.id == "ounces")
    }

    @Test("grams has correct ID")
    func testGramsID() {
        #expect(WeightUnit.grams.id == "grams")
    }

    @Test("ID matches raw value")
    func testIDMatchesRawValue() {
        for unit in WeightUnit.allCases {
            #expect(unit.id == unit.rawValue)
        }
    }

    @Test("All IDs are unique")
    func testUniqueIDs() {
        let ids = WeightUnit.allCases.map { $0.id }
        let uniqueIDs = Set(ids)

        #expect(ids.count == uniqueIDs.count)
    }

    // MARK: - Display Name Tests

    @Test("ounces has correct display name")
    func testOuncesDisplayName() {
        #expect(WeightUnit.ounces.displayName == "Ounces")
    }

    @Test("grams has correct display name")
    func testGramsDisplayName() {
        #expect(WeightUnit.grams.displayName == "Grams")
    }

    @Test("All display names are capitalized")
    func testDisplayNamesCapitalized() {
        for unit in WeightUnit.allCases {
            #expect(unit.displayName.first?.isUppercase == true)
        }
    }

    @Test("Each unit has unique display name")
    func testUniqueDisplayNames() {
        let names = WeightUnit.allCases.map { $0.displayName }
        let uniqueNames = Set(names)

        #expect(names.count == uniqueNames.count)
    }

    // MARK: - Symbol Tests

    @Test("ounces has correct symbol")
    func testOuncesSymbol() {
        #expect(WeightUnit.ounces.symbol == "oz")
    }

    @Test("grams has correct symbol")
    func testGramsSymbol() {
        #expect(WeightUnit.grams.symbol == "g")
    }

    @Test("Symbols are short abbreviations")
    func testSymbolsAreShort() {
        for unit in WeightUnit.allCases {
            #expect(unit.symbol.count <= 3)
            #expect(!unit.symbol.isEmpty)
        }
    }

    @Test("Symbols are lowercase")
    func testSymbolsAreLowercase() {
        for unit in WeightUnit.allCases {
            #expect(unit.symbol == unit.symbol.lowercased())
        }
    }

    @Test("Each unit has unique symbol")
    func testUniqueSymbols() {
        let symbols = WeightUnit.allCases.map { $0.symbol }
        let uniqueSymbols = Set(symbols)

        #expect(symbols.count == uniqueSymbols.count)
    }

    // MARK: - System Image Tests

    @Test("ounces has correct system image")
    func testOuncesSystemImage() {
        #expect(WeightUnit.ounces.systemImage == "scalemass")
    }

    @Test("grams has correct system image")
    func testGramsSystemImage() {
        #expect(WeightUnit.grams.systemImage == "scalemass")
    }

    @Test("All system images are valid SF Symbol names")
    func testSystemImagesAreValidSFSymbols() {
        for unit in WeightUnit.allCases {
            let image = unit.systemImage
            #expect(!image.isEmpty)
            // SF Symbols should be lowercase or contain dots
            #expect(image == image.lowercased() || image.contains("."))
        }
    }

    @Test("All weight units use scalemass icon")
    func testAllUseScalemassIcon() {
        for unit in WeightUnit.allCases {
            #expect(unit.systemImage == "scalemass")
        }
    }

    // MARK: - Conversion Tests

    @Test("Convert ounces to ounces returns same value")
    func testConvertOuncesToOunces() {
        let value = 10.0
        let result = WeightUnit.ounces.convert(value, to: .ounces)

        #expect(result == value)
    }

    @Test("Convert grams to grams returns same value")
    func testConvertGramsToGrams() {
        let value = 100.0
        let result = WeightUnit.grams.convert(value, to: .grams)

        #expect(result == value)
    }

    @Test("Convert ounces to grams")
    func testConvertOuncesToGrams() {
        let ounces = 10.0
        let grams = WeightUnit.ounces.convert(ounces, to: .grams)

        // 10 oz * 28.3495 = 283.495 g
        let expected = 283.495
        #expect(abs(grams - expected) < 0.001)
    }

    @Test("Convert grams to ounces")
    func testConvertGramsToOunces() {
        let grams = 100.0
        let ounces = WeightUnit.grams.convert(grams, to: .ounces)

        // 100 g / 28.3495 = 3.527 oz
        let expected = 3.527
        #expect(abs(ounces - expected) < 0.001)
    }

    @Test("Convert zero ounces to grams")
    func testConvertZeroOuncesToGrams() {
        let result = WeightUnit.ounces.convert(0.0, to: .grams)
        #expect(result == 0.0)
    }

    @Test("Convert zero grams to ounces")
    func testConvertZeroGramsToOunces() {
        let result = WeightUnit.grams.convert(0.0, to: .ounces)
        #expect(result == 0.0)
    }

    @Test("Conversion is reversible (ounces)")
    func testConversionReversibleOunces() {
        let original = 5.0
        let converted = WeightUnit.ounces.convert(original, to: .grams)
        let backToOriginal = WeightUnit.grams.convert(converted, to: .ounces)

        #expect(abs(backToOriginal - original) < 0.001)
    }

    @Test("Conversion is reversible (grams)")
    func testConversionReversibleGrams() {
        let original = 250.0
        let converted = WeightUnit.grams.convert(original, to: .ounces)
        let backToOriginal = WeightUnit.ounces.convert(converted, to: .grams)

        #expect(abs(backToOriginal - original) < 0.001)
    }

    @Test("Convert fractional ounces to grams")
    func testConvertFractionalOunces() {
        let ounces = 0.5
        let grams = WeightUnit.ounces.convert(ounces, to: .grams)

        // 0.5 oz * 28.3495 = 14.17475 g
        let expected = 14.17475
        #expect(abs(grams - expected) < 0.001)
    }

    @Test("Convert large value ounces to grams")
    func testConvertLargeValue() {
        let ounces = 100.0
        let grams = WeightUnit.ounces.convert(ounces, to: .grams)

        // 100 oz * 28.3495 = 2834.95 g
        let expected = 2834.95
        #expect(abs(grams - expected) < 0.01)
    }

    @Test("Conversion factor accuracy (1 oz to g)")
    func testConversionFactorAccuracy() {
        let oneOunceInGrams = WeightUnit.ounces.convert(1.0, to: .grams)

        #expect(abs(oneOunceInGrams - 28.3495) < 0.0001)
    }

    @Test("Conversion factor accuracy (1 g to oz)")
    func testConversionFactorAccuracyReverse() {
        let oneGramInOunces = WeightUnit.grams.convert(1.0, to: .ounces)

        // 1 g / 28.3495 = 0.03527 oz
        #expect(abs(oneGramInOunces - 0.03527) < 0.00001)
    }

    // MARK: - Equatable Tests

    @Test("WeightUnit equality works correctly")
    func testEquality() {
        #expect(WeightUnit.ounces == WeightUnit.ounces)
        #expect(WeightUnit.ounces != WeightUnit.grams)
        #expect(WeightUnit.grams == WeightUnit.grams)
    }

    // MARK: - Real-World Glass Usage Tests

    @Test("Convert typical frit weight (4 oz jar)")
    func testTypicalFritWeight() {
        let ounces = 4.0
        let grams = WeightUnit.ounces.convert(ounces, to: .grams)

        // 4 oz ≈ 113.4 g
        #expect(grams > 113.0 && grams < 114.0)
    }

    @Test("Convert powder sample (50g)")
    func testPowderSampleWeight() {
        let grams = 50.0
        let ounces = WeightUnit.grams.convert(grams, to: .ounces)

        // 50 g ≈ 1.76 oz
        #expect(ounces > 1.7 && ounces < 1.8)
    }

    @Test("Convert enamel jar (2 oz)")
    func testEnamelJarWeight() {
        let ounces = 2.0
        let grams = WeightUnit.ounces.convert(ounces, to: .grams)

        // 2 oz ≈ 56.7 g
        #expect(grams > 56.0 && grams < 57.0)
    }

    @Test("Convert bulk frit order (500g)")
    func testBulkFritOrder() {
        let grams = 500.0
        let ounces = WeightUnit.grams.convert(grams, to: .ounces)

        // 500 g ≈ 17.6 oz
        #expect(ounces > 17.0 && ounces < 18.0)
    }

    @Test("Units can be used in UserDefaults storage")
    func testUserDefaultsCompatibility() {
        // Raw values are suitable for UserDefaults
        for unit in WeightUnit.allCases {
            let rawValue = unit.rawValue
            let restored = WeightUnit(rawValue: rawValue)

            #expect(restored == unit)
        }
    }

    @Test("Units can be used in UI pickers")
    func testUIPickerCompatibility() {
        // Display names are user-friendly
        for unit in WeightUnit.allCases {
            #expect(unit.displayName.first?.isUppercase == true)
            #expect(!unit.displayName.contains("_"))
            #expect(!unit.displayName.contains("-"))
        }
    }

    // MARK: - Edge Cases

    @Test("Convert very small weight")
    func testConvertVerySmallWeight() {
        let smallOunces = 0.001
        let grams = WeightUnit.ounces.convert(smallOunces, to: .grams)

        #expect(grams > 0.0)
        #expect(grams < 0.03)
    }

    @Test("Convert negative weight (edge case)")
    func testConvertNegativeWeight() {
        // Negative weights don't make physical sense, but conversion should still work mathematically
        let negativeOunces = -5.0
        let grams = WeightUnit.ounces.convert(negativeOunces, to: .grams)

        #expect(grams < 0.0)
    }

    @Test("Symbols are suitable for inline display")
    func testSymbolsForInlineDisplay() {
        // Symbols should be short and not contain spaces
        for unit in WeightUnit.allCases {
            #expect(!unit.symbol.contains(" "))
            #expect(unit.symbol.count < unit.displayName.count)
        }
    }

    @Test("Conversion maintains precision for common weights")
    func testConversionPrecision() {
        let testWeights = [0.1, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]

        for weight in testWeights {
            let g = WeightUnit.ounces.convert(weight, to: .grams)
            let backToOunces = WeightUnit.grams.convert(g, to: .ounces)

            // Should maintain precision within 0.1%
            let percentError = abs(backToOunces - weight) / weight
            #expect(percentError < 0.001)
        }
    }
}

// MARK: - WeightUnitPreference Tests

@MainActor
@Suite("WeightUnitPreference Tests")
struct WeightUnitPreferenceTests {

    init() {
        // Set up test UserDefaults
        WeightUnitPreference.setUserDefaults(UserDefaults(suiteName: "test.weightunits")!)
    }

    deinit {
        // Clean up
        WeightUnitPreference.resetToStandard()
    }

    @Test("default preference is grams")
    func testDefaultPreference() {
        // Clear any stored preference
        if let testDefaults = UserDefaults(suiteName: "test.weightunits") {
            testDefaults.removeObject(forKey: WeightUnitPreference.storageKey)
        }

        #expect(WeightUnitPreference.current == .grams)
    }

    @Test("storage key is correct")
    func testStorageKey() {
        #expect(WeightUnitPreference.storageKey == "defaultUnits")
    }
}
