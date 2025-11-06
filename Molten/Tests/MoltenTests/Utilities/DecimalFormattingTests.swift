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
struct DecimalFormattingTests {

    // MARK: - formatted() Tests (default formatting)

    @Test("Format decimal with no fractional part")
    func testFormatWholeNumber() {
        let value = Decimal(5)
        let formatted = value.formatted()

        #expect(formatted == "5")
    }

    @Test("Format decimal with one decimal place")
    func testFormatOneDecimalPlace() {
        let value = Decimal(string: "3.5")!
        let formatted = value.formatted()

        #expect(formatted == "3.5")
    }

    @Test("Format decimal with two decimal places")
    func testFormatTwoDecimalPlaces() {
        let value = Decimal(string: "12.75")!
        let formatted = value.formatted()

        #expect(formatted == "12.75")
    }

    @Test("Format decimal removing trailing zeros")
    func testFormatRemovesTrailingZeros() {
        let value = Decimal(string: "10.00")!
        let formatted = value.formatted()

        #expect(formatted == "10")
    }

    @Test("Format decimal with more than two decimal places rounds")
    func testFormatRoundsToTwoPlaces() {
        let value = Decimal(string: "3.456")!
        let formatted = value.formatted()

        #expect(formatted == "3.46") // Rounds up
    }

    @Test("Format decimal with rounding down")
    func testFormatRoundsDown() {
        let value = Decimal(string: "3.454")!
        let formatted = value.formatted()

        #expect(formatted == "3.45") // Rounds down
    }

    @Test("Format zero")
    func testFormatZero() {
        let value = Decimal(0)
        let formatted = value.formatted()

        #expect(formatted == "0")
    }

    @Test("Format negative decimal")
    func testFormatNegative() {
        let value = Decimal(string: "-5.75")!
        let formatted = value.formatted()

        #expect(formatted == "-5.75")
    }

    @Test("Format large number with thousands")
    func testFormatLargeNumber() {
        let value = Decimal(1234)
        let formatted = value.formatted()

        #expect(formatted == "1,234")
    }

    @Test("Format very small decimal")
    func testFormatVerySmallDecimal() {
        let value = Decimal(string: "0.01")!
        let formatted = value.formatted()

        #expect(formatted == "0.01")
    }

    @Test("Format decimal at rounding boundary (half up)")
    func testFormatHalfUpRounding() {
        let value = Decimal(string: "2.125")!
        let formatted = value.formatted()

        // With halfUp rounding mode, .125 should round to .13
        #expect(formatted == "2.13")
    }

    // MARK: - formatted(decimalPlaces:) Tests (custom decimal places)

    @Test("Format with zero decimal places")
    func testFormatZeroDecimalPlaces() {
        let value = Decimal(string: "3.7")!
        let formatted = value.formatted(decimalPlaces: 0)

        #expect(formatted == "4") // Rounds to nearest whole number
    }

    @Test("Format with one decimal place")
    func testFormatOneDecimalPlaceExplicit() {
        let value = Decimal(string: "3.456")!
        let formatted = value.formatted(decimalPlaces: 1)

        #expect(formatted == "3.5")
    }

    @Test("Format with three decimal places")
    func testFormatThreeDecimalPlaces() {
        let value = Decimal(string: "2.5")!
        let formatted = value.formatted(decimalPlaces: 3)

        #expect(formatted == "2.500") // Pads with zeros
    }

    @Test("Format with four decimal places")
    func testFormatFourDecimalPlaces() {
        let value = Decimal(string: "1.23456")!
        let formatted = value.formatted(decimalPlaces: 4)

        #expect(formatted == "1.2346") // Rounds to 4 places
    }

    @Test("Format whole number with decimal places specified")
    func testFormatWholeNumberWithDecimalPlaces() {
        let value = Decimal(10)
        let formatted = value.formatted(decimalPlaces: 2)

        #expect(formatted == "10.00")
    }

    @Test("Format zero with decimal places")
    func testFormatZeroWithDecimalPlaces() {
        let value = Decimal(0)
        let formatted = value.formatted(decimalPlaces: 3)

        #expect(formatted == "0.000")
    }

    @Test("Format negative with custom decimal places")
    func testFormatNegativeWithDecimalPlaces() {
        let value = Decimal(string: "-12.3456")!
        let formatted = value.formatted(decimalPlaces: 2)

        #expect(formatted == "-12.35")
    }

    // MARK: - Edge Cases

    @Test("Format very large decimal")
    func testFormatVeryLargeDecimal() {
        let value = Decimal(string: "1000000.99")!
        let formatted = value.formatted()

        #expect(formatted == "1,000,000.99")
    }

    @Test("Format fraction less than 0.01")
    func testFormatTinyFraction() {
        let value = Decimal(string: "0.001")!
        let formatted = value.formatted()

        #expect(formatted == "0") // Rounds to 0 because max 2 decimal places
    }

    @Test("Format with 5 decimal places preserves precision")
    func testFormatHighPrecision() {
        let value = Decimal(string: "3.14159")!
        let formatted = value.formatted(decimalPlaces: 5)

        #expect(formatted == "3.14159")
    }
}
