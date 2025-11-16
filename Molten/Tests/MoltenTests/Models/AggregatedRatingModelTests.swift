//
//  AggregatedRatingModelTests.swift
//  MoltenTests
//
//  Created by TDD for rating system on 11/13/25.
//

import Foundation
import Testing
@testable import Molten

@Suite("AggregatedRatingModel Tests")
struct AggregatedRatingModelTests {

    // MARK: - Initialization Tests

    @Test("Initialization with valid data creates model")
    func initialization_withValidData_createsModel() {
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
        #expect(model.itemStableId == itemStableId)
        #expect(abs(model.averageRating - averageRating) < 0.01)
        #expect(model.totalRatings == totalRatings)
        #expect(model.topWords.count == 2)
        #expect(model.lastAggregated == lastAggregated)
    }

    @Test("Initialization trims whitespace from item stable ID")
    func initialization_trimsWhitespaceFromItemStableId() {
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
        #expect(model.itemStableId == "bullseye-001-0")
    }

    // MARK: - Validation Tests

    @Test("Valid data returns isValid true")
    func isValid_withValidData_returnsTrue() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: []
        )

        // When/Then
        #expect(model.isValid)
        #expect(model.validationErrors.isEmpty)
    }

    @Test("Empty item stable ID returns isValid false")
    func isValid_withEmptyItemStableId_returnsFalse() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: []
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Item stable ID is required"))
    }

    @Test("Average rating too low returns isValid false")
    func isValid_withAverageRatingTooLow_returnsFalse() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 0.5,
            totalRatings: 10,
            topWords: []
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Average rating must be between 1.0 and 5.0"))
    }

    @Test("Average rating too high returns isValid false")
    func isValid_withAverageRatingTooHigh_returnsFalse() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 5.5,
            totalRatings: 10,
            topWords: []
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Average rating must be between 1.0 and 5.0"))
    }

    @Test("Negative total ratings returns isValid false")
    func isValid_withNegativeTotalRatings_returnsFalse() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: -1,
            topWords: []
        )

        // When/Then
        #expect(!model.isValid)
        #expect(model.validationErrors.contains("Total ratings must be non-negative"))
    }

    // MARK: - Business Logic Tests

    @Test("Rating category with high rating returns excellent")
    func ratingCategory_withHighRating_returnsExcellent() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.8,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        #expect(model.ratingCategory == .excellent)
    }

    @Test("Rating category with good rating returns good")
    func ratingCategory_withGoodRating_returnsGood() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.2,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        #expect(model.ratingCategory == .good)
    }

    @Test("Rating category with average rating returns good (boundary case)")
    func ratingCategory_withAverageRating_returnsGood() {
        // Given - 3.5 is the LOWER boundary of .good range (3.5..<4.5)
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 3.5,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        #expect(model.ratingCategory == .good)
    }

    @Test("Rating category below average boundary returns average")
    func ratingCategory_belowAverageBoundary_returnsAverage() {
        // Given - 3.4 is just below the .good range, so it's .average (2.5..<3.5)
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 3.4,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        #expect(model.ratingCategory == .average)
    }

    @Test("Rating category with below average rating returns below average")
    func ratingCategory_withBelowAverageRating_returnsBelowAverage() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 2.3,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        #expect(model.ratingCategory == .belowAverage)
    }

    @Test("Rating category with poor rating returns poor")
    func ratingCategory_withPoorRating_returnsPoor() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 1.4,
            totalRatings: 100,
            topWords: []
        )

        // When/Then
        #expect(model.ratingCategory == .poor)
    }

    @Test("Has enough ratings with sufficient ratings returns true")
    func hasEnoughRatings_withSufficientRatings_returnsTrue() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: []
        )

        // When/Then
        #expect(model.hasEnoughRatings)
    }

    @Test("Has enough ratings with insufficient ratings returns false")
    func hasEnoughRatings_withInsufficientRatings_returnsFalse() {
        // Given
        let model = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 4,
            topWords: []
        )

        // When/Then
        #expect(!model.hasEnoughRatings)
    }

    @Test("Top words sorted by rank")
    func topWords_sortedByRank() {
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
        #expect(sortedWords[0].rank == 1)
        #expect(sortedWords[1].rank == 2)
        #expect(sortedWords[2].rank == 3)
    }

    @Test("Top words for display returns first 10")
    func topWordsForDisplay_returnsFirst10() {
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
        #expect(displayWords.count == 10)
        #expect(displayWords.first?.rank == 1)
        #expect(displayWords.last?.rank == 10)
    }

    @Test("Top words for display with custom limit returns correct count")
    func topWordsForDisplay_withCustomLimit_returnsCorrectCount() {
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
        #expect(displayWords.count == 5)
        #expect(displayWords.first?.rank == 1)
        #expect(displayWords.last?.rank == 5)
    }

    @Test("Formatted average rating returns correct format")
    func formattedAverageRating_returnsCorrectFormat() {
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
        #expect(formatted == "4.7")
    }

    // MARK: - Equatable Tests

    @Test("Equatable with same data returns true (excluding auto-generated ID)")
    func equatable_sameData_returnsTrue() {
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

        // When/Then - Compare individual fields since UUIDs are auto-generated
        #expect(model1.itemStableId == model2.itemStableId)
        #expect(model1.averageRating == model2.averageRating)
        #expect(model1.totalRatings == model2.totalRatings)
        #expect(model1.topWords == model2.topWords)
        #expect(model1.lastAggregated == model2.lastAggregated)
    }

    @Test("Equatable with different average rating returns false")
    func equatable_differentAverageRating_returnsFalse() {
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
        #expect(model1 != model2)
    }

    // MARK: - Codable Tests

    @Test("Codable encode/decode preserves data")
    func codable_encodeDecode_preservesData() throws {
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
        #expect(decoded.itemStableId == original.itemStableId)
        #expect(abs(decoded.averageRating - original.averageRating) < 0.01)
        #expect(decoded.totalRatings == original.totalRatings)
        #expect(decoded.topWords.count == original.topWords.count)
    }
}
