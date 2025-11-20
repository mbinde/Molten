//
//  UserTagsRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Foundation

/// Owner type for user tags
enum TagOwnerType: String, CaseIterable, Codable, Sendable {
    case glassItem = "glassItem"
    case project = "project"
    case logbook = "logbook"
    case recipe = "recipe"

    var displayName: String {
        switch self {
        case .glassItem: return "Glass Item"
        case .project: return "Project"
        case .logbook: return "Logbook"
        case .recipe: return "Recipe"
        }
    }
}

/// Repository protocol for UserTags data persistence operations
/// Handles normalized many-to-many relationship between entities and user-created tags
///
/// ARCHITECTURE NOTE:
/// - Extends TagsRepository with multi-entity support (projects, logbooks, recipes, glass items)
/// - Backed by Core Data with CloudKit sync (read-write, user-created tags)
/// - User tags are personal organizational tags (e.g., "favorite", "current-project", "wishlist")
/// - For catalog tags (manufacturer metadata), see ItemTagsRepository (SQLite, read-only)
nonisolated protocol UserTagsRepository: TagsRepository {

    // MARK: - Generic Tag Operations (Multi-Entity Support)

    /// Fetch all user tags for a specific owner
    /// - Parameters:
    ///   - ownerType: Type of owner (glassItem, project, logbook, recipe)
    ///   - ownerId: ID of the owner (natural key for glass items, UUID string for projects/logbooks)
    /// - Returns: Array of tag strings for the owner
    func fetchTags(ownerType: TagOwnerType, ownerId: String) async throws -> [String]

    /// Batch fetch user tags for multiple owners (optimized for performance)
    /// - Parameters:
    ///   - ownerType: Type of owner
    ///   - ownerIds: Array of owner IDs to fetch tags for
    /// - Returns: Dictionary mapping owner ID to array of tags
    func fetchTagsForOwners(ownerType: TagOwnerType, ownerIds: [String]) async throws -> [String: [String]]

    /// Add a user tag to an owner
    /// - Parameters:
    ///   - tag: The tag string to add
    ///   - ownerType: Type of owner
    ///   - ownerId: ID of the owner
    func addTag(_ tag: String, ownerType: TagOwnerType, ownerId: String) async throws

    /// Add multiple user tags to an owner
    /// - Parameters:
    ///   - tags: Array of tag strings to add
    ///   - ownerType: Type of owner
    ///   - ownerId: ID of the owner
    func addTags(_ tags: [String], ownerType: TagOwnerType, ownerId: String) async throws

    /// Remove a specific user tag from an owner
    /// - Parameters:
    ///   - tag: The tag string to remove
    ///   - ownerType: Type of owner
    ///   - ownerId: ID of the owner
    func removeTag(_ tag: String, ownerType: TagOwnerType, ownerId: String) async throws

    /// Remove all user tags from an owner
    /// - Parameters:
    ///   - ownerType: Type of owner
    ///   - ownerId: ID of the owner
    func removeAllTags(ownerType: TagOwnerType, ownerId: String) async throws

    /// Replace all user tags for an owner with a new set of tags
    /// - Parameters:
    ///   - tags: Array of new tag strings
    ///   - ownerType: Type of owner
    ///   - ownerId: ID of the owner
    func setTags(_ tags: [String], ownerType: TagOwnerType, ownerId: String) async throws

    // MARK: - Extended Tag Discovery Operations

    /// Get all distinct user tags for a specific owner type
    /// - Parameter ownerType: Type of owner to filter by
    /// - Returns: Sorted array of unique tag strings for that owner type
    func getAllTags(forOwnerType ownerType: TagOwnerType) async throws -> [String]

    /// Get user tags that start with a specific prefix (for autocomplete)
    /// - Parameters:
    ///   - prefix: The prefix to search for
    ///   - ownerType: Optional owner type to filter by
    /// - Returns: Sorted array of matching tag strings
    func getTags(withPrefix prefix: String, ownerType: TagOwnerType?) async throws -> [String]

    /// Get the most frequently used user tags
    /// - Parameters:
    ///   - limit: Maximum number of tags to return
    ///   - ownerType: Optional owner type to filter by
    /// - Returns: Array of tag strings sorted by usage frequency (descending)
    func getMostUsedTags(limit: Int, ownerType: TagOwnerType?) async throws -> [String]

    // MARK: - Owner Discovery Operations

    /// Find owners that have a specific user tag
    /// - Parameters:
    ///   - tag: The tag string to search for
    ///   - ownerType: Type of owner to search
    /// - Returns: Array of owner IDs with this tag
    func fetchOwners(withTag tag: String, ownerType: TagOwnerType) async throws -> [String]

    /// Find owners that have all of the specified user tags
    /// - Parameters:
    ///   - tags: Array of tag strings that must all be present
    ///   - ownerType: Type of owner to search
    /// - Returns: Array of owner IDs with all specified tags
    func fetchOwners(withAllTags tags: [String], ownerType: TagOwnerType) async throws -> [String]

    /// Find owners that have any of the specified user tags
    /// - Parameters:
    ///   - tags: Array of tag strings, owners with any of these will be returned
    ///   - ownerType: Type of owner to search
    /// - Returns: Array of owner IDs with any of the specified tags
    func fetchOwners(withAnyTags tags: [String], ownerType: TagOwnerType) async throws -> [String]

    // MARK: - Extended Tag Analytics Operations

    /// Get count of owners for each user tag
    /// - Parameter ownerType: Optional owner type to filter by
    /// - Returns: Dictionary mapping tag strings to owner counts
    func getTagUsageCounts(ownerType: TagOwnerType?) async throws -> [String: Int]

    /// Get user tags with their usage counts, sorted by frequency
    /// - Parameters:
    ///   - minCount: Minimum usage count to include (default: 1)
    ///   - ownerType: Optional owner type to filter by
    /// - Returns: Array of tuples containing tag and count, sorted by count descending
    func getTagsWithCounts(minCount: Int, ownerType: TagOwnerType?) async throws -> [(tag: String, count: Int)]

    /// Check if a user tag exists in the system
    /// - Parameters:
    ///   - tag: The tag string to check
    ///   - ownerType: Optional owner type to filter by
    /// - Returns: True if the tag is used by at least one owner
    func tagExists(_ tag: String, ownerType: TagOwnerType?) async throws -> Bool

    // MARK: - Legacy Support (Glass Items - delegates to TagsRepository base)
    // Note: These methods delegate to generic owner-based API with ownerType = .glassItem

    /// Add a user tag to a glass item (legacy method)
    /// - Parameters:
    ///   - tag: The tag string to add
    ///   - item_stable_id: The natural key of the glass item
    func addTag(_ tag: String, toItem item_stable_id: String) async throws

    /// Add multiple user tags to a glass item (legacy method)
    /// - Parameters:
    ///   - tags: Array of tag strings to add
    ///   - item_stable_id: The natural key of the glass item
    func addTags(_ tags: [String], toItem item_stable_id: String) async throws

    /// Remove a specific user tag from a glass item (legacy method)
    /// - Parameters:
    ///   - tag: The tag string to remove
    ///   - item_stable_id: The natural key of the glass item
    func removeTag(_ tag: String, fromItem item_stable_id: String) async throws

    /// Remove all user tags from a glass item (legacy method)
    /// - Parameter item_stable_id: The natural key of the glass item
    func removeAllTags(fromItem item_stable_id: String) async throws

    /// Replace all user tags for a glass item with a new set of tags (legacy method)
    /// - Parameters:
    ///   - tags: Array of new tag strings
    ///   - item_stable_id: The natural key of the glass item
    func setTags(_ tags: [String], forItem item_stable_id: String) async throws
}

/// Domain model representing a user tag relationship
struct UserTagModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let ownerType: TagOwnerType
    let ownerId: String  // Natural key for glass items, UUID.uuidString for projects/logbooks
    let tag: String

    init(id: UUID = UUID(), ownerType: TagOwnerType, ownerId: String, tag: String) {
        self.id = id
        self.ownerType = ownerType
        self.ownerId = ownerId
        // Use shared cleaning logic from TagsRepository protocol
        self.tag = CoreDataUserTagsRepository.cleanTag(tag)
    }

    /// Legacy initializer for backward compatibility with glass items
    init(id: UUID = UUID(), item_stable_id: String, tag: String) {
        self.id = id
        self.ownerType = .glassItem
        self.ownerId = item_stable_id
        // Use shared cleaning logic from TagsRepository protocol
        self.tag = CoreDataUserTagsRepository.cleanTag(tag)
    }

    /// Legacy support - maps to ownerId for glass items
    var item_stable_id: String? {
        ownerType == .glassItem ? ownerId : nil
    }
}

// MARK: - UserTagModel Extensions

extension UserTagModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Common User Tags

extension UserTagModel {
    /// Common user tag suggestions for glass items (user-created organizational tags)
    enum CommonTags {
        static let status = ["favorite", "wishlist", "discontinued", "backup", "surplus"]
        static let usage = ["current-project", "test", "sample", "archived"]
        static let quality = ["premium", "standard", "economy", "experimental"]
        static let organization = ["shelf-a", "shelf-b", "storage", "workspace"]

        static let allCommonTags = status + usage + quality + organization
    }
}
