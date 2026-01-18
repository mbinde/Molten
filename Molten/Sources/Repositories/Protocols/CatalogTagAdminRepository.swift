//
//  CatalogTagAdminRepository.swift
//  Molten
//
//  Repository protocol for admin-created catalog tags
//

import Foundation

/// Repository for admin-created catalog tags
/// Used for catalog contributions that will be exported and incorporated into the bundled catalog
nonisolated protocol CatalogTagAdminRepository: Sendable {

    // MARK: - Single Item Operations

    /// Fetch all admin tags for a specific item (both additions and removals)
    func fetchTags(for item_stable_id: String) async throws -> [CatalogTagAdminModel]

    /// Fetch only tag additions for a specific item
    func fetchTagAdditions(for item_stable_id: String) async throws -> [CatalogTagAdminModel]

    /// Fetch only tag removals for a specific item
    func fetchTagRemovals(for item_stable_id: String) async throws -> [CatalogTagAdminModel]

    /// Add a tag to an item
    func addTag(_ tag: String, to item_stable_id: String) async throws

    /// Mark a bundled tag for removal from an item
    func markTagForRemoval(_ tag: String, from item_stable_id: String) async throws

    /// Remove a specific admin tag record by ID (undo an addition or removal)
    func removeAdminTag(_ tagId: UUID) async throws

    /// Remove an admin tag record by item and tag value
    func removeAdminTag(item_stable_id: String, tag: String) async throws

    // MARK: - Batch Operations

    /// Fetch tags for multiple items
    func fetchTags(for item_stable_ids: [String]) async throws -> [String: [CatalogTagAdminModel]]

    /// Fetch all admin tags (for export)
    func fetchAllTags() async throws -> [CatalogTagAdminModel]

    // MARK: - Discovery Operations

    /// Get all unique tag values that have been added
    func getAllTags() async throws -> [String]

    /// Get tag usage counts (how many items have each tag)
    func getTagUsageCounts() async throws -> [String: Int]

    /// Find all items that have a specific tag
    func findItems(withTag tag: String) async throws -> [String]
}
