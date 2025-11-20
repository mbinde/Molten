//
//  UserNotesModel.swift
//  Flameworker
//
//  Created by Repository Pattern Migration on 10/16/25.
//

import Foundation

/// Business model for user notes with validation and business logic
struct UserNotesModel: Identifiable, Equatable, Codable, Sendable {
    nonisolated let id: UUID
    nonisolated let item_stable_id: String
    nonisolated let notes: String

    /// Initialize with business logic validation
    nonisolated init(id: UUID = UUID(), item_stable_id: String, notes: String) {
        self.id = id
        self.item_stable_id = item_stable_id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Business Logic

    /// Check if notes match search text
    nonisolated func matchesSearchText(_ searchText: String) -> Bool {
        let lowercaseSearch = searchText.lowercased()
        return notes.lowercased().contains(lowercaseSearch) ||
               item_stable_id.contains(searchText)
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
        return existing.item_stable_id != new.item_stable_id ||
               existing.notes != new.notes
    }

    // MARK: - Validation

    /// Validate that the notes have required data
    nonisolated var isValid: Bool {
        return !item_stable_id.isEmpty && !notes.isEmpty
    }

    /// Get validation errors if any
    nonisolated var validationErrors: [String] {
        var errors: [String] = []

        if item_stable_id.isEmpty {
            errors.append("Item stable ID is required")
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
        guard let item_stable_id = dictionary["item_stable_id"] as? String,
              let notes = dictionary["notes"] as? String else {
            return nil
        }

        // Try to get UUID from dictionary, or generate new one
        let id: UUID
        if let uuidString = dictionary["id"] as? String, let uuid = UUID(uuidString: uuidString) {
            id = uuid
        } else {
            id = UUID()
        }

        return UserNotesModel(
            id: id,
            item_stable_id: item_stable_id,
            notes: notes
        )
    }

    /// Convert to dictionary (useful for storage or API calls)
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "item_stable_id": item_stable_id,
            "notes": notes
        ]
    }
}
