//
//  ItemMinimumRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Repository protocol for ItemMinimum data persistence operations
/// Handles shopping list and low water mark functionality
nonisolated protocol ItemMinimumRepository {
    
    // MARK: - Basic CRUD Operations
    
    /// Fetch all item minimum records matching the given predicate
    /// - Parameter predicate: Optional predicate for filtering
    /// - Returns: Array of ItemMinimumModel instances
    func fetchMinimums(matching predicate: NSPredicate?) async throws -> [ItemMinimumModel]
    
    /// Fetch minimum record for a specific item and type
    /// - Parameters:
    ///   - itemNaturalKey: The natural key of the glass item
    ///   - type: The inventory type
    /// - Returns: ItemMinimumModel if found, nil otherwise
    func fetchMinimum(forItem itemNaturalKey: String, type: String) async throws -> ItemMinimumModel?
    
    /// Fetch all minimums for a specific item
    /// - Parameter itemNaturalKey: The natural key of the glass item
    /// - Returns: Array of ItemMinimumModel instances for the item
    func fetchMinimums(forItem itemNaturalKey: String) async throws -> [ItemMinimumModel]
    
    /// Fetch all minimums for a specific store
    /// - Parameter store: The store name
    /// - Returns: Array of ItemMinimumModel instances for the store
    func fetchMinimums(forStore store: String) async throws -> [ItemMinimumModel]
    
    /// Create a new item minimum record
    /// - Parameter minimum: The ItemMinimumModel to create
    /// - Returns: The created ItemMinimumModel
    func createMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel
    
    /// Create multiple minimum records in a batch operation
    /// - Parameter minimums: Array of ItemMinimumModel instances to create
    /// - Returns: Array of created ItemMinimumModel instances
    func createMinimums(_ minimums: [ItemMinimumModel]) async throws -> [ItemMinimumModel]
    
    /// Update an existing minimum record
    /// - Parameter minimum: The ItemMinimumModel with updated values
    /// - Returns: The updated ItemMinimumModel
    func updateMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel
    
    /// Delete a minimum record
    /// - Parameters:
    ///   - itemNaturalKey: The natural key of the glass item
    ///   - type: The inventory type
    func deleteMinimum(forItem itemNaturalKey: String, type: String) async throws
    
    /// Delete all minimums for a specific item
    /// - Parameter itemNaturalKey: The natural key of the glass item
    func deleteMinimums(forItem itemNaturalKey: String) async throws
    
    /// Delete all minimums for a specific store
    /// - Parameter store: The store name
    func deleteMinimums(forStore store: String) async throws
    
    // MARK: - Shopping List Operations
    
    /// Generate shopping list for a specific store
    /// - Parameters:
    ///   - store: The store name
    ///   - currentInventory: Dictionary mapping item+type to current quantities
    /// - Returns: Array of items that need to be purchased
    func generateShoppingList(forStore store: String, currentInventory: [String: [String: Double]]) async throws -> [ShoppingListItemModel]
    
    /// Generate shopping list for all stores
    /// - Parameter currentInventory: Dictionary mapping item+type to current quantities
    /// - Returns: Dictionary mapping store names to shopping list items
    func generateShoppingLists(currentInventory: [String: [String: Double]]) async throws -> [String: [ShoppingListItemModel]]
    
    /// Get items that are below their minimum threshold
    /// - Parameter currentInventory: Dictionary mapping item+type to current quantities
    /// - Returns: Array of low stock items with details
    func getLowStockItems(currentInventory: [String: [String: Double]]) async throws -> [LowStockItemModel]
    
    /// Set minimum quantity for an item and type
    /// - Parameters:
    ///   - quantity: The minimum quantity threshold
    ///   - itemNaturalKey: The natural key of the glass item
    ///   - type: The inventory type
    ///   - store: The preferred store for purchasing
    /// - Returns: The created or updated ItemMinimumModel
    func setMinimumQuantity(_ quantity: Double, forItem itemNaturalKey: String, type: String, store: String) async throws -> ItemMinimumModel
    
    // MARK: - Store Management Operations
    
    /// Get all distinct store names in the system (for autocomplete)
    /// - Returns: Sorted array of store name strings
    func getDistinctStores() async throws -> [String]
    
    /// Get store names that start with a specific prefix (for autocomplete)
    /// - Parameter prefix: The prefix to search for
    /// - Returns: Sorted array of matching store name strings
    func getStores(withPrefix prefix: String) async throws -> [String]
    
    /// Get store utilization (how many minimums reference each store)
    /// - Returns: Dictionary mapping store names to count of minimum records
    func getStoreUtilization() async throws -> [String: Int]
    
    /// Update store name across all minimum records
    /// - Parameters:
    ///   - oldStoreName: The current store name
    ///   - newStoreName: The new store name
    func updateStoreName(from oldStoreName: String, to newStoreName: String) async throws
    
    // MARK: - Analytics Operations
    
    /// Get minimum quantity statistics
    /// - Returns: Statistics about minimum quantities across all records
    func getMinimumQuantityStatistics() async throws -> MinimumQuantityStatistics
    
    /// Get items with highest minimum quantities
    /// - Parameter limit: Maximum number of items to return
    /// - Returns: Array of minimums sorted by quantity descending
    func getHighestMinimums(limit: Int) async throws -> [ItemMinimumModel]
    
    /// Get most common types in minimum records
    /// - Returns: Dictionary mapping inventory types to count of minimum records
    func getMostCommonTypes() async throws -> [String: Int]
    
    /// Validate minimum records against current inventory structure
    /// - Parameter validItemKeys: Set of valid item natural keys
    /// - Returns: Array of minimum records that reference invalid items
    func validateMinimumRecords(validItemKeys: Set<String>) async throws -> [ItemMinimumModel]
}

/// Domain model representing an item minimum (for shopping lists)
struct ItemMinimumModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let itemNaturalKey: String
    let quantity: Double
    let type: String
    let store: String

    nonisolated init(id: UUID = UUID(), itemNaturalKey: String, quantity: Double, type: String, store: String) {
        self.id = id
        self.itemNaturalKey = itemNaturalKey
        self.quantity = max(0.0, quantity) // Ensure non-negative quantity
        self.type = InventoryModel.cleanType(type) // Use inventory type cleaning
        self.store = ItemMinimumModel.cleanStoreName(store)
    }
}

/// Model representing a shopping list item with context
struct ShoppingListItemModel: Identifiable, Equatable, Sendable {
    let itemNaturalKey: String
    let type: String
    let currentQuantity: Double
    let minimumQuantity: Double
    let neededQuantity: Double
    let store: String
    let priority: ShoppingPriority

    nonisolated var id: String { "\(itemNaturalKey)-\(type)" }

    nonisolated init(itemNaturalKey: String, type: String, currentQuantity: Double, minimumQuantity: Double, store: String) {
        self.itemNaturalKey = itemNaturalKey
        self.type = type
        self.currentQuantity = currentQuantity
        self.minimumQuantity = minimumQuantity
        self.neededQuantity = max(0.0, minimumQuantity - currentQuantity)
        self.store = store

        // Determine priority based on how far below minimum we are
        let deficit = minimumQuantity - currentQuantity
        let deficitRatio = deficit / minimumQuantity

        if deficitRatio >= 0.8 {
            self.priority = .critical
        } else if deficitRatio >= 0.5 {
            self.priority = .high
        } else if deficitRatio >= 0.2 {
            self.priority = .medium
        } else {
            self.priority = .low
        }
    }
}

/// Shopping priority levels
enum ShoppingPriority: Int, CaseIterable, Sendable {
    case critical = 4
    case high = 3
    case medium = 2
    case low = 1

    nonisolated var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

/// Model representing a low stock item with context
struct LowStockItemModel: Identifiable, Equatable, Sendable {
    let itemNaturalKey: String
    let type: String
    let currentQuantity: Double
    let minimumQuantity: Double
    let shortfall: Double
    let store: String

    nonisolated var id: String { "\(itemNaturalKey)-\(type)" }

    nonisolated init(itemNaturalKey: String, type: String, currentQuantity: Double, minimumQuantity: Double, store: String) {
        self.itemNaturalKey = itemNaturalKey
        self.type = type
        self.currentQuantity = currentQuantity
        self.minimumQuantity = minimumQuantity
        self.shortfall = max(0.0, minimumQuantity - currentQuantity)
        self.store = store
    }
}

/// Statistics about minimum quantities across the system
struct MinimumQuantityStatistics: Sendable {
    let totalMinimumRecords: Int
    let averageMinimumQuantity: Double
    let highestMinimumQuantity: Double
    let lowestMinimumQuantity: Double
    let distinctStores: Int
    let distinctTypes: Int
    let distinctItems: Int

    nonisolated init(minimums: [ItemMinimumModel]) {
        self.totalMinimumRecords = minimums.count

        if minimums.isEmpty {
            self.averageMinimumQuantity = 0.0
            self.highestMinimumQuantity = 0.0
            self.lowestMinimumQuantity = 0.0
        } else {
            self.averageMinimumQuantity = minimums.reduce(0.0) { $0 + $1.quantity } / Double(minimums.count)
            self.highestMinimumQuantity = minimums.map { $0.quantity }.max() ?? 0.0
            self.lowestMinimumQuantity = minimums.map { $0.quantity }.min() ?? 0.0
        }

        self.distinctStores = Set(minimums.map { $0.store }).count
        self.distinctTypes = Set(minimums.map { $0.type }).count
        self.distinctItems = Set(minimums.map { $0.itemNaturalKey }).count
    }
}

// MARK: - ItemMinimumModel Extensions

extension ItemMinimumModel: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - ShoppingListItemModel Extensions

extension ShoppingListItemModel: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ShoppingListItemModel: Comparable {
    nonisolated static func < (lhs: ShoppingListItemModel, rhs: ShoppingListItemModel) -> Bool {
        if lhs.priority.rawValue != rhs.priority.rawValue {
            return lhs.priority.rawValue > rhs.priority.rawValue // Higher priority first
        }
        return lhs.neededQuantity > rhs.neededQuantity // Higher need first
    }
}

// MARK: - LowStockItemModel Extensions

extension LowStockItemModel: Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension LowStockItemModel: Comparable {
    nonisolated static func < (lhs: LowStockItemModel, rhs: LowStockItemModel) -> Bool {
        return lhs.shortfall > rhs.shortfall // Higher shortfall first
    }
}

// MARK: - Store Name Helper

extension ItemMinimumModel {
    /// Validates that a store name string is valid
    /// - Parameter store: The store name string to validate
    /// - Returns: True if valid, false otherwise
    nonisolated static func isValidStoreName(_ store: String) -> Bool {
        let trimmed = store.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 50
    }

    /// Cleans and normalizes a store name string
    /// - Parameter store: The raw store string
    /// - Returns: Cleaned store string suitable for storage
    nonisolated static func cleanStoreName(_ store: String) -> String {
        return store.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Common store names for glass supplies
    enum CommonStores {
        static let online = ["bullseye", "spectrum", "coe33", "oceanside", "armstrong"]
        static let local = ["local-shop", "art-store", "craft-store"]
        
        static let allCommonStores = online + local
    }
}