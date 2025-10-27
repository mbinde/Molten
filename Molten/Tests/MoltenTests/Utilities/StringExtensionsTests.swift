//
//  StringExtensionsTests.swift
//  MoltenTests
//
//  Created by Claude Code on 10/26/25.
//  Tests for String+Extensions following TDD and Swift 6 concurrency guidelines
//

import Testing
import Foundation
@testable import Molten

@Suite("String Extensions Tests")
struct StringExtensionsTests {

    // MARK: - truncatedSKU(maxLength:) Tests

    @Test("Truncate SKU longer than max length")
    func testTruncateSKULongerThanMax() {
        let sku = "VERYLONGSKU123"
        let truncated = sku.truncatedSKU(maxLength: 8)

        #expect(truncated == "VERYLONG…")
        #expect(truncated.count == 9) // 8 chars + ellipsis
    }

    @Test("SKU equal to max length is not truncated")
    func testTruncateSKUEqualToMax() {
        let sku = "SKU12345"
        let truncated = sku.truncatedSKU(maxLength: 8)

        #expect(truncated == "SKU12345")
        #expect(truncated.count == 8)
    }

    @Test("SKU shorter than max length is not truncated")
    func testTruncateSKUShorterThanMax() {
        let sku = "SHORT"
        let truncated = sku.truncatedSKU(maxLength: 8)

        #expect(truncated == "SHORT")
    }

    @Test("Truncate SKU with default max length")
    func testTruncateSKUDefaultMaxLength() {
        let sku = "DEFAULTMAX123"
        let truncated = sku.truncatedSKU()

        #expect(truncated == "DEFAULTM…")
        #expect(truncated.count == 9) // Default is 8 + ellipsis
    }

    @Test("Truncate empty SKU")
    func testTruncateEmptySKU() {
        let sku = ""
        let truncated = sku.truncatedSKU(maxLength: 8)

        #expect(truncated == "")
    }

    @Test("Truncate SKU with max length of 1")
    func testTruncateSKUMaxLengthOne() {
        let sku = "ABC"
        let truncated = sku.truncatedSKU(maxLength: 1)

        #expect(truncated == "A…")
    }

    @Test("Truncate SKU with max length of 0")
    func testTruncateSKUMaxLengthZero() {
        let sku = "ABC"
        let truncated = sku.truncatedSKU(maxLength: 0)

        #expect(truncated == "…")
    }

    @Test("Truncate SKU preserves special characters")
    func testTruncateSKUSpecialCharacters() {
        let sku = "SKU-001-EXTRA"
        let truncated = sku.truncatedSKU(maxLength: 8)

        #expect(truncated == "SKU-001-…")
    }

    @Test("Truncate SKU with unicode characters")
    func testTruncateSKUUnicodeCharacters() {
        let sku = "SKU™®©123456"
        let truncated = sku.truncatedSKU(maxLength: 8)

        #expect(truncated == "SKU™®©12…")
    }

    @Test("Truncate SKU with very large max length")
    func testTruncateSKUVeryLargeMaxLength() {
        let sku = "SHORT"
        let truncated = sku.truncatedSKU(maxLength: 1000)

        #expect(truncated == "SHORT")
    }

    @Test("Truncate SKU with custom max length 3")
    func testTruncateSKUCustomMaxLengthThree() {
        let sku = "ABCDEFG"
        let truncated = sku.truncatedSKU(maxLength: 3)

        #expect(truncated == "ABC…")
    }

    @Test("Truncate SKU with custom max length 15")
    func testTruncateSKUCustomMaxLengthFifteen() {
        let sku = "THIS-IS-A-VERY-LONG-SKU-CODE"
        let truncated = sku.truncatedSKU(maxLength: 15)

        #expect(truncated == "THIS-IS-A-VERY-…")
    }

    @Test("Truncate single character SKU with max length 1")
    func testTruncateSingleCharSKU() {
        let sku = "A"
        let truncated = sku.truncatedSKU(maxLength: 1)

        #expect(truncated == "A")
    }

    @Test("Truncate SKU with whitespace")
    func testTruncateSKUWithWhitespace() {
        let sku = "SKU 001 EXTRA"
        let truncated = sku.truncatedSKU(maxLength: 8)

        #expect(truncated == "SKU 001 …")
    }

    @Test("Truncate numeric SKU")
    func testTruncateNumericSKU() {
        let sku = "123456789"
        let truncated = sku.truncatedSKU(maxLength: 5)

        #expect(truncated == "12345…")
    }
}
