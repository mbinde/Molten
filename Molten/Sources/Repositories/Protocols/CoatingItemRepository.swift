//
//  CoatingItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/29/25.
//

import Foundation

/// Repository protocol for CoatingItem data persistence operations
/// Follows clean architecture: NO business logic, only data storage/retrieval
nonisolated protocol CoatingItemRepository: Sendable {

    // MARK: - Basic CRUD Operations

    /// Fetch all coating items matching the given predicate
    /// - Parameter predicate: Optional predicate for filtering
    /// - Returns: Array of CoatingItemModel instances
    func fetchItems(matching predicate: NSPredicate?) async throws -> [CoatingItemModel]

    /// Fetch a single coating item by its stable ID
    /// - Parameter stableId: The stable ID (6-character hash)
    /// - Returns: CoatingItemModel if found, nil otherwise
    func fetchItem(byStableId stableId: String) async throws -> CoatingItemModel?

    /// Create a new coating item
    /// - Parameter item: The CoatingItemModel to create
    /// - Returns: The created CoatingItemModel with any generated values
    func createItem(_ item: CoatingItemModel) async throws -> CoatingItemModel

    /// Create multiple coating items in a batch operation
    /// - Parameter items: Array of CoatingItemModel instances to create
    /// - Returns: Array of created CoatingItemModel instances
    func createItems(_ items: [CoatingItemModel]) async throws -> [CoatingItemModel]

    /// Update an existing coating item
    /// - Parameter item: The CoatingItemModel with updated values
    /// - Returns: The updated CoatingItemModel
    func updateItem(_ item: CoatingItemModel) async throws -> CoatingItemModel

    /// Delete a coating item by stable ID
    /// - Parameter stableId: The stable ID of the item to delete
    func deleteItem(stableId: String) async throws

    /// Delete multiple coating items by stable IDs
    /// - Parameter stableIds: Array of stable IDs to delete
    func deleteItems(stableIds: [String]) async throws

    // MARK: - Search & Filter Operations

    /// Search coating items by text (searches name, manufacturer, and notes)
    /// - Parameter text: Search text
    /// - Returns: Array of matching CoatingItemModel instances
    func searchItems(text: String) async throws -> [CoatingItemModel]

    /// Fetch coating items by manufacturer
    /// - Parameter manufacturer: Manufacturer identifier
    /// - Returns: Array of CoatingItemModel instances from the manufacturer
    func fetchItems(byManufacturer manufacturer: String) async throws -> [CoatingItemModel]

    /// Fetch coating items by manufacturer status
    /// - Parameter status: Manufacturer status (available, discontinued, etc.)
    /// - Returns: Array of CoatingItemModel instances with matching status
    func fetchItems(byStatus status: String) async throws -> [CoatingItemModel]

    // MARK: - Business Query Operations

    /// Get all distinct manufacturers in the system
    /// - Returns: Sorted array of manufacturer identifiers
    func getDistinctManufacturers() async throws -> [String]

    /// Get all distinct manufacturer statuses in the system
    /// - Returns: Sorted array of status values
    func getDistinctStatuses() async throws -> [String]

    /// Check if a stable ID already exists
    /// - Parameter stableId: The stable ID to check
    /// - Returns: True if the stable ID exists, false otherwise
    func stableIdExists(_ stableId: String) async throws -> Bool

    /// Generate the next available natural key for a manufacturer and SKU
    /// - Parameters:
    ///   - manufacturer: Manufacturer identifier
    ///   - sku: Manufacturer SKU
    /// - Returns: Next available natural key with appropriate sequence number
    func generateNextNaturalKey(manufacturer: String, sku: String?) async throws -> String
}

// Note: CoatingItemModel is defined in SharedModels.swift
