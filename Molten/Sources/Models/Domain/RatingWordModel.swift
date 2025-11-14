//
//  RatingWordModel.swift
//  Molten
//
//  Created by TDD for rating system on 11/13/25.
//

import Foundation

/// Business model for a rating word with its frequency and rank
struct RatingWordModel: Identifiable, Equatable, Codable, Sendable, Comparable {
    let id: UUID
    let word: String
    let frequency: Int
    let rank: Int

    /// Initialize with business logic validation
    nonisolated init(
        id: UUID = UUID(),
        word: String,
        frequency: Int,
        rank: Int
    ) {
        self.id = id
        self.word = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.frequency = frequency
        self.rank = rank
    }

    // MARK: - Validation

    /// Validate that the word has required data
    nonisolated var isValid: Bool {
        return validationErrors.isEmpty
    }

    /// Get validation errors if any
    nonisolated var validationErrors: [String] {
        var errors: [String] = []

        if word.isEmpty {
            errors.append("Word cannot be empty")
        }

        if frequency < 1 {
            errors.append("Frequency must be positive")
        }

        if rank < 1 {
            errors.append("Rank must be positive")
        }

        return errors
    }

    // MARK: - Comparable

    /// Compare by rank (lower rank is "less than")
    static func < (lhs: RatingWordModel, rhs: RatingWordModel) -> Bool {
        return lhs.rank < rhs.rank
    }
}

// MARK: - Helper Extensions

extension RatingWordModel {
    /// Create word model from a dictionary (useful for JSON parsing)
    static func from(dictionary: [String: Any]) -> RatingWordModel? {
        guard let word = dictionary["word"] as? String,
              let frequency = dictionary["frequency"] as? Int,
              let rank = dictionary["rank"] as? Int else {
            return nil
        }

        let id = (dictionary["id"] as? String).flatMap { UUID(uuidString: $0) } ?? UUID()

        return RatingWordModel(
            id: id,
            word: word,
            frequency: frequency,
            rank: rank
        )
    }

    /// Convert to dictionary (useful for storage or API calls)
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "word": word,
            "frequency": frequency,
            "rank": rank
        ]
    }
}
