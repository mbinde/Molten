//
//  TagsRepository.swift
//  Molten
//
//  Base protocol for tag repositories (shared operations between ItemTags and UserTags)
//  Created on 2025-11-20.
//

import Foundation

/// Base repository protocol for tag data persistence operations
/// Provides common tag operations shared between ItemTags (catalog) and UserTags (user-created)
///
/// Architecture:
/// - ItemTagsRepository: Read-only catalog tags (SQLite, bundled with app)
/// - UserTagsRepository: Read-write user tags (Core Data, CloudKit-synced)
nonisolated protocol TagsRepository: Sendable {

    // MARK: - Basic Tag Operations (for glass items)

    /// Fetch all tags for a specific item
    /// - Parameter item_stable_id: The natural key of the glass item
    /// - Returns: Array of tag strings for the item
    func fetchTags(forItem item_stable_id: String) async throws -> [String]

    /// Batch fetch tags for multiple items (optimized for performance)
    /// - Parameter item_stable_ids: Array of natural keys to fetch tags for
    /// - Returns: Dictionary mapping natural key to array of tags
    func fetchTagsForItems(_ item_stable_ids: [String]) async throws -> [String: [String]]

    // MARK: - Tag Discovery Operations

    /// Get all distinct tags in the system
    /// - Returns: Sorted array of all unique tag strings
    func getAllTags() async throws -> [String]

    /// Get tags that start with a specific prefix (for autocomplete)
    /// - Parameter prefix: The prefix to search for
    /// - Returns: Sorted array of matching tag strings
    func getTags(withPrefix prefix: String) async throws -> [String]

    /// Get the most frequently used tags
    /// - Parameter limit: Maximum number of tags to return
    /// - Returns: Array of tag strings sorted by usage frequency (descending)
    func getMostUsedTags(limit: Int) async throws -> [String]

    // MARK: - Item Discovery Operations

    /// Find items that have a specific tag
    /// - Parameter tag: The tag string to search for
    /// - Returns: Array of natural keys for items with this tag
    func fetchItems(withTag tag: String) async throws -> [String]

    /// Find items that have all of the specified tags
    /// - Parameter tags: Array of tag strings that must all be present
    /// - Returns: Array of natural keys for items with all specified tags
    func fetchItems(withAllTags tags: [String]) async throws -> [String]

    /// Find items that have any of the specified tags
    /// - Parameter tags: Array of tag strings, items with any of these will be returned
    /// - Returns: Array of natural keys for items with any of the specified tags
    func fetchItems(withAnyTags tags: [String]) async throws -> [String]

    // MARK: - Tag Analytics Operations

    /// Get count of items for each tag
    /// - Returns: Dictionary mapping tag strings to item counts
    func getTagUsageCounts() async throws -> [String: Int]

    /// Get tags with their usage counts, sorted by frequency
    /// - Parameter minCount: Minimum usage count to include (default: 1)
    /// - Returns: Array of tuples containing tag and count, sorted by count descending
    func getTagsWithCounts(minCount: Int) async throws -> [(tag: String, count: Int)]

    /// Check if a tag exists in the system
    /// - Parameter tag: The tag string to check
    /// - Returns: True if the tag is used by at least one item
    func tagExists(_ tag: String) async throws -> Bool
}

// MARK: - Shared Tag Validation Logic

extension TagsRepository {
    /// Validates that a tag string is valid
    /// - Parameter tag: The tag string to validate
    /// - Returns: True if valid, false otherwise
    ///
    /// Business Rules:
    /// - Must be 2-30 characters long
    /// - Must contain only letters, numbers, hyphens, underscores, or spaces
    /// - Cannot be empty after trimming whitespace
    nonisolated static func isValidTag(_ tag: String) -> Bool {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty &&
               trimmed.count <= 30 &&
               trimmed.count >= 2 &&
               trimmed.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0.isWhitespace }
    }

    /// Cleans and normalizes a tag string
    /// - Parameter tag: The raw tag string
    /// - Returns: Cleaned tag string suitable for storage
    ///
    /// Business Rules:
    /// - Trims whitespace
    /// - Converts to lowercase
    /// - Replaces spaces and underscores with hyphens
    /// - Collapses multiple consecutive hyphens to single hyphen
    nonisolated static func cleanTag(_ tag: String) -> String {
        return tag.trimmingCharacters(in: .whitespacesAndNewlines)
                  .lowercased()
                  .replacingOccurrences(of: " ", with: "-")
                  .replacingOccurrences(of: "_", with: "-")
                  .replacingOccurrences(of: "--", with: "-")
    }
}
