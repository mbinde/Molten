//
//  ToolItemRepository.swift
//  Molten
//
//  Repository protocol for ToolItem data persistence operations
//

import Foundation

/// Repository protocol for ToolItem data persistence operations
/// Follows clean architecture: NO business logic, only data storage/retrieval
nonisolated protocol ToolItemRepository: Sendable {

    // MARK: - Basic CRUD Operations

    /// Fetch all tool items matching the given predicate
    /// - Parameter predicate: Optional predicate for filtering
    /// - Returns: Array of ToolItemModel instances
    func fetchItems(matching predicate: NSPredicate?) async throws -> [ToolItemModel]

    /// Fetch a single tool item by its stable ID
    /// - Parameter stableId: The stable ID (6-character hash)
    /// - Returns: ToolItemModel if found, nil otherwise
    func fetchItem(byStableId stableId: String) async throws -> ToolItemModel?

    /// Create a new tool item
    /// - Parameter item: The ToolItemModel to create
    /// - Returns: The created ToolItemModel with any generated values
    func createItem(_ item: ToolItemModel) async throws -> ToolItemModel

    /// Create multiple tool items in a batch operation
    /// - Parameter items: Array of ToolItemModel instances to create
    /// - Returns: Array of created ToolItemModel instances
    func createItems(_ items: [ToolItemModel]) async throws -> [ToolItemModel]

    /// Update an existing tool item
    /// - Parameter item: The ToolItemModel with updated values
    /// - Returns: The updated ToolItemModel
    func updateItem(_ item: ToolItemModel) async throws -> ToolItemModel

    /// Delete a tool item by stable ID
    /// - Parameter stableId: The stable ID of the item to delete
    func deleteItem(stableId: String) async throws

    /// Delete multiple tool items by stable IDs
    /// - Parameter stableIds: Array of stable IDs to delete
    func deleteItems(stableIds: [String]) async throws

    // MARK: - Search & Filter Operations

    /// Search tool items by text (searches name, manufacturer, and notes)
    /// - Parameter text: Search text
    /// - Returns: Array of matching ToolItemModel instances
    func searchItems(text: String) async throws -> [ToolItemModel]

    /// Fetch tool items by manufacturer
    /// - Parameter manufacturer: Manufacturer identifier
    /// - Returns: Array of ToolItemModel instances from the manufacturer
    func fetchItems(byManufacturer manufacturer: String) async throws -> [ToolItemModel]

    /// Fetch tool items by manufacturer status
    /// - Parameter status: Manufacturer status (available, discontinued, etc.)
    /// - Returns: Array of ToolItemModel instances with matching status
    func fetchItems(byStatus status: String) async throws -> [ToolItemModel]

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

// Note: ToolItemModel is defined in SharedModels.swift
