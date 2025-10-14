//
//  ItemMinimumRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Repository protocol for ItemMinimum data persistence operations
/// Handles shopping list and low water mark functionality
protocol ItemMinimumRepository {
    
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

/// Domain model representing an item minimum threshold
struct ItemMinimumModel {
    let itemNaturalKey: String
    let quantity: Double
    let type: String
    let store: String
    
    init(itemNaturalKey: String, quantity: Double, type: String, store: String) {
        self.itemNaturalKey = itemNaturalKey
        self.quantity = max(0.0, quantity) // Ensure non-negative quantity
        self.type = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.store = store.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Domain model for shopping list items
struct ShoppingListItemModel {
    let itemNaturalKey: String
    let type: String
    let currentQuantity: Double
    let minimumQuantity: Double
    let neededQuantity: Double
    let store: String
    
    init(minimum: ItemMinimumModel, currentQuantity: Double) {
        self.itemNaturalKey = minimum.itemNaturalKey
        self.type = minimum.type
        self.currentQuantity = currentQuantity
        self.minimumQuantity = minimum.quantity
        self.neededQuantity = max(0.0, minimum.quantity - currentQuantity)
        self.store = minimum.store
    }
}

/// Domain model for low stock items
struct LowStockItemModel {
    let itemNaturalKey: String
    let type: String
    let currentQuantity: Double
    let minimumQuantity: Double
    let shortfall: Double
    let store: String
    
    init(minimum: ItemMinimumModel, currentQuantity: Double) {
        self.itemNaturalKey = minimum.itemNaturalKey
        self.type = minimum.type
        self.currentQuantity = currentQuantity
        self.minimumQuantity = minimum.quantity
        self.shortfall = minimum.quantity - currentQuantity
        self.store = minimum.store
    }
}

/// Statistics about minimum quantities
struct MinimumQuantityStatistics {
    let totalMinimums: Int
    let averageQuantity: Double
    let minimumQuantity: Double
    let maximumQuantity: Double
    let distinctItems: Int
    let distinctTypes: Int
    let distinctStores: Int
    
    init(minimums: [ItemMinimumModel]) {
        self.totalMinimums = minimums.count
        
        if minimums.isEmpty {
            self.averageQuantity = 0.0
            self.minimumQuantity = 0.0
            self.maximumQuantity = 0.0
        } else {
            let quantities = minimums.map { $0.quantity }
            self.averageQuantity = quantities.reduce(0.0, +) / Double(quantities.count)
            self.minimumQuantity = quantities.min() ?? 0.0
            self.maximumQuantity = quantities.max() ?? 0.0
        }
        
        self.distinctItems = Set(minimums.map { $0.itemNaturalKey }).count
        self.distinctTypes = Set(minimums.map { $0.type }).count
        self.distinctStores = Set(minimums.map { $0.store }).count
    }
}

// MARK: - Model Extensions

extension ItemMinimumModel: Equatable {
    static func == (lhs: ItemMinimumModel, rhs: ItemMinimumModel) -> Bool {
        return lhs.itemNaturalKey == rhs.itemNaturalKey && lhs.type == rhs.type
    }
}

extension ItemMinimumModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(itemNaturalKey)
        hasher.combine(type)
    }
}

extension ItemMinimumModel: Identifiable {
    var id: String { "\(itemNaturalKey)-\(type)" }
}

extension ShoppingListItemModel: Identifiable {
    var id: String { "\(itemNaturalKey)-\(type)" }
}

extension LowStockItemModel: Identifiable {
    var id: String { "\(itemNaturalKey)-\(type)" }
}

// MARK: - Store and Type Helpers

extension ItemMinimumModel {
    /// Common store names
    enum CommonStore {
        static let frantz = "Frantz"
        static let bullseyeGlass = "Bullseye Glass"
        static let spectrumGlass = "Spectrum Glass"
        static let creationsMessy = "Creations In Messy"
        static let localSupplier = "Local Supplier"
        
        static let allCommonStores = [frantz, bullseyeGlass, spectrumGlass, creationsMessy, localSupplier]
    }
    
    /// Validates that a store name is valid
    /// - Parameter store: The store name to validate
    /// - Returns: True if valid, false otherwise
    static func isValidStore(_ store: String) -> Bool {
        let trimmed = store.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 100
    }
    
    /// Cleans and normalizes a store name
    /// - Parameter store: The raw store name
    /// - Returns: Cleaned store name suitable for storage
    static func cleanStore(_ store: String) -> String {
        return store.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Suggests store names based on partial input (for autocomplete)
    /// - Parameters:
    ///   - input: Partial store name input
    ///   - existingStores: Array of existing store names for suggestions
    /// - Returns: Array of suggested store names
    static func suggestStores(for input: String, from existingStores: [String]) -> [String] {
        let cleanInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty else { return Array(CommonStore.allCommonStores) }
        
        let matchingExisting = existingStores.filter { store in
            store.lowercased().contains(cleanInput)
        }
        
        let matchingCommon = CommonStore.allCommonStores.filter { store in
            store.lowercased().contains(cleanInput)
        }
        
        return Array(Set(matchingExisting + matchingCommon)).sorted()
    }
}