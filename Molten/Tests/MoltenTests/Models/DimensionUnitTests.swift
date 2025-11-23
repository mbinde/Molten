//
//  DimensionUnitTests.swift
//  MoltenTests
//
//  Unit tests for DimensionUnit enum and related types
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
@Suite("DimensionUnit Tests")
struct DimensionUnitTests {

    // MARK: - Raw Value Tests

    @Test("millimeters has correct raw value")
    func testMillimetersRawValue() {
        #expect(DimensionUnit.millimeters.rawValue == "millimeters")
    }

    @Test("centimeters has correct raw value")
    func testCentimetersRawValue() {
        #expect(DimensionUnit.centimeters.rawValue == "centimeters")
    }

    @Test("inches has correct raw value")
    func testInchesRawValue() {
        #expect(DimensionUnit.inches.rawValue == "inches")
    }

    @Test("DimensionUnit can be initialized from raw value")
    func testInitFromRawValue() {
        #expect(DimensionUnit(rawValue: "millimeters") == .millimeters)
        #expect(DimensionUnit(rawValue: "centimeters") == .centimeters)
        #expect(DimensionUnit(rawValue: "inches") == .inches)
    }

    @Test("DimensionUnit returns nil for invalid raw value")
    func testInvalidRawValue() {
        #expect(DimensionUnit(rawValue: "invalid") == nil)
        #expect(DimensionUnit(rawValue: "") == nil)
        #expect(DimensionUnit(rawValue: "mm") == nil)
        #expect(DimensionUnit(rawValue: "cm") == nil)
        #expect(DimensionUnit(rawValue: "in") == nil)
    }

    // MARK: - CaseIterable Tests

    @Test("allCases contains all dimension units")
    func testAllCases() {
        let allCases = DimensionUnit.allCases

        #expect(allCases.count == 3)
        #expect(allCases.contains(.millimeters))
        #expect(allCases.contains(.centimeters))
        #expect(allCases.contains(.inches))
    }

    @Test("allCases order is consistent")
    func testAllCasesOrder() {
        let allCases = DimensionUnit.allCases

        #expect(allCases[0] == .millimeters)
        #expect(allCases[1] == .centimeters)
        #expect(allCases[2] == .inches)
    }

    // MARK: - Identifiable Tests

    @Test("millimeters has correct ID")
    func testMillimetersID() {
        #expect(DimensionUnit.millimeters.id == "millimeters")
    }

    @Test("centimeters has correct ID")
    func testCentimetersID() {
        #expect(DimensionUnit.centimeters.id == "centimeters")
    }

    @Test("inches has correct ID")
    func testInchesID() {
        #expect(DimensionUnit.inches.id == "inches")
    }

    @Test("ID matches raw value")
    func testIDMatchesRawValue() {
        for unit in DimensionUnit.allCases {
            #expect(unit.id == unit.rawValue)
        }
    }

    @Test("All IDs are unique")
    func testUniqueIDs() {
        let ids = DimensionUnit.allCases.map { $0.id }
        let uniqueIDs = Set(ids)

        #expect(ids.count == uniqueIDs.count)
    }

    // MARK: - Display Name Tests

    @Test("millimeters has correct display name")
    func testMillimetersDisplayName() {
        #expect(DimensionUnit.millimeters.displayName == "Millimeters")
    }

    @Test("centimeters has correct display name")
    func testCentimetersDisplayName() {
        #expect(DimensionUnit.centimeters.displayName == "Centimeters")
    }

    @Test("inches has correct display name")
    func testInchesDisplayName() {
        #expect(DimensionUnit.inches.displayName == "Inches")
    }

    @Test("All display names are capitalized")
    func testDisplayNamesCapitalized() {
        for unit in DimensionUnit.allCases {
            #expect(unit.displayName.first?.isUppercase == true)
        }
    }

    @Test("Each unit has unique display name")
    func testUniqueDisplayNames() {
        let names = DimensionUnit.allCases.map { $0.displayName }
        let uniqueNames = Set(names)

        #expect(names.count == uniqueNames.count)
    }

    // MARK: - Symbol Tests

    @Test("millimeters has correct symbol")
    func testMillimetersSymbol() {
        #expect(DimensionUnit.millimeters.symbol == "mm")
    }

    @Test("centimeters has correct symbol")
    func testCentimetersSymbol() {
        #expect(DimensionUnit.centimeters.symbol == "cm")
    }

    @Test("inches has correct symbol")
    func testInchesSymbol() {
        #expect(DimensionUnit.inches.symbol == "in")
    }

    @Test("Symbols are short abbreviations")
    func testSymbolsAreShort() {
        for unit in DimensionUnit.allCases {
            #expect(!unit.symbol.isEmpty)
            #expect(unit.symbol.count <= 3)
        }
    }

    @Test("Symbols are lowercase")
    func testSymbolsAreLowercase() {
        for unit in DimensionUnit.allCases {
            #expect(unit.symbol == unit.symbol.lowercased())
        }
    }

    @Test("Each unit has unique symbol")
    func testUniqueSymbols() {
        let symbols = DimensionUnit.allCases.map { $0.symbol }
        let uniqueSymbols = Set(symbols)

        #expect(symbols.count == uniqueSymbols.count)
    }

    // MARK: - Conversion Tests

    @Test("Convert millimeters to millimeters returns same value")
    func testConvertMillimetersToMillimeters() {
        let value = 100.0
        let result = DimensionUnit.millimeters.convert(value, to: .millimeters)

        #expect(result == value)
    }

    @Test("Convert centimeters to centimeters returns same value")
    func testConvertCentimetersToCentimeters() {
        let value = 10.0
        let result = DimensionUnit.centimeters.convert(value, to: .centimeters)

        #expect(result == value)
    }

    @Test("Convert inches to inches returns same value")
    func testConvertInchesToInches() {
        let value = 5.0
        let result = DimensionUnit.inches.convert(value, to: .inches)

        #expect(result == value)
    }

    @Test("Convert millimeters to centimeters")
    func testConvertMillimetersToCentimeters() {
        let mm = 100.0
        let cm = DimensionUnit.millimeters.convert(mm, to: .centimeters)

        // 100 mm = 10 cm
        #expect(cm == 10.0)
    }

    @Test("Convert centimeters to millimeters")
    func testConvertCentimetersToMillimeters() {
        let cm = 5.0
        let mm = DimensionUnit.centimeters.convert(cm, to: .millimeters)

        // 5 cm = 50 mm
        #expect(mm == 50.0)
    }

    @Test("Convert inches to centimeters")
    func testConvertInchesToCentimeters() {
        let inches = 10.0
        let cm = DimensionUnit.inches.convert(inches, to: .centimeters)

        // 10 in * 2.54 = 25.4 cm
        #expect(abs(cm - 25.4) < 0.001)
    }

    @Test("Convert centimeters to inches")
    func testConvertCentimetersToInches() {
        let cm = 25.4
        let inches = DimensionUnit.centimeters.convert(cm, to: .inches)

        // 25.4 cm / 2.54 = 10 in
        #expect(abs(inches - 10.0) < 0.001)
    }

    @Test("Convert millimeters to inches")
    func testConvertMillimetersToInches() {
        let mm = 254.0
        let inches = DimensionUnit.millimeters.convert(mm, to: .inches)

        // 254 mm = 25.4 cm = 10 in
        #expect(abs(inches - 10.0) < 0.001)
    }

    @Test("Convert inches to millimeters")
    func testConvertInchesToMillimeters() {
        let inches = 1.0
        let mm = DimensionUnit.inches.convert(inches, to: .millimeters)

        // 1 in = 2.54 cm = 25.4 mm
        #expect(abs(mm - 25.4) < 0.001)
    }

    @Test("Convert zero values")
    func testConvertZeroValues() {
        #expect(DimensionUnit.millimeters.convert(0.0, to: .centimeters) == 0.0)
        #expect(DimensionUnit.centimeters.convert(0.0, to: .inches) == 0.0)
        #expect(DimensionUnit.inches.convert(0.0, to: .millimeters) == 0.0)
    }

    @Test("Conversion is reversible (millimeters ↔ centimeters)")
    func testConversionReversibleMillimetersCentimeters() {
        let original = 100.0
        let converted = DimensionUnit.millimeters.convert(original, to: .centimeters)
        let backToOriginal = DimensionUnit.centimeters.convert(converted, to: .millimeters)

        #expect(abs(backToOriginal - original) < 0.001)
    }

    @Test("Conversion is reversible (inches ↔ centimeters)")
    func testConversionReversibleInchesCentimeters() {
        let original = 12.0
        let converted = DimensionUnit.inches.convert(original, to: .centimeters)
        let backToOriginal = DimensionUnit.centimeters.convert(converted, to: .inches)

        #expect(abs(backToOriginal - original) < 0.001)
    }

    @Test("Conversion is reversible (inches ↔ millimeters)")
    func testConversionReversibleInchesMillimeters() {
        let original = 6.0
        let converted = DimensionUnit.inches.convert(original, to: .millimeters)
        let backToOriginal = DimensionUnit.millimeters.convert(converted, to: .inches)

        #expect(abs(backToOriginal - original) < 0.001)
    }

    @Test("Convert fractional millimeters to centimeters")
    func testConvertFractionalMillimeters() {
        let mm = 25.5
        let cm = DimensionUnit.millimeters.convert(mm, to: .centimeters)

        // 25.5 mm = 2.55 cm
        #expect(abs(cm - 2.55) < 0.001)
    }

    @Test("Convert large value inches to millimeters")
    func testConvertLargeValue() {
        let inches = 100.0
        let mm = DimensionUnit.inches.convert(inches, to: .millimeters)

        // 100 in * 2.54 = 254 cm = 2540 mm
        #expect(abs(mm - 2540.0) < 0.1)
    }

    @Test("Conversion factor accuracy (1 inch to cm)")
    func testConversionFactorAccuracyInchToCm() {
        let oneInchInCm = DimensionUnit.inches.convert(1.0, to: .centimeters)

        #expect(abs(oneInchInCm - 2.54) < 0.000001)
    }

    @Test("Conversion factor accuracy (10 mm to cm)")
    func testConversionFactorAccuracyMmToCm() {
        let tenMmInCm = DimensionUnit.millimeters.convert(10.0, to: .centimeters)

        #expect(tenMmInCm == 1.0)
    }

    // MARK: - Equatable Tests

    @Test("DimensionUnit equality works correctly")
    func testEquality() {
        #expect(DimensionUnit.millimeters == DimensionUnit.millimeters)
        #expect(DimensionUnit.millimeters != DimensionUnit.centimeters)
        #expect(DimensionUnit.millimeters != DimensionUnit.inches)
        #expect(DimensionUnit.centimeters == DimensionUnit.centimeters)
        #expect(DimensionUnit.centimeters != DimensionUnit.inches)
        #expect(DimensionUnit.inches == DimensionUnit.inches)
    }

    // MARK: - Real-World Glass Rod Dimensions Tests

    @Test("Convert typical glass rod diameter (6mm)")
    func testTypicalRodDiameter() {
        let mm = 6.0
        let inches = DimensionUnit.millimeters.convert(mm, to: .inches)

        // 6mm ≈ 0.236 inches (about 1/4 inch)
        #expect(inches > 0.2 && inches < 0.25)
    }

    @Test("Convert glass rod length (18 inches)")
    func testGlassRodLength() {
        let inches = 18.0
        let cm = DimensionUnit.inches.convert(inches, to: .centimeters)

        // 18 in ≈ 45.72 cm
        #expect(cm > 45.0 && cm < 46.0)
    }

    @Test("Convert sheet thickness (3mm)")
    func testSheetThickness() {
        let mm = 3.0
        let inches = DimensionUnit.millimeters.convert(mm, to: .inches)

        // 3mm ≈ 0.118 inches
        #expect(inches > 0.11 && inches < 0.13)
    }

    @Test("Convert tubing outer diameter (25mm)")
    func testTubingOuterDiameter() {
        let mm = 25.0
        let inches = DimensionUnit.millimeters.convert(mm, to: .inches)

        // 25mm ≈ 0.984 inches (almost 1 inch)
        #expect(inches > 0.98 && inches < 1.0)
    }

    // MARK: - Edge Cases

    @Test("Convert very small dimension")
    func testConvertVerySmallDimension() {
        let smallMm = 0.1
        let cm = DimensionUnit.millimeters.convert(smallMm, to: .centimeters)

        #expect(cm == 0.01)
    }

    @Test("Convert negative dimension (edge case)")
    func testConvertNegativeDimension() {
        // Negative dimensions don't make physical sense, but conversion should still work
        let negativeMm = -10.0
        let cm = DimensionUnit.millimeters.convert(negativeMm, to: .centimeters)

        #expect(cm == -1.0)
    }

    @Test("Symbols are suitable for inline display")
    func testSymbolsForInlineDisplay() {
        // Symbols should be short and not contain spaces
        for unit in DimensionUnit.allCases {
            #expect(!unit.symbol.contains(" "))
            #expect(unit.symbol.count < unit.displayName.count)
        }
    }

    @Test("Conversion maintains precision for common dimensions")
    func testConversionPrecision() {
        let testDimensions = [0.5, 1.0, 5.0, 10.0, 25.0, 100.0]

        for dimension in testDimensions {
            // Test mm → cm → mm
            let cm = DimensionUnit.millimeters.convert(dimension, to: .centimeters)
            let backToMm = DimensionUnit.centimeters.convert(cm, to: .millimeters)
            #expect(abs(backToMm - dimension) < 0.001)

            // Test in → cm → in
            let cmFromInches = DimensionUnit.inches.convert(dimension, to: .centimeters)
            let backToInches = DimensionUnit.centimeters.convert(cmFromInches, to: .inches)
            let percentError = abs(backToInches - dimension) / dimension
            #expect(percentError < 0.001) // Within 0.1%
        }
    }

    // MARK: - Units can be used in UserDefaults
    @Test("Units can be used in UserDefaults storage")
    func testUserDefaultsCompatibility() {
        // Raw values are suitable for UserDefaults
        for unit in DimensionUnit.allCases {
            let rawValue = unit.rawValue
            let restored = DimensionUnit(rawValue: rawValue)

            #expect(restored == unit)
        }
    }

    // MARK: - UI Picker Compatibility
    @Test("Units can be used in UI pickers")
    func testUIPickerCompatibility() {
        // Display names are user-friendly
        for unit in DimensionUnit.allCases {
            #expect(unit.displayName.first?.isUppercase == true)
            #expect(!unit.displayName.contains("_"))
            #expect(!unit.displayName.contains("-"))
        }
    }
}

// MARK: - DefaultDimensionUnits Tests

@MainActor
@Suite("DefaultDimensionUnits Tests")
struct DefaultDimensionUnitsTests {

    @Test("metric has correct raw value")
    func testMetricRawValue() {
        #expect(DefaultDimensionUnits.metric.rawValue == "Metric")
    }

    @Test("imperial has correct raw value")
    func testImperialRawValue() {
        #expect(DefaultDimensionUnits.imperial.rawValue == "Imperial")
    }

    @Test("metric has correct display name")
    func testMetricDisplayName() {
        #expect(DefaultDimensionUnits.metric.displayName == "Metric (cm/mm)")
    }

    @Test("imperial has correct display name")
    func testImperialDisplayName() {
        #expect(DefaultDimensionUnits.imperial.displayName == "Imperial (inches)")
    }

    @Test("metric primary unit is centimeters")
    func testMetricPrimaryUnit() {
        #expect(DefaultDimensionUnits.metric.primaryUnit == .centimeters)
    }

    @Test("imperial primary unit is inches")
    func testImperialPrimaryUnit() {
        #expect(DefaultDimensionUnits.imperial.primaryUnit == .inches)
    }

    @Test("metric secondary unit is millimeters")
    func testMetricSecondaryUnit() {
        #expect(DefaultDimensionUnits.metric.secondaryUnit == .millimeters)
    }

    @Test("imperial secondary unit is inches")
    func testImperialSecondaryUnit() {
        #expect(DefaultDimensionUnits.imperial.secondaryUnit == .inches)
    }

    @Test("allCases contains both metric and imperial")
    func testAllCases() {
        let allCases = DefaultDimensionUnits.allCases

        #expect(allCases.count == 2)
        #expect(allCases.contains(.metric))
        #expect(allCases.contains(.imperial))
    }
}

// MARK: - DimensionUnitPreference Tests

@MainActor
@Suite("DimensionUnitPreference Tests")
struct DimensionUnitPreferenceTests {

    init() {
        // Set up test UserDefaults
        DimensionUnitPreference.setUserDefaults(UserDefaults(suiteName: "test.dimensionunits")!)
    }

    deinit {
        // Clean up
        DimensionUnitPreference.resetUserDefaults()
    }

    @Test("default preference is metric")
    func testDefaultPreference() {
        // Clear any stored preference
        if let testDefaults = UserDefaults(suiteName: "test.dimensionunits") {
            testDefaults.removeObject(forKey: DimensionUnitPreference.storageKey)
        }

        #expect(DimensionUnitPreference.current == .metric)
    }

    @Test("can set and retrieve metric preference")
    func testSetMetricPreference() {
        DimensionUnitPreference.set(.metric)

        #expect(DimensionUnitPreference.current == .metric)
    }

    @Test("can set and retrieve imperial preference")
    func testSetImperialPreference() {
        DimensionUnitPreference.set(.imperial)

        #expect(DimensionUnitPreference.current == .imperial)
    }

    @Test("preference persists across reads")
    func testPreferencePersistence() {
        DimensionUnitPreference.set(.imperial)

        let first = DimensionUnitPreference.current
        let second = DimensionUnitPreference.current

        #expect(first == second)
        #expect(first == .imperial)
    }

    @Test("storage key is correct")
    func testStorageKey() {
        #expect(DimensionUnitPreference.storageKey == "defaultDimensionUnits")
    }
}
