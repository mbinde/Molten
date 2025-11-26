//
//  StorageLocationDefinitionRepository.swift
//  Molten
//
//  Repository protocol for storage location definitions
//  These are the canonical definitions of storage locations (e.g., "Shelf A", "Box 3")
//

import Foundation

/// Repository protocol for storage location definition persistence operations
/// StorageLocationDefinition is the source of truth for location names.
/// Renaming a definition updates the name everywhere it's used.
protocol StorageLocationDefinitionRepository: Sendable {

    // MARK: - Fetch Operations

    /// Fetch all location definitions (excluding soft-deleted)
    /// - Returns: Array of StorageLocationDefinitionModel instances, sorted by name
    func fetchAll() async throws -> [StorageLocationDefinitionModel]

    /// Fetch all location definitions including soft-deleted
    /// - Returns: Array of all StorageLocationDefinitionModel instances
    func fetchAllIncludingDeleted() async throws -> [StorageLocationDefinitionModel]

    /// Fetch a location definition by ID
    /// - Parameter id: The UUID of the definition
    /// - Returns: The definition if found, nil otherwise
    func fetch(byId id: UUID) async throws -> StorageLocationDefinitionModel?

    /// Fetch a location definition by name (case-insensitive)
    /// - Parameter name: The location name to search for
    /// - Returns: The definition if found, nil otherwise
    func fetch(byName name: String) async throws -> StorageLocationDefinitionModel?

    // MARK: - Create/Update Operations

    /// Create a new location definition
    /// - Parameter definition: The definition to create
    /// - Returns: The created definition
    func create(_ definition: StorageLocationDefinitionModel) async throws -> StorageLocationDefinitionModel

    /// Update an existing location definition
    /// - Parameter definition: The definition with updated values
    /// - Returns: The updated definition
    func update(_ definition: StorageLocationDefinitionModel) async throws -> StorageLocationDefinitionModel

    // MARK: - Delete Operations

    /// Soft-delete a location definition (sets deleted_at)
    /// - Parameter id: The UUID of the definition to delete
    func softDelete(id: UUID) async throws

    /// Permanently delete a location definition
    /// - Parameter id: The UUID of the definition to delete
    /// - Warning: This permanently removes the definition. Use softDelete for normal operations.
    func hardDelete(id: UUID) async throws

    /// Restore a soft-deleted location definition
    /// - Parameter id: The UUID of the definition to restore
    func restore(id: UUID) async throws

    // MARK: - Query Operations

    /// Get or create a location definition by name
    /// If a definition with the given name exists, returns it.
    /// Otherwise, creates a new definition with that name.
    /// - Parameter name: The location name
    /// - Returns: The existing or newly created definition
    func getOrCreate(name: String) async throws -> StorageLocationDefinitionModel

    /// Check if a location name already exists (case-insensitive)
    /// - Parameter name: The name to check
    /// - Returns: True if a definition with this name exists
    func nameExists(_ name: String) async throws -> Bool

    /// Get usage count for a location (how many StorageLocation records reference it)
    /// - Parameter id: The UUID of the definition
    /// - Returns: The number of StorageLocation records using this definition
    func getUsageCount(for id: UUID) async throws -> Int
}
