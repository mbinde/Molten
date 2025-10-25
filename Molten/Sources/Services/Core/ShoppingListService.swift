//
//  ShoppingListService.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Service for managing shopping lists and minimum inventory thresholds
/// Coordinates ItemMinimum, Inventory, and GlassItem repositories
/// Follows clean architecture: orchestrates repositories, delegates business logic to models
@preconcurrency
class ShoppingListService {
    
    // MARK: - Dependencies

    nonisolated(unsafe) private let _itemMinimumRepository: ItemMinimumRepository
    nonisolated(unsafe) private let _shoppingListRepository: ShoppingListRepository
    nonisolated(unsafe) private let inventoryRepository: InventoryRepository
    nonisolated(unsafe) private let glassItemRepository: GlassItemRepository
    nonisolated(unsafe) private let itemTagsRepository: ItemTagsRepository
    nonisolated(unsafe) private let userTagsRepository: UserTagsRepository

    // MARK: - Exposed Dependencies for Advanced Operations

    /// Direct access to item minimum repository for advanced operations
    /// This allows the CatalogService to access shopping list functionality directly
    nonisolated var itemMinimumRepository: ItemMinimumRepository {
        return _itemMinimumRepository
    }

    /// Direct access to shopping list repository for manually added items
    nonisolated var shoppingListRepository: ShoppingListRepository {
        return _shoppingListRepository
    }

    // MARK: - Initialization

    nonisolated init(
        itemMinimumRepository: ItemMinimumRepository,
        shoppingListRepository: ShoppingListRepository,
        inventoryRepository: InventoryRepository,
        glassItemRepository: GlassItemRepository,
        itemTagsRepository: ItemTagsRepository,
        userTagsRepository: UserTagsRepository
    ) {
        self._itemMinimumRepository = itemMinimumRepository
        self._shoppingListRepository = shoppingListRepository
        self.inventoryRepository = inventoryRepository
        self.glassItemRepository = glassItemRepository
        self.itemTagsRepository = itemTagsRepository
        self.userTagsRepository = userTagsRepository
    }
    
    // MARK: - Shopping List Operations
    
    /// Generate complete shopping list for a specific store
    /// - Parameter store: Store name to generate shopping list for
    /// - Returns: Detailed shopping list with item information
    func generateShoppingList(forStore store: String) async throws -> DetailedShoppingListModel {
        // 1. Get current inventory state
        let currentInventory = try await getCurrentInventoryState()
        
        // 2. Generate basic shopping list
        let basicShoppingList = try await self.itemMinimumRepository.generateShoppingList(
            forStore: store,
            currentInventory: currentInventory
        )
        
        // 3. Enhance with detailed item information
        var detailedItems: [DetailedShoppingListItemModel] = []
        
        for basicItem in basicShoppingList {
            if let glassItem = try await glassItemRepository.fetchItem(byStableId: basicItem.itemNaturalKey) {
                let tags = try await itemTagsRepository.fetchTags(forItem: basicItem.itemNaturalKey)
                let userTags = try await userTagsRepository.fetchTags(forItem: basicItem.itemNaturalKey)

                let detailedItem = DetailedShoppingListItemModel(
                    shoppingListItem: basicItem,
                    glassItem: glassItem,
                    tags: tags,
                    userTags: userTags
                )
                detailedItems.append(detailedItem)
            }
        }
        
        // 4. Sort by priority (highest shortfall first)
        detailedItems.sort { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }
        
        return DetailedShoppingListModel(
            store: store,
            items: detailedItems,
            totalItems: detailedItems.count,
            totalValue: estimateTotalValue(for: detailedItems)
        )
    }
    
    /// Generate shopping lists for all stores
    /// Combines items from two sources:
    /// 1. Items below their minimum thresholds (from ItemMinimum)
    /// 2. Manually added shopping list items (from ItemShopping)
    /// - Returns: Dictionary mapping store names to detailed shopping lists
    func generateAllShoppingLists() async throws -> [String: DetailedShoppingListModel] {
        // 1. Get current inventory state
        let currentInventory = try await getCurrentInventoryState()

        // 2. Generate shopping lists from minimums (items below threshold)
        let minimumBasedLists = try await self.itemMinimumRepository.generateShoppingLists(currentInventory: currentInventory)

        // 3. Get manually added shopping list items
        let manuallyAddedItems = try await self._shoppingListRepository.fetchAllItems()

        // 4. Combine both sources, grouping by store
        var combinedListsByStore: [String: [ShoppingListItemModel]] = [:]

        // Add items from minimums
        for (store, items) in minimumBasedLists {
            combinedListsByStore[store] = items
        }

        // Add manually added items
        for manualItem in manuallyAddedItems {
            let store = manualItem.store ?? "Other"
            let itemType = manualItem.type ?? "rod"

            // Get current inventory for this item
            let currentQty = try await inventoryRepository.getTotalQuantity(
                forItem: manualItem.item_stable_id,
                type: itemType
            )

            // Create ShoppingListItemModel from ItemShoppingModel
            // For manually added items, we set minimumQuantity = currentQuantity + quantity needed
            // This way neededQuantity will be calculated as: minimumQuantity - currentQuantity = quantity
            let shoppingListItem = ShoppingListItemModel(
                itemNaturalKey: manualItem.item_stable_id,
                type: itemType,
                currentQuantity: currentQty,
                minimumQuantity: currentQty + manualItem.quantity,
                store: store
            )

            // Check if this item already exists in the list (from minimums)
            if var existingItems = combinedListsByStore[store] {
                // Check for duplicate by item natural key
                if let existingIndex = existingItems.firstIndex(where: { $0.itemNaturalKey == manualItem.item_stable_id }) {
                    // Item exists - combine the needed quantities
                    let existingItem = existingItems[existingIndex]
                    // The new minimum should be current + max(existing needed, manual needed)
                    let combinedNeeded = max(existingItem.neededQuantity, manualItem.quantity)
                    let mergedItem = ShoppingListItemModel(
                        itemNaturalKey: existingItem.itemNaturalKey,
                        type: existingItem.type,
                        currentQuantity: existingItem.currentQuantity,
                        minimumQuantity: existingItem.currentQuantity + combinedNeeded,
                        store: existingItem.store
                    )
                    existingItems[existingIndex] = mergedItem
                    combinedListsByStore[store] = existingItems
                } else {
                    // New item for this store
                    existingItems.append(shoppingListItem)
                    combinedListsByStore[store] = existingItems
                }
            } else {
                // First item for this store
                combinedListsByStore[store] = [shoppingListItem]
            }
        }

        // 5. Convert to detailed shopping lists
        var detailedShoppingLists: [String: DetailedShoppingListModel] = [:]

        for (store, basicItems) in combinedListsByStore {
            var detailedItems: [DetailedShoppingListItemModel] = []

            for basicItem in basicItems {
                if let glassItem = try await glassItemRepository.fetchItem(byStableId: basicItem.itemNaturalKey) {
                    let tags = try await itemTagsRepository.fetchTags(forItem: basicItem.itemNaturalKey)
                    let userTags = try await userTagsRepository.fetchTags(forItem: basicItem.itemNaturalKey)

                    let detailedItem = DetailedShoppingListItemModel(
                        shoppingListItem: basicItem,
                        glassItem: glassItem,
                        tags: tags,
                        userTags: userTags
                    )
                    detailedItems.append(detailedItem)
                }
            }

            // Sort by priority (highest needed quantity first)
            detailedItems.sort { $0.shoppingListItem.neededQuantity > $1.shoppingListItem.neededQuantity }

            detailedShoppingLists[store] = DetailedShoppingListModel(
                store: store,
                items: detailedItems,
                totalItems: detailedItems.count,
                totalValue: estimateTotalValue(for: detailedItems)
            )
        }

        return detailedShoppingLists
    }
    
    /// Get comprehensive low stock report
    /// - Returns: Low stock report with actionable information
    func getLowStockReport() async throws -> LowStockReportModel {
        // 1. Get current inventory state
        let currentInventory = try await getCurrentInventoryState()
        
        // 2. Get low stock items from minimums
        let lowStockItems = try await self.itemMinimumRepository.getLowStockItems(currentInventory: currentInventory)
        
        // 3. Enhance with detailed item information
        var detailedLowStockItems: [DetailedLowStockItemModel] = []
        
        for lowStockItem in lowStockItems {
            if let glassItem = try await glassItemRepository.fetchItem(byStableId: lowStockItem.itemNaturalKey) {
                let tags = try await itemTagsRepository.fetchTags(forItem: lowStockItem.itemNaturalKey)
                
                let detailedItem = DetailedLowStockItemModel(
                    lowStockItem: lowStockItem,
                    glassItem: glassItem,
                    tags: tags
                )
                detailedLowStockItems.append(detailedItem)
            }
        }
        
        // 4. Group by store for shopping organization
        let groupedByStore = Dictionary(grouping: detailedLowStockItems) { $0.lowStockItem.store }
        
        // 5. Calculate summary statistics
        let totalItemsLow = detailedLowStockItems.count
        let totalShortfall = detailedLowStockItems.reduce(0.0) { $0 + $1.lowStockItem.shortfall }
        let storesAffected = Set(detailedLowStockItems.map { $0.lowStockItem.store }).count
        
        return LowStockReportModel(
            items: detailedLowStockItems,
            groupedByStore: groupedByStore,
            totalItemsLow: totalItemsLow,
            totalShortfall: totalShortfall,
            storesAffected: storesAffected,
            generatedAt: Date()
        )
    }
    
    // MARK: - Minimum Management Operations
    
    /// Set or update minimum quantity for an item
    /// - Parameters:
    ///   - stableId: Item natural key
    ///   - type: Inventory type
    ///   - quantity: Minimum quantity threshold
    ///   - store: Preferred store for purchasing
    /// - Returns: Updated minimum model
    func setMinimum(
        forItem stableId: String,
        type: String,
        quantity: Double,
        store: String
    ) async throws -> DetailedMinimumModel {
        
        // 1. Verify the glass item exists
        guard let glassItem = try await glassItemRepository.fetchItem(byStableId: stableId) else {
            throw ShoppingListServiceError.itemNotFound(stableId)
        }
        
        // 2. Set the minimum
        let minimum = try await self.itemMinimumRepository.setMinimumQuantity(
            quantity,
            forItem: stableId,
            type: type,
            store: store
        )
        
        // 3. Get additional context
        let tags = try await itemTagsRepository.fetchTags(forItem: stableId)
        let currentInventory = try await inventoryRepository.getTotalQuantity(forItem: stableId, type: type)
        
        return DetailedMinimumModel(
            minimum: minimum,
            glassItem: glassItem,
            tags: tags,
            currentQuantity: currentInventory
        )
    }
    
    /// Get all minimums for an item with current inventory context
    /// - Parameter stableId: Item natural key
    /// - Returns: Array of detailed minimum models
    func getMinimumsForItem(_ stableId: String) async throws -> [DetailedMinimumModel] {
        // 1. Get the glass item
        guard let glassItem = try await glassItemRepository.fetchItem(byStableId: stableId) else {
            throw ShoppingListServiceError.itemNotFound(stableId)
        }
        
        // 2. Get all minimums for this item
        let minimums = try await self.itemMinimumRepository.fetchMinimums(forItem: stableId)
        
        // 3. Get tags once
        let tags = try await itemTagsRepository.fetchTags(forItem: stableId)
        
        // 4. Build detailed models with current inventory
        var detailedMinimums: [DetailedMinimumModel] = []
        
        for minimum in minimums {
            let currentQuantity = try await inventoryRepository.getTotalQuantity(
                forItem: stableId,
                type: minimum.type
            )
            
            detailedMinimums.append(DetailedMinimumModel(
                minimum: minimum,
                glassItem: glassItem,
                tags: tags,
                currentQuantity: currentQuantity
            ))
        }
        
        return detailedMinimums.sorted { $0.minimum.type < $1.minimum.type }
    }
    
    /// Remove minimum for an item and type
    /// - Parameters:
    ///   - stableId: Item natural key
    ///   - type: Inventory type
    func removeMinimum(forItem stableId: String, type: String) async throws {
        try await self.itemMinimumRepository.deleteMinimum(forItem: stableId, type: type)
    }
    
    // MARK: - Store Management Operations
    
    /// Get all stores with their utilization statistics
    /// - Returns: Array of store statistics
    func getStoreStatistics() async throws -> [StoreStatisticsModel] {
        // 1. Get store utilization (how many minimums reference each store)
        let storeUtilization = try await self.itemMinimumRepository.getStoreUtilization()
        
        // 2. Get distinct stores
        let allStores = try await self.itemMinimumRepository.getDistinctStores()
        
        // 3. Build statistics for each store
        var statistics: [StoreStatisticsModel] = []
        
        for store in allStores {
            let minimumCount = storeUtilization[store] ?? 0
            
            // Generate a sample shopping list to get current needs
            let currentInventory = try await getCurrentInventoryState()
            let shoppingList = try await self.itemMinimumRepository.generateShoppingList(
                forStore: store,
                currentInventory: currentInventory
            )
            
            statistics.append(StoreStatisticsModel(
                storeName: store,
                minimumCount: minimumCount,
                currentNeedsCount: shoppingList.count,
                totalNeededQuantity: shoppingList.reduce(0.0) { $0 + $1.neededQuantity }
            ))
        }
        
        return statistics.sorted { $0.currentNeedsCount > $1.currentNeedsCount }
    }
    
    /// Update store name across all minimum records
    /// - Parameters:
    ///   - oldName: Current store name
    ///   - newName: New store name
    func updateStoreName(from oldName: String, to newName: String) async throws {
        try await self.itemMinimumRepository.updateStoreName(from: oldName, to: newName)
    }
    
    // MARK: - Analytics Operations
    
    /// Get minimum quantity analytics
    /// - Returns: Statistics about minimum quantities across the system
    func getMinimumAnalytics() async throws -> MinimumAnalyticsModel {
        // 1. Get basic statistics
        let statistics = try await self.itemMinimumRepository.getMinimumQuantityStatistics()
        
        // 2. Get most common types
        let commonTypes = try await self.itemMinimumRepository.getMostCommonTypes()
        
        // 3. Get store distribution
        let storeUtilization = try await self.itemMinimumRepository.getStoreUtilization()
        
        // 4. Get highest minimums
        let highestMinimums = try await self.itemMinimumRepository.getHighestMinimums(limit: 10)
        
        return MinimumAnalyticsModel(
            basicStatistics: statistics,
            commonTypes: commonTypes,
            storeDistribution: storeUtilization,
            highestMinimums: highestMinimums
        )
    }
    
    // MARK: - Private Helper Methods
    
    /// Get current inventory state for all items
    private func getCurrentInventoryState() async throws -> [String: [String: Double]] {
        let allSummaries = try await inventoryRepository.getInventorySummary()
        
        var inventoryState: [String: [String: Double]] = [:]
        
        for summary in allSummaries {
            inventoryState[summary.item_stable_id] = summary.inventoryByType
        }
        
        return inventoryState
    }
    
    /// Estimate total value of shopping list items (placeholder implementation)
    private func estimateTotalValue(for items: [DetailedShoppingListItemModel]) -> Double {
        // Placeholder: In a real implementation, this would use pricing data
        // For now, return a simple estimate based on quantity
        return items.reduce(0.0) { total, item in
            total + (item.shoppingListItem.neededQuantity * 10.0) // $10 per unit estimate
        }
    }
}

// MARK: - Service Models

/// Detailed shopping list with complete item information
nonisolated struct DetailedShoppingListModel {
    let store: String
    let items: [DetailedShoppingListItemModel]
    let totalItems: Int
    let totalValue: Double

    /// Items grouped by manufacturer for easier shopping
    nonisolated var itemsByManufacturer: [String: [DetailedShoppingListItemModel]] {
        Dictionary(grouping: items) { $0.glassItem.manufacturer }
    }
}

/// Shopping list item with complete glass item information
nonisolated struct DetailedShoppingListItemModel {
    let shoppingListItem: ShoppingListItemModel
    let glassItem: GlassItemModel
    let tags: [String]  // Manufacturer/system tags
    let userTags: [String]  // User-created tags

    /// All tags combined (manufacturer + user tags)
    nonisolated var allTags: [String] {
        Array(Set(tags + userTags)).sorted()
    }

    /// Priority score based on shortfall percentage
    nonisolated var priorityScore: Double {
        guard shoppingListItem.minimumQuantity > 0 else { return 0 }
        return shoppingListItem.neededQuantity / shoppingListItem.minimumQuantity
    }

    /// Complete item model for navigation purposes
    /// Note: inventory will be empty for shopping list items
    nonisolated var completeItem: CompleteInventoryItemModel {
        CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: tags,
            userTags: userTags
        )
    }
}

/// Low stock report with actionable information
nonisolated struct LowStockReportModel {
    let items: [DetailedLowStockItemModel]
    let groupedByStore: [String: [DetailedLowStockItemModel]]
    let totalItemsLow: Int
    let totalShortfall: Double
    let storesAffected: Int
    let generatedAt: Date
}

/// Low stock item with complete context
nonisolated struct DetailedLowStockItemModel {
    let lowStockItem: LowStockItemModel
    let glassItem: GlassItemModel
    let tags: [String]

    /// Urgency level based on how far below minimum we are
    nonisolated var urgencyLevel: UrgencyLevel {
        let shortfallPercentage = lowStockItem.shortfall / lowStockItem.minimumQuantity
        if shortfallPercentage >= 0.8 {
            return .critical
        } else if shortfallPercentage >= 0.5 {
            return .high
        } else if shortfallPercentage >= 0.2 {
            return .medium
        } else {
            return .low
        }
    }
}

/// Minimum with complete context
nonisolated struct DetailedMinimumModel {
    let minimum: ItemMinimumModel
    let glassItem: GlassItemModel
    let tags: [String]
    let currentQuantity: Double

    /// Whether current inventory meets the minimum
    nonisolated var meetsMinimum: Bool {
        currentQuantity >= minimum.quantity
    }

    /// How much more is needed to meet minimum
    nonisolated var shortfall: Double {
        max(0, minimum.quantity - currentQuantity)
    }
}

/// Store utilization statistics
nonisolated struct StoreStatisticsModel {
    let storeName: String
    let minimumCount: Int
    let currentNeedsCount: Int
    let totalNeededQuantity: Double
    
    /// Percentage of minimums that currently need restocking
    nonisolated var restockingPercentage: Double {
        guard minimumCount > 0 else { return 0 }
        return Double(currentNeedsCount) / Double(minimumCount) * 100.0
    }
}

/// Comprehensive minimum analytics
nonisolated struct MinimumAnalyticsModel {
    let basicStatistics: MinimumQuantityStatistics
    let commonTypes: [String: Int]
    let storeDistribution: [String: Int]
    let highestMinimums: [ItemMinimumModel]
}

/// Urgency levels for low stock items
enum UrgencyLevel: String, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "blue"
        }
    }
}

// MARK: - Service Errors

enum ShoppingListServiceError: Error, LocalizedError {
    case itemNotFound(String)
    case invalidMinimum(String)
    case storeNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound(let stableId):
            return "Glass item not found: \(stableId)"
        case .invalidMinimum(let message):
            return "Invalid minimum configuration: \(message)"
        case .storeNotFound(let store):
            return "Store not found: \(store)"
        }
    }
}
