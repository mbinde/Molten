//
//  ShareCodeGeneratorTests.swift
//  MoltenTests
//
//  Tests for ShareCodeGenerator - generates and validates share codes
//  Share code format: GLASS-XXXX-XXXX (8 chars of alphanumeric entropy)
//

import Testing
import Foundation
@testable import Molten

@Suite("ShareCodeGenerator Tests")
@MainActor
struct ShareCodeGeneratorTests {

    // MARK: - Generation Tests

    @Test("Should generate share code with correct format")
    func testGenerateShareCodeFormat() {
        let generator = ShareCodeGenerator()
        let code = generator.generate()

        // Format: 6 random characters (e.g., "A7B2X9")
        #expect(code.count == 6, "Code should be 6 characters")
        #expect(code == code.uppercased(), "Code should be uppercase")
    }

    @Test("Should generate unique codes")
    func testGenerateUniqueShareCodes() {
        let generator = ShareCodeGenerator()
        let codes = Set((0..<100).map { _ in generator.generate() })

        // All 100 codes should be unique
        #expect(codes.count == 100)
    }

    @Test("Should generate codes with safe characters only")
    func testGenerateSafeCharactersOnly() {
        let generator = ShareCodeGenerator()

        // Generate many codes to test character distribution
        let codes = (0..<100).map { _ in generator.generate() }
        let allChars = codes.joined()

        // Verify no confusing characters appear
        #expect(!allChars.contains("0"), "Should not contain zero")
        #expect(!allChars.contains("O"), "Should not contain capital O")
        #expect(!allChars.contains("1"), "Should not contain one")
        #expect(!allChars.contains("l"), "Should not contain lowercase L")
        #expect(!allChars.contains("I"), "Should not contain capital I")
    }

    @Test("Should generate uppercase codes")
    func testGenerateUppercaseCodes() {
        let generator = ShareCodeGenerator()
        let code = generator.generate()

        #expect(code == code.uppercased())
    }

    // MARK: - Validation Tests

    @Test("Should validate correct share code format")
    func testValidateCorrectFormat() {
        let generator = ShareCodeGenerator()

        #expect(generator.isValid("A7B2X9"))
        #expect(generator.isValid("XYZ9AB"))
        #expect(generator.isValid("234567"))
    }

    @Test("Should validate case-insensitive codes")
    func testValidateCaseInsensitive() {
        let generator = ShareCodeGenerator()

        #expect(generator.isValid("a7b2x9"))
        #expect(generator.isValid("A7b2X9"))
        #expect(generator.isValid("xyz9ab"))
    }

    @Test("Should reject confusing characters")
    func testRejectConfusingCharacters() {
        let generator = ShareCodeGenerator()

        #expect(!generator.isValid("A0B2X9")) // Contains 0
        #expect(!generator.isValid("AO B2X9")) // Contains O
        #expect(!generator.isValid("A1B2X9")) // Contains 1
        #expect(!generator.isValid("AlB2X9")) // Contains lowercase l
        #expect(!generator.isValid("AIB2X9")) // Contains I
        #expect(!generator.isValid(""))
    }

    @Test("Should reject invalid lengths")
    func testRejectInvalidLengths() {
        let generator = ShareCodeGenerator()

        #expect(!generator.isValid("ABC23")) // Too short (5 chars)
        #expect(!generator.isValid("ABCD")) // Too short (4 chars)
        #expect(!generator.isValid("AB")) // Too short (2 chars)
        #expect(!generator.isValid("ABCD234")) // Too long (7 chars)
        #expect(!generator.isValid("ABCD2345")) // Too long (8 chars)
    }

    @Test("Should reject codes with special characters")
    func testRejectSpecialCharacters() {
        let generator = ShareCodeGenerator()

        #expect(!generator.isValid("AB@D23"))
        #expect(!generator.isValid("ABCD2$"))
        #expect(!generator.isValid("AB.D23"))
        #expect(!generator.isValid("ABCD 3"))
        #expect(!generator.isValid("ABC-23"))
    }

    // MARK: - Normalization Tests

    @Test("Should normalize codes to uppercase")
    func testNormalizeToUppercase() {
        let generator = ShareCodeGenerator()

        #expect(generator.normalize("a7b2x9") == "A7B2X9")
        #expect(generator.normalize("XyZ9Ab") == "XYZ9AB")
    }

    @Test("Should normalize whitespace in codes")
    func testNormalizeWhitespace() {
        let generator = ShareCodeGenerator()

        #expect(generator.normalize(" A7B2X9 ") == "A7B2X9")
        #expect(generator.normalize("A7B2X9\n") == "A7B2X9")
    }

    @Test("Should return nil for invalid codes during normalization")
    func testNormalizeInvalidCodes() {
        let generator = ShareCodeGenerator()

        #expect(generator.normalize("INVALID") == nil) // Wrong length
        #expect(generator.normalize("AB@D23") == nil) // Special character
        #expect(generator.normalize("") == nil) // Empty
    }

    // MARK: - Entropy Tests

    @Test("Should have sufficient entropy (6 safe characters)")
    func testSufficientEntropy() {
        let generator = ShareCodeGenerator()
        let codes = Set((0..<1000).map { _ in generator.generate() })

        // With 31^6 = ~887 million possible combinations, 1000 codes should all be unique
        #expect(codes.count == 1000)

        // Verify we're using full character set (not just numbers or just letters)
        let allChars = codes.joined()
        let hasNumbers = allChars.contains(where: { $0.isNumber })
        let hasLetters = allChars.contains(where: { $0.isLetter })

        #expect(hasNumbers, "Generated codes should include numbers")
        #expect(hasLetters, "Generated codes should include letters")
    }
}
