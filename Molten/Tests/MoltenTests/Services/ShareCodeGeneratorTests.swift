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

        // Format: GLASS-XXXX-XXXX
        #expect(code.hasPrefix("GLASS-"))
        #expect(code.count == 15) // GLASS-XXXX-XXXX = 15 characters

        let parts = code.split(separator: "-")
        #expect(parts.count == 3)
        #expect(parts[0] == "GLASS")
        #expect(parts[1].count == 4)
        #expect(parts[2].count == 4)
    }

    @Test("Should generate unique codes")
    func testGenerateUniqueShareCodes() {
        let generator = ShareCodeGenerator()
        let codes = Set((0..<100).map { _ in generator.generate() })

        // All 100 codes should be unique
        #expect(codes.count == 100)
    }

    @Test("Should generate codes with only alphanumeric characters")
    func testGenerateAlphanumericOnly() {
        let generator = ShareCodeGenerator()
        let code = generator.generate()

        // Remove prefix and dashes
        let codeWithoutPrefix = code.replacingOccurrences(of: "GLASS-", with: "")
        let codePart = codeWithoutPrefix.replacingOccurrences(of: "-", with: "")

        let alphanumericSet = CharacterSet.alphanumerics
        let codeCharacterSet = CharacterSet(charactersIn: codePart)

        #expect(alphanumericSet.isSuperset(of: codeCharacterSet))
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

        #expect(generator.isValid("GLASS-ABCD-1234"))
        #expect(generator.isValid("GLASS-XYZ9-ABC1"))
        #expect(generator.isValid("GLASS-0000-ZZZZ"))
    }

    @Test("Should validate case-insensitive codes")
    func testValidateCaseInsensitive() {
        let generator = ShareCodeGenerator()

        #expect(generator.isValid("glass-abcd-1234"))
        #expect(generator.isValid("Glass-ABCD-1234"))
        #expect(generator.isValid("GLASS-abcd-1234"))
    }

    @Test("Should reject invalid prefixes")
    func testRejectInvalidPrefix() {
        let generator = ShareCodeGenerator()

        #expect(!generator.isValid("METAL-ABCD-1234"))
        #expect(!generator.isValid("ABCD-1234-5678"))
        #expect(!generator.isValid(""))
    }

    @Test("Should reject invalid lengths")
    func testRejectInvalidLengths() {
        let generator = ShareCodeGenerator()

        #expect(!generator.isValid("GLASS-ABC-1234")) // Too short
        #expect(!generator.isValid("GLASS-ABCDE-1234")) // Too long
        #expect(!generator.isValid("GLASS-ABCD-12345")) // Too long
        #expect(!generator.isValid("GLASS-ABCD")) // Missing part
    }

    @Test("Should reject codes with special characters")
    func testRejectSpecialCharacters() {
        let generator = ShareCodeGenerator()

        #expect(!generator.isValid("GLASS-AB@D-1234"))
        #expect(!generator.isValid("GLASS-ABCD-12$4"))
        #expect(!generator.isValid("GLASS-AB.D-1234"))
        #expect(!generator.isValid("GLASS-ABCD-12 4"))
    }

    @Test("Should reject codes with wrong separator")
    func testRejectWrongSeparator() {
        let generator = ShareCodeGenerator()

        #expect(!generator.isValid("GLASS_ABCD_1234"))
        #expect(!generator.isValid("GLASS.ABCD.1234"))
        #expect(!generator.isValid("GLASSABCD1234"))
    }

    // MARK: - Normalization Tests

    @Test("Should normalize codes to uppercase")
    func testNormalizeToUppercase() {
        let generator = ShareCodeGenerator()

        #expect(generator.normalize("glass-abcd-1234") == "GLASS-ABCD-1234")
        #expect(generator.normalize("Glass-XyZ9-AbC1") == "GLASS-XYZ9-ABC1")
    }

    @Test("Should normalize whitespace in codes")
    func testNormalizeWhitespace() {
        let generator = ShareCodeGenerator()

        #expect(generator.normalize(" GLASS-ABCD-1234 ") == "GLASS-ABCD-1234")
        #expect(generator.normalize("GLASS-ABCD-1234\n") == "GLASS-ABCD-1234")
    }

    @Test("Should return nil for invalid codes during normalization")
    func testNormalizeInvalidCodes() {
        let generator = ShareCodeGenerator()

        #expect(generator.normalize("INVALID") == nil)
        #expect(generator.normalize("GLASS-AB-1234") == nil)
        #expect(generator.normalize("") == nil)
    }

    // MARK: - Entropy Tests

    @Test("Should have sufficient entropy (8 alphanumeric characters)")
    func testSufficientEntropy() {
        let generator = ShareCodeGenerator()
        let codes = Set((0..<1000).map { _ in generator.generate() })

        // With 36^8 possible combinations, 1000 codes should all be unique
        #expect(codes.count == 1000)

        // Verify we're using full character set (not just numbers or just letters)
        let allChars = codes.joined().replacingOccurrences(of: "GLASS-", with: "").replacingOccurrences(of: "-", with: "")
        let hasNumbers = allChars.contains(where: { $0.isNumber })
        let hasLetters = allChars.contains(where: { $0.isLetter })

        #expect(hasNumbers, "Generated codes should include numbers")
        #expect(hasLetters, "Generated codes should include letters")
    }
}
