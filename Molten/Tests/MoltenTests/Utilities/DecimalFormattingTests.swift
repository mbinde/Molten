//
//  DecimalFormattingTests.swift
//  MoltenTests
//
//  Unit tests for Decimal+Formatting extension
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

@Suite("Decimal Formatting Tests")
@MainActor
struct DecimalFormattingTests {

    // MARK: - formatted() Tests (default formatting)

    @Test("Format decimal with no fractional part")
    func testFormatWholeNumber() {
        let value: Decimal = 5
        let formatted: String = value.formatted()

        #expect(formatted == "5")
    }

    @Test("Format decimal with one decimal place")
    func testFormatOneDecimalPlace() {
        let value = Decimal(string: "3.5")!
        let formatted = value.formatted() as String

        #expect(formatted == "3.5")
    }

    @Test("Format decimal with two decimal places")
    func testFormatTwoDecimalPlaces() {
        let value = Decimal(string: "12.75")!
        let formatted = value.formatted() as String

        #expect(formatted == "12.75")
    }

    @Test("Format decimal removing trailing zeros")
    func testFormatRemovesTrailingZeros() {
        let value = Decimal(string: "10.00")!
        let formatted = value.formatted() as String

        #expect(formatted == "10")
    }

    @Test("Format decimal with more than two decimal places rounds")
    func testFormatRoundsToTwoPlaces() {
        let value = Decimal(string: "3.456")!
        let formatted = value.formatted() as String

        #expect(formatted == "3.46") // Rounds up
    }

    @Test("Format decimal with rounding down")
    func testFormatRoundsDown() {
        let value = Decimal(string: "3.454")!
        let formatted = value.formatted() as String

        #expect(formatted == "3.45") // Rounds down
    }

    @Test("Format zero")
    func testFormatZero() {
        let value: Decimal = 0
        let formatted = value.formatted() as String

        #expect(formatted == "0")
    }

    @Test("Format negative decimal")
    func testFormatNegative() {
        let value = Decimal(string: "-5.5")!
        let formatted = value.formatted() as String

        #expect(formatted == "-5.5")
    }

    @Test("Format very small decimal")
    func testFormatVerySmall() {
        let value = Decimal(string: "0.01")!
        let formatted = value.formatted() as String

        #expect(formatted == "0.01")
    }

    @Test("Format very large decimal")
    func testFormatVeryLarge() {
        let value = Decimal(string: "1234567.89")!
        let formatted = value.formatted() as String

        // Note: NumberFormatter with .decimal style adds grouping separators
        #expect(formatted.contains("1") && formatted.contains("234567"))
    }

    @Test("Format decimal with trailing zeros after decimal point")
    func testFormatTrailingZerosAfterDecimal() {
        let value = Decimal(string: "5.50")!
        let formatted = value.formatted() as String

        #expect(formatted == "5.5")
    }

    // MARK: - formatted(decimalPlaces:) Tests

    @Test("Format with specific decimal places - 0 places")
    func testFormatZeroDecimalPlaces() {
        let value = Decimal(string: "3.7")!
        let formatted = value.formatted(decimalPlaces: 0) as String

        #expect(formatted == "4") // Rounds up
    }

    @Test("Format with specific decimal places - 1 place")
    func testFormatWithOneDecimalPlace() {
        let value = Decimal(string: "3.456")!
        let formatted = value.formatted(decimalPlaces: 1) as String

        #expect(formatted == "3.5") // Rounds to 1 decimal
    }

    @Test("Format with specific decimal places - 3 places")
    func testFormatThreeDecimalPlaces() {
        let value = Decimal(string: "2.5")!
        let formatted = value.formatted(decimalPlaces: 3) as String

        #expect(formatted == "2.500") // Pads with zeros
    }

    @Test("Format with specific decimal places - 2 places exact")
    func testFormatTwoDecimalPlacesExact() {
        let value = Decimal(string: "10.99")!
        let formatted = value.formatted(decimalPlaces: 2) as String

        #expect(formatted == "10.99")
    }

    @Test("Format with specific decimal places - rounding down")
    func testFormatRoundingDown() {
        let value = Decimal(string: "3.444")!
        let formatted = value.formatted(decimalPlaces: 2) as String

        #expect(formatted == "3.44")
    }

    @Test("Format with specific decimal places - rounding up")
    func testFormatRoundingUp() {
        let value = Decimal(string: "3.446")!
        let formatted = value.formatted(decimalPlaces: 2) as String

        #expect(formatted == "3.45")
    }

    // MARK: - Edge Cases

    @Test("Format decimal with no fractional component but trailing zeros")
    func testFormatWholeNumberWithTrailingZeros() {
        let value = Decimal(string: "100.00")!
        let formatted = value.formatted() as String

        #expect(formatted == "100")
    }

    @Test("Format negative zero")
    func testFormatNegativeZero() {
        let value = Decimal(string: "-0.0")!
        let formatted = value.formatted() as String

        // Should format as "0" not "-0"
        #expect(formatted == "0" || formatted == "-0")
    }

    @Test("Format with 4 decimal places")
    func testFormatFourDecimalPlaces() {
        let value = Decimal(string: "1.2345")!
        let formatted = value.formatted(decimalPlaces: 4) as String

        #expect(formatted == "1.2345")
    }

    @Test("Format whole number with forced decimal places")
    func testFormatWholeNumberForcedDecimals() {
        let value: Decimal = 10
        let formatted = value.formatted(decimalPlaces: 2) as String

        #expect(formatted == "10.00")
    }
}
