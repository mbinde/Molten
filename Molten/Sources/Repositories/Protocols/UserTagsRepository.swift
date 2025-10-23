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

    var displayName: String {
        switch self {
        case .glassItem: return "Glass Item"
        case .project: return "Project"
        case .logbook: return "Logbook"
        }
    }
}

/// Repository protocol for UserTags data persistence operations
/// Handles normalized many-to-many relationship between entities and user-created tags
nonisolated protocol UserTagsRepository {

    // MARK: - Generic Tag Operations (Support all owner types)

    /// Fetch all user tags for a specific owner
    /// - Parameters:
    ///   - ownerType: Type of owner (glassItem, project, logbook)
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

    // MARK: - Tag Discovery Operations

    /// Get all distinct user tags in the system (across all owner types)
    /// - Returns: Sorted array of all unique tag strings
    func getAllTags() async throws -> [String]

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

    // MARK: - Tag Analytics Operations

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

    // MARK: - Legacy Support (for backward compatibility with glass items)

    /// Fetch all user tags for a glass item (legacy method)
    /// - Parameter itemNaturalKey: The natural key of the glass item
    /// - Returns: Array of tag strings for the item
    func fetchTags(forItem itemNaturalKey: String) async throws -> [String]

    /// Batch fetch user tags for multiple glass items (legacy method)
    /// - Parameter itemNaturalKeys: Array of natural keys to fetch tags for
    /// - Returns: Dictionary mapping natural key to array of tags
    func fetchTagsForItems(_ itemNaturalKeys: [String]) async throws -> [String: [String]]

    /// Add a user tag to a glass item (legacy method)
    /// - Parameters:
    ///   - tag: The tag string to add
    ///   - itemNaturalKey: The natural key of the glass item
    func addTag(_ tag: String, toItem itemNaturalKey: String) async throws

    /// Add multiple user tags to a glass item (legacy method)
    /// - Parameters:
    ///   - tags: Array of tag strings to add
    ///   - itemNaturalKey: The natural key of the glass item
    func addTags(_ tags: [String], toItem itemNaturalKey: String) async throws

    /// Remove a specific user tag from a glass item (legacy method)
    /// - Parameters:
    ///   - tag: The tag string to remove
    ///   - itemNaturalKey: The natural key of the glass item
    func removeTag(_ tag: String, fromItem itemNaturalKey: String) async throws

    /// Remove all user tags from a glass item (legacy method)
    /// - Parameter itemNaturalKey: The natural key of the glass item
    func removeAllTags(fromItem itemNaturalKey: String) async throws

    /// Replace all user tags for a glass item with a new set of tags (legacy method)
    /// - Parameters:
    ///   - tags: Array of new tag strings
    ///   - itemNaturalKey: The natural key of the glass item
    func setTags(_ tags: [String], forItem itemNaturalKey: String) async throws

    /// Find glass items that have a specific user tag (legacy method)
    /// - Parameter tag: The tag string to search for
    /// - Returns: Array of natural keys for items with this tag
    func fetchItems(withTag tag: String) async throws -> [String]

    /// Find glass items that have all of the specified user tags (legacy method)
    /// - Parameter tags: Array of tag strings that must all be present
    /// - Returns: Array of natural keys for items with all specified tags
    func fetchItems(withAllTags tags: [String]) async throws -> [String]

    /// Find glass items that have any of the specified user tags (legacy method)
    /// - Parameter tags: Array of tag strings, items with any of these will be returned
    /// - Returns: Array of natural keys for items with any of the specified tags
    func fetchItems(withAnyTags tags: [String]) async throws -> [String]
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
        self.tag = UserTagModel.cleanTag(tag)
    }

    /// Legacy initializer for backward compatibility with glass items
    init(id: UUID = UUID(), itemNaturalKey: String, tag: String) {
        self.id = id
        self.ownerType = .glassItem
        self.ownerId = itemNaturalKey
        self.tag = UserTagModel.cleanTag(tag)
    }

    /// Legacy support - maps to ownerId for glass items
    var itemNaturalKey: String? {
        ownerType == .glassItem ? ownerId : nil
    }
}

// MARK: - UserTagModel Extensions

extension UserTagModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Tag Validation and Cleaning Helper

extension UserTagModel {
    /// Validates that a tag string is valid
    /// - Parameter tag: The tag string to validate
    /// - Returns: True if valid, false otherwise
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
    nonisolated static func cleanTag(_ tag: String) -> String {
        return tag.trimmingCharacters(in: .whitespacesAndNewlines)
                  .lowercased()
                  .replacingOccurrences(of: " ", with: "-")
                  .replacingOccurrences(of: "_", with: "-")
                  .replacingOccurrences(of: "--", with: "-")
    }

    /// Common user tag suggestions for glass items
    enum CommonTags {
        static let status = ["favorite", "wishlist", "discontinued", "backup", "surplus"]
        static let usage = ["current-project", "test", "sample", "archived"]
        static let quality = ["premium", "standard", "economy", "experimental"]
        static let organization = ["shelf-a", "shelf-b", "storage", "workspace"]

        static let allCommonTags = status + usage + quality + organization
    }
}
