//
//  CoreDataRatingRepositoryTests.swift
//  RepositoryTests
//
//  Integration tests for CoreDataRatingRepository
//  Tests actual Core Data persistence with isolated test contexts
//

import Testing
import CoreData
@testable import Molten

@Suite("CoreDataRatingRepository Tests")
@MainActor
struct CoreDataRatingRepositoryTests {

    let repository: CoreDataRatingRepository
    let persistenceController: PersistenceController

    init() throws {
        // Create isolated test controller
        persistenceController = PersistenceController.createTestController()

        // Verify test controller loaded successfully
        if let error = persistenceController.storeLoadingError {
            throw error
        }

        // Create repository with test contexts
        repository = CoreDataRatingRepository(
            localContext: persistenceController.localContext,
            cloudContext: persistenceController.cloudContext
        )
    }

    // MARK: - Aggregated Ratings Tests

    @Test("Save and fetch aggregated rating")
    func saveAndFetchAggregatedRating() async throws {
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
        #expect(fetched != nil)
        #expect(fetched?.itemStableId == "bullseye-001-0")
        #expect(fetched?.averageRating == 4.5)
        #expect(fetched?.totalRatings == 10)
        #expect(fetched?.topWords.count == 2)
        #expect(fetched?.topWords.first?.word == "beautiful")
    }

    @Test("Fetch non-existent rating returns nil")
    func fetchNonExistentRating() async throws {
        // When
        let rating = try await repository.fetchAggregatedRating(forItem: "nonexistent-item")

        // Then
        #expect(rating == nil)
    }

    @Test("Batch fetch aggregated ratings")
    func batchFetchAggregatedRatings() async throws {
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
        #expect(ratings.count == 2)
        #expect(ratings["bullseye-001-0"] != nil)
        #expect(ratings["cim-412-0"] != nil)
        #expect(ratings["nonexistent-0"] == nil)
    }

    @Test("Update aggregated rating replaces old data")
    func updateAggregatedRating() async throws {
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
        #expect(fetched?.averageRating == 4.5)
        #expect(fetched?.totalRatings == 10)
        #expect(fetched?.topWords.count == 1)
    }

    @Test("Delete aggregated rating")
    func deleteAggregatedRating() async throws {
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
        #expect(fetched == nil)
    }

    @Test("Clear all ratings")
    func clearAllRatings() async throws {
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

        #expect(fetched1 == nil)
        #expect(fetched2 == nil)
    }

    // MARK: - Rating Words Tests

    @Test("Save and fetch rating words")
    func saveAndFetchRatingWords() async throws {
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
        #expect(fetched.count == 3)
        #expect(fetched[0].word == "beautiful")
        #expect(fetched[0].frequency == 10)
        #expect(fetched[1].word == "vibrant")
        #expect(fetched[2].word == "smooth")
    }

    @Test("Fetch non-existent words returns empty")
    func fetchNonExistentWords() async throws {
        // When
        let words = try await repository.fetchRatingWords(forItem: "nonexistent-item")

        // Then
        #expect(words.isEmpty)
    }

    @Test("Update rating words replaces old list")
    func updateRatingWords() async throws {
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
        #expect(fetched.count == 2)
        #expect(fetched[0].word == "excellent")
        #expect(fetched[1].word == "stunning")
    }

    @Test("Delete rating words")
    func deleteRatingWords() async throws {
        // Given
        let words = [
            RatingWordModel(word: "beautiful", frequency: 10, rank: 1)
        ]

        try await repository.saveRatingWords(words, forItem: "bullseye-001-0")

        // When
        try await repository.deleteRatingWords(forItem: "bullseye-001-0")
        let fetched = try await repository.fetchRatingWords(forItem: "bullseye-001-0")

        // Then
        #expect(fetched.isEmpty)
    }

    // MARK: - Pending Submissions Tests

    @Test("Add and fetch pending submission")
    func addAndFetchPendingSubmission() async throws {
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
        #expect(pending.count == 1)
        #expect(pending[0].itemStableId == "bullseye-001-0")
        #expect(pending[0].starRating == 5)
        #expect(pending[0].words.count == 5)
    }

    @Test("Add multiple pending submissions")
    func addMultiplePendingSubmissions() async throws {
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
        #expect(pending.count == 2)
    }

    @Test("Remove pending submission")
    func removePendingSubmission() async throws {
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
        #expect(pending.isEmpty)
    }

    @Test("Update pending submission attempts")
    func updatePendingSubmissionAttempts() async throws {
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
        #expect(pending.count == 1)
    }

    @Test("Clear pending submissions")
    func clearPendingSubmissions() async throws {
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
        #expect(pending.isEmpty)
    }

    // MARK: - Staleness Check Tests

    @Test("Non-existent rating is stale")
    func isRatingStaleNoRating() async throws {
        // When - No rating exists
        let isStale = try await repository.isRatingStale(
            forItem: "nonexistent-item",
            threshold: 3600
        )

        // Then - Should be stale
        #expect(isStale == true)
    }

    @Test("Fresh rating is not stale")
    func isRatingFresh() async throws {
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
        #expect(isStale == false)
    }

    @Test("Old rating is stale")
    func isRatingOld() async throws {
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
        #expect(isStale == true)
    }

    // MARK: - Integration Tests (Combined Operations)

    @Test("Saving aggregated rating also saves words")
    func saveAggregatedRatingWithWords() async throws {
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

        #expect(fetchedRating != nil)
        #expect(fetchedWords.count == 2)
    }

    @Test("Deleting aggregated rating also deletes words")
    func deleteAggregatedRatingAlsoDeletesWords() async throws {
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

        #expect(fetchedRating == nil)
        #expect(fetchedWords.isEmpty)
    }
}
