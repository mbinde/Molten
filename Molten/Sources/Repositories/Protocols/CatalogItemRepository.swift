//
//  CatalogItemRepository.swift
//  Molten
//
//  Generic repository protocol for catalog items (glass, coatings, tools)
//  Uses associated types to provide type-safe, DRY repository interface
//

import Foundation

/// Generic repository protocol for all catalog item types
/// Eliminates duplication by using associated types - one protocol, multiple implementations
nonisolated protocol CatalogItemRepository: Sendable {
    associatedtype ItemType: CatalogItem

    // MARK: - Basic CRUD Operations

    /// Fetch all items matching the given predicate
    /// - Parameter predicate: Optional predicate for filtering
    /// - Returns: Array of ItemType instances
    func fetchItems(matching predicate: NSPredicate?) async throws -> [ItemType]

    /// Fetch a single item by its stable ID
    /// - Parameter stableId: The stable ID (6-character hash)
    /// - Returns: ItemType if found, nil otherwise
    func fetchItem(byStableId stableId: String) async throws -> ItemType?

    /// Create a new item
    /// - Parameter item: The ItemType to create
    /// - Returns: The created ItemType with any generated values
    func createItem(_ item: ItemType) async throws -> ItemType

    /// Create multiple items in a batch operation
    /// - Parameter items: Array of ItemType instances to create
    /// - Returns: Array of created ItemType instances
    func createItems(_ items: [ItemType]) async throws -> [ItemType]

    /// Update an existing item
    /// - Parameter item: The ItemType with updated values
    /// - Returns: The updated ItemType
    func updateItem(_ item: ItemType) async throws -> ItemType

    /// Delete an item by stable ID
    /// - Parameter stableId: The stable ID of the item to delete
    func deleteItem(stableId: String) async throws

    /// Delete multiple items by stable IDs
    /// - Parameter stableIds: Array of stable IDs to delete
    func deleteItems(stableIds: [String]) async throws

    // MARK: - Search & Filter Operations

    /// Search items by text (searches name, manufacturer, and notes)
    /// - Parameter text: Search text
    /// - Returns: Array of matching ItemType instances
    func searchItems(text: String) async throws -> [ItemType]

    /// Fetch items by manufacturer
    /// - Parameter manufacturer: Manufacturer identifier
    /// - Returns: Array of ItemType instances from the manufacturer
    func fetchItems(byManufacturer manufacturer: String) async throws -> [ItemType]

    /// Fetch items by manufacturer status
    /// - Parameter status: Manufacturer status (available, discontinued, etc.)
    /// - Returns: Array of ItemType instances with matching status
    func fetchItems(byStatus status: String) async throws -> [ItemType]

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

// MARK: - Glass-Specific Extensions

/// Extension providing glass-specific methods (COE queries, kiln schedule relationships)
/// These methods are ONLY available when ItemType == GlassItemModel
extension CatalogItemRepository where ItemType == GlassItemModel {
    /// Fetch glass items by COE (coefficient of expansion)
    /// - Parameter coe: COE value
    /// - Returns: Array of GlassItemModel instances with matching COE
    /// - Note: Only available for GlassItemRepository (glass items have COE, coatings/tools don't)
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        // Default implementation throws - concrete repositories must override
        fatalError("fetchItems(byCOE:) must be implemented by concrete GlassItemRepository")
    }

    /// Get all distinct COE values in the system
    /// - Returns: Sorted array of COE values
    /// - Note: Only available for GlassItemRepository (glass items have COE, coatings/tools don't)
    func getDistinctCOEValues() async throws -> [Int32] {
        // Default implementation throws - concrete repositories must override
        fatalError("getDistinctCOEValues() must be implemented by concrete GlassItemRepository")
    }

    /// Get recommended kiln schedules for a glass item
    /// - Parameter stableId: The stable ID of the glass item
    /// - Returns: Array of kiln schedule IDs recommended for this glass item
    /// - Note: Only available for GlassItemRepository (only glass items have kiln schedules)
    func getRecommendedSchedules(forGlassItem stableId: String) async throws -> [UUID] {
        // Default implementation throws - concrete repositories must override
        fatalError("getRecommendedSchedules(forGlassItem:) must be implemented by concrete GlassItemRepository")
    }

    /// Add a kiln schedule to a glass item's recommended schedules
    /// - Parameters:
    ///   - scheduleId: The kiln schedule ID to add
    ///   - stableId: The stable ID of the glass item
    /// - Note: Only available for GlassItemRepository (only glass items have kiln schedules)
    func addRecommendedSchedule(scheduleId: UUID, toGlassItem stableId: String) async throws {
        // Default implementation throws - concrete repositories must override
        fatalError("addRecommendedSchedule(scheduleId:toGlassItem:) must be implemented by concrete GlassItemRepository")
    }

    /// Remove a kiln schedule from a glass item's recommended schedules
    /// - Parameters:
    ///   - scheduleId: The kiln schedule ID to remove
    ///   - stableId: The stable ID of the glass item
    /// - Note: Only available for GlassItemRepository (only glass items have kiln schedules)
    func removeRecommendedSchedule(scheduleId: UUID, fromGlassItem stableId: String) async throws {
        // Default implementation throws - concrete repositories must override
        fatalError("removeRecommendedSchedule(scheduleId:fromGlassItem:) must be implemented by concrete GlassItemRepository")
    }
}

// MARK: - Type Aliases for Backwards Compatibility

/// Type alias for glass item repositories (backwards compatibility with existing code)
typealias GlassItemRepository = any CatalogItemRepository<GlassItemModel>

/// Type alias for coating item repositories (backwards compatibility with existing code)
typealias CoatingItemRepository = any CatalogItemRepository<CoatingItemModel>

/// Type alias for tool item repositories (backwards compatibility with existing code)
typealias ToolItemRepository = any CatalogItemRepository<ToolItemModel>

