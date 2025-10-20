//
//  CatalogItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import CoreData

/// Repository protocol for CatalogItem (child) entity operations
/// Updated for parent-child architecture while maintaining backward compatibility
protocol CatalogItemRepository {
    
    // MARK: - CRUD Operations
    
    /// Fetches catalog items matching the given predicate
    /// - Parameter predicate: Optional NSPredicate for filtering (nil = fetch all)
    /// - Returns: Array of CatalogItemModel instances
    /// - Throws: Repository errors for data access issues
    func fetchItems(matching predicate: NSPredicate?) async throws -> [CatalogItemModel]
    
    /// Creates a new catalog item in the repository
    /// - Parameter item: The CatalogItemModel to create
    /// - Returns: The created CatalogItemModel (may have updated ID/timestamps)
    /// - Throws: Repository errors for creation failures
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel
    
    /// Updates an existing catalog item
    /// - Parameter item: The CatalogItemModel with updated data
    /// - Returns: The updated CatalogItemModel
    /// - Throws: Repository errors for update failures or if item not found
    func updateItem(_ item: CatalogItemModel) async throws -> CatalogItemModel
    
    /// Deletes a catalog item by legacy ID (String)
    /// - Parameter id: The String ID of the item to delete
    /// - Throws: Repository errors for deletion failures or if item not found
    /// - Note: Maintains backward compatibility with existing String ID system
    func deleteItem(id: String) async throws
    
    /// Deletes a catalog item by new UUID (id2)
    /// - Parameter id2: The UUID of the item to delete  
    /// - Throws: Repository errors for deletion failures or if item not found
    /// - Note: New method for parent-child architecture
    func deleteItem(id2: UUID) async throws
    
    // MARK: - Query Operations
    
    /// Searches catalog items by text across searchable fields
    /// - Parameter text: Search text to match against item properties
    /// - Returns: Array of matching CatalogItemModel instances
    /// - Throws: Repository errors for search failures
    func searchItems(text: String) async throws -> [CatalogItemModel]
    
    /// Fetches a specific item by legacy ID (String)
    /// - Parameter id: The String ID of the item to fetch
    /// - Returns: The CatalogItemModel if found, nil otherwise
    /// - Throws: Repository errors for data access issues
    func fetchItem(id: String) async throws -> CatalogItemModel?
    
    /// Fetches a specific item by new UUID (id2)
    /// - Parameter id2: The UUID of the item to fetch
    /// - Returns: The CatalogItemModel if found, nil otherwise
    /// - Throws: Repository errors for data access issues
    func fetchItem(id2: UUID) async throws -> CatalogItemModel?
    
    /// Fetches all catalog items
    /// - Returns: Array of all CatalogItemModel instances
    /// - Throws: Repository errors for data access issues
    func getAllItems() async throws -> [CatalogItemModel]
    
    // MARK: - Parent-Child Relationship Operations
    
    /// Fetches all items belonging to a specific parent
    /// - Parameter parentId: The UUID of the parent
    /// - Returns: Array of CatalogItemModel instances belonging to the parent
    /// - Throws: Repository errors for data access issues
    func fetchItems(for parentId: UUID) async throws -> [CatalogItemModel]
    
    /// Creates a catalog item linked to a specific parent
    /// - Parameters:
    ///   - item: The CatalogItemModel to create
    ///   - parentId: The UUID of the parent to link to
    /// - Returns: The created CatalogItemModel with parent relationship established
    /// - Throws: Repository errors for creation failures
    func createItem(_ item: CatalogItemModel, parentId: UUID) async throws -> CatalogItemModel
    
    /// Updates the parent relationship for an existing item
    /// - Parameters:
    ///   - itemId2: The UUID (id2) of the item to update
    ///   - newParentId: The UUID of the new parent
    /// - Returns: The updated CatalogItemModel
    /// - Throws: Repository errors for update failures
    func updateItemParent(itemId2: UUID, newParentId: UUID) async throws -> CatalogItemModel
    
    // MARK: - Batch Operations
    
    /// Creates multiple catalog items in a single transaction
    /// - Parameter items: Array of CatalogItemModel instances to create
    /// - Returns: Array of created CatalogItemModel instances
    /// - Throws: Repository errors for batch creation failures
    func createItems(_ items: [CatalogItemModel]) async throws -> [CatalogItemModel]
    
    /// Updates multiple catalog items in a single transaction
    /// - Parameter items: Array of CatalogItemModel instances to update
    /// - Returns: Array of updated CatalogItemModel instances
    /// - Throws: Repository errors for batch update failures
    func updateItems(_ items: [CatalogItemModel]) async throws -> [CatalogItemModel]
    
    // MARK: - Legacy Support & Migration
    
    /// Checks if an existing item should be updated with new data
    /// - Parameters:
    ///   - existing: The existing CatalogItemModel
    ///   - new: The new CatalogItemModel with potential updates
    /// - Returns: True if the item should be updated, false otherwise
    /// - Throws: Repository errors for comparison failures
    func shouldUpdateItem(existing: CatalogItemModel, with new: CatalogItemModel) async throws -> Bool
    
    /// Migrates an item from legacy ID system to new UUID system
    /// - Parameter legacyId: The String ID of the item to migrate
    /// - Returns: The migrated CatalogItemModel with id2 populated
    /// - Throws: Repository errors for migration failures
    func migrateItemToUUID(legacyId: String) async throws -> CatalogItemModel
    
    /// Validates parent-child relationship integrity for an item
    /// - Parameter item: The CatalogItemModel to validate
    /// - Throws: Validation errors if relationships are inconsistent
    func validateItemRelationships(_ item: CatalogItemModel) async throws
}

/// Repository errors specific to CatalogItem operations
enum CatalogItemRepositoryError: Error, LocalizedError {
    case itemNotFound(String)
    case itemNotFoundByUUID(UUID)
    case invalidItemData(String)
    case parentNotFound(UUID)
    case relationshipValidationFailed(String)
    case migrationFailed(String)
    case batchOperationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound(let id):
            return "Item with ID \(id) not found"
        case .itemNotFoundByUUID(let id):
            return "Item with UUID \(id) not found"
        case .invalidItemData(let message):
            return "Invalid item data: \(message)"
        case .parentNotFound(let parentId):
            return "Parent with ID \(parentId) not found"
        case .relationshipValidationFailed(let message):
            return "Relationship validation failed: \(message)"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .batchOperationFailed(let message):
            return "Batch operation failed: \(message)"
        }
    }
}