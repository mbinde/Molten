//
//  CatalogService.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//  Updated by Assistant on 10/14/25.
//  Migrated from Legacy Support - Removed legacy InventoryService dependencies
//

import Foundation

/// Service layer that handles catalog business logic using repository pattern
/// ENHANCED: Pure GlassItem system implementation with advanced search capabilities,
/// bulk operations, and comprehensive inventory integration
actor CatalogService {

    // MARK: - Dependencies

    // Catalog item repositories
    private let glassItemRepository: GlassItemRepository
    private let coatingItemRepository: CoatingItemRepository
    private let toolItemRepository: ToolItemRepository

    // Supporting services
    private let inventoryTrackingService: InventoryTrackingService
    private let itemMinimumRepository: ItemMinimumRepository
    private let itemTagsRepository: ItemTagsRepository
    private let userTagsRepository: UserTagsRepository
    private let ratingService: RatingService

    // MARK: - Initialization

    /// Initialize with all catalog repositories
    init(
        glassItemRepository: GlassItemRepository,
        coatingItemRepository: CoatingItemRepository,
        toolItemRepository: ToolItemRepository,
        inventoryTrackingService: InventoryTrackingService,
        itemMinimumRepository: ItemMinimumRepository,
        itemTagsRepository: ItemTagsRepository,
        userTagsRepository: UserTagsRepository,
        ratingService: RatingService
    ) {
        self.glassItemRepository = glassItemRepository
        self.coatingItemRepository = coatingItemRepository
        self.toolItemRepository = toolItemRepository
        self.inventoryTrackingService = inventoryTrackingService
        self.itemMinimumRepository = itemMinimumRepository
        self.itemTagsRepository = itemTagsRepository
        self.userTagsRepository = userTagsRepository
        self.ratingService = ratingService
    }
    
    // MARK: - GlassItem System Support

    /// Get all glass items in lightweight format (no inventory/tags/locations)
    /// Use this for search/autocomplete functionality where you only need basic item info
    /// For full data including inventory and tags, use getAllGlassItems() instead
    func getGlassItemsLightweight(
        sortBy: GlassItemSortOption = .name
    ) async throws -> [GlassItemModel] {
        // Get all glass items without any relationships
        let glassItems = try await glassItemRepository.fetchItems(matching: nil)

        // Apply sorting
        switch sortBy {
        case .name:
            return glassItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .manufacturer:
            return glassItems.sorted { item1, item2 in
                if item1.manufacturer != item2.manufacturer {
                    return item1.manufacturer.localizedCaseInsensitiveCompare(item2.manufacturer) == .orderedAscending
                }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        case .coe:
            return glassItems.sorted { item1, item2 in
                if item1.coe != item2.coe {
                    return item1.coe < item2.coe
                }
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        case .totalQuantity:
            // Can't sort by quantity in lightweight mode, fall back to name
            return glassItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .rating:
            // Can't sort by rating in lightweight mode, fall back to name
            return glassItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// Get all catalog items (glass, coatings, and tools) with complete information and flexible sorting
    func getAllGlassItems(
        sortBy: GlassItemSortOption = .name,
        includeWithoutInventory: Bool = true
    ) async throws -> [CompleteInventoryItemModel] {
        let trackingService = inventoryTrackingService

        // Get all three types of catalog items in parallel
        async let glassItemsTask = glassItemRepository.fetchItems(matching: nil)
        async let coatingItemsTask = coatingItemRepository.fetchItems(matching: nil)
        async let toolItemsTask = toolItemRepository.fetchItems(matching: nil)

        let (glassItems, coatingItems, toolItems) = try await (glassItemsTask, coatingItemsTask, toolItemsTask)

        // Convert all items to UnifiedCatalogItem
        var allCatalogItems: [UnifiedCatalogItem] = []
        allCatalogItems += glassItems.map { UnifiedCatalogItem(glassItem: $0) }
        allCatalogItems += coatingItems.map { UnifiedCatalogItem(coatingItem: $0) }
        allCatalogItems += toolItems.map { UnifiedCatalogItem(toolItem: $0) }

        // Filter by inventory if requested
        let filteredItems: [UnifiedCatalogItem]
        if includeWithoutInventory {
            filteredItems = allCatalogItems
        } else {
            let itemsWithInventory = Set(try await trackingService.getItemsWithInventory())
            filteredItems = allCatalogItems.filter { itemsWithInventory.contains($0.stable_id) }
        }

        // OPTIMIZED: Batch fetch inventory for all items instead of individual calls
        let allInventory = try await trackingService.fetchAllInventory(matching: nil)
        let inventoryByItem = Dictionary(grouping: allInventory) { $0.item_stable_id }

        // OPTIMIZED: Batch fetch tags for all items instead of individual calls
        let allItemKeys = filteredItems.map { $0.stable_id }
        let tagsByItem = try await itemTagsRepository.fetchTagsForItems(allItemKeys)
        print("🏷️ DEBUG CatalogService: Batch fetched tags for \(allItemKeys.count) items, got tags for \(tagsByItem.count) items")
        if let firstItem = tagsByItem.first {
            print("🏷️ DEBUG CatalogService: Sample - item \(firstItem.key) has \(firstItem.value.count) tags: \(firstItem.value.prefix(5).joined(separator: ", "))")
        }

        // OPTIMIZED: Batch fetch user tags for all items
        let userTagsByItem = try await userTagsRepository.fetchTagsForItems(allItemKeys)

        // OPTIMIZED: Fetch ALL ratings (bulk if available, otherwise per-item)
        var ratingsByItem: [String: AggregatedRatingModel] = [:]
        do {
            // Try bulk endpoint first (more efficient)
            let allRatings = try await ratingService.fetchAllRatingsBulk(forceRefresh: false)
            ratingsByItem = Dictionary(uniqueKeysWithValues: allRatings.map { ($0.itemStableId, $0) })
        } catch {
            // Bulk endpoint not available, fall back to per-item fetch
            do {
                let ratings = try await ratingService.fetchRatings(forItems: allItemKeys, forceRefresh: false)
                ratingsByItem = Dictionary(uniqueKeysWithValues: ratings.map { ($0.itemStableId, $0) })
            } catch {
                print("⚠️ [CatalogService] Failed to load ratings")
            }
        }

        // Convert to complete models using batch-fetched data
        var completeItems: [CompleteInventoryItemModel] = []
        var attachedCount = 0
        for catalogItem in filteredItems {
            let inventory = inventoryByItem[catalogItem.stable_id] ?? []
            let tags = tagsByItem[catalogItem.stable_id] ?? []
            let userTags = userTagsByItem[catalogItem.stable_id] ?? []
            let rating = ratingsByItem[catalogItem.stable_id]

            if rating != nil {
                attachedCount += 1
            }

            let completeItem = CompleteInventoryItemModel(
                catalogItem: catalogItem,
                inventory: inventory,
                tags: tags,
                userTags: userTags,
                rating: rating
            )
            completeItems.append(completeItem)
        }

        // Apply sorting
        let sortedItems = sortItems(completeItems, by: sortBy)
        return sortedItems
    }
    
    /// Enhanced search with advanced filtering and sorting options
    func searchGlassItems(
        request: GlassItemSearchRequest
    ) async throws -> GlassItemSearchResult {
        let trackingService = inventoryTrackingService

        // Start with text search if provided
        var candidateItems: [GlassItemModel]
        if let searchText = request.searchText, !searchText.isEmpty {
            candidateItems = try await glassItemRepository.searchItems(text: searchText)
        } else {
            candidateItems = try await glassItemRepository.fetchItems(matching: nil)
        }

        // OPTIMIZED: Batch fetch inventory for all items
        let allInventory = try await trackingService.fetchAllInventory(matching: nil)
        let inventoryByItem = Dictionary(grouping: allInventory) { $0.item_stable_id }

        // OPTIMIZED: Batch fetch tags for all items
        let allItemKeys = candidateItems.map { $0.stable_id }
        let tagsByItem = try await itemTagsRepository.fetchTagsForItems(allItemKeys)

        // OPTIMIZED: Batch fetch user tags for all items
        let userTagsByItem = try await userTagsRepository.fetchTagsForItems(allItemKeys)

        // Convert to complete models using batch-fetched data
        var completeItems: [CompleteInventoryItemModel] = []
        for glassItem in candidateItems {
            let inventory = inventoryByItem[glassItem.stable_id] ?? []
            let tags = tagsByItem[glassItem.stable_id] ?? []
            let userTags = userTagsByItem[glassItem.stable_id] ?? []

            let completeItem = CompleteInventoryItemModel(
                glassItem: glassItem,
                inventory: inventory,
                tags: tags,
                userTags: userTags
            )
            completeItems.append(completeItem)
        }

        // OPTIMIZATION: Extract actor-isolated properties before creating closures
        // to avoid async closure requirements
        var tagsByStableId: [String: [String]] = [:]
        for item in completeItems {
            let stableId = await item.glassItem.stable_id
            let tags = await item.tags
            tagsByStableId[stableId] = tags
        }

        // Apply filters using model business logic
        let tagFilterClosure: ([String]) -> [String] = { requestedTags in
            // Return items that have ALL requested tags
            tagsByStableId
                .filter { (_, itemTags) in
                    Set(requestedTags).isSubset(of: Set(itemTags))
                }
                .map { $0.key }
        }

        let inventoryFilterClosure: (String) -> Bool = { stableId in
            inventoryByItem[stableId]?.isEmpty == false
        }

        completeItems = request.filter(
            completeItems,
            itemsWithTags: tagFilterClosure,
            itemsWithInventory: inventoryFilterClosure
        )

        // Apply sorting
        let sortedItems = sortItems(completeItems, by: request.sortBy)
        
        // Apply pagination if requested
        let paginatedItems: [CompleteInventoryItemModel]
        if let offset = request.offset, let limit = request.limit {
            let startIndex = min(offset, sortedItems.count)
            let endIndex = min(offset + limit, sortedItems.count)
            paginatedItems = Array(sortedItems[startIndex..<endIndex])
        } else {
            paginatedItems = sortedItems
        }
        
        return GlassItemSearchResult(
            items: paginatedItems,
            totalCount: sortedItems.count,
            hasMore: request.limit != nil && sortedItems.count > (request.offset ?? 0) + (request.limit ?? 0),
            appliedFilters: request.getAppliedFiltersDescription()
        )
    }
    
    /// Create a complete glass item with inventory and tags
    func createGlassItem(
        _ glassItem: GlassItemModel,
        initialInventory: [InventoryModel] = [],
        tags: [String] = []
    ) async throws -> CompleteInventoryItemModel {
        let trackingService = inventoryTrackingService
        
        return try await trackingService.createCompleteItem(
            glassItem,
            initialInventory: initialInventory,
            tags: tags
        )
    }
    
    /// Create multiple glass items in a batch operation with validation
    func createGlassItems(
        _ items: [GlassItemCreationRequest]
    ) async throws -> [CompleteInventoryItemModel] {
        let trackingService = inventoryTrackingService
        
        // Validate natural keys and generate if needed
        var glassItemsToCreate: [GlassItemModel] = []
        for request in items {
            let naturalKey = try await generateOrValidateNaturalKey(
                manufacturer: request.manufacturer,
                sku: request.sku,
                customNaturalKey: request.customNaturalKey
            )
            
            let glassItem = GlassItemModel(
                stable_id: naturalKey,
                name: request.name,
                sku: request.sku,
                manufacturer: request.manufacturer,
                mfr_notes: request.mfr_notes,
                coe: request.coe,
                url: request.url,
                mfr_status: request.mfr_status,
                image_url: request.image_url,
                image_path: request.image_path
            )
            glassItemsToCreate.append(glassItem)
        }
        
        // Create all glass items in batch
        let createdGlassItems = try await glassItemRepository.createItems(glassItemsToCreate)
        
        // Create complete items with inventory and tags
        var completeItems: [CompleteInventoryItemModel] = []
        for (index, createdItem) in createdGlassItems.enumerated() {
            let request = items[index]
            let completeItem = try await trackingService.createCompleteItem(
                createdItem,
                initialInventory: request.initialInventory,
                tags: request.tags
            )
            completeItems.append(completeItem)
        }
        
        return completeItems
    }
    
    /// Generate or validate a natural key for a manufacturer and SKU
    func generateOrValidateNaturalKey(
        manufacturer: String,
        sku: String?,  // Optional - some manufacturers don't use SKUs
        customNaturalKey: String? = nil
    ) async throws -> String {
        if let customKey = customNaturalKey {
            // Validate that the custom stable_id doesn't already exist
            let exists = try await glassItemRepository.stableIdExists(customKey)
            if exists {
                throw CatalogServiceError.naturalKeyAlreadyExists(customKey)
            }

            // stable_id is just a 6-char hash - no format validation needed
            return customKey
        } else {
            // Generate the next available stable_id
            return try await glassItemRepository.generateNextNaturalKey(manufacturer: manufacturer, sku: sku)
        }
    }
    
    /// Check if a natural key is available
    func isNaturalKeyAvailable(_ stableId: String) async throws -> Bool {
        return !(try await glassItemRepository.stableIdExists(stableId))
    }
    
    /// Get the next available natural key for a manufacturer and SKU
    func getNextNaturalKey(manufacturer: String, sku: String) async throws -> String {
        return try await glassItemRepository.generateNextNaturalKey(manufacturer: manufacturer, sku: sku)
    }
    
    /// Get a single glass item by its natural key with complete information
    /// - Parameter stableId: The natural key of the item to retrieve
    /// - Returns: CompleteInventoryItemModel if found, nil otherwise
    func getGlassItemByNaturalKey(_ stableId: String) async throws -> CompleteInventoryItemModel? {
        // Use the existing getCompleteItem method from InventoryTrackingService
        return try await inventoryTrackingService.getCompleteItem(stableId: stableId)
    }

    /// Get a single glass item by its stable_id (lightweight, without inventory/tags)
    /// - Parameter stableId: The stable_id of the item to retrieve
    /// - Returns: GlassItemModel if found, nil otherwise
    func fetchGlassItem(byStableId stableId: String) async throws -> GlassItemModel? {
        return try await glassItemRepository.fetchItem(byStableId: stableId)
    }

    /// Update a glass item with comprehensive data
    func updateGlassItem(
        stableId: String,
        updatedGlassItem: GlassItemModel,
        updatedTags: [String]? = nil
    ) async throws -> CompleteInventoryItemModel {
        let trackingService = inventoryTrackingService

        return try await trackingService.updateCompleteItem(
            stableId: stableId,
            updatedGlassItem: updatedGlassItem,
            updatedTags: updatedTags
        )
    }
    
    /// Delete a glass item and all related data
    func deleteGlassItem(stableId: String) async throws {
        // Cascade delete all related data
        // 1. Delete all inventory for this item (this will also cascade to locations)
        try await inventoryTrackingService.deleteInventory(forItem: stableId)

        // 2. Remove all tags for this item
        try await itemTagsRepository.removeAllTags(fromItem: stableId)

        // 3. Remove any shopping list minimums for this item
        try await itemMinimumRepository.deleteMinimums(forItem: stableId)

        // 4. Finally, delete the glass item itself
        try await glassItemRepository.deleteItem(stableId: stableId)
    }
    
    /// Delete multiple glass items in a batch operation
    func deleteGlassItems(naturalKeys: [String]) async throws {
        // Cascade delete all related data for each item
        for naturalKey in naturalKeys {
            // 1. Delete all inventory for this item (this will also cascade to locations)
            try await inventoryTrackingService.deleteInventory(forItem: naturalKey)

            // 2. Remove all tags for this item
            try await itemTagsRepository.removeAllTags(fromItem: naturalKey)

            // 3. Remove any shopping list minimums for this item
            try await itemMinimumRepository.deleteMinimums(forItem: naturalKey)
        }

        // 4. Finally, delete all glass items
        try await glassItemRepository.deleteItems(stableIds: naturalKeys)
    }
    
    // MARK: - System Status Operations
    
    /// Check the current system status
    func getSystemStatus() async throws -> SystemStatusModel {
        // Check new system
        let newItems = try await glassItemRepository.fetchItems(matching: nil)
        let newItemCount = newItems.count
        let hasNewData = newItemCount > 0
        
        return SystemStatusModel(
            itemCount: newItemCount,
            hasData: hasNewData,
            systemType: "GlassItem"
        )
    }
    
    /// Validate that the catalog system is ready for operation
    func validateSystemReadiness() async throws {
        let status = try await getSystemStatus()
        
        if !status.hasData {
            throw CatalogServiceError.invalidOperation("No catalog data available")
        }
    }
    
    // MARK: - Discovery and Analytics Operations
    
    /// Get catalog overview statistics
    func getCatalogOverview() async throws -> CatalogOverviewModel {
        return try await getSystemOverview()
    }
    
    /// Get manufacturers with item counts
    func getManufacturerStatistics() async throws -> [ManufacturerStatisticsModel] {
        let manufacturers = try await glassItemRepository.getDistinctManufacturers()
        var statistics: [ManufacturerStatisticsModel] = []
        
        for manufacturer in manufacturers {
            let items = try await glassItemRepository.fetchItems(byManufacturer: manufacturer)
            statistics.append(ManufacturerStatisticsModel(
                name: manufacturer,
                itemCount: items.count
            ))
        }
        
        return statistics.sorted() // Uses Comparable conformance from model
    }
    
    /// Get popular tags with usage counts
    func getPopularTags(limit: Int = 20) async throws -> [(tag: String, count: Int)] {
        let tagsRepository = itemTagsRepository
        
        return try await tagsRepository.getTagsWithCounts(minCount: 1)
                                     .prefix(limit)
                                     .map { (tag: $0.tag, count: $0.count) }
    }
    
    /// Get items that might need attention (no inventory, missing tags, etc.)
    func getItemsNeedingAttention() async throws -> ItemAttentionReportModel {
        let trackingService = inventoryTrackingService
        let tagsRepository = itemTagsRepository
        
        let allItems = try await glassItemRepository.fetchItems(matching: nil)
        
        var itemsWithoutInventory: [GlassItemModel] = []
        var itemsWithoutTags: [GlassItemModel] = []
        var itemsWithInconsistentData: [GlassItemModel] = []
        
        for item in allItems {
            // Check for inventory
            let inventory = try await trackingService.fetchInventory(forItem: item.stable_id)
            if inventory.isEmpty {
                itemsWithoutInventory.append(item)
            }
            
            // Check for tags
            let tags = try await tagsRepository.fetchTags(forItem: item.stable_id)
            if tags.isEmpty {
                itemsWithoutTags.append(item)
            }
            
            // Check for data consistency
            let validation = try await trackingService.validateInventoryConsistency(for: item.stable_id)
            if !validation.isValid {
                itemsWithInconsistentData.append(item)
            }
        }
        
        return ItemAttentionReportModel(
            itemsWithoutInventory: itemsWithoutInventory,
            itemsWithoutTags: itemsWithoutTags,
            itemsWithInconsistentData: itemsWithInconsistentData,
            totalItems: allItems.count
        )
    }
    
    // MARK: - Private Helper Methods

    private func sortItems(
        _ items: [CompleteInventoryItemModel],
        by sortOption: GlassItemSortOption
    ) -> [CompleteInventoryItemModel] {
        return sortOption.sort(items) // Uses business logic from model
    }
    
    private func getSystemOverview() async throws -> CatalogOverviewModel {
        let trackingService = inventoryTrackingService
        let tagsRepository = itemTagsRepository
        
        let totalItems = try await glassItemRepository.fetchItems(matching: nil).count
        let totalManufacturers = try await glassItemRepository.getDistinctManufacturers().count
        let totalTags = try await tagsRepository.getAllTags().count
        let itemsWithInventory = try await trackingService.getItemsWithInventory().count
        let lowStockItems = try await trackingService.getLowStockItems(threshold: 5.0).count

        // Use business logic from model
        return CatalogOverviewModel.from(
            totalItems: totalItems,
            totalManufacturers: totalManufacturers,
            totalTags: totalTags,
            itemsWithInventory: itemsWithInventory,
            lowStockItems: lowStockItems,
            systemType: "GlassItem"
        )
    }
}
