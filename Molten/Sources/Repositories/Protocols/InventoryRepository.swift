//
//  InventoryRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Repository protocol for Inventory data persistence operations
/// Handles inventory quantity tracking by type for glass items
protocol InventoryRepository {
    
    // MARK: - Basic CRUD Operations
    
    /// Fetch all inventory records matching the given predicate
    /// - Parameter predicate: Optional predicate for filtering
    /// - Returns: Array of InventoryModel instances
    func fetchInventory(matching predicate: NSPredicate?) async throws -> [InventoryModel]
    
    /// Fetch a single inventory record by its ID
    /// - Parameter id: The UUID of the inventory record
    /// - Returns: InventoryModel if found, nil otherwise
    func fetchInventory(byId id: UUID) async throws -> InventoryModel?
    
    /// Fetch all inventory records for a specific item
    /// - Parameter item_natural_key: The natural key of the glass item
    /// - Returns: Array of InventoryModel instances for the item
    func fetchInventory(forItem item_natural_key: String) async throws -> [InventoryModel]
    
    /// Fetch inventory records for a specific item and type
    /// - Parameters:
    ///   - item_natural_key: The natural key of the glass item
    ///   - type: The inventory type (rod, frit, etc.)
    /// - Returns: Array of InventoryModel instances matching the criteria
    func fetchInventory(forItem item_natural_key: String, type: String) async throws -> [InventoryModel]
    
    /// Create a new inventory record
    /// - Parameter inventory: The InventoryModel to create
    /// - Returns: The created InventoryModel with generated ID
    func createInventory(_ inventory: InventoryModel) async throws -> InventoryModel
    
    /// Create multiple inventory records in a batch operation
    /// - Parameter inventories: Array of InventoryModel instances to create
    /// - Returns: Array of created InventoryModel instances with generated IDs
    func createInventories(_ inventories: [InventoryModel]) async throws -> [InventoryModel]
    
    /// Update an existing inventory record
    /// - Parameter inventory: The InventoryModel with updated values
    /// - Returns: The updated InventoryModel
    func updateInventory(_ inventory: InventoryModel) async throws -> InventoryModel
    
    /// Delete an inventory record by ID
    /// - Parameter id: The UUID of the inventory record to delete
    func deleteInventory(id: UUID) async throws
    
    /// Delete all inventory records for a specific item
    /// - Parameter item_natural_key: The natural key of the glass item
    func deleteInventory(forItem item_natural_key: String) async throws
    
    /// Delete inventory records for a specific item and type
    /// - Parameters:
    ///   - item_natural_key: The natural key of the glass item
    ///   - type: The inventory type to delete
    func deleteInventory(forItem item_natural_key: String, type: String) async throws
    
    // MARK: - Quantity Operations
    
    /// Get total quantity for an item across all inventory records
    /// - Parameter item_natural_key: The natural key of the glass item
    /// - Returns: Total quantity as Double
    func getTotalQuantity(forItem item_natural_key: String) async throws -> Double
    
    /// Get total quantity for an item of a specific type
    /// - Parameters:
    ///   - item_natural_key: The natural key of the glass item
    ///   - type: The inventory type
    /// - Returns: Total quantity as Double
    func getTotalQuantity(forItem item_natural_key: String, type: String) async throws -> Double
    
    /// Add quantity to existing inventory or create new record
    /// - Parameters:
    ///   - quantity: Amount to add
    ///   - item_natural_key: The natural key of the glass item
    ///   - type: The inventory type
    /// - Returns: The updated or created InventoryModel
    func addQuantity(_ quantity: Double, toItem item_natural_key: String, type: String) async throws -> InventoryModel
    
    /// Subtract quantity from existing inventory
    /// - Parameters:
    ///   - quantity: Amount to subtract
    ///   - item_natural_key: The natural key of the glass item
    ///   - type: The inventory type
    /// - Returns: The updated InventoryModel, or nil if record was deleted due to zero quantity
    func subtractQuantity(_ quantity: Double, fromItem item_natural_key: String, type: String) async throws -> InventoryModel?
    
    /// Set exact quantity for an item and type (creates or updates record)
    /// - Parameters:
    ///   - quantity: Exact quantity to set
    ///   - item_natural_key: The natural key of the glass item
    ///   - type: The inventory type
    /// - Returns: The updated or created InventoryModel, or nil if quantity is zero and record was deleted
    func setQuantity(_ quantity: Double, forItem item_natural_key: String, type: String) async throws -> InventoryModel?
    
    // MARK: - Discovery Operations
    
    /// Get all distinct inventory types in the system
    /// - Returns: Sorted array of inventory type strings
    func getDistinctTypes() async throws -> [String]
    
    /// Get all items that have inventory
    /// - Returns: Sorted array of natural keys for items with inventory
    func getItemsWithInventory() async throws -> [String]
    
    /// Get all items that have inventory of a specific type
    /// - Parameter type: The inventory type to search for
    /// - Returns: Sorted array of natural keys for items with inventory of this type
    func getItemsWithInventory(ofType type: String) async throws -> [String]
    
    /// Get all items with low inventory (quantity > 0 but < threshold)
    /// - Parameter threshold: The quantity threshold below which inventory is considered low
    /// - Returns: Array of tuples containing natural key, type, and current quantity
    func getItemsWithLowInventory(threshold: Double) async throws -> [(item_natural_key: String, type: String, quantity: Double)]
    
    /// Get all items with zero inventory
    /// - Returns: Array of natural keys for items that had inventory but now have zero
    func getItemsWithZeroInventory() async throws -> [String]
    
    // MARK: - Aggregation Operations
    
    /// Get inventory summary for all items
    /// - Returns: Array of inventory summary models
    func getInventorySummary() async throws -> [InventorySummaryModel]
    
    /// Get inventory summary for a specific item
    /// - Parameter item_natural_key: The natural key of the glass item
    /// - Returns: InventorySummaryModel for the item, or nil if no inventory exists
    func getInventorySummary(forItem item_natural_key: String) async throws -> InventorySummaryModel?
    
    /// Get total inventory value if prices were available
    /// - Parameter pricePerUnit: Default price per unit for calculation
    /// - Returns: Dictionary mapping item natural keys to total values
    func estimateInventoryValue(defaultPricePerUnit: Double) async throws -> [String: Double]
}

// Note: InventoryModel and InventorySummaryModel are defined in SharedModels.swift

// MARK: - Inventory Type Helper

extension InventoryModel {
    /// Common inventory types
    enum CommonType {
        static let rod = "rod"
        static let stringer = "stringer"
        static let frit = "frit"
        static let sheet = "sheet"
        static let tube = "tube"
        static let powder = "powder"
        static let scrap = "scrap"

        static let allCommonTypes = [rod, stringer, frit, sheet, tube, powder, scrap]
    }
    
    /// Validates that an inventory type string is valid
    /// - Parameter type: The inventory type string to validate
    /// - Returns: True if valid, false otherwise
    static func isValidType(_ type: String) -> Bool {
        let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 30
    }
}
