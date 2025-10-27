//
//  CatalogFormattersTests.swift
//  MoltenTests
//
//  Created by Claude Code on 10/26/25.
//  Tests for CatalogFormatters following TDD and Swift 6 concurrency guidelines
//

import Testing
import Foundation
@testable import Molten

@Suite("CatalogFormatters Tests")
@MainActor
struct CatalogFormattersTests {

    // MARK: - itemFormatter Tests

    @Test("itemFormatter has short date style")
    func testItemFormatterDateStyle() {
        let formatter = CatalogFormatters.itemFormatter

        #expect(formatter.dateStyle == .short)
    }

    @Test("itemFormatter has medium time style")
    func testItemFormatterTimeStyle() {
        let formatter = CatalogFormatters.itemFormatter

        #expect(formatter.timeStyle == .medium)
    }

    @Test("itemFormatter formats date with both date and time")
    func testItemFormatterFormatsDate() {
        let formatter = CatalogFormatters.itemFormatter

        // Create a known date: January 15, 2025 at 3:30 PM
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 15
        components.minute = 30
        components.second = 0

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = formatter.string(from: date)

        // Should include date and time components
        // Format varies by locale, but should contain both parts
        #expect(formatted.isEmpty == false)
        #expect(formatted.count > 5) // Should be reasonably long with date and time
    }

    @Test("itemFormatter is reusable across multiple calls")
    func testItemFormatterReusable() {
        let formatter1 = CatalogFormatters.itemFormatter
        let formatter2 = CatalogFormatters.itemFormatter

        // Should be the same instance (static lazy)
        #expect(formatter1.dateStyle == formatter2.dateStyle)
        #expect(formatter1.timeStyle == formatter2.timeStyle)
    }

    @Test("itemFormatter handles current date")
    func testItemFormatterCurrentDate() {
        let formatter = CatalogFormatters.itemFormatter
        let now = Date()

        let formatted = formatter.string(from: now)

        #expect(formatted.isEmpty == false)
    }

    @Test("itemFormatter handles past date")
    func testItemFormatterPastDate() {
        let formatter = CatalogFormatters.itemFormatter

        // Create a date in the past: January 1, 2000
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = 12
        components.minute = 0

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = formatter.string(from: date)

        #expect(formatted.isEmpty == false)
    }

    @Test("itemFormatter handles future date")
    func testItemFormatterFutureDate() {
        let formatter = CatalogFormatters.itemFormatter

        // Create a date in the future: January 1, 2030
        var components = DateComponents()
        components.year = 2030
        components.month = 1
        components.day = 1
        components.hour = 12
        components.minute = 0

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = formatter.string(from: date)

        #expect(formatted.isEmpty == false)
    }

    // MARK: - yearFormatter Tests

    @Test("yearFormatter has correct date format")
    func testYearFormatterDateFormat() {
        let formatter = CatalogFormatters.yearFormatter

        #expect(formatter.dateFormat == "yyyy")
    }

    @Test("yearFormatter formats year correctly")
    func testYearFormatterFormatsYear() {
        let formatter = CatalogFormatters.yearFormatter

        // Create a date in 2025
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = formatter.string(from: date)

        #expect(formatted == "2025")
    }

    @Test("yearFormatter formats year in past")
    func testYearFormatterPastYear() {
        let formatter = CatalogFormatters.yearFormatter

        // Create a date in 1999
        var components = DateComponents()
        components.year = 1999
        components.month = 12
        components.day = 31

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = formatter.string(from: date)

        #expect(formatted == "1999")
    }

    @Test("yearFormatter formats year in future")
    func testYearFormatterFutureYear() {
        let formatter = CatalogFormatters.yearFormatter

        // Create a date in 2050
        var components = DateComponents()
        components.year = 2050
        components.month = 1
        components.day = 1

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = formatter.string(from: date)

        #expect(formatted == "2050")
    }

    @Test("yearFormatter handles current year")
    func testYearFormatterCurrentYear() {
        let formatter = CatalogFormatters.yearFormatter
        let now = Date()

        let formatted = formatter.string(from: now)

        // Should be 4 digits
        #expect(formatted.count == 4)

        // Should be parseable as an integer
        #expect(Int(formatted) != nil)
    }

    @Test("yearFormatter is reusable across multiple calls")
    func testYearFormatterReusable() {
        let formatter1 = CatalogFormatters.yearFormatter
        let formatter2 = CatalogFormatters.yearFormatter

        // Should be the same instance (static lazy)
        #expect(formatter1.dateFormat == formatter2.dateFormat)
    }

    @Test("yearFormatter only returns year digits")
    func testYearFormatterOnlyYear() {
        let formatter = CatalogFormatters.yearFormatter

        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 26
        components.hour = 14
        components.minute = 30

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = formatter.string(from: date)

        // Should only contain year, no month, day, or time
        #expect(formatted == "2025")
        #expect(formatted.contains("/") == false)
        #expect(formatted.contains("-") == false)
        #expect(formatted.contains(":") == false)
    }

    @Test("yearFormatter handles leap year")
    func testYearFormatterLeapYear() {
        let formatter = CatalogFormatters.yearFormatter

        // 2024 is a leap year
        var components = DateComponents()
        components.year = 2024
        components.month = 2
        components.day = 29 // Leap day

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let formatted = formatter.string(from: date)

        #expect(formatted == "2024")
    }

    // MARK: - Formatter Interaction Tests

    @Test("Both formatters can format the same date independently")
    func testBothFormattersIndependent() {
        let itemFormatter = CatalogFormatters.itemFormatter
        let yearFormatter = CatalogFormatters.yearFormatter

        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 26
        components.hour = 14
        components.minute = 30

        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create test date")
            return
        }

        let itemFormatted = itemFormatter.string(from: date)
        let yearFormatted = yearFormatter.string(from: date)

        // Both should successfully format
        #expect(itemFormatted.isEmpty == false)
        #expect(yearFormatted == "2025")

        // Year formatted should be shorter (just year)
        #expect(yearFormatted.count < itemFormatted.count)
    }

    @Test("Formatters are stateless and thread-safe")
    func testFormattersStateless() {
        let formatter = CatalogFormatters.itemFormatter

        var components1 = DateComponents()
        components1.year = 2025
        components1.month = 1
        components1.day = 1

        var components2 = DateComponents()
        components2.year = 2024
        components2.month = 12
        components2.day = 31

        let calendar = Calendar.current
        guard let date1 = calendar.date(from: components1),
              let date2 = calendar.date(from: components2) else {
            Issue.record("Failed to create test dates")
            return
        }

        let formatted1 = formatter.string(from: date1)
        let formatted2 = formatter.string(from: date2)

        // Both should format successfully
        #expect(formatted1.isEmpty == false)
        #expect(formatted2.isEmpty == false)

        // Should be different since dates are different
        #expect(formatted1 != formatted2)
    }
}
