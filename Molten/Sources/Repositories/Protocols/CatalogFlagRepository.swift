//
//  CatalogFlagRepository.swift
//  Molten
//
//  Created on 2025-12-21.
//
//  Repository protocols for catalog flags (admin and user)
//

import Foundation

// MARK: - Admin Flag Repository

/// Repository for admin-created catalog flags
/// Used for catalog contributions that will be exported and incorporated into the bundled catalog
nonisolated protocol CatalogFlagAdminRepository: Sendable {

    // MARK: - Single Item Operations

    /// Fetch all admin flags for a specific item (both additions and removals)
    func fetchFlags(for item_stable_id: String) async throws -> [CatalogFlagAdminModel]

    /// Fetch only flag additions for a specific item
    func fetchFlagAdditions(for item_stable_id: String) async throws -> [CatalogFlagAdminModel]

    /// Fetch only flag removals for a specific item
    func fetchFlagRemovals(for item_stable_id: String) async throws -> [CatalogFlagAdminModel]

    /// Add or update an admin flag
    /// If a flag with the same item_stable_id and flag_key exists, it will be updated
    func saveFlag(_ flag: CatalogFlagAdminModel) async throws

    /// Mark a bundled flag for removal from an item
    func markFlagForRemoval(item_stable_id: String, flag_key: String) async throws

    /// Remove a specific admin flag record by ID (undo an addition or removal)
    func removeAdminFlag(_ flagId: UUID) async throws

    /// Remove an admin flag record by item and key
    func removeAdminFlag(item_stable_id: String, flag_key: String) async throws

    // MARK: - Batch Operations

    /// Fetch flags for multiple items
    func fetchFlags(for item_stable_ids: [String]) async throws -> [String: [CatalogFlagAdminModel]]

    /// Fetch all admin flags (for export)
    func fetchAllFlags() async throws -> [CatalogFlagAdminModel]

    // MARK: - Discovery Operations

    /// Find all items that have a specific flag
    func findItems(withFlagKey flag_key: String) async throws -> [String]

    /// Find all items that have a specific flag with a specific value
    func findItems(withFlagKey flag_key: String, value: Bool) async throws -> [String]

    /// Delete all admin flags (for clearing CloudKit data to rely on bundled flags only)
    func deleteAllFlags() async throws -> Int
}

// MARK: - Bundled Flag Repository

/// Repository for bundled catalog flags (read-only)
/// These flags ship with the app in catalog.sqlite and cannot be modified by users
nonisolated protocol CatalogFlagBundledRepository: Sendable {

    // MARK: - Single Item Operations

    /// Fetch all bundled flags for a specific item
    func fetchFlags(for item_stable_id: String) async throws -> [CatalogFlagBundledModel]

    // MARK: - Batch Operations

    /// Fetch flags for multiple items
    func fetchFlags(for item_stable_ids: [String]) async throws -> [String: [CatalogFlagBundledModel]]

    /// Fetch all bundled flags
    func fetchAllFlags() async throws -> [CatalogFlagBundledModel]

    // MARK: - Discovery Operations

    /// Find all items that have a specific flag
    func findItems(withFlagKey flag_key: String) async throws -> [String]

    /// Get all available flag keys in the bundled data
    func getAllFlagKeys() async throws -> [String]

    /// Get flag counts by key
    func getFlagCounts() async throws -> [String: Int]
}

// MARK: - User Flag Repository

/// Repository for user-created catalog flags
/// Used for personal corrections and additions that sync across the user's devices
nonisolated protocol CatalogFlagUserRepository: Sendable {

    // MARK: - Single Item Operations

    /// Fetch all user flags for a specific item
    func fetchFlags(for item_stable_id: String) async throws -> [CatalogFlagUserModel]

    /// Add or update a user flag
    /// If a flag with the same item_stable_id and flag_key exists, it will be updated
    func saveFlag(_ flag: CatalogFlagUserModel) async throws

    /// Remove a specific flag by ID
    func removeFlag(_ flagId: UUID) async throws

    /// Remove a flag by item and key
    func removeFlag(item_stable_id: String, flag_key: String) async throws

    // MARK: - Batch Operations

    /// Fetch flags for multiple items
    func fetchFlags(for item_stable_ids: [String]) async throws -> [String: [CatalogFlagUserModel]]

    /// Fetch all user flags
    func fetchAllFlags() async throws -> [CatalogFlagUserModel]

    // MARK: - Discovery Operations

    /// Find all items that have a specific flag
    func findItems(withFlagKey flag_key: String) async throws -> [String]

    /// Find all items that have a specific flag with a specific value
    func findItems(withFlagKey flag_key: String, value: Bool) async throws -> [String]
}
