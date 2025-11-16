//
//  AggregatedRatingModel.swift
//  Molten
//
//  Created by TDD for rating system on 11/13/25.
//

import Foundation

/// Business model for aggregated rating data from the server
public nonisolated struct AggregatedRatingModel: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let itemStableId: String
    public let averageRating: Double
    public let totalRatings: Int
    public let topWords: [RatingWordModel]
    public let lastAggregated: Date

    /// Initialize with business logic validation
    public nonisolated init(
        id: UUID = UUID(),
        itemStableId: String,
        averageRating: Double,
        totalRatings: Int,
        topWords: [RatingWordModel] = [],
        lastAggregated: Date = Date()
    ) {
        self.id = id
        self.itemStableId = itemStableId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.averageRating = averageRating
        self.totalRatings = totalRatings
        self.topWords = topWords.sorted() // Sort by rank
        self.lastAggregated = lastAggregated
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case itemStableId
        case averageRating
        case totalRatings
        case topWords
        case lastAggregated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID() // Generate new ID on decode
        self.itemStableId = try container.decode(String.self, forKey: .itemStableId)
        self.averageRating = try container.decode(Double.self, forKey: .averageRating)
        self.totalRatings = try container.decode(Int.self, forKey: .totalRatings)
        self.topWords = try container.decode([RatingWordModel].self, forKey: .topWords).sorted()
        self.lastAggregated = try container.decode(Date.self, forKey: .lastAggregated)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(itemStableId, forKey: .itemStableId)
        try container.encode(averageRating, forKey: .averageRating)
        try container.encode(totalRatings, forKey: .totalRatings)
        try container.encode(topWords, forKey: .topWords)
        try container.encode(lastAggregated, forKey: .lastAggregated)
    }

    // MARK: - Validation

    /// Validate that the aggregated rating has required data
    public nonisolated var isValid: Bool {
        return validationErrors.isEmpty
    }

    /// Get validation errors if any
    public nonisolated var validationErrors: [String] {
        var errors: [String] = []

        if itemStableId.isEmpty {
            errors.append("Item stable ID is required")
        }

        if averageRating < 1.0 || averageRating > 5.0 {
            errors.append("Average rating must be between 1.0 and 5.0")
        }

        if totalRatings < 0 {
            errors.append("Total ratings must be non-negative")
        }

        return errors
    }

    // MARK: - Business Logic

    /// Rating category based on average rating
    public var ratingCategory: RatingCategory {
        switch averageRating {
        case 4.5...5.0:
            return .excellent
        case 3.5..<4.5:
            return .good
        case 2.5..<3.5:
            return .average
        case 1.51..<2.5:  // Changed from 1.5 to 1.51 - rating 1.5 should be "poor"
            return .belowAverage
        default:
            return .poor
        }
    }

    /// Check if there are enough ratings to display
    /// (minimum 1 rating - show any ratings that exist)
    public var hasEnoughRatings: Bool {
        return totalRatings >= 1
    }

    /// Get top N words for display (default 10)
    public func topWordsForDisplay(limit: Int = 10) -> [RatingWordModel] {
        return Array(topWords.prefix(limit))
    }

    /// Formatted average rating (e.g., "4.7")
    public var formattedAverageRating: String {
        return String(format: "%.1f", averageRating)
    }

    /// Check if data is stale (older than specified interval)
    public nonisolated func isStale(threshold: TimeInterval) -> Bool {
        return Date().timeIntervalSince(lastAggregated) > threshold
    }
}

// MARK: - Rating Category

public enum RatingCategory: String, Codable, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case average = "Average"
    case belowAverage = "Below Average"
    case poor = "Poor"
}

// MARK: - Helper Extensions

extension AggregatedRatingModel {
    /// Create aggregated rating from a dictionary (useful for JSON parsing from server)
    public static func from(dictionary: [String: Any]) -> AggregatedRatingModel? {
        guard let itemStableId = dictionary["itemStableId"] as? String,
              let averageRating = dictionary["averageRating"] as? Double,
              let totalRatings = dictionary["totalRatings"] as? Int else {
            return nil
        }

        let id = (dictionary["id"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()
        let lastAggregated = (dictionary["lastAggregated"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) } ?? Date()

        var topWords: [RatingWordModel] = []
        if let wordsArray = dictionary["topWords"] as? [[String: Any]] {
            topWords = wordsArray.compactMap { RatingWordModel.from(dictionary: $0) }
        }

        return AggregatedRatingModel(
            id: id,
            itemStableId: itemStableId,
            averageRating: averageRating,
            totalRatings: totalRatings,
            topWords: topWords,
            lastAggregated: lastAggregated
        )
    }

    /// Convert to dictionary (useful for storage)
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "itemStableId": itemStableId,
            "averageRating": averageRating,
            "totalRatings": totalRatings,
            "topWords": topWords.map { $0.toDictionary() },
            "lastAggregated": lastAggregated.timeIntervalSince1970
        ]
    }
}
