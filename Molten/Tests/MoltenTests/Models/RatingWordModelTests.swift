//
//  RatingWordModelTests.swift
//  MoltenTests
//
//  Created by TDD for rating system on 11/13/25.
//

import XCTest
@testable import Molten

final class RatingWordModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization_WithValidData_CreatesModel() {
        // Given
        let word = "beautiful"
        let frequency = 89
        let rank = 1

        // When
        let model = RatingWordModel(word: word, frequency: frequency, rank: rank)

        // Then
        XCTAssertEqual(model.word, word)
        XCTAssertEqual(model.frequency, frequency)
        XCTAssertEqual(model.rank, rank)
    }

    func testInitialization_TrimsWhitespaceFromWord() {
        // Given
        let word = "  beautiful  "

        // When
        let model = RatingWordModel(word: word, frequency: 89, rank: 1)

        // Then
        XCTAssertEqual(model.word, "beautiful")
    }

    func testInitialization_LowercasesWord() {
        // Given
        let word = "Beautiful"

        // When
        let model = RatingWordModel(word: word, frequency: 89, rank: 1)

        // Then
        XCTAssertEqual(model.word, "beautiful")
    }

    // MARK: - Validation Tests

    func testIsValid_WithValidData_ReturnsTrue() {
        // Given
        let model = RatingWordModel(word: "beautiful", frequency: 89, rank: 1)

        // When/Then
        XCTAssertTrue(model.isValid)
        XCTAssertTrue(model.validationErrors.isEmpty)
    }

    func testIsValid_WithEmptyWord_ReturnsFalse() {
        // Given
        let model = RatingWordModel(word: "", frequency: 89, rank: 1)

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Word cannot be empty"))
    }

    func testIsValid_WithNegativeFrequency_ReturnsFalse() {
        // Given
        let model = RatingWordModel(word: "beautiful", frequency: -1, rank: 1)

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Frequency must be positive"))
    }

    func testIsValid_WithNonPositiveRank_ReturnsFalse() {
        // Given
        let model = RatingWordModel(word: "beautiful", frequency: 89, rank: 0)

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Rank must be positive"))
    }

    // MARK: - Comparable Tests

    func testComparable_LowerRank_IsLessThan() {
        // Given
        let word1 = RatingWordModel(word: "beautiful", frequency: 89, rank: 1)
        let word2 = RatingWordModel(word: "vibrant", frequency: 67, rank: 2)

        // When/Then
        XCTAssertTrue(word1 < word2)
        XCTAssertFalse(word2 < word1)
    }

    func testComparable_SameRank_Equal() {
        // Given
        let word1 = RatingWordModel(word: "beautiful", frequency: 89, rank: 1)
        let word2 = RatingWordModel(word: "stunning", frequency: 85, rank: 1)

        // When/Then
        XCTAssertFalse(word1 < word2)
        XCTAssertFalse(word2 < word1)
    }

    // MARK: - Equatable Tests

    func testEquatable_SameData_ReturnsTrue() {
        // Given
        let word1 = RatingWordModel(word: "beautiful", frequency: 89, rank: 1)
        let word2 = RatingWordModel(word: "beautiful", frequency: 89, rank: 1)

        // When/Then
        XCTAssertEqual(word1, word2)
    }

    func testEquatable_DifferentFrequency_ReturnsFalse() {
        // Given
        let word1 = RatingWordModel(word: "beautiful", frequency: 89, rank: 1)
        let word2 = RatingWordModel(word: "beautiful", frequency: 90, rank: 1)

        // When/Then
        XCTAssertNotEqual(word1, word2)
    }

    // MARK: - Codable Tests

    func testCodable_EncodeDecode_PreservesData() throws {
        // Given
        let original = RatingWordModel(word: "beautiful", frequency: 89, rank: 1)

        // When
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RatingWordModel.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.word, original.word)
        XCTAssertEqual(decoded.frequency, original.frequency)
        XCTAssertEqual(decoded.rank, original.rank)
    }
}
