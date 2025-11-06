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

@Suite("WeightUnit Tests")
struct WeightUnitTests {

    // MARK: - Raw Value Tests

    @Test("pounds has correct raw value")
    func testPoundsRawValue() {
        #expect(WeightUnit.pounds.rawValue == "pounds")
    }

    @Test("kilograms has correct raw value")
    func testKilogramsRawValue() {
        #expect(WeightUnit.kilograms.rawValue == "kilograms")
    }

    @Test("WeightUnit can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(WeightUnit(rawValue: "pounds") == .pounds)
        #expect(WeightUnit(rawValue: "kilograms") == .kilograms)
    }

    @Test("WeightUnit returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(WeightUnit(rawValue: "invalid") == nil)
        #expect(WeightUnit(rawValue: "") == nil)
        #expect(WeightUnit(rawValue: "lbs") == nil)
        #expect(WeightUnit(rawValue: "kg") == nil)
    }

    // MARK: - CaseIterable Tests

    @Test("allCases contains all weight units")
    func testAllCases() {
        let allCases = WeightUnit.allCases

        #expect(allCases.count == 2)
        #expect(allCases.contains(.pounds))
        #expect(allCases.contains(.kilograms))
    }

    @Test("allCases order is consistent")
    func testAllCasesOrder() {
        let allCases = WeightUnit.allCases

        #expect(allCases[0] == .pounds)
        #expect(allCases[1] == .kilograms)
    }

    // MARK: - Identifiable Tests

    @Test("pounds has correct ID")
    func testPoundsID() {
        #expect(WeightUnit.pounds.id == "pounds")
    }

    @Test("kilograms has correct ID")
    func testKilogramsID() {
        #expect(WeightUnit.kilograms.id == "kilograms")
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

    @Test("pounds has correct display name")
    func testPoundsDisplayName() {
        #expect(WeightUnit.pounds.displayName == "Pounds")
    }

    @Test("kilograms has correct display name")
    func testKilogramsDisplayName() {
        #expect(WeightUnit.kilograms.displayName == "Kilograms")
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

    @Test("pounds has correct symbol")
    func testPoundsSymbol() {
        #expect(WeightUnit.pounds.symbol == "lb")
    }

    @Test("kilograms has correct symbol")
    func testKilogramsSymbol() {
        #expect(WeightUnit.kilograms.symbol == "kg")
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

    @Test("pounds has correct system image")
    func testPoundsSystemImage() {
        #expect(WeightUnit.pounds.systemImage == "scalemass")
    }

    @Test("kilograms has correct system image")
    func testKilogramsSystemImage() {
        #expect(WeightUnit.kilograms.systemImage == "scalemass")
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

    @Test("Convert pounds to pounds returns same value")
    func testConvertPoundsToPounds() {
        let value = 10.0
        let result = WeightUnit.pounds.convert(value, to: .pounds)

        #expect(result == value)
    }

    @Test("Convert kilograms to kilograms returns same value")
    func testConvertKilogramsToKilograms() {
        let value = 5.0
        let result = WeightUnit.kilograms.convert(value, to: .kilograms)

        #expect(result == value)
    }

    @Test("Convert pounds to kilograms")
    func testConvertPoundsToKilograms() {
        let pounds = 10.0
        let kilograms = WeightUnit.pounds.convert(pounds, to: .kilograms)

        // 10 lb * 0.453592 = 4.53592 kg
        let expected = 4.53592
        #expect(abs(kilograms - expected) < 0.00001)
    }

    @Test("Convert kilograms to pounds")
    func testConvertKilogramsToPounds() {
        let kilograms = 5.0
        let pounds = WeightUnit.kilograms.convert(kilograms, to: .pounds)

        // 5 kg / 0.453592 = 11.0231 lb
        let expected = 11.0231
        #expect(abs(pounds - expected) < 0.001)
    }

    @Test("Convert zero pounds to kilograms")
    func testConvertZeroPoundsToKilograms() {
        let result = WeightUnit.pounds.convert(0.0, to: .kilograms)
        #expect(result == 0.0)
    }

    @Test("Convert zero kilograms to pounds")
    func testConvertZeroKilogramsToPounds() {
        let result = WeightUnit.kilograms.convert(0.0, to: .pounds)
        #expect(result == 0.0)
    }

    @Test("Conversion is reversible (pounds)")
    func testConversionReversiblePounds() {
        let original = 100.0
        let converted = WeightUnit.pounds.convert(original, to: .kilograms)
        let backToOriginal = WeightUnit.kilograms.convert(converted, to: .pounds)

        #expect(abs(backToOriginal - original) < 0.001)
    }

    @Test("Conversion is reversible (kilograms)")
    func testConversionReversibleKilograms() {
        let original = 50.0
        let converted = WeightUnit.kilograms.convert(original, to: .pounds)
        let backToOriginal = WeightUnit.pounds.convert(converted, to: .kilograms)

        #expect(abs(backToOriginal - original) < 0.001)
    }

    @Test("Convert fractional pounds to kilograms")
    func testConvertFractionalPounds() {
        let pounds = 2.5
        let kilograms = WeightUnit.pounds.convert(pounds, to: .kilograms)

        // 2.5 lb * 0.453592 = 1.13398 kg
        let expected = 1.13398
        #expect(abs(kilograms - expected) < 0.00001)
    }

    @Test("Convert large value pounds to kilograms")
    func testConvertLargeValue() {
        let pounds = 1000.0
        let kilograms = WeightUnit.pounds.convert(pounds, to: .kilograms)

        // 1000 lb * 0.453592 = 453.592 kg
        let expected = 453.592
        #expect(abs(kilograms - expected) < 0.001)
    }

    @Test("Conversion factor accuracy (1 lb to kg)")
    func testConversionFactorAccuracy() {
        let onePoundInKg = WeightUnit.pounds.convert(1.0, to: .kilograms)

        #expect(abs(onePoundInKg - 0.453592) < 0.000001)
    }

    @Test("Conversion factor accuracy (1 kg to lb)")
    func testConversionFactorAccuracyReverse() {
        let oneKgInPounds = WeightUnit.kilograms.convert(1.0, to: .pounds)

        // 1 kg = 2.20462 lb
        #expect(abs(oneKgInPounds - 2.20462) < 0.00001)
    }

    // MARK: - Equatable Tests

    @Test("WeightUnit equality works correctly")
    func testEquality() {
        #expect(WeightUnit.pounds == WeightUnit.pounds)
        #expect(WeightUnit.pounds != WeightUnit.kilograms)
        #expect(WeightUnit.kilograms == WeightUnit.kilograms)
    }

    // MARK: - Real-World Usage Tests

    @Test("Convert typical glass rod weight (0.25 lb)")
    func testTypicalGlassRodWeight() {
        let pounds = 0.25
        let kilograms = WeightUnit.pounds.convert(pounds, to: .kilograms)

        // 0.25 lb ≈ 0.113 kg
        #expect(kilograms > 0.1 && kilograms < 0.15)
    }

    @Test("Convert glass sheet weight (10 lbs)")
    func testGlassSheetWeight() {
        let pounds = 10.0
        let kilograms = WeightUnit.pounds.convert(pounds, to: .kilograms)

        // 10 lb ≈ 4.54 kg
        #expect(kilograms > 4.5 && kilograms < 4.6)
    }

    @Test("Convert bulk glass order (50 kg)")
    func testBulkGlassOrder() {
        let kilograms = 50.0
        let pounds = WeightUnit.kilograms.convert(kilograms, to: .pounds)

        // 50 kg ≈ 110 lb
        #expect(pounds > 110.0 && pounds < 111.0)
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
        let smallPounds = 0.001
        let kilograms = WeightUnit.pounds.convert(smallPounds, to: .kilograms)

        #expect(kilograms > 0.0)
        #expect(kilograms < 0.001)
    }

    @Test("Convert negative weight (edge case)")
    func testConvertNegativeWeight() {
        // Negative weights don't make physical sense, but conversion should still work mathematically
        let negativePounds = -5.0
        let kilograms = WeightUnit.pounds.convert(negativePounds, to: .kilograms)

        #expect(kilograms < 0.0)
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
        let testWeights = [0.1, 0.5, 1.0, 5.0, 10.0, 25.0, 100.0]

        for weight in testWeights {
            let kg = WeightUnit.pounds.convert(weight, to: .kilograms)
            let backToPounds = WeightUnit.kilograms.convert(kg, to: .pounds)

            // Should maintain precision within 0.1%
            let percentError = abs(backToPounds - weight) / weight
            #expect(percentError < 0.001)
        }
    }
}
