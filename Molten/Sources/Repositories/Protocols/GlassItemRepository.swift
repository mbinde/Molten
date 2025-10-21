//
//  GlassItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Repository protocol for GlassItem data persistence operations
/// Follows clean architecture: NO business logic, only data storage/retrieval
nonisolated protocol GlassItemRepository {
    
    // MARK: - Basic CRUD Operations
    
    /// Fetch all glass items matching the given predicate
    /// - Parameter predicate: Optional predicate for filtering
    /// - Returns: Array of GlassItemModel instances
    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel]
    
    /// Fetch a single glass item by its natural key
    /// - Parameter naturalKey: The natural key (format: manufacturer-sku-sequence)
    /// - Returns: GlassItemModel if found, nil otherwise
    func fetchItem(byNaturalKey naturalKey: String) async throws -> GlassItemModel?
    
    /// Create a new glass item
    /// - Parameter item: The GlassItemModel to create
    /// - Returns: The created GlassItemModel with any generated values
    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel
    
    /// Create multiple glass items in a batch operation
    /// - Parameter items: Array of GlassItemModel instances to create
    /// - Returns: Array of created GlassItemModel instances
    func createItems(_ items: [GlassItemModel]) async throws -> [GlassItemModel]
    
    /// Update an existing glass item
    /// - Parameter item: The GlassItemModel with updated values
    /// - Returns: The updated GlassItemModel
    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel
    
    /// Delete a glass item by natural key
    /// - Parameter naturalKey: The natural key of the item to delete
    func deleteItem(naturalKey: String) async throws
    
    /// Delete multiple glass items by natural keys
    /// - Parameter naturalKeys: Array of natural keys to delete
    func deleteItems(naturalKeys: [String]) async throws
    
    // MARK: - Search & Filter Operations
    
    /// Search glass items by text (searches name, manufacturer, and notes)
    /// - Parameter text: Search text
    /// - Returns: Array of matching GlassItemModel instances
    func searchItems(text: String) async throws -> [GlassItemModel]
    
    /// Fetch glass items by manufacturer
    /// - Parameter manufacturer: Manufacturer identifier
    /// - Returns: Array of GlassItemModel instances from the manufacturer
    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel]
    
    /// Fetch glass items by COE (coefficient of expansion)
    /// - Parameter coe: COE value
    /// - Returns: Array of GlassItemModel instances with matching COE
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel]
    
    /// Fetch glass items by manufacturer status
    /// - Parameter status: Manufacturer status (available, discontinued, etc.)
    /// - Returns: Array of GlassItemModel instances with matching status
    func fetchItems(byStatus status: String) async throws -> [GlassItemModel]
    
    // MARK: - Business Query Operations
    
    /// Get all distinct manufacturers in the system
    /// - Returns: Sorted array of manufacturer identifiers
    func getDistinctManufacturers() async throws -> [String]
    
    /// Get all distinct COE values in the system
    /// - Returns: Sorted array of COE values
    func getDistinctCOEValues() async throws -> [Int32]
    
    /// Get all distinct manufacturer statuses in the system
    /// - Returns: Sorted array of status values
    func getDistinctStatuses() async throws -> [String]
    
    /// Check if a natural key already exists
    /// - Parameter naturalKey: The natural key to check
    /// - Returns: True if the natural key exists, false otherwise
    func naturalKeyExists(_ naturalKey: String) async throws -> Bool
    
    /// Generate the next available natural key for a manufacturer and SKU
    /// - Parameters:
    ///   - manufacturer: Manufacturer identifier
    ///   - sku: Manufacturer SKU
    /// - Returns: Next available natural key with appropriate sequence number
    func generateNextNaturalKey(manufacturer: String, sku: String) async throws -> String
}

// Note: GlassItemModel is defined in SharedModels.swift