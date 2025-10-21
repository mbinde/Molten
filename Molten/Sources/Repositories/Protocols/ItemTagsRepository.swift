//
//  ItemTagsRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Repository protocol for ItemTags data persistence operations
/// Handles normalized many-to-many relationship between items and tags
nonisolated protocol ItemTagsRepository {
    
    // MARK: - Basic Tag Operations

    /// Fetch all tags for a specific item
    /// - Parameter itemNaturalKey: The natural key of the glass item
    /// - Returns: Array of tag strings for the item
    func fetchTags(forItem itemNaturalKey: String) async throws -> [String]

    /// Batch fetch tags for multiple items (optimized for performance)
    /// - Parameter itemNaturalKeys: Array of natural keys to fetch tags for
    /// - Returns: Dictionary mapping natural key to array of tags
    func fetchTagsForItems(_ itemNaturalKeys: [String]) async throws -> [String: [String]]
    
    /// Add a tag to an item
    /// - Parameters:
    ///   - tag: The tag string to add
    ///   - itemNaturalKey: The natural key of the glass item
    func addTag(_ tag: String, toItem itemNaturalKey: String) async throws
    
    /// Add multiple tags to an item
    /// - Parameters:
    ///   - tags: Array of tag strings to add
    ///   - itemNaturalKey: The natural key of the glass item
    func addTags(_ tags: [String], toItem itemNaturalKey: String) async throws
    
    /// Remove a specific tag from an item
    /// - Parameters:
    ///   - tag: The tag string to remove
    ///   - itemNaturalKey: The natural key of the glass item
    func removeTag(_ tag: String, fromItem itemNaturalKey: String) async throws
    
    /// Remove all tags from an item
    /// - Parameter itemNaturalKey: The natural key of the glass item
    func removeAllTags(fromItem itemNaturalKey: String) async throws
    
    /// Replace all tags for an item with a new set of tags
    /// - Parameters:
    ///   - tags: Array of new tag strings
    ///   - itemNaturalKey: The natural key of the glass item
    func setTags(_ tags: [String], forItem itemNaturalKey: String) async throws
    
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

/// Domain model representing an item tag relationship
struct ItemTagModel: Identifiable, Equatable {
    let id: UUID
    let itemNaturalKey: String
    let tag: String
    
    init(id: UUID = UUID(), itemNaturalKey: String, tag: String) {
        self.id = id
        self.itemNaturalKey = itemNaturalKey
        self.tag = ItemTagModel.cleanTag(tag)
    }
}

// MARK: - ItemTagModel Extensions

extension ItemTagModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Tag Validation and Cleaning Helper

extension ItemTagModel {
    /// Validates that a tag string is valid
    /// - Parameter tag: The tag string to validate
    /// - Returns: True if valid, false otherwise
    nonisolated static func isValidTag(_ tag: String) -> Bool {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty &&
               trimmed.count <= 30 &&
               trimmed.count >= 2 &&
               trimmed.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    /// Cleans and normalizes a tag string
    /// - Parameter tag: The raw tag string
    /// - Returns: Cleaned tag string suitable for storage
    nonisolated static func cleanTag(_ tag: String) -> String {
        return tag.trimmingCharacters(in: .whitespacesAndNewlines)
                  .lowercased()
                  .replacingOccurrences(of: " ", with: "-")
                  .replacingOccurrences(of: "_", with: "-")
                  .replacingOccurrences(of: "--", with: "-")
    }
    
    /// Common tag categories for glass items
    enum CommonTags {
        static let colors = ["red", "blue", "green", "yellow", "purple", "orange", "pink", "brown", "black", "white", "clear"]
        static let opacity = ["transparent", "opaque", "semi-opaque", "translucent"]
        static let finish = ["glossy", "matte", "textured", "smooth"]
        static let uses = ["fusing", "blowing", "casting", "lampwork", "mosaic", "sculpture"]
        static let properties = ["soft", "hard", "stiff", "flexible", "reactive", "stable"]
        
        static let allCommonTags = colors + opacity + finish + uses + properties
    }
}