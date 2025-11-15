//
//  AggregatedRatingModelTests.swift
//  MoltenTests
//
//  Created by TDD for rating system on 11/13/25.
//

import XCTest
@testable import Molten

final class AggregatedRatingModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization_WithValidData_CreatesModel() {
        // Given
        let itemStableId = "bullseye-001-0"
        let averageRating = 4.7
        let totalRatings = 142
        let topWords = [
            RatingWordModel(word: "beautiful", frequency: 89, rank: 1),
            RatingWordModel(word: "vibrant", frequency: 67, rank: 2)
        ]
        let lastAggregated = Date()

        // When
        let model = AggregatedRatingModel(
            itemStableId: itemStableId,
            averageRating: averageRating,
            totalRatings: totalRatings,
            topWords: topWords,
            lastAggregated: lastAggregated
        )

        // Then
        XCTAssertEqual(model.itemStableId, itemStableId)
        XCTAssertEqual(model.averageRating, averageRating, accuracy: 0.01)
        XCTAssertEqual(model.totalRatings, totalRatings)
        XCTAssertEqual(model.topWords.count, 2)
        XCTAssertEqual(model.lastAggregated, lastAggregated)
    }

    func testInitialization_TrimsWhitespaceFromItemStableId() {
        // Given
        let itemStableId = "  bullseye-001-0  "

        // When
        let model = AggregatedRatingModel(
            itemStableId: itemStableId,
            averageRating: 4.5,
            totalRatings: 10,
            topWords: []
        )

        // Then
        XCTAssertEqual(model.itemStableId, "bullseye-001-0")
    }

    // MARK: - Validation Tests

    func testIsValid_WithValidData_ReturnsTrue() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: []
        )

        // When/Then
        XCTAssertTrue(model.isValid)
        XCTAssertTrue(model.validationErrors.isEmpty)
    }

    func testIsValid_WithEmptyItemStableId_ReturnsFalse() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: []
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Item stable ID is required"))
    }

    func testIsValid_WithAverageRatingTooLow_ReturnsFalse() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 0.5,
            totalRatings: 10,
            topWords: []
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Average rating must be between 1.0 and 5.0"))
    }

    func testIsValid_WithAverageRatingTooHigh_ReturnsFalse() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 5.5,
            totalRatings: 10,
            topWords: []
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Average rating must be between 1.0 and 5.0"))
    }

    func testIsValid_WithNegativeTotalRatings_ReturnsFalse() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: -1,
            topWords: []
        )

        // When/Then
        XCTAssertFalse(model.isValid)
        XCTAssertTrue(model.validationErrors.contains("Total ratings must be non-negative"))
    }

    // MARK: - Business Logic Tests

    func testRatingCategory_WithHighRating_ReturnsExcellent() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.8,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        XCTAssertEqual(model.ratingCategory, .excellent)
    }

    func testRatingCategory_WithGoodRating_ReturnsGood() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.2,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        XCTAssertEqual(model.ratingCategory, .good)
    }

    func testRatingCategory_WithAverageRating_ReturnsAverage() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 3.5,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        XCTAssertEqual(model.ratingCategory, .average)
    }

    func testRatingCategory_WithBelowAverageRating_ReturnsBelowAverage() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 2.5,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        XCTAssertEqual(model.ratingCategory, .belowAverage)
    }

    func testRatingCategory_WithPoorRating_ReturnsPoor() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 1.5,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        XCTAssertEqual(model.ratingCategory, .poor)
    }

    func testHasEnoughRatings_WithSufficientRatings_ReturnsTrue() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: []
        )

        // When/Then
        XCTAssertTrue(model.hasEnoughRatings)
    }

    func testHasEnoughRatings_WithInsufficientRatings_ReturnsFalse() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 4,
            topWords: []
        )

        // When/Then
        XCTAssertFalse(model.hasEnoughRatings)
    }

    func testTopWords_SortedByRank() {
        // Given
        let words = [
            RatingWordModel(word: "vibrant", frequency: 67, rank: 2),
            RatingWordModel(word: "beautiful", frequency: 89, rank: 1),
            RatingWordModel(word: "smooth", frequency: 45, rank: 3)
        ]
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 100,
            topWords: words
        )

        // When
        let sortedWords = model.topWords

        // Then
        XCTAssertEqual(sortedWords[0].rank, 1)
        XCTAssertEqual(sortedWords[1].rank, 2)
        XCTAssertEqual(sortedWords[2].rank, 3)
    }

    func testTopWordsForDisplay_ReturnsFirst10() {
        // Given
        let words = (1...15).map { RatingWordModel(word: "word\($0)", frequency: 100 - $0, rank: $0) }
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 100,
            topWords: words
        )

        // When
        let displayWords = model.topWordsForDisplay()

        // Then
        XCTAssertEqual(displayWords.count, 10)
        XCTAssertEqual(displayWords.first?.rank, 1)
        XCTAssertEqual(displayWords.last?.rank, 10)
    }

    func testTopWordsForDisplay_WithCustomLimit_ReturnsCorrectCount() {
        // Given
        let words = (1...15).map { RatingWordModel(word: "word\($0)", frequency: 100 - $0, rank: $0) }
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 100,
            topWords: words
        )

        // When
        let displayWords = model.topWordsForDisplay(limit: 5)

        // Then
        XCTAssertEqual(displayWords.count, 5)
        XCTAssertEqual(displayWords.first?.rank, 1)
        XCTAssertEqual(displayWords.last?.rank, 5)
    }

    func testFormattedAverageRating_ReturnsCorrectFormat() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.67,
            totalRatings: 100,
            topWords: []
        )

        // When
        let formatted = model.formattedAverageRating

        // Then
        XCTAssertEqual(formatted, "4.7")
    }

    // MARK: - Equatable Tests

    func testEquatable_SameData_ReturnsTrue() {
        // Given
        let date = Date()
        let words = [RatingWordModel(word: "beautiful", frequency: 89, rank: 1)]
        let model1 = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 100,
            topWords: words,
            lastAggregated: date
        )
        let model2 = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 100,
            topWords: words,
            lastAggregated: date
        )

        // When/Then
        XCTAssertEqual(model1, model2)
    }

    func testEquatable_DifferentAverageRating_ReturnsFalse() {
        // Given
        let model1 = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 100,
            topWords: []
        )
        let model2 = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.7,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        XCTAssertNotEqual(model1, model2)
    }

    // MARK: - Codable Tests

    func testCodable_EncodeDecode_PreservesData() throws {
        // Given
        let words = [
            RatingWordModel(word: "beautiful", frequency: 89, rank: 1),
            RatingWordModel(word: "vibrant", frequency: 67, rank: 2)
        ]
        let original = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.7,
            totalRatings: 142,
            topWords: words
        )

        // When
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AggregatedRatingModel.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.itemStableId, original.itemStableId)
        XCTAssertEqual(decoded.averageRating, original.averageRating, accuracy: 0.01)
        XCTAssertEqual(decoded.totalRatings, original.totalRatings)
        XCTAssertEqual(decoded.topWords.count, original.topWords.count)
    }
}
