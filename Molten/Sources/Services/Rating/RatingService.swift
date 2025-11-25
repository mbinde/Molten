//
//  RatingService.swift
//  Molten
//
//  Service for orchestrating rating operations (submit, fetch, delete, offline queue)
//

import Foundation

/// Protocol for rating service (for dependency injection)
public protocol RatingServiceProtocol {
    func submitRating(_ submission: RatingSubmissionModel) async throws
    func fetchRatings(forItems itemStableIds: [String], forceRefresh: Bool) async throws -> [AggregatedRatingModel]
    func deleteAllRatings() async throws -> Int
    func processPendingSubmissions() async throws -> Int
    func getPendingSubmissionCount() async throws -> Int
}

/// Service for managing ratings (submission, fetching, caching, offline queue)
@MainActor
public class RatingService: RatingServiceProtocol {

    // MARK: - Properties

    private let repository: RatingRepository
    private let apiClient: RatingAPIClientProtocol
    private let identityService: CloudKitIdentityServiceProtocol
    private let updateInterval: TimeInterval
    private let logger: LoggingService

    // MARK: - Initialization

    public init(
        repository: RatingRepository,
        apiClient: RatingAPIClientProtocol = RatingAPIClient(),
        identityService: CloudKitIdentityServiceProtocol = CloudKitIdentityService(),
        updateInterval: TimeInterval = 3600, // 1 hour default
        logger: LoggingService? = nil
    ) {
        self.repository = repository
        self.apiClient = apiClient
        self.identityService = identityService
        self.updateInterval = updateInterval
        self.logger = logger ?? AppDependencies.shared.loggingService
    }

    // MARK: - Submit Rating

    /// Submit a rating (online or queue if offline)
    public func submitRating(_ submission: RatingSubmissionModel) async throws {
        // Validate submission
        guard submission.isValid else {
            throw RatingServiceError.validationFailed(submission.validationErrors)
        }

        // Check for profanity
        guard !submission.containsProfanity else {
            throw RatingServiceError.profanityDetected
        }

        // Try to submit online
        do {
            try await submitRatingOnline(submission)
        } catch {
            // If offline or network error, queue for later
            if isNetworkError(error) {
                try await repository.addPendingSubmission(submission)
                throw RatingServiceError.queuedForLater
            } else {
                // Other errors (validation, rate limit, etc.) should propagate
                throw error
            }
        }
    }

    /// Submit rating to server (requires network)
    private func submitRatingOnline(_ submission: RatingSubmissionModel) async throws {
        // Get CloudKit user ID hash
        let userIdHash = try await identityService.getHashedUserID()

        // TODO: Get App Attest token (for now, use placeholder)
        let attestToken = "placeholder-token"

        // Submit to API
        try await apiClient.submitRating(submission, userIdHash: userIdHash, attestToken: attestToken)
    }

    // MARK: - Fetch Ratings

    /// Fetch all ratings in bulk and cache locally (optimized for catalog loading)
    public func fetchAllRatingsBulk(forceRefresh: Bool = false) async throws -> [AggregatedRatingModel] {
        // Check if we have a fresh bulk cache
        if !forceRefresh {
            let allCached = try await repository.fetchAllAggregatedRatings()

            // If we have cached data and it's fresh, return it
            if !allCached.isEmpty {
                // Check if any are stale (if at least one is fresh, use the cache)
                let hasAnythingFresh = allCached.values.contains { !$0.isStale(threshold: updateInterval) }
                if hasAnythingFresh {
                    return Array(allCached.values)
                }
            }
        }

        // Fetch all ratings from server in one request
        do {
            // IMPORTANT: Use cache busting when forceRefresh=true to bypass Cloudflare CDN cache
            let freshRatings = try await apiClient.fetchAllRatingsBulk(cacheBust: forceRefresh)

            // Save to cache
            try await repository.saveAggregatedRatings(freshRatings)

            return freshRatings
        } catch {
            // If network error and we have some cached data, return cached (even if stale)
            let allCached = try await repository.fetchAllAggregatedRatings()
            if isNetworkError(error) && !allCached.isEmpty {
                return Array(allCached.values)
            }
            throw error
        }
    }

    /// Fetch ratings for specific items (from cache or server)
    /// Note: For large batches, consider using fetchAllRatingsBulk() instead
    public func fetchRatings(
        forItems itemStableIds: [String],
        forceRefresh: Bool = false
    ) async throws -> [AggregatedRatingModel] {
        var ratings: [AggregatedRatingModel] = []

        // If not forcing refresh, try to get from cache first
        if !forceRefresh {
            let cached = try await repository.fetchAggregatedRatings(forItems: itemStableIds)

            // Filter out stale ratings
            for (itemId, rating) in cached {
                if !rating.isStale(threshold: updateInterval) {
                    ratings.append(rating)
                }
            }

            // If we got all ratings from cache and none are stale, return them
            if ratings.count == itemStableIds.count {
                return ratings
            }
        }

        // Fetch from server (for missing or stale items)
        do {
            let freshRatings = try await apiClient.fetchRatings(itemStableIds: itemStableIds)

            // Save to cache
            try await repository.saveAggregatedRatings(freshRatings)

            logger.info("Rating cache updated successfully", context: [
                "operation": "rating-cache-rebuild",
                "items_updated": freshRatings.count,
                "forced_refresh": forceRefresh
            ])

            return freshRatings
        } catch {
            // If network error and we have cached data, return cached (even if stale)
            if isNetworkError(error) && !ratings.isEmpty {
                logger.warning("Rating fetch failed, using stale cache", context: [
                    "operation": "rating-cache-rebuild",
                    "items_requested": itemStableIds.count,
                    "stale_items_returned": ratings.count
                ])
                return ratings
            }

            logger.error("Rating cache rebuild failed", context: [
                "operation": "rating-cache-rebuild",
                "items_requested": itemStableIds.count,
                "had_cached_data": !ratings.isEmpty,
                "error_type": String(describing: type(of: error))
            ], error: error)

            throw error
        }
    }

    // MARK: - Delete Ratings

    /// Delete all user's ratings
    public func deleteAllRatings() async throws -> Int {
        // Get CloudKit user ID hash
        let userIdHash = try await identityService.getHashedUserID()

        // TODO: Get App Attest token (for now, use placeholder)
        let attestToken = "placeholder-token"

        // Delete from server
        let deletedCount = try await apiClient.deleteAllRatings(userIdHash: userIdHash, attestToken: attestToken)

        // Clear local cache
        try await repository.clearAllRatings()

        return deletedCount
    }

    // MARK: - Offline Queue

    /// Process all pending submissions
    /// Returns count of successfully submitted ratings
    public func processPendingSubmissions() async throws -> Int {
        let pending = try await repository.fetchPendingSubmissions()
        var successCount = 0

        for submission in pending {
            do {
                // Try to submit
                try await submitRatingOnline(submission)

                // Success - remove from queue
                try await repository.removePendingSubmission(id: submission.id)
                successCount += 1

            } catch {
                // Update attempt count
                let attempts = (try? await repository.fetchPendingSubmissions())?
                    .first(where: { $0.id == submission.id })
                    .flatMap { _ in 1 } ?? 0

                try await repository.updatePendingSubmissionAttempts(id: submission.id, attempts: attempts + 1)

                // If max attempts reached, remove from queue
                if attempts >= 3 {
                    try await repository.removePendingSubmission(id: submission.id)
                }
            }
        }

        return successCount
    }

    /// Get count of pending submissions in queue
    public func getPendingSubmissionCount() async throws -> Int {
        let pending = try await repository.fetchPendingSubmissions()
        return pending.count
    }

    // MARK: - Helpers

    private func isNetworkError(_ error: Error) -> Bool {
        if let apiError = error as? RatingAPIError {
            switch apiError {
            case .networkError, .invalidResponse:
                return true
            default:
                return false
            }
        }

        // Check for URLSession network errors
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }
}

// MARK: - Service Errors

public enum RatingServiceError: Error, LocalizedError {
    case validationFailed([String])
    case profanityDetected
    case queuedForLater
    case identityUnavailable

    public var errorDescription: String? {
        switch self {
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .profanityDetected:
            return "One or more words contain profanity"
        case .queuedForLater:
            return "Rating queued for submission when online"
        case .identityUnavailable:
            return "Unable to retrieve user identity"
        }
    }
}
