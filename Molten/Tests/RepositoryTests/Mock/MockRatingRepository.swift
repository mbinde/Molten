//
//  MockRatingRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of RatingRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of RatingRepository for testing
/// Stores ratings in memory
final class MockRatingRepository: RatingRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var aggregatedRatings: [String: AggregatedRatingModel] = [:]
    nonisolated(unsafe) private var ratingWords: [String: [RatingWordModel]] = [:]
    nonisolated(unsafe) private var pendingSubmissions: [UUID: RatingSubmissionModel] = [:]
    nonisolated(unsafe) private var lastUpdated: [String: Date] = [:]

    // MARK: - Aggregated Ratings

    func fetchAggregatedRating(forItem itemStableId: String) async throws -> AggregatedRatingModel? {
        return aggregatedRatings[itemStableId]
    }

    func fetchAggregatedRatings(forItems itemStableIds: [String]) async throws -> [String: AggregatedRatingModel] {
        var result: [String: AggregatedRatingModel] = [:]
        for stableId in itemStableIds {
            if let rating = aggregatedRatings[stableId] {
                result[stableId] = rating
            }
        }
        return result
    }

    func fetchAllAggregatedRatings() async throws -> [String: AggregatedRatingModel] {
        return aggregatedRatings
    }

    func saveAggregatedRating(_ rating: AggregatedRatingModel) async throws {
        aggregatedRatings[rating.itemStableId] = rating
        lastUpdated[rating.itemStableId] = Date()
    }

    func saveAggregatedRatings(_ ratings: [AggregatedRatingModel]) async throws {
        for rating in ratings {
            aggregatedRatings[rating.itemStableId] = rating
            lastUpdated[rating.itemStableId] = Date()
        }
    }

    func deleteAggregatedRating(forItem itemStableId: String) async throws {
        aggregatedRatings.removeValue(forKey: itemStableId)
        lastUpdated.removeValue(forKey: itemStableId)
    }

    func clearAllRatings() async throws {
        aggregatedRatings.removeAll()
        ratingWords.removeAll()
        lastUpdated.removeAll()
    }

    // MARK: - Rating Words

    func fetchRatingWords(forItem itemStableId: String) async throws -> [RatingWordModel] {
        return ratingWords[itemStableId] ?? []
    }

    func saveRatingWords(_ words: [RatingWordModel], forItem itemStableId: String) async throws {
        ratingWords[itemStableId] = words
    }

    func deleteRatingWords(forItem itemStableId: String) async throws {
        ratingWords.removeValue(forKey: itemStableId)
    }

    // MARK: - Pending Submissions

    func fetchPendingSubmissions() async throws -> [RatingSubmissionModel] {
        return Array(pendingSubmissions.values).sorted { $0.createdAt < $1.createdAt }
    }

    func addPendingSubmission(_ submission: RatingSubmissionModel) async throws {
        pendingSubmissions[submission.id] = submission
    }

    func removePendingSubmission(id submissionId: UUID) async throws {
        pendingSubmissions.removeValue(forKey: submissionId)
    }

    func updatePendingSubmissionAttempts(id submissionId: UUID, attempts: Int) async throws {
        // Mock implementation - attempts tracking not needed for basic tests
        // In a real implementation, this would update Core Data entity's attempt count
    }

    func clearPendingSubmissions() async throws {
        pendingSubmissions.removeAll()
    }

    // MARK: - Staleness Check

    func isRatingStale(forItem itemStableId: String, threshold: TimeInterval) async throws -> Bool {
        guard let updated = lastUpdated[itemStableId] else {
            return true // No data = stale
        }
        return Date().timeIntervalSince(updated) > threshold
    }

    // MARK: - Test Helpers

    func clearAllData() {
        aggregatedRatings.removeAll()
        ratingWords.removeAll()
        pendingSubmissions.removeAll()
        lastUpdated.removeAll()
    }
}
