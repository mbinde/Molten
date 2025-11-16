//
//  CoreDataRatingRepository.swift
//  Molten
//
//  Core Data implementation of RatingRepository
//  NOTE: Uses snake_case for Core Data attributes (e.g., item_stable_id, average_rating)
//

import Foundation
import CoreData

/// Core Data implementation of RatingRepository
public final class CoreDataRatingRepository: RatingRepository, @unchecked Sendable {

    // MARK: - Properties

    private let localContext: NSManagedObjectContext  // For cached ratings (Local Store)
    private let cloudContext: NSManagedObjectContext  // For pending submissions (Cloud Store)

    // MARK: - Initialization

    public init(localContext: NSManagedObjectContext, cloudContext: NSManagedObjectContext) {
        self.localContext = localContext
        self.cloudContext = cloudContext
    }

    // MARK: - Aggregated Ratings

    public func fetchAggregatedRating(forItem itemStableId: String) async throws -> AggregatedRatingModel? {
        return try await localContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ItemRating")
            request.predicate = NSPredicate(format: "item_stable_id == %@", itemStableId)
            request.fetchLimit = 1

            guard let entity = try self.localContext.fetch(request).first else {
                return nil
            }

            return self.aggregatedRatingFromEntity(entity, itemStableId: itemStableId)
        }
    }

    public func fetchAggregatedRatings(forItems itemStableIds: [String]) async throws -> [String: AggregatedRatingModel] {
        return try await localContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ItemRating")
            request.predicate = NSPredicate(format: "item_stable_id IN %@", itemStableIds)

            let entities = try self.localContext.fetch(request)
            var result: [String: AggregatedRatingModel] = [:]

            for entity in entities {
                if let itemStableId = entity.value(forKey: "item_stable_id") as? String,
                   let rating = self.aggregatedRatingFromEntity(entity, itemStableId: itemStableId) {
                    result[itemStableId] = rating
                }
            }

            return result
        }
    }

    public func fetchAllAggregatedRatings() async throws -> [String: AggregatedRatingModel] {
        return try await localContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ItemRating")

            let entities = try self.localContext.fetch(request)
            var result: [String: AggregatedRatingModel] = [:]

            for entity in entities {
                if let itemStableId = entity.value(forKey: "item_stable_id") as? String,
                   let rating = self.aggregatedRatingFromEntity(entity, itemStableId: itemStableId) {
                    result[itemStableId] = rating
                }
            }

            return result
        }
    }

    public func saveAggregatedRating(_ rating: AggregatedRatingModel) async throws {
        try await localContext.perform {
            // Delete existing rating
            let deleteRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemRating")
            deleteRequest.predicate = NSPredicate(format: "item_stable_id == %@", rating.itemStableId)
            if let existing = try? self.localContext.fetch(deleteRequest).first {
                self.localContext.delete(existing)
            }

            // Create new rating entity
            let entity = NSEntityDescription.insertNewObject(forEntityName: "ItemRating", into: self.localContext)
            entity.setValue(rating.itemStableId, forKey: "item_stable_id")
            entity.setValue(rating.averageRating, forKey: "average_rating")
            entity.setValue(rating.totalRatings, forKey: "total_ratings")
            entity.setValue(rating.lastAggregated, forKey: "last_updated")

            // Save words separately
            try self.saveRatingWordsSync(rating.topWords, forItem: rating.itemStableId)

            // Save context
            if self.localContext.hasChanges {
                try self.localContext.save()
            }
        }
    }

    public func saveAggregatedRatings(_ ratings: [AggregatedRatingModel]) async throws {
        for rating in ratings {
            try await saveAggregatedRating(rating)
        }
    }

    public func deleteAggregatedRating(forItem itemStableId: String) async throws {
        try await localContext.perform {
            // Delete rating
            let request = NSFetchRequest<NSManagedObject>(entityName: "ItemRating")
            request.predicate = NSPredicate(format: "item_stable_id == %@", itemStableId)

            let entities = try self.localContext.fetch(request)
            for entity in entities {
                self.localContext.delete(entity)
            }

            // Delete words
            try self.deleteRatingWordsSync(forItem: itemStableId)

            // Save context
            if self.localContext.hasChanges {
                try self.localContext.save()
            }
        }
    }

    public func clearAllRatings() async throws {
        try await localContext.perform {
            // Delete all ratings
            let ratingRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemRating")
            let ratings = try self.localContext.fetch(ratingRequest)
            for entity in ratings {
                self.localContext.delete(entity)
            }

            // Delete all words
            let wordRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemRatingWord")
            let words = try self.localContext.fetch(wordRequest)
            for entity in words {
                self.localContext.delete(entity)
            }

            // Save context
            if self.localContext.hasChanges {
                try self.localContext.save()
            }
        }
    }

    // MARK: - Rating Words

    public func fetchRatingWords(forItem itemStableId: String) async throws -> [RatingWordModel] {
        return try await localContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ItemRatingWord")
            request.predicate = NSPredicate(format: "item_stable_id == %@", itemStableId)
            request.sortDescriptors = [NSSortDescriptor(key: "rank", ascending: true)]

            let entities = try self.localContext.fetch(request)
            return entities.compactMap { self.ratingWordFromEntity($0) }
        }
    }

    public func saveRatingWords(_ words: [RatingWordModel], forItem itemStableId: String) async throws {
        try await localContext.perform {
            try self.saveRatingWordsSync(words, forItem: itemStableId)

            if self.localContext.hasChanges {
                try self.localContext.save()
            }
        }
    }

    private func saveRatingWordsSync(_ words: [RatingWordModel], forItem itemStableId: String) throws {
        // Delete existing words for this item
        try deleteRatingWordsSync(forItem: itemStableId)

        // Insert new words
        for word in words {
            let entity = NSEntityDescription.insertNewObject(forEntityName: "ItemRatingWord", into: self.localContext)
            entity.setValue(itemStableId, forKey: "item_stable_id")
            entity.setValue(word.word, forKey: "word")
            entity.setValue(word.frequency, forKey: "frequency")
            entity.setValue(word.rank, forKey: "rank")
        }
    }

    public func deleteRatingWords(forItem itemStableId: String) async throws {
        try await localContext.perform {
            try self.deleteRatingWordsSync(forItem: itemStableId)

            if self.localContext.hasChanges {
                try self.localContext.save()
            }
        }
    }

    private func deleteRatingWordsSync(forItem itemStableId: String) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ItemRatingWord")
        request.predicate = NSPredicate(format: "item_stable_id == %@", itemStableId)

        let entities = try self.localContext.fetch(request)
        for entity in entities {
            self.localContext.delete(entity)
        }
    }

    // MARK: - Pending Submissions

    public func fetchPendingSubmissions() async throws -> [RatingSubmissionModel] {
        return try await cloudContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "PendingRatingSubmission")
            request.sortDescriptors = [NSSortDescriptor(key: "created_at", ascending: true)]

            let entities = try self.cloudContext.fetch(request)
            return entities.compactMap { self.submissionFromEntity($0) }
        }
    }

    public func addPendingSubmission(_ submission: RatingSubmissionModel) async throws {
        try await cloudContext.perform {
            let entity = NSEntityDescription.insertNewObject(forEntityName: "PendingRatingSubmission", into: self.cloudContext)
            entity.setValue(submission.id, forKey: "id")
            entity.setValue(submission.itemStableId, forKey: "item_stable_id")
            entity.setValue(submission.starRating, forKey: "star_rating")
            entity.setValue(submission.word(at: 1), forKey: "word1")
            entity.setValue(submission.word(at: 2), forKey: "word2")
            entity.setValue(submission.word(at: 3), forKey: "word3")
            entity.setValue(submission.word(at: 4), forKey: "word4")
            entity.setValue(submission.word(at: 5), forKey: "word5")
            entity.setValue(submission.createdAt, forKey: "created_at")
            entity.setValue(0, forKey: "attempts")

            if self.cloudContext.hasChanges {
                try self.cloudContext.save()
            }
        }
    }

    public func removePendingSubmission(id submissionId: UUID) async throws {
        try await cloudContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "PendingRatingSubmission")
            request.predicate = NSPredicate(format: "id == %@", submissionId as CVarArg)

            if let entity = try self.cloudContext.fetch(request).first {
                self.cloudContext.delete(entity)

                if self.cloudContext.hasChanges {
                    try self.cloudContext.save()
                }
            }
        }
    }

    public func updatePendingSubmissionAttempts(id submissionId: UUID, attempts: Int) async throws {
        try await cloudContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "PendingRatingSubmission")
            request.predicate = NSPredicate(format: "id == %@", submissionId as CVarArg)

            if let entity = try self.cloudContext.fetch(request).first {
                entity.setValue(attempts, forKey: "attempts")

                if self.cloudContext.hasChanges {
                    try self.cloudContext.save()
                }
            }
        }
    }

    public func clearPendingSubmissions() async throws {
        try await cloudContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "PendingRatingSubmission")
            let entities = try self.cloudContext.fetch(request)

            for entity in entities {
                self.cloudContext.delete(entity)
            }

            if self.cloudContext.hasChanges {
                try self.cloudContext.save()
            }
        }
    }

    // MARK: - Staleness Check

    public func isRatingStale(forItem itemStableId: String, threshold: TimeInterval) async throws -> Bool {
        guard let rating = try await fetchAggregatedRating(forItem: itemStableId) else {
            return true // No rating = stale
        }

        return rating.isStale(threshold: threshold)
    }

    // MARK: - Helper Methods

    private func aggregatedRatingFromEntity(_ entity: NSManagedObject, itemStableId: String) -> AggregatedRatingModel? {
        guard let averageRating = entity.value(forKey: "average_rating") as? Double,
              let totalRatings = entity.value(forKey: "total_ratings") as? Int,
              let lastUpdated = entity.value(forKey: "last_updated") as? Date else {
            return nil
        }

        // Fetch words for this item
        let request = NSFetchRequest<NSManagedObject>(entityName: "ItemRatingWord")
        request.predicate = NSPredicate(format: "item_stable_id == %@", itemStableId)
        request.sortDescriptors = [NSSortDescriptor(key: "rank", ascending: true)]

        let words = (try? localContext.fetch(request))?.compactMap { ratingWordFromEntity($0) } ?? []

        return AggregatedRatingModel(
            itemStableId: itemStableId,
            averageRating: averageRating,
            totalRatings: totalRatings,
            topWords: words,
            lastAggregated: lastUpdated
        )
    }

    private func ratingWordFromEntity(_ entity: NSManagedObject) -> RatingWordModel? {
        guard let word = entity.value(forKey: "word") as? String,
              let frequency = entity.value(forKey: "frequency") as? Int,
              let rank = entity.value(forKey: "rank") as? Int else {
            return nil
        }

        return RatingWordModel(word: word, frequency: frequency, rank: rank)
    }

    private func submissionFromEntity(_ entity: NSManagedObject) -> RatingSubmissionModel? {
        guard let id = entity.value(forKey: "id") as? UUID,
              let itemStableId = entity.value(forKey: "item_stable_id") as? String,
              let starRating = entity.value(forKey: "star_rating") as? Int,
              let word1 = entity.value(forKey: "word1") as? String,
              let word2 = entity.value(forKey: "word2") as? String,
              let word3 = entity.value(forKey: "word3") as? String,
              let word4 = entity.value(forKey: "word4") as? String,
              let word5 = entity.value(forKey: "word5") as? String,
              let createdAt = entity.value(forKey: "created_at") as? Date else {
            return nil
        }

        return RatingSubmissionModel(
            id: id,
            itemStableId: itemStableId,
            starRating: starRating,
            words: [word1, word2, word3, word4, word5],
            createdAt: createdAt
        )
    }
}
