//
//  RatingWordModel.swift
//  Molten
//
//  Created by TDD for rating system on 11/13/25.
//

import Foundation

/// Business model for a rating word with its frequency and rank
public nonisolated struct RatingWordModel: Identifiable, Equatable, Codable, Sendable, Comparable {
    public let id: UUID
    public let word: String
    public let frequency: Int
    public let rank: Int

    // MARK: - Equatable

    /// Custom Equatable implementation that compares semantic data (excludes id)
    /// Two words are equal if they have the same data, regardless of ID
    public static func == (lhs: RatingWordModel, rhs: RatingWordModel) -> Bool {
        return lhs.word == rhs.word &&
               lhs.frequency == rhs.frequency &&
               lhs.rank == rhs.rank
    }

    /// Initialize with business logic validation
    public nonisolated init(
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

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case word
        case frequency
        case rank
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID() // Generate new ID on decode
        self.word = try container.decode(String.self, forKey: .word)
        self.frequency = try container.decode(Int.self, forKey: .frequency)
        self.rank = try container.decode(Int.self, forKey: .rank)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(word, forKey: .word)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(rank, forKey: .rank)
    }

    // MARK: - Validation

    /// Validate that the word has required data
    public nonisolated var isValid: Bool {
        return validationErrors.isEmpty
    }

    /// Get validation errors if any
    public nonisolated var validationErrors: [String] {
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
    public static func < (lhs: RatingWordModel, rhs: RatingWordModel) -> Bool {
        return lhs.rank < rhs.rank
    }
}

// MARK: - Helper Extensions

extension RatingWordModel {
    /// Create word model from a dictionary (useful for JSON parsing)
    public static func from(dictionary: [String: Any]) -> RatingWordModel? {
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
