//
//  UserNotesModel.swift
//  Flameworker
//
//  Created by Repository Pattern Migration on 10/16/25.
//

import Foundation

/// Business model for user notes with validation and business logic
struct UserNotesModel: Identifiable, Equatable, Codable {
    let id: String
    let item_natural_key: String
    let notes: String

    /// Initialize with business logic validation
    nonisolated init(id: String = UUID().uuidString, item_natural_key: String, notes: String) {
        self.id = id
        self.item_natural_key = item_natural_key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Business Logic

    /// Check if notes match search text
    func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        return notes.lowercased().contains(lowercaseSearch) ||
               item_natural_key.lowercased().contains(lowercaseSearch)
    }

    /// Check if notes are empty after trimming
    var isEmpty: Bool {
        return notes.isEmpty
    }

    /// Get word count of notes
    var wordCount: Int {
        return notes.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    /// Get character count of notes
    var characterCount: Int {
        return notes.count
    }

    /// Compare notes for changes (useful for updates)
    static func hasChanges(existing: UserNotesModel, new: UserNotesModel) -> Bool {
        return existing.item_natural_key != new.item_natural_key ||
               existing.notes != new.notes
    }

    // MARK: - Validation

    /// Validate that the notes have required data
    nonisolated var isValid: Bool {
        return !item_natural_key.isEmpty && !notes.isEmpty
    }

    /// Get validation errors if any
    nonisolated var validationErrors: [String] {
        var errors: [String] = []

        if item_natural_key.isEmpty {
            errors.append("Item natural key is required")
        }

        if notes.isEmpty {
            errors.append("Notes cannot be empty")
        }

        return errors
    }
}

// MARK: - Helper Extensions

extension UserNotesModel {
    /// Create user notes from a dictionary (useful for JSON parsing)
    static func from(dictionary: [String: Any]) -> UserNotesModel? {
        guard let item_natural_key = dictionary["item_natural_key"] as? String,
              let notes = dictionary["notes"] as? String else {
            return nil
        }

        let id = dictionary["id"] as? String ?? UUID().uuidString

        return UserNotesModel(
            id: id,
            item_natural_key: item_natural_key,
            notes: notes
        )
    }

    /// Convert to dictionary (useful for storage or API calls)
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "item_natural_key": item_natural_key,
            "notes": notes
        ]
    }
}
