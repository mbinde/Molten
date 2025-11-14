//
//  CoreDataRatingRepositoryTests.swift
//  RepositoryTests
//
//  Integration tests for CoreDataRatingRepository
//  Tests actual Core Data persistence with isolated test contexts
//

import XCTest
import CoreData
@testable import Molten

final class CoreDataRatingRepositoryTests: XCTestCase {

    var persistenceController: PersistenceController!
    var repository: CoreDataRatingRepository!

    override func setUp() async throws {
        try await super.setUp()

        // Create isolated test controller
        persistenceController = PersistenceController.createTestController()

        // Create repository with test contexts
        repository = CoreDataRatingRepository(
            localContext: persistenceController.localContext,
            cloudContext: persistenceController.cloudContext
        )
    }

    override func tearDown() async throws {
        repository = nil
        persistenceController = nil
        try await super.tearDown()
    }

    // MARK: - Aggregated Ratings Tests

    func testSaveAndFetchAggregatedRating() async throws {
        // Given
        let rating = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: [
                RatingWordModel(word: "beautiful", frequency: 8, rank: 1),
                RatingWordModel(word: "vibrant", frequency: 6, rank: 2)
            ],
            lastAggregated: Date()
        )

        // When
        try await repository.saveAggregatedRating(rating)
        let fetched = try await repository.fetchAggregatedRating(forItem: "bullseye-001-0")

        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.itemStableId, "bullseye-001-0")
        XCTAssertEqual(fetched?.averageRating, 4.5)
        XCTAssertEqual(fetched?.totalRatings, 10)
        XCTAssertEqual(fetched?.topWords.count, 2)
        XCTAssertEqual(fetched?.topWords.first?.word, "beautiful")
    }

    func testFetchNonExistentRating() async throws {
        // When
        let rating = try await repository.fetchAggregatedRating(forItem: "nonexistent-item")

        // Then
        XCTAssertNil(rating)
    }

    func testBatchFetchAggregatedRatings() async throws {
        // Given
        let rating1 = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: [],
            lastAggregated: Date()
        )

        let rating2 = AggregatedRatingModel(
            itemStableId: "cim-412-0",
            averageRating: 3.8,
            totalRatings: 5,
            topWords: [],
            lastAggregated: Date()
        )

        try await repository.saveAggregatedRating(rating1)
        try await repository.saveAggregatedRating(rating2)

        // When
        let ratings = try await repository.fetchAggregatedRatings(
            forItems: ["bullseye-001-0", "cim-412-0", "nonexistent-0"]
        )

        // Then
        XCTAssertEqual(ratings.count, 2)
        XCTAssertNotNil(ratings["bullseye-001-0"])
        XCTAssertNotNil(ratings["cim-412-0"])
        XCTAssertNil(ratings["nonexistent-0"])
    }

    func testUpdateAggregatedRating() async throws {
        // Given - Save initial rating
        let initialRating = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.0,
            totalRatings: 5,
            topWords: [],
            lastAggregated: Date()
        )

        try await repository.saveAggregatedRating(initialRating)

        // When - Update with new data
        let updatedRating = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: [
                RatingWordModel(word: "excellent", frequency: 7, rank: 1)
            ],
            lastAggregated: Date()
        )

        try await repository.saveAggregatedRating(updatedRating)
        let fetched = try await repository.fetchAggregatedRating(forItem: "bullseye-001-0")

        // Then - Should have updated values
        XCTAssertEqual(fetched?.averageRating, 4.5)
        XCTAssertEqual(fetched?.totalRatings, 10)
        XCTAssertEqual(fetched?.topWords.count, 1)
    }

    func testDeleteAggregatedRating() async throws {
        // Given
        let rating = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: [],
            lastAggregated: Date()
        )

        try await repository.saveAggregatedRating(rating)

        // When
        try await repository.deleteAggregatedRating(forItem: "bullseye-001-0")
        let fetched = try await repository.fetchAggregatedRating(forItem: "bullseye-001-0")

        // Then
        XCTAssertNil(fetched)
    }

    func testClearAllRatings() async throws {
        // Given - Save multiple ratings
        let rating1 = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: [],
            lastAggregated: Date()
        )

        let rating2 = AggregatedRatingModel(
            itemStableId: "cim-412-0",
            averageRating: 3.8,
            totalRatings: 5,
            topWords: [],
            lastAggregated: Date()
        )

        try await repository.saveAggregatedRating(rating1)
        try await repository.saveAggregatedRating(rating2)

        // When
        try await repository.clearAllRatings()

        // Then
        let fetched1 = try await repository.fetchAggregatedRating(forItem: "bullseye-001-0")
        let fetched2 = try await repository.fetchAggregatedRating(forItem: "cim-412-0")

        XCTAssertNil(fetched1)
        XCTAssertNil(fetched2)
    }

    // MARK: - Rating Words Tests

    func testSaveAndFetchRatingWords() async throws {
        // Given
        let words = [
            RatingWordModel(word: "beautiful", frequency: 10, rank: 1),
            RatingWordModel(word: "vibrant", frequency: 8, rank: 2),
            RatingWordModel(word: "smooth", frequency: 6, rank: 3)
        ]

        // When
        try await repository.saveRatingWords(words, forItem: "bullseye-001-0")
        let fetched = try await repository.fetchRatingWords(forItem: "bullseye-001-0")

        // Then
        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(fetched[0].word, "beautiful")
        XCTAssertEqual(fetched[0].frequency, 10)
        XCTAssertEqual(fetched[1].word, "vibrant")
        XCTAssertEqual(fetched[2].word, "smooth")
    }

    func testFetchNonExistentWords() async throws {
        // When
        let words = try await repository.fetchRatingWords(forItem: "nonexistent-item")

        // Then
        XCTAssertTrue(words.isEmpty)
    }

    func testUpdateRatingWords() async throws {
        // Given - Initial words
        let initialWords = [
            RatingWordModel(word: "beautiful", frequency: 5, rank: 1)
        ]

        try await repository.saveRatingWords(initialWords, forItem: "bullseye-001-0")

        // When - Update with new words
        let updatedWords = [
            RatingWordModel(word: "excellent", frequency: 10, rank: 1),
            RatingWordModel(word: "stunning", frequency: 7, rank: 2)
        ]

        try await repository.saveRatingWords(updatedWords, forItem: "bullseye-001-0")
        let fetched = try await repository.fetchRatingWords(forItem: "bullseye-001-0")

        // Then - Should have new words only
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched[0].word, "excellent")
        XCTAssertEqual(fetched[1].word, "stunning")
    }

    func testDeleteRatingWords() async throws {
        // Given
        let words = [
            RatingWordModel(word: "beautiful", frequency: 10, rank: 1)
        ]

        try await repository.saveRatingWords(words, forItem: "bullseye-001-0")

        // When
        try await repository.deleteRatingWords(forItem: "bullseye-001-0")
        let fetched = try await repository.fetchRatingWords(forItem: "bullseye-001-0")

        // Then
        XCTAssertTrue(fetched.isEmpty)
    }

    // MARK: - Pending Submissions Tests

    func testAddAndFetchPendingSubmission() async throws {
        // Given
        let submission = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
        )

        // When
        try await repository.addPendingSubmission(submission)
        let pending = try await repository.fetchPendingSubmissions()

        // Then
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].itemStableId, "bullseye-001-0")
        XCTAssertEqual(pending[0].starRating, 5)
        XCTAssertEqual(pending[0].words.count, 5)
    }

    func testAddMultiplePendingSubmissions() async throws {
        // Given
        let submission1 = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["a", "b", "c", "d", "e"]
        )

        let submission2 = RatingSubmissionModel(
            itemStableId: "cim-412-0",
            starRating: 4,
            words: ["f", "g", "h", "i", "j"]
        )

        // When
        try await repository.addPendingSubmission(submission1)
        try await repository.addPendingSubmission(submission2)
        let pending = try await repository.fetchPendingSubmissions()

        // Then
        XCTAssertEqual(pending.count, 2)
    }

    func testRemovePendingSubmission() async throws {
        // Given
        let submission = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["a", "b", "c", "d", "e"]
        )

        try await repository.addPendingSubmission(submission)

        // When
        try await repository.removePendingSubmission(id: submission.id)
        let pending = try await repository.fetchPendingSubmissions()

        // Then
        XCTAssertTrue(pending.isEmpty)
    }

    func testUpdatePendingSubmissionAttempts() async throws {
        // Given
        let submission = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["a", "b", "c", "d", "e"]
        )

        try await repository.addPendingSubmission(submission)

        // When
        try await repository.updatePendingSubmissionAttempts(id: submission.id, attempts: 3)
        let pending = try await repository.fetchPendingSubmissions()

        // Then
        // Note: We can't directly verify attempts without exposing it in the model,
        // but we verify the operation doesn't throw
        XCTAssertEqual(pending.count, 1)
    }

    func testClearPendingSubmissions() async throws {
        // Given
        let submission1 = RatingSubmissionModel(
            itemStableId: "bullseye-001-0",
            starRating: 5,
            words: ["a", "b", "c", "d", "e"]
        )

        let submission2 = RatingSubmissionModel(
            itemStableId: "cim-412-0",
            starRating: 4,
            words: ["f", "g", "h", "i", "j"]
        )

        try await repository.addPendingSubmission(submission1)
        try await repository.addPendingSubmission(submission2)

        // When
        try await repository.clearPendingSubmissions()
        let pending = try await repository.fetchPendingSubmissions()

        // Then
        XCTAssertTrue(pending.isEmpty)
    }

    // MARK: - Staleness Check Tests

    func testIsRatingStale_NoRating() async throws {
        // When - No rating exists
        let isStale = try await repository.isRatingStale(
            forItem: "nonexistent-item",
            threshold: 3600
        )

        // Then - Should be stale
        XCTAssertTrue(isStale)
    }

    func testIsRatingStale_Fresh() async throws {
        // Given - Fresh rating (just saved)
        let rating = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: [],
            lastAggregated: Date()
        )

        try await repository.saveAggregatedRating(rating)

        // When - Check with 1 hour threshold
        let isStale = try await repository.isRatingStale(
            forItem: "bullseye-001-0",
            threshold: 3600
        )

        // Then - Should not be stale
        XCTAssertFalse(isStale)
    }

    func testIsRatingStale_Old() async throws {
        // Given - Old rating (2 hours ago)
        let twoHoursAgo = Date().addingTimeInterval(-7200)
        let rating = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: [],
            lastAggregated: twoHoursAgo
        )

        try await repository.saveAggregatedRating(rating)

        // When - Check with 1 hour threshold
        let isStale = try await repository.isRatingStale(
            forItem: "bullseye-001-0",
            threshold: 3600
        )

        // Then - Should be stale
        XCTAssertTrue(isStale)
    }

    // MARK: - Integration Tests (Combined Operations)

    func testSaveAggregatedRatingWithWords() async throws {
        // Given - Rating with words
        let words = [
            RatingWordModel(word: "beautiful", frequency: 10, rank: 1),
            RatingWordModel(word: "vibrant", frequency: 8, rank: 2)
        ]

        let rating = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: words,
            lastAggregated: Date()
        )

        // When
        try await repository.saveAggregatedRating(rating)

        // Then - Both rating and words should be saved
        let fetchedRating = try await repository.fetchAggregatedRating(forItem: "bullseye-001-0")
        let fetchedWords = try await repository.fetchRatingWords(forItem: "bullseye-001-0")

        XCTAssertNotNil(fetchedRating)
        XCTAssertEqual(fetchedWords.count, 2)
    }

    func testDeleteAggregatedRatingAlsoDeletesWords() async throws {
        // Given - Rating with words
        let words = [
            RatingWordModel(word: "beautiful", frequency: 10, rank: 1)
        ]

        let rating = AggregatedRatingModel(
            itemStableId: "bullseye-001-0",
            averageRating: 4.5,
            totalRatings: 10,
            topWords: words,
            lastAggregated: Date()
        )

        try await repository.saveAggregatedRating(rating)

        // When
        try await repository.deleteAggregatedRating(forItem: "bullseye-001-0")

        // Then - Both rating and words should be deleted
        let fetchedRating = try await repository.fetchAggregatedRating(forItem: "bullseye-001-0")
        let fetchedWords = try await repository.fetchRatingWords(forItem: "bullseye-001-0")

        XCTAssertNil(fetchedRating)
        XCTAssertTrue(fetchedWords.isEmpty)
    }
}
