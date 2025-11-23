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
actor ShoppingListService {

    // MARK: - Dependencies

    private let _itemMinimumRepository: ItemMinimumRepository
    private let _shoppingListRepository: ShoppingListRepository
    private let inventoryRepository: InventoryRepository
    private let glassItemRepository: GlassItemRepository
    private let coatingItemRepository: CoatingItemRepository
    private let toolItemRepository: ToolItemRepository
    private let itemTagsRepository: ItemTagsRepository
    private let userTagsRepository: UserTagsRepository

    // MARK: - Exposed Dependencies for Advanced Operations

    /// Direct access to item minimum repository for advanced operations
    /// This allows the CatalogService to access shopping list functionality directly
    var itemMinimumRepository: ItemMinimumRepository {
        return _itemMinimumRepository
    }

    /// Direct access to shopping list repository for manually added items
    var shoppingListRepository: ShoppingListRepository {
        return _shoppingListRepository
    }

    // MARK: - Initialization

    init(
        itemMinimumRepository: ItemMinimumRepository,
        shoppingListRepository: ShoppingListRepository,
        inventoryRepository: InventoryRepository,
        glassItemRepository: GlassItemRepository,
        coatingItemRepository: CoatingItemRepository,
        toolItemRepository: ToolItemRepository,
        itemTagsRepository: ItemTagsRepository,
        userTagsRepository: UserTagsRepository
    ) {
        self._itemMinimumRepository = itemMinimumRepository
        self._shoppingListRepository = shoppingListRepository
        self.inventoryRepository = inventoryRepository
        self.glassItemRepository = glassItemRepository
        self.coatingItemRepository = coatingItemRepository
        self.toolItemRepository = toolItemRepository
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
            if let catalogItem = try await fetchCatalogItem(byStableId: basicItem.item_stable_id) {
                let tags = try await itemTagsRepository.fetchTags(forItem: basicItem.item_stable_id)
                let userTags = try await userTagsRepository.fetchTags(forItem: basicItem.item_stable_id)

                let detailedItem = DetailedShoppingListItemModel(
                    shoppingListItem: basicItem,
                    catalogItem: catalogItem,
                    tags: tags,
                    userTags: userTags
                )
                detailedItems.append(detailedItem)
            }
        }
        
        // 4. Sort by priority (highest shortfall first)
        detailedItems.sort() // Uses Comparable conformance from model
        
        return DetailedShoppingListModel(
            store: store,
            items: detailedItems,
            totalItems: detailedItems.count
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
                item_stable_id: manualItem.item_stable_id,
                type: itemType,
                currentQuantity: currentQty,
                minimumQuantity: currentQty + manualItem.quantity,
                store: store
            )

            // Check if this item already exists in the list (from minimums)
            if var existingItems = combinedListsByStore[store] {
                // Check for duplicate by item natural key
                if let existingIndex = existingItems.firstIndex(where: { $0.item_stable_id == manualItem.item_stable_id }) {
                    // Item exists - use business logic from model
                    let existingItem = existingItems[existingIndex]
                    let mergedItem = existingItem.merged(with: shoppingListItem)
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
                if let catalogItem = try await fetchCatalogItem(byStableId: basicItem.item_stable_id) {
                    let tags = try await itemTagsRepository.fetchTags(forItem: basicItem.item_stable_id)
                    let userTags = try await userTagsRepository.fetchTags(forItem: basicItem.item_stable_id)

                    let detailedItem = DetailedShoppingListItemModel(
                        shoppingListItem: basicItem,
                        catalogItem: catalogItem,
                        tags: tags,
                        userTags: userTags
                    )
                    detailedItems.append(detailedItem)
                }
            }

            // Sort by priority (highest needed quantity first)
            detailedItems.sort() // Uses Comparable conformance from model

            detailedShoppingLists[store] = DetailedShoppingListModel(
                store: store,
                items: detailedItems,
                totalItems: detailedItems.count
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
            if let catalogItem = try await fetchCatalogItem(byStableId: lowStockItem.item_stable_id) {
                let tags = try await itemTagsRepository.fetchTags(forItem: lowStockItem.item_stable_id)

                let detailedItem = DetailedLowStockItemModel(
                    lowStockItem: lowStockItem,
                    catalogItem: catalogItem,
                    tags: tags
                )
                detailedLowStockItems.append(detailedItem)
            }
        }
        
        // 4. Use business logic from model to create report
        return LowStockReportModel.from(items: detailedLowStockItems)
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


        // 1. Verify the catalog item exists
        guard let catalogItem = try await fetchCatalogItem(byStableId: stableId) else {
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
            catalogItem: catalogItem,
            tags: tags,
            currentQuantity: currentInventory
        )
    }
    
    /// Get all minimums for an item with current inventory context
    /// - Parameter stableId: Item natural key
    /// - Returns: Array of detailed minimum models
    func getMinimumsForItem(_ stableId: String) async throws -> [DetailedMinimumModel] {
        // 1. Get the catalog item
        guard let catalogItem = try await fetchCatalogItem(byStableId: stableId) else {
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
                catalogItem: catalogItem,
                tags: tags,
                currentQuantity: currentQuantity
            ))
        }

        return detailedMinimums.sorted() // Uses Comparable conformance from model
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
        
        return statistics.sorted() // Uses Comparable conformance from model
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

    /// Fetch catalog item by stable_id from any repository (glass, coating, or tool)
    /// Tries all three repositories in parallel and returns the first match
    private func fetchCatalogItem(byStableId stableId: String) async throws -> UnifiedCatalogItem? {
        // Try fetching from all three repositories in parallel
        async let glassItemTask = glassItemRepository.fetchItem(byStableId: stableId)
        async let coatingItemTask = coatingItemRepository.fetchItem(byStableId: stableId)
        async let toolItemTask = toolItemRepository.fetchItem(byStableId: stableId)

        let (glassItem, coatingItem, toolItem) = try await (glassItemTask, coatingItemTask, toolItemTask)

        // Return whichever one we found (only one should exist for a given stable_id)
        if let glassItem = glassItem {
            return UnifiedCatalogItem(glassItem: glassItem)
        } else if let coatingItem = coatingItem {
            return UnifiedCatalogItem(coatingItem: coatingItem)
        } else if let toolItem = toolItem {
            return UnifiedCatalogItem(toolItem: toolItem)
        } else {
            return nil
        }
    }

}

// MARK: - Service Models
// Models moved to Models/Domain/ShoppingListModels.swift for proper architecture layering

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
