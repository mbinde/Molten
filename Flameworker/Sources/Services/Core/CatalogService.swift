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
class CatalogService {
    
    // MARK: - Dependencies
    
    // New GlassItem system dependencies
    private let glassItemRepository: GlassItemRepository
    private let inventoryTrackingService: InventoryTrackingService
    private let shoppingListService: ShoppingListService
    private let itemTagsRepository: ItemTagsRepository
    
    // MARK: - Exposed Dependencies for Advanced Operations
    
    /// Direct access to inventory repository for advanced inventory operations
    /// This allows external code to perform complex inventory queries when needed
    var inventoryRepository: InventoryRepository {
        return inventoryTrackingService.inventoryRepository
    }
    
    // MARK: - Initialization
    
    /// Initialize with new GlassItem system
    init(
        glassItemRepository: GlassItemRepository,
        inventoryTrackingService: InventoryTrackingService,
        shoppingListService: ShoppingListService,
        itemTagsRepository: ItemTagsRepository
    ) {
        self.glassItemRepository = glassItemRepository
        self.inventoryTrackingService = inventoryTrackingService
        self.shoppingListService = shoppingListService
        self.itemTagsRepository = itemTagsRepository
    }
    
    // MARK: - GlassItem System Support
    
    /// Get all glass items with complete information and flexible sorting
    func getAllGlassItems(
        sortBy: GlassItemSortOption = .name,
        includeWithoutInventory: Bool = true
    ) async throws -> [CompleteInventoryItemModel] {
        let trackingService = inventoryTrackingService
        
        // Get all glass items
        let glassItems = try await glassItemRepository.fetchItems(matching: nil)
        
        // Filter by inventory if requested
        let filteredItems: [GlassItemModel]
        if includeWithoutInventory {
            filteredItems = glassItems
        } else {
            let itemsWithInventory = Set(try await trackingService.inventoryRepository.getItemsWithInventory())
            filteredItems = glassItems.filter { itemsWithInventory.contains($0.natural_key) }
        }
        
        // Convert to complete models
        var completeItems: [CompleteInventoryItemModel] = []
        for glassItem in filteredItems {
            if let completeItem = try await trackingService.getCompleteItem(naturalKey: glassItem.natural_key) {
                completeItems.append(completeItem)
            }
        }
        
        // Apply sorting
        return sortItems(completeItems, by: sortBy)
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
        
        // Apply filters
        candidateItems = try await applyFilters(candidateItems, using: request)
        
        // Convert to complete models
        var completeItems: [CompleteInventoryItemModel] = []
        for glassItem in candidateItems {
            if let completeItem = try await trackingService.getCompleteItem(naturalKey: glassItem.natural_key) {
                completeItems.append(completeItem)
            }
        }
        
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
                natural_key: naturalKey,
                name: request.name,
                sku: request.sku,
                manufacturer: request.manufacturer,
                mfr_notes: request.mfr_notes,
                coe: request.coe,
                url: request.url,
                mfr_status: request.mfr_status
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
        sku: String,
        customNaturalKey: String? = nil
    ) async throws -> String {
        if let customKey = customNaturalKey {
            // Validate that the custom natural key doesn't already exist
            let exists = try await glassItemRepository.naturalKeyExists(customKey)
            if exists {
                throw CatalogServiceError.naturalKeyAlreadyExists(customKey)
            }
            
            // Validate that the custom key follows the expected format
            guard let parsed = GlassItemModel.parseNaturalKey(customKey),
                  parsed.manufacturer == manufacturer,
                  parsed.sku == sku else {
                throw CatalogServiceError.invalidNaturalKeyFormat(customKey)
            }
            
            return customKey
        } else {
            // Generate the next available natural key
            return try await glassItemRepository.generateNextNaturalKey(manufacturer: manufacturer, sku: sku)
        }
    }
    
    /// Check if a natural key is available
    func isNaturalKeyAvailable(_ naturalKey: String) async throws -> Bool {
        return !(try await glassItemRepository.naturalKeyExists(naturalKey))
    }
    
    /// Get the next available natural key for a manufacturer and SKU
    func getNextNaturalKey(manufacturer: String, sku: String) async throws -> String {
        return try await glassItemRepository.generateNextNaturalKey(manufacturer: manufacturer, sku: sku)
    }
    
    /// Update a glass item with comprehensive data
    func updateGlassItem(
        naturalKey: String,
        updatedGlassItem: GlassItemModel,
        updatedTags: [String]? = nil
    ) async throws -> CompleteInventoryItemModel {
        let trackingService = inventoryTrackingService
        
        return try await trackingService.updateCompleteItem(
            naturalKey: naturalKey,
            updatedGlassItem: updatedGlassItem,
            updatedTags: updatedTags
        )
    }
    
    /// Delete a glass item and all related data
    func deleteGlassItem(naturalKey: String) async throws {
        let inventoryRepository = inventoryTrackingService.inventoryRepository
        let tagsRepository = itemTagsRepository
        
        // Cascade delete all related data
        // 1. Delete all inventory for this item (this will also cascade to locations)
        try await inventoryRepository.deleteInventory(forItem: naturalKey)
        
        // 2. Remove all tags for this item
        try await tagsRepository.removeAllTags(fromItem: naturalKey)
        
        // 3. Remove any shopping list minimums for this item
        try await shoppingListService.itemMinimumRepository.deleteMinimums(forItem: naturalKey)
        
        // 4. Finally, delete the glass item itself
        try await glassItemRepository.deleteItem(naturalKey: naturalKey)
    }
    
    /// Delete multiple glass items in a batch operation
    func deleteGlassItems(naturalKeys: [String]) async throws {
        let inventoryRepository = inventoryTrackingService.inventoryRepository
        let tagsRepository = itemTagsRepository
        
        // Cascade delete all related data for each item
        for naturalKey in naturalKeys {
            // 1. Delete all inventory for this item (this will also cascade to locations)
            try await inventoryRepository.deleteInventory(forItem: naturalKey)
            
            // 2. Remove all tags for this item
            try await tagsRepository.removeAllTags(fromItem: naturalKey)
            
            // 3. Remove any shopping list minimums for this item
            try await shoppingListService.itemMinimumRepository.deleteMinimums(forItem: naturalKey)
        }
        
        // 4. Finally, delete all glass items
        try await glassItemRepository.deleteItems(naturalKeys: naturalKeys)
    }
    
    // MARK: - System Status Operations
    
    /// Check the current system status 
    func getSystemStatus() async throws -> SystemStatusModel {
        let trackingService = inventoryTrackingService
        
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
        
        return statistics.sorted { $0.itemCount > $1.itemCount }
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
            let inventory = try await trackingService.inventoryRepository.fetchInventory(forItem: item.natural_key)
            if inventory.isEmpty {
                itemsWithoutInventory.append(item)
            }
            
            // Check for tags
            let tags = try await tagsRepository.fetchTags(forItem: item.natural_key)
            if tags.isEmpty {
                itemsWithoutTags.append(item)
            }
            
            // Check for data consistency
            let validation = try await trackingService.validateInventoryConsistency(for: item.natural_key)
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
    
    private func applyFilters(
        _ items: [GlassItemModel],
        using request: GlassItemSearchRequest
    ) async throws -> [GlassItemModel] {
        var filteredItems = items
        
        // Filter by tags
        if !request.tags.isEmpty {
            let itemsWithTags = try await itemTagsRepository.fetchItems(withAllTags: request.tags)
            filteredItems = filteredItems.filter { itemsWithTags.contains($0.natural_key) }
        }
        
        // Filter by manufacturers
        if !request.manufacturers.isEmpty {
            filteredItems = filteredItems.filter { item in
                request.manufacturers.contains(item.manufacturer)
            }
        }
        
        // Filter by COE values
        if !request.coeValues.isEmpty {
            filteredItems = filteredItems.filter { item in
                request.coeValues.contains(item.coe)
            }
        }
        
        // Filter by manufacturer status
        if !request.manufacturerStatuses.isEmpty {
            filteredItems = filteredItems.filter { item in
                request.manufacturerStatuses.contains(item.mfr_status)
            }
        }
        
        // Filter by inventory status
        if let hasInventory = request.hasInventory {
            let itemsWithInventory = Set(try await inventoryTrackingService.inventoryRepository.getItemsWithInventory())
            filteredItems = filteredItems.filter { item in
                let hasInv = itemsWithInventory.contains(item.natural_key)
                return hasInv == hasInventory
            }
        }
        
        // Filter by inventory types
        if !request.inventoryTypes.isEmpty {
            var itemsWithTypes: Set<String> = []
            for type in request.inventoryTypes {
                let itemsOfType = try await inventoryTrackingService.inventoryRepository.getItemsWithInventory(ofType: type)
                itemsWithTypes.formUnion(itemsOfType)
            }
            filteredItems = filteredItems.filter { item in
                itemsWithTypes.contains(item.natural_key)
            }
        }
        
        return filteredItems
    }
    
    private func sortItems(
        _ items: [CompleteInventoryItemModel],
        by sortOption: GlassItemSortOption
    ) -> [CompleteInventoryItemModel] {
        switch sortOption {
        case .name:
            return items.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
                item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            }
        case .manufacturer:
            return items.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
                if item1.glassItem.manufacturer != item2.glassItem.manufacturer {
                    return item1.glassItem.manufacturer.localizedCaseInsensitiveCompare(item2.glassItem.manufacturer) == .orderedAscending
                }
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            }
        case .coe:
            return items.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
                if item1.glassItem.coe != item2.glassItem.coe {
                    return item1.glassItem.coe < item2.glassItem.coe
                }
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            }
        case .totalQuantity:
            return items.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
                if item1.totalQuantity != item2.totalQuantity {
                    return item1.totalQuantity > item2.totalQuantity // Descending for quantity
                }
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            }
        case .natural_key:
            return items.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
                item1.glassItem.natural_key < item2.glassItem.natural_key
            }
        }
    }
    
    private func getSystemOverview() async throws -> CatalogOverviewModel {
        let trackingService = inventoryTrackingService
        let tagsRepository = itemTagsRepository
        
        let totalItems = try await glassItemRepository.fetchItems(matching: nil).count
        let totalManufacturers = try await glassItemRepository.getDistinctManufacturers().count
        let totalTags = try await tagsRepository.getAllTags().count
        let itemsWithInventory = try await trackingService.inventoryRepository.getItemsWithInventory().count
        let lowStockItems = try await trackingService.getLowStockItems(threshold: 5.0).count
        
        return CatalogOverviewModel(
            totalItems: totalItems,
            totalManufacturers: totalManufacturers,
            totalTags: totalTags,
            itemsWithInventory: itemsWithInventory,
            lowStockItems: lowStockItems,
            systemType: "GlassItem"
        )
    }
}
