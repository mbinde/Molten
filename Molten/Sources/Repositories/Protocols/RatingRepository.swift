//
//  RatingRepository.swift
//  Molten
//
//  Repository protocol for rating data persistence operations
//  Stores aggregated rating data fetched from server
//

import Foundation

/// Repository protocol for rating data persistence operations
public nonisolated protocol RatingRepository: Sendable {

    // MARK: - Aggregated Ratings (Cached from Server)

    /// Fetch aggregated rating for a specific item
    /// - Parameter itemStableId: The stable ID of the item
    /// - Returns: Aggregated rating model, or nil if not found
    func fetchAggregatedRating(forItem itemStableId: String) async throws -> AggregatedRatingModel?

    /// Batch fetch aggregated ratings for multiple items
    /// - Parameter itemStableIds: Array of stable IDs to fetch ratings for
    /// - Returns: Dictionary mapping stable ID to aggregated rating
    func fetchAggregatedRatings(forItems itemStableIds: [String]) async throws -> [String: AggregatedRatingModel]

    /// Fetch ALL aggregated ratings from cache (for bulk operations)
    /// - Returns: Dictionary mapping stable ID to aggregated rating
    func fetchAllAggregatedRatings() async throws -> [String: AggregatedRatingModel]

    /// Save aggregated rating (from server) to local cache
    /// - Parameter rating: The aggregated rating to save
    func saveAggregatedRating(_ rating: AggregatedRatingModel) async throws

    /// Save multiple aggregated ratings (batch operation)
    /// - Parameter ratings: Array of aggregated ratings to save
    func saveAggregatedRatings(_ ratings: [AggregatedRatingModel]) async throws

    /// Delete aggregated rating from cache
    /// - Parameter itemStableId: The stable ID of the item
    func deleteAggregatedRating(forItem itemStableId: String) async throws

    /// Clear all cached ratings
    func clearAllRatings() async throws

    // MARK: - Rating Words (Cached from Server)

    /// Fetch rating words for a specific item
    /// - Parameter itemStableId: The stable ID of the item
    /// - Returns: Array of rating words, sorted by rank
    func fetchRatingWords(forItem itemStableId: String) async throws -> [RatingWordModel]

    /// Save rating words for a specific item
    /// - Parameters:
    ///   - words: Array of rating words
    ///   - itemStableId: The stable ID of the item
    func saveRatingWords(_ words: [RatingWordModel], forItem itemStableId: String) async throws

    /// Delete rating words for a specific item
    /// - Parameter itemStableId: The stable ID of the item
    func deleteRatingWords(forItem itemStableId: String) async throws

    // MARK: - Pending Submissions (Offline Queue)

    /// Fetch all pending rating submissions
    /// - Returns: Array of pending submissions, ordered by creation date
    func fetchPendingSubmissions() async throws -> [RatingSubmissionModel]

    /// Add a rating submission to the pending queue
    /// - Parameter submission: The rating submission to queue
    func addPendingSubmission(_ submission: RatingSubmissionModel) async throws

    /// Remove a pending submission from the queue (after successful upload)
    /// - Parameter submissionId: The ID of the submission to remove
    func removePendingSubmission(id submissionId: UUID) async throws

    /// Update attempt count for a pending submission
    /// - Parameters:
    ///   - submissionId: The ID of the submission
    ///   - attempts: The new attempt count
    func updatePendingSubmissionAttempts(id submissionId: UUID, attempts: Int) async throws

    /// Remove all pending submissions (e.g., after successful sync)
    func clearPendingSubmissions() async throws

    // MARK: - Staleness Check

    /// Check if rating data needs refresh from server
    /// - Parameters:
    ///   - itemStableId: The stable ID of the item
    ///   - threshold: Time interval after which data is considered stale
    /// - Returns: True if data should be refreshed
    func isRatingStale(forItem itemStableId: String, threshold: TimeInterval) async throws -> Bool
}
