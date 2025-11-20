//
//  ItemTagsRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Repository protocol for ItemTags data persistence operations
/// Handles normalized many-to-many relationship between items and catalog tags
///
/// ARCHITECTURE NOTE:
/// - Extends TagsRepository with read-only catalog tag operations
/// - Backed by bundled SQLite database (read-only)
/// - Catalog tags are manufacturer-provided metadata (e.g., "red", "transparent", "opaque")
/// - For user-created tags, see UserTagsRepository (Core Data, CloudKit-synced)
nonisolated protocol ItemTagsRepository: TagsRepository {

    // MARK: - Write Operations (Catalog Management)
    // Note: These are typically no-ops in production (catalog is read-only)
    // Only used during development/testing for catalog updates

    /// Add a tag to an item
    /// - Parameters:
    ///   - tag: The tag string to add
    ///   - item_stable_id: The natural key of the glass item
    func addTag(_ tag: String, toItem item_stable_id: String) async throws

    /// Add multiple tags to an item
    /// - Parameters:
    ///   - tags: Array of tag strings to add
    ///   - item_stable_id: The natural key of the glass item
    func addTags(_ tags: [String], toItem item_stable_id: String) async throws

    /// Remove a specific tag from an item
    /// - Parameters:
    ///   - tag: The tag string to remove
    ///   - item_stable_id: The natural key of the glass item
    func removeTag(_ tag: String, fromItem item_stable_id: String) async throws

    /// Remove all tags from an item
    /// - Parameter item_stable_id: The natural key of the glass item
    func removeAllTags(fromItem item_stable_id: String) async throws

    /// Replace all tags for an item with a new set of tags
    /// - Parameters:
    ///   - tags: Array of new tag strings
    ///   - item_stable_id: The natural key of the glass item
    func setTags(_ tags: [String], forItem item_stable_id: String) async throws
}

/// Domain model representing an item tag relationship
struct ItemTagModel: Identifiable, Equatable {
    let id: UUID
    let item_stable_id: String
    let tag: String

    init(id: UUID = UUID(), item_stable_id: String, tag: String) {
        self.id = id
        self.item_stable_id = item_stable_id
        // Use shared cleaning logic from TagsRepository protocol
        self.tag = SQLiteItemTagsRepository.cleanTag(tag)
    }
}

// MARK: - ItemTagModel Extensions

extension ItemTagModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Common Catalog Tags

extension ItemTagModel {
    /// Common tag categories for glass items (catalog metadata)
    enum CommonTags {
        static let colors = ["red", "blue", "green", "yellow", "purple", "orange", "pink", "brown", "black", "white", "clear"]
        static let opacity = ["transparent", "opaque", "semi-opaque", "translucent"]
        static let finish = ["glossy", "matte", "textured", "smooth"]
        static let uses = ["fusing", "blowing", "casting", "lampwork", "mosaic", "sculpture"]
        static let properties = ["soft", "hard", "stiff", "flexible", "reactive", "stable"]

        static let allCommonTags = colors + opacity + finish + uses + properties
    }
}