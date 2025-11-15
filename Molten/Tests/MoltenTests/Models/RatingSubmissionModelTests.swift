//
//  RatingSubmissionModelTests.swift
//  MoltenTests
//
//  Created by TDD for rating system on 11/13/25.
//

import XCTest
@testable import Molten

final class RatingSubmissionModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization_WithValidData_CreatesModel() {
        // Given
        let itemStableId = "bullseye-001-0"
        let starRating = 5
        let words = ["beautiful", "vibrant", "smooth", "reliable", "stunning"]

        // When
        let model = RatingSubmissionModel(
            itemStableId: itemStableId,
            starRating: starRating,
            words: words
        )

        // Then
        XCTAssertEqual(model.itemStableId, itemStableId)
        XCTAssertEqual(model.starRating, starRating)
        XCTAssertEqual(model.words, words)
        XCTAssertNotNil(model.createdAt)
    }

    func testInitialization_TrimsWhitespaceFromItemStableId() {
        // Given
        let itemStableId = "  bullseye-001-0  "

        // When
        let model = RatingSubmissionModel(
            itemStableId: itemStableId,
            starRating: 5,
            words: ["test", "words", "here", "now", "go"]
        )

        // Then
        XCTAssertEqual(model.itemStableId, "bullseye-001-0")
    }

    func testInitialization_TrimsWhitespaceFromWords() {
        // Given
        let words = ["  beautiful  ", "vibrant", "  smooth", "reliable  ", "stunning"]

        // When
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: words
        )

        // Then
        XCTAssertEqual(model.words, ["beautiful", "vibrant", "smooth", "reliable", "stunning"])
    }

    func testInitialization_LowercasesWords() {
        // Given
        let words = ["Beautiful", "VIBRANT", "SmOoTh", "reliable", "STUNNING"]

        // When
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: words
        )

        // Then
        XCTAssertEqual(model.words, ["beautiful", "vibrant", "smooth", "reliable", "stunning"])
    }

    // MARK: - Validation Tests

    func testIsValid_WithValidData_ReturnsTrue() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        XCTAssertTrue(model.isValid)
        XCTAssertTrue(model.validationErrors.isEmpty)
    }

    func testIsValid_WithEmptyItemStableId_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Item stable ID is required"))
    }

    func testIsValid_WithStarRatingTooLow_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 0,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Star rating must be between 1 and 5"))
    }

    func testIsValid_WithStarRatingTooHigh_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 6,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Star rating must be between 1 and 5"))
    }

    func testIsValid_WithFewerThanFiveWords_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant"]
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Exactly 5 words are required"))
    }

    func testIsValid_WithMoreThanFiveWords_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning", "extra"]
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Exactly 5 words are required"))
    }

    func testIsValid_WithEmptyWord_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "", "smooth", "reliable", "stunning"]
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("All words must be non-empty"))
    }

    func testIsValid_WithWordTooLong_ReturnsFalse() {
        // Given
        let longWord = String(repeating: "a", count: 31)
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", longWord, "smooth", "reliable", "stunning"]
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Words must be 30 characters or less"))
    }

    func testIsValid_WithDuplicateWords_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "beautiful", "reliable", "stunning"]
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Words must be unique"))
    }

    // MARK: - Profanity Filter Tests

    func testContainsProfanity_WithCleanWords_ReturnsFalse() {
        // Given
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        XCTAssertFalse(model.containsProfanity)
    }

    func testContainsProfanity_WithProfaneWord_ReturnsTrue() {
        // Given - using a mild example for testing
        let model = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "damn", "smooth", "reliable", "stunning"]
        )

        // When/Then
        XCTAssertTrue(model.containsProfanity)
    }

    // MARK: - Equatable Tests

    func testEquatable_SameData_ReturnsTrue() {
        // Given
        let date = Date()
        let model1 = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"],
            createdAt: date
        )
        let model2 = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"],
            createdAt: date
        )

        // When/Then
        XCTAssertEqual(model1, model2)
    }

    func testEquatable_DifferentStarRating_ReturnsFalse() {
        // Given
        let model1 = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )
        let model2 = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 4,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When/Then
        XCTAssertNotEqual(model1, model2)
    }

    // MARK: - Codable Tests

    func testCodable_EncodeDecode_PreservesData() throws {
        // Given
        let original = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RatingSubmissionModel.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.itemStableId, original.itemStableId)
        XCTAssertEqual(decoded.starRating, original.starRating)
        XCTAssertEqual(decoded.words, original.words)
    }
}
