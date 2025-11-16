//
//  RatingSubmissionModel.swift
//  Molten
//
//  Created by TDD for rating system on 11/13/25.
//

import Foundation

/// Business model for submitting a rating (star rating + descriptive words)
public nonisolated struct RatingSubmissionModel: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let itemStableId: String
    public let starRating: Int
    public let words: [String]
    public let createdAt: Date

    // MARK: - Equatable

    /// Custom Equatable implementation that compares semantic data (excludes id)
    /// Two submissions are equal if they have the same data, regardless of ID
    public static func == (lhs: RatingSubmissionModel, rhs: RatingSubmissionModel) -> Bool {
        return lhs.itemStableId == rhs.itemStableId &&
               lhs.starRating == rhs.starRating &&
               lhs.words == rhs.words &&
               lhs.createdAt == rhs.createdAt
    }

    /// Initialize with business logic validation
    public nonisolated init(
        id: UUID = UUID(),
        itemStableId: String,
        starRating: Int,
        words: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.itemStableId = itemStableId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.starRating = starRating
        self.words = words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        self.createdAt = createdAt
    }

    // MARK: - Validation

    /// Validate that the submission has required data
    public nonisolated var isValid: Bool {
        return validationErrors.isEmpty
    }

    /// Get validation errors if any
    public nonisolated var validationErrors: [String] {
        var errors: [String] = []

        if itemStableId.isEmpty {
            errors.append("Item stable ID is required")
        }

        if starRating < 1 || starRating > 5 {
            errors.append("Star rating must be between 1 and 5")
        }

        // Words are optional, any number from 0-5 is valid
        let nonEmptyWords = words.filter { !$0.isEmpty }
        if nonEmptyWords.count > 5 {
            errors.append("Maximum 5 words allowed")
        }

        if words.contains(where: { !$0.isEmpty && $0.count > 30 }) {
            errors.append("Words must be 30 characters or less")
        }

        // Check for duplicates only among non-empty words
        if Set(nonEmptyWords).count != nonEmptyWords.count {
            errors.append("Words must be unique")
        }

        return errors
    }

    // MARK: - Profanity Filter

    /// Check if any word contains profanity (client-side filtering)
    ///
    /// This provides first-line defense using a comprehensive word list.
    /// Server-side batch moderation with ML provides second-line defense.
    public nonisolated var containsProfanity: Bool {
        let nonEmptyWords = words.filter { !$0.isEmpty }
        return ProfanityList.containsProfanity(in: nonEmptyWords)
    }

    // MARK: - Business Logic

    /// Check if this is a positive rating (4-5 stars)
    var isPositive: Bool {
        return starRating >= 4
    }

    /// Check if this is a negative rating (1-2 stars)
    var isNegative: Bool {
        return starRating <= 2
    }

    /// Check if this is a neutral rating (3 stars)
    var isNeutral: Bool {
        return starRating == 3
    }

    /// Get word at specific position (1-5)
    nonisolated func word(at position: Int) -> String? {
        guard position >= 1 && position <= 5 else { return nil }
        let index = position - 1
        guard index < words.count else { return nil }
        return words[index]
    }
}

// MARK: - Helper Extensions

extension RatingSubmissionModel {
    /// Create submission from a dictionary (useful for JSON parsing)
    static func from(dictionary: [String: Any]) -> RatingSubmissionModel? {
        guard let itemStableId = dictionary["itemStableId"] as? String,
              let starRating = dictionary["starRating"] as? Int,
              let words = dictionary["words"] as? [String] else {
            return nil
        }

        let id = (dictionary["id"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()
        let createdAt = (dictionary["createdAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) } ?? Date()

        return RatingSubmissionModel(
            id: id,
            itemStableId: itemStableId,
            starRating: starRating,
            words: words,
            createdAt: createdAt
        )
    }

    /// Convert to dictionary (useful for API calls)
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "itemStableId": itemStableId,
            "starRating": starRating,
            "words": words,
            "createdAt": createdAt.timeIntervalSince1970
        ]
    }
}
