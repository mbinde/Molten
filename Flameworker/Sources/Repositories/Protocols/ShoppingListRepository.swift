//
//  ShoppingListRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Foundation

/// Repository protocol for shopping list data persistence operations
/// Handles shopping list items that track items to purchase
protocol ShoppingListRepository {

    // MARK: - Basic CRUD Operations

    /// Fetch all shopping list items
    /// - Returns: Array of ShoppingListItemModel instances
    func fetchAllItems() async throws -> [ShoppingListItemModel]

    /// Fetch shopping list items matching the given predicate
    /// - Parameter predicate: Optional predicate for filtering
    /// - Returns: Array of ShoppingListItemModel instances
    func fetchItems(matching predicate: NSPredicate?) async throws -> [ShoppingListItemModel]

    /// Fetch a single shopping list item by its ID
    /// - Parameter id: The UUID of the shopping list item
    /// - Returns: ShoppingListItemModel if found, nil otherwise
    func fetchItem(byId id: UUID) async throws -> ShoppingListItemModel?

    /// Fetch shopping list item for a specific glass item
    /// - Parameter item_natural_key: The natural key of the glass item
    /// - Returns: ShoppingListItemModel if found, nil otherwise
    func fetchItem(forItem item_natural_key: String) async throws -> ShoppingListItemModel?

    /// Fetch all shopping list items for a specific store
    /// - Parameter store: The store name
    /// - Returns: Array of ShoppingListItemModel instances for the store
    func fetchItems(forStore store: String) async throws -> [ShoppingListItemModel]

    /// Create a new shopping list item
    /// - Parameter item: The ShoppingListItemModel to create
    /// - Returns: The created ShoppingListItemModel
    func createItem(_ item: ShoppingListItemModel) async throws -> ShoppingListItemModel

    /// Update an existing shopping list item
    /// - Parameter item: The ShoppingListItemModel with updated values
    /// - Returns: The updated ShoppingListItemModel
    func updateItem(_ item: ShoppingListItemModel) async throws -> ShoppingListItemModel

    /// Delete a shopping list item by ID
    /// - Parameter id: The UUID of the shopping list item to delete
    func deleteItem(id: UUID) async throws

    /// Delete shopping list item for a specific glass item
    /// - Parameter item_natural_key: The natural key of the glass item
    func deleteItem(forItem item_natural_key: String) async throws

    /// Delete all shopping list items
    func deleteAllItems() async throws

    // MARK: - Quantity Operations

    /// Update quantity for a shopping list item
    /// - Parameters:
    ///   - quantity: New quantity value
    ///   - item_natural_key: The natural key of the glass item
    /// - Returns: The updated ShoppingListItemModel
    func updateQuantity(_ quantity: Double, forItem item_natural_key: String) async throws -> ShoppingListItemModel

    /// Add quantity to existing shopping list item or create new if doesn't exist
    /// - Parameters:
    ///   - quantity: Amount to add
    ///   - item_natural_key: The natural key of the glass item
    ///   - store: Optional store name
    /// - Returns: The updated or created ShoppingListItemModel
    func addQuantity(_ quantity: Double, toItem item_natural_key: String, store: String?) async throws -> ShoppingListItemModel

    // MARK: - Store Operations

    /// Update store for a shopping list item
    /// - Parameters:
    ///   - store: New store name (nil to remove)
    ///   - item_natural_key: The natural key of the glass item
    /// - Returns: The updated ShoppingListItemModel
    func updateStore(_ store: String?, forItem item_natural_key: String) async throws -> ShoppingListItemModel

    /// Get all distinct store names in shopping list
    /// - Returns: Sorted array of store names
    func getDistinctStores() async throws -> [String]

    /// Get count of items per store
    /// - Returns: Dictionary mapping store names to item counts
    func getItemCountByStore() async throws -> [String: Int]

    // MARK: - Discovery Operations

    /// Check if an item is in the shopping list
    /// - Parameter item_natural_key: The natural key of the glass item
    /// - Returns: True if item is in shopping list, false otherwise
    func isItemInList(_ item_natural_key: String) async throws -> Bool

    /// Get total number of items in shopping list
    /// - Returns: Count of shopping list items
    func getItemCount() async throws -> Int

    /// Get total number of items for a specific store
    /// - Parameter store: The store name
    /// - Returns: Count of shopping list items for the store
    func getItemCount(forStore store: String) async throws -> Int

    /// Get items sorted by date added
    /// - Parameter ascending: Sort order (true = oldest first, false = newest first)
    /// - Returns: Sorted array of ShoppingListItemModel instances
    func getItemsSortedByDate(ascending: Bool) async throws -> [ShoppingListItemModel]

    /// Get items sorted by quantity
    /// - Parameter ascending: Sort order (true = smallest first, false = largest first)
    /// - Returns: Sorted array of ShoppingListItemModel instances
    func getItemsSortedByQuantity(ascending: Bool) async throws -> [ShoppingListItemModel]

    // MARK: - Batch Operations

    /// Add multiple items to shopping list
    /// - Parameter items: Array of ShoppingListItemModel instances to create
    /// - Returns: Array of created ShoppingListItemModel instances
    func addItems(_ items: [ShoppingListItemModel]) async throws -> [ShoppingListItemModel]

    /// Delete multiple items by their IDs
    /// - Parameter ids: Array of UUIDs to delete
    func deleteItems(ids: [UUID]) async throws

    /// Delete all items for a specific store
    /// - Parameter store: The store name
    func deleteItems(forStore store: String) async throws
}

// MARK: - Helper Types

/// Summary model for shopping list statistics
struct ShoppingListSummary {
    let totalItems: Int
    let totalQuantity: Double
    let storeCount: Int
    let itemsByStore: [String: Int]
}
