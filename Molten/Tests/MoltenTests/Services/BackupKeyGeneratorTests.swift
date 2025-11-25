//
//  BackupKeyGeneratorTests.swift
//  MoltenTests
//
//  Tests for BackupKeyGenerator - generates and validates backup keys
//  Format: 3 sets of 3 alphanumerics separated by dashes (e.g., "A1B-C2D-E3F")
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

@Suite("BackupKeyGenerator Tests")
@MainActor
struct BackupKeyGeneratorTests {

    // MARK: - Generation Tests

    @Test("Should generate key in correct format XXX-XXX-XXX")
    func testGenerateKeyFormat() {
        let generator = BackupKeyGenerator()

        let key = generator.generate()

        // Should be 11 characters: XXX-XXX-XXX
        #expect(key.count == 11)

        // Should have dashes in correct positions
        let parts = key.split(separator: "-")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { $0.count == 3 })
    }

    @Test("Should generate unique keys")
    func testGenerateUniqueKeys() {
        let generator = BackupKeyGenerator()

        var keys = Set<String>()
        for _ in 0..<100 {
            keys.insert(generator.generate())
        }

        // All 100 keys should be unique
        #expect(keys.count == 100)
    }

    @Test("Should only use safe characters (no 0, O, 1, I, L)")
    func testOnlySafeCharacters() {
        let generator = BackupKeyGenerator()
        let confusingChars = Set("01OIL")

        for _ in 0..<100 {
            let key = generator.generate()
            let keyWithoutDashes = key.replacingOccurrences(of: "-", with: "")

            for char in keyWithoutDashes {
                #expect(!confusingChars.contains(char), "Key contains confusing character: \(char)")
            }
        }
    }

    @Test("Should generate uppercase characters")
    func testGenerateUppercase() {
        let generator = BackupKeyGenerator()

        for _ in 0..<50 {
            let key = generator.generate()
            #expect(key == key.uppercased())
        }
    }

    // MARK: - Validation Tests

    @Test("Should validate correctly formatted key")
    func testValidateCorrectFormat() {
        let generator = BackupKeyGenerator()

        #expect(generator.isValid("ABC-DEF-GHJ") == true)
        #expect(generator.isValid("A2B-C3D-E4F") == true)
        #expect(generator.isValid("XYZ-789-ABC") == true)
    }

    @Test("Should validate generated keys")
    func testValidateGeneratedKeys() {
        let generator = BackupKeyGenerator()

        for _ in 0..<50 {
            let key = generator.generate()
            #expect(generator.isValid(key) == true, "Generated key should be valid: \(key)")
        }
    }

    @Test("Should reject keys with wrong segment count")
    func testRejectWrongSegmentCount() {
        let generator = BackupKeyGenerator()

        #expect(generator.isValid("ABC-DEF") == false)
        #expect(generator.isValid("ABC-DEF-GHJ-KLM") == false)
        #expect(generator.isValid("ABCDEFGHJ") == false)
    }

    @Test("Should reject keys with wrong segment length")
    func testRejectWrongSegmentLength() {
        let generator = BackupKeyGenerator()

        #expect(generator.isValid("AB-DEF-GHJ") == false)
        #expect(generator.isValid("ABCD-DEF-GHJ") == false)
        #expect(generator.isValid("ABC-DE-GHJ") == false)
        #expect(generator.isValid("ABC-DEF-GH") == false)
    }

    @Test("Should reject keys with invalid characters")
    func testRejectInvalidCharacters() {
        let generator = BackupKeyGenerator()

        #expect(generator.isValid("ABC-DEF-GH!") == false)
        #expect(generator.isValid("ABC-DEF-GH@") == false)
        #expect(generator.isValid("ABC-DEF-GH ") == false)
        #expect(generator.isValid("abc-def-ghj") == false) // lowercase (validation normalizes)
    }

    @Test("Should validate lowercase keys (case insensitive)")
    func testValidateLowercaseKeys() {
        let generator = BackupKeyGenerator()

        // Validation should be case-insensitive
        #expect(generator.isValid("abc-def-ghj") == true)
        #expect(generator.isValid("Abc-Def-Ghj") == true)
    }

    @Test("Should reject empty string")
    func testRejectEmptyString() {
        let generator = BackupKeyGenerator()

        #expect(generator.isValid("") == false)
    }

    // MARK: - Normalization Tests

    @Test("Should normalize lowercase to uppercase")
    func testNormalizeLowercase() {
        let generator = BackupKeyGenerator()

        let normalized = generator.normalize("abc-def-ghj")
        #expect(normalized == "ABC-DEF-GHJ")
    }

    @Test("Should normalize mixed case")
    func testNormalizeMixedCase() {
        let generator = BackupKeyGenerator()

        let normalized = generator.normalize("AbC-dEf-GhJ")
        #expect(normalized == "ABC-DEF-GHJ")
    }

    @Test("Should trim whitespace during normalization")
    func testNormalizeTrimWhitespace() {
        let generator = BackupKeyGenerator()

        #expect(generator.normalize("  ABC-DEF-GHJ  ") == "ABC-DEF-GHJ")
        #expect(generator.normalize("\nABC-DEF-GHJ\n") == "ABC-DEF-GHJ")
        #expect(generator.normalize("\tABC-DEF-GHJ\t") == "ABC-DEF-GHJ")
    }

    @Test("Should return nil for invalid key during normalization")
    func testNormalizeInvalidReturnsNil() {
        let generator = BackupKeyGenerator()

        #expect(generator.normalize("invalid") == nil)
        #expect(generator.normalize("ABC-DEF") == nil)
        #expect(generator.normalize("") == nil)
    }

    @Test("Should normalize generated keys to themselves")
    func testNormalizeGeneratedKeys() {
        let generator = BackupKeyGenerator()

        for _ in 0..<50 {
            let key = generator.generate()
            let normalized = generator.normalize(key)
            #expect(normalized == key, "Generated key should normalize to itself")
        }
    }

    // MARK: - Character Set Tests

    @Test("Should use only allowed characters: A-Z (except O,I,L) and 2-9")
    func testAllowedCharacterSet() {
        let generator = BackupKeyGenerator()
        let allowedChars = Set("ABCDEFGHJKMNPQRSTVWXYZ23456789")

        for _ in 0..<100 {
            let key = generator.generate()
            let keyWithoutDashes = key.replacingOccurrences(of: "-", with: "")

            for char in keyWithoutDashes {
                #expect(allowedChars.contains(char), "Character \(char) should be in allowed set")
            }
        }
    }
}
