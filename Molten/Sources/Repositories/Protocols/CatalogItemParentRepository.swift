//
//  CatalogItemParentRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//

import Foundation

/// Repository protocol for CatalogItemParent entity operations
/// Defines the interface for parent catalog item data persistence
nonisolated protocol CatalogItemParentRepository {
    
    // MARK: - CRUD Operations
    
    /// Fetches parent items matching the given predicate
    /// - Parameter predicate: Optional NSPredicate for filtering (nil = fetch all)
    /// - Returns: Array of CatalogItemParentModel instances
    /// - Throws: Repository errors for data access issues
    func fetchParents(matching predicate: NSPredicate?) async throws -> [CatalogItemParentModel]
    
    /// Creates a new parent item in the repository
    /// - Parameter parent: The CatalogItemParentModel to create
    /// - Returns: The created CatalogItemParentModel (may have updated ID/timestamps)
    /// - Throws: Repository errors for creation failures
    func createParent(_ parent: CatalogItemParentModel) async throws -> CatalogItemParentModel
    
    /// Updates an existing parent item
    /// - Parameter parent: The CatalogItemParentModel with updated data
    /// - Returns: The updated CatalogItemParentModel
    /// - Throws: Repository errors for update failures or if item not found
    func updateParent(_ parent: CatalogItemParentModel) async throws -> CatalogItemParentModel
    
    /// Deletes a parent item by ID
    /// - Parameter id: The UUID of the parent to delete
    /// - Throws: Repository errors for deletion failures or if item not found
    /// - Note: Should also handle cascading delete of child items
    func deleteParent(id: UUID) async throws
    
    // MARK: - Query Operations
    
    /// Searches parent items by text across searchable fields
    /// - Parameter text: Search text to match against parent properties
    /// - Returns: Array of matching CatalogItemParentModel instances
    /// - Throws: Repository errors for search failures
    func searchParents(text: String) async throws -> [CatalogItemParentModel]
    
    /// Fetches a specific parent by ID
    /// - Parameter id: The UUID of the parent to fetch
    /// - Returns: The CatalogItemParentModel if found, nil otherwise
    /// - Throws: Repository errors for data access issues
    func fetchParent(id: UUID) async throws -> CatalogItemParentModel?
    
    /// Fetches all parent items
    /// - Returns: Array of all CatalogItemParentModel instances
    /// - Throws: Repository errors for data access issues
    func getAllParents() async throws -> [CatalogItemParentModel]
    
    // MARK: - Relationship Operations
    
    /// Fetches all children for a specific parent
    /// - Parameter parentId: The UUID of the parent
    /// - Returns: Array of CatalogItemModel instances belonging to the parent
    /// - Throws: Repository errors for data access issues
    func fetchChildren(for parentId: UUID) async throws -> [CatalogItemModel]
    
    /// Checks if a parent exists with the given criteria
    /// - Parameters:
    ///   - baseName: The base name to search for
    ///   - manufacturer: The manufacturer to search for
    /// - Returns: The existing CatalogItemParentModel if found, nil otherwise
    /// - Throws: Repository errors for data access issues
    func findParent(baseName: String, manufacturer: String) async throws -> CatalogItemParentModel?
    
    // MARK: - Batch Operations
    
    /// Creates multiple parent items in a single transaction
    /// - Parameter parents: Array of CatalogItemParentModel instances to create
    /// - Returns: Array of created CatalogItemParentModel instances
    /// - Throws: Repository errors for batch creation failures
    func createParents(_ parents: [CatalogItemParentModel]) async throws -> [CatalogItemParentModel]
    
    /// Updates multiple parent items in a single transaction
    /// - Parameter parents: Array of CatalogItemParentModel instances to update
    /// - Returns: Array of updated CatalogItemParentModel instances
    /// - Throws: Repository errors for batch update failures
    func updateParents(_ parents: [CatalogItemParentModel]) async throws -> [CatalogItemParentModel]
}

/// Repository errors specific to CatalogItemParent operations
enum CatalogItemParentRepositoryError: Error, LocalizedError {
    case parentNotFound(UUID)
    case invalidParentData(String)
    case duplicateParent(String)
    case cascadeDeleteFailed(String)
    case batchOperationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .parentNotFound(let id):
            return "Parent with ID \(id) not found"
        case .invalidParentData(let message):
            return "Invalid parent data: \(message)"
        case .duplicateParent(let message):
            return "Duplicate parent: \(message)"
        case .cascadeDeleteFailed(let message):
            return "Failed to delete parent and children: \(message)"
        case .batchOperationFailed(let message):
            return "Batch operation failed: \(message)"
        }
    }
}