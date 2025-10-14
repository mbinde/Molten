//
//  CatalogService.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//  Updated by Assistant on 10/14/25.
//

import Foundation

/// Service layer that handles catalog business logic using repository pattern
/// ENHANCED: Upgraded with improved new GlassItem system support, better error handling,
/// enhanced search capabilities, bulk operations, and migration support
class CatalogService {
    
    // MARK: - Dependencies
    
    // Legacy dependencies (for backward compatibility during transition)
    private let legacyCatalogRepository: CatalogItemRepository?
    private let legacyInventoryService: InventoryService?
    
    // New GlassItem system dependencies
    private let glassItemRepository: GlassItemRepository?
    private let inventoryTrackingService: InventoryTrackingService?
    private let shoppingListService: ShoppingListService?
    private let itemTagsRepository: ItemTagsRepository?
    
    // MARK: - Exposed Dependencies for Advanced Operations
    
    /// Direct access to inventory repository for advanced inventory operations
    /// This allows external code to perform complex inventory queries when needed
    var inventoryRepository: InventoryRepository? {
        return inventoryTrackingService?.inventoryRepository
    }
    
    // MARK: - Initialization
    
    /// Initialize with legacy repositories (backward compatibility)
    init(repository: CatalogItemRepository, inventoryService: InventoryService? = nil) {
        self.legacyCatalogRepository = repository
        self.legacyInventoryService = inventoryService
        
        // New system not initialized
        self.glassItemRepository = nil
        self.inventoryTrackingService = nil
        self.shoppingListService = nil
        self.itemTagsRepository = nil
    }
    
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
        
        // Legacy system not initialized
        self.legacyCatalogRepository = nil
        self.legacyInventoryService = nil
    }
    
    /// Enhanced initializer with all dependencies for migration scenarios
    /// Use this when you need both legacy and new system support simultaneously
    init(
        legacyCatalogRepository: CatalogItemRepository?,
        legacyInventoryService: InventoryService?,
        glassItemRepository: GlassItemRepository?,
        inventoryTrackingService: InventoryTrackingService?,
        shoppingListService: ShoppingListService?,
        itemTagsRepository: ItemTagsRepository?
    ) {
        self.legacyCatalogRepository = legacyCatalogRepository
        self.legacyInventoryService = legacyInventoryService
        self.glassItemRepository = glassItemRepository
        self.inventoryTrackingService = inventoryTrackingService
        self.shoppingListService = shoppingListService
        self.itemTagsRepository = itemTagsRepository
    }
    
    // MARK: - System Detection
    
    /// Determine which system is being used
    private var isUsingNewSystem: Bool {
        return glassItemRepository != nil
    }
    
    // MARK: - Legacy System Support (Backward Compatibility)
    
    /// Get all catalog items (Legacy)
    func getAllItems() async throws -> [CatalogItemModel] {
        guard let repository = legacyCatalogRepository else {
            throw CatalogServiceError.legacySystemNotAvailable
        }
        return try await repository.fetchItems(matching: nil)
    }
    
    /// Search catalog items by text (Legacy)
    func searchItems(searchText: String) async throws -> [CatalogItemModel] {
        guard let repository = legacyCatalogRepository else {
            throw CatalogServiceError.legacySystemNotAvailable
        }
        return try await repository.searchItems(text: searchText)
    }
    
    /// Create a new catalog item (Legacy)
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        guard let repository = legacyCatalogRepository else {
            throw CatalogServiceError.legacySystemNotAvailable
        }
        return try await repository.createItem(item)
    }
    
    /// Update an existing catalog item (Legacy)
    func updateItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        guard let repository = legacyCatalogRepository else {
            throw CatalogServiceError.legacySystemNotAvailable
        }
        return try await repository.updateItem(item)
    }
    
    /// Delete a catalog item and cascade delete related inventory items (Legacy)
    func deleteItem(withId id: String) async throws {
        guard let repository = legacyCatalogRepository else {
            throw CatalogServiceError.legacySystemNotAvailable
        }
        
        // First, get the item to find its code for inventory deletion
        let allItems = try await repository.fetchItems(matching: nil)
        guard let itemToDelete = allItems.first(where: { $0.id == id }) else {
            throw CatalogServiceError.itemNotFound
        }
        
        // Cascade delete: Remove all inventory items that reference this catalog code
        if let inventoryService = legacyInventoryService {
            try await inventoryService.deleteItemsByCatalogCode(itemToDelete.code)
        }
        
        // Delete the catalog item
        try await repository.deleteItem(id: id)
    }
    
    /// Determine if an existing item should be updated with new data (Legacy)
    func shouldUpdateItem(existing: CatalogItemModel, with new: CatalogItemModel) async throws -> Bool {
        return CatalogItemModel.hasChanges(existing: existing, new: new)
    }
    
    // MARK: - Enhanced New GlassItem System Support
    
    /// Get all glass items with complete information and flexible sorting
    func getAllGlassItems(
        sortBy: GlassItemSortOption = .name,
        includeWithoutInventory: Bool = true
    ) async throws -> [CompleteInventoryItemModel] {
        guard let repository = glassItemRepository,
              let trackingService = inventoryTrackingService else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        // Get all glass items
        let glassItems = try await repository.fetchItems(matching: nil)
        
        // Filter by inventory if requested
        let filteredItems: [GlassItemModel]
        if includeWithoutInventory {
            filteredItems = glassItems
        } else {
            let itemsWithInventory = Set(try await trackingService.inventoryRepository.getItemsWithInventory())
            filteredItems = glassItems.filter { itemsWithInventory.contains($0.naturalKey) }
        }
        
        // Convert to complete models
        var completeItems: [CompleteInventoryItemModel] = []
        for glassItem in filteredItems {
            if let completeItem = try await trackingService.getCompleteItem(naturalKey: glassItem.naturalKey) {
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
        guard let repository = glassItemRepository,
              let trackingService = inventoryTrackingService else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        // Start with text search if provided
        var candidateItems: [GlassItemModel]
        if let searchText = request.searchText, !searchText.isEmpty {
            candidateItems = try await repository.searchItems(text: searchText)
        } else {
            candidateItems = try await repository.fetchItems(matching: nil)
        }
        
        // Apply filters
        candidateItems = try await applyFilters(candidateItems, using: request)
        
        // Convert to complete models
        var completeItems: [CompleteInventoryItemModel] = []
        for glassItem in candidateItems {
            if let completeItem = try await trackingService.getCompleteItem(naturalKey: glassItem.naturalKey) {
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
        guard let trackingService = inventoryTrackingService else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
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
        guard let repository = glassItemRepository,
              let trackingService = inventoryTrackingService else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        // Validate natural keys and generate if needed
        var glassItemsToCreate: [GlassItemModel] = []
        for request in items {
            let naturalKey = try await generateOrValidateNaturalKey(
                manufacturer: request.manufacturer,
                sku: request.sku,
                customNaturalKey: request.customNaturalKey
            )
            
            let glassItem = GlassItemModel(
                naturalKey: naturalKey,
                name: request.name,
                sku: request.sku,
                manufacturer: request.manufacturer,
                mfrNotes: request.mfrNotes,
                coe: request.coe,
                url: request.url,
                mfrStatus: request.mfrStatus
            )
            glassItemsToCreate.append(glassItem)
        }
        
        // Create all glass items in batch
        let createdGlassItems = try await repository.createItems(glassItemsToCreate)
        
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
        guard let repository = glassItemRepository else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        if let customKey = customNaturalKey {
            // Validate that the custom natural key doesn't already exist
            let exists = try await repository.naturalKeyExists(customKey)
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
            return try await repository.generateNextNaturalKey(manufacturer: manufacturer, sku: sku)
        }
    }
    
    /// Check if a natural key is available
    func isNaturalKeyAvailable(_ naturalKey: String) async throws -> Bool {
        guard let repository = glassItemRepository else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        return !(try await repository.naturalKeyExists(naturalKey))
    }
    
    /// Get the next available natural key for a manufacturer and SKU
    func getNextNaturalKey(manufacturer: String, sku: String) async throws -> String {
        guard let repository = glassItemRepository else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        return try await repository.generateNextNaturalKey(manufacturer: manufacturer, sku: sku)
    }
    
    /// Update a glass item with comprehensive data
    func updateGlassItem(
        naturalKey: String,
        updatedGlassItem: GlassItemModel,
        updatedTags: [String]? = nil
    ) async throws -> CompleteInventoryItemModel {
        guard let trackingService = inventoryTrackingService else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        return try await trackingService.updateCompleteItem(
            naturalKey: naturalKey,
            updatedGlassItem: updatedGlassItem,
            updatedTags: updatedTags
        )
    }
    
    /// Delete a glass item and all related data
    func deleteGlassItem(naturalKey: String) async throws {
        guard let repository = glassItemRepository,
              let inventoryRepository = inventoryTrackingService?.inventoryRepository,
              let tagsRepository = itemTagsRepository else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        // Cascade delete all related data
        // 1. Delete all inventory for this item (this will also cascade to locations)
        try await inventoryRepository.deleteInventory(forItem: naturalKey)
        
        // 2. Remove all tags for this item
        try await tagsRepository.removeAllTags(fromItem: naturalKey)
        
        // 3. Remove any shopping list minimums for this item
        if let shoppingService = shoppingListService {
            try await shoppingService.itemMinimumRepository.deleteMinimums(forItem: naturalKey)
        }
        
        // 4. Finally, delete the glass item itself
        try await repository.deleteItem(naturalKey: naturalKey)
    }
    
    /// Delete multiple glass items in a batch operation
    func deleteGlassItems(naturalKeys: [String]) async throws {
        guard let repository = glassItemRepository,
              let inventoryRepository = inventoryTrackingService?.inventoryRepository,
              let tagsRepository = itemTagsRepository else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        // Cascade delete all related data for each item
        for naturalKey in naturalKeys {
            // 1. Delete all inventory for this item (this will also cascade to locations)
            try await inventoryRepository.deleteInventory(forItem: naturalKey)
            
            // 2. Remove all tags for this item
            try await tagsRepository.removeAllTags(fromItem: naturalKey)
            
            // 3. Remove any shopping list minimums for this item
            if let shoppingService = shoppingListService {
                try await shoppingService.itemMinimumRepository.deleteMinimums(forItem: naturalKey)
            }
        }
        
        // 4. Finally, delete all glass items
        try await repository.deleteItems(naturalKeys: naturalKeys)
    }
    
    // MARK: - Migration Support Operations
    
    /// Check the migration status of the catalog system
    func getMigrationStatus() async throws -> MigrationStatusModel {
        var hasLegacyData = false
        var hasNewData = false
        var legacyItemCount = 0
        var newItemCount = 0
        
        // Check legacy system
        if let legacyRepo = legacyCatalogRepository {
            do {
                let legacyItems = try await legacyRepo.fetchItems(matching: nil)
                legacyItemCount = legacyItems.count
                hasLegacyData = legacyItemCount > 0
            } catch {
                // Legacy system might not be available
            }
        }
        
        // Check new system
        if let newRepo = glassItemRepository {
            do {
                let newItems = try await newRepo.fetchItems(matching: nil)
                newItemCount = newItems.count
                hasNewData = newItemCount > 0
            } catch {
                // New system might not be available
            }
        }
        
        let migrationStage: MigrationStage
        if !hasLegacyData && !hasNewData {
            migrationStage = .empty
        } else if hasLegacyData && !hasNewData {
            migrationStage = .legacyOnly
        } else if hasLegacyData && hasNewData {
            migrationStage = .transitional
        } else {
            migrationStage = .newSystemOnly
        }
        
        return MigrationStatusModel(
            migrationStage: migrationStage,
            legacyItemCount: legacyItemCount,
            newItemCount: newItemCount,
            canMigrate: hasLegacyData && glassItemRepository != nil,
            canRollback: hasNewData && legacyCatalogRepository != nil
        )
    }
    
    /// Validate that the catalog system is ready for a specific operation
    func validateSystemReadiness(for operation: CatalogOperation) async throws {
        let migrationStatus = try await getMigrationStatus()
        
        switch operation {
        case .legacyRead, .legacyWrite:
            guard migrationStatus.migrationStage == .legacyOnly || migrationStatus.migrationStage == .transitional else {
                throw CatalogServiceError.systemNotReadyForOperation(operation, "Legacy system not available or no legacy data")
            }
        case .newRead, .newWrite:
            guard migrationStatus.migrationStage == .newSystemOnly || migrationStatus.migrationStage == .transitional else {
                throw CatalogServiceError.systemNotReadyForOperation(operation, "New system not available or no new data")
            }
        case .migration:
            guard migrationStatus.canMigrate else {
                throw CatalogServiceError.systemNotReadyForOperation(operation, "Migration not possible - either no legacy data or new system not available")
            }
        case .rollback:
            guard migrationStatus.canRollback else {
                throw CatalogServiceError.systemNotReadyForOperation(operation, "Rollback not possible - either no new data or legacy system not available")
            }
        }
    }
    
    // MARK: - Discovery and Analytics Operations
    
    /// Get catalog overview statistics
    func getCatalogOverview() async throws -> CatalogOverviewModel {
        if isUsingNewSystem {
            return try await getNewSystemOverview()
        } else {
            return try await getLegacySystemOverview()
        }
    }
    
    /// Get manufacturers with item counts
    func getManufacturerStatistics() async throws -> [ManufacturerStatisticsModel] {
        guard let repository = glassItemRepository else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        let manufacturers = try await repository.getDistinctManufacturers()
        var statistics: [ManufacturerStatisticsModel] = []
        
        for manufacturer in manufacturers {
            let items = try await repository.fetchItems(byManufacturer: manufacturer)
            statistics.append(ManufacturerStatisticsModel(
                name: manufacturer,
                itemCount: items.count
            ))
        }
        
        return statistics.sorted { $0.itemCount > $1.itemCount }
    }
    
    /// Get popular tags with usage counts
    func getPopularTags(limit: Int = 20) async throws -> [(tag: String, count: Int)] {
        guard let tagsRepository = itemTagsRepository else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        return try await tagsRepository.getTagsWithCounts(minCount: 1)
                                     .prefix(limit)
                                     .map { (tag: $0.tag, count: $0.count) }
    }
    
    /// Get items that might need attention (no inventory, missing tags, etc.)
    func getItemsNeedingAttention() async throws -> ItemAttentionReportModel {
        guard let repository = glassItemRepository,
              let trackingService = inventoryTrackingService,
              let tagsRepository = itemTagsRepository else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        let allItems = try await repository.fetchItems(matching: nil)
        
        var itemsWithoutInventory: [GlassItemModel] = []
        var itemsWithoutTags: [GlassItemModel] = []
        var itemsWithInconsistentData: [GlassItemModel] = []
        
        for item in allItems {
            // Check for inventory
            let inventory = try await trackingService.inventoryRepository.fetchInventory(forItem: item.naturalKey)
            if inventory.isEmpty {
                itemsWithoutInventory.append(item)
            }
            
            // Check for tags
            let tags = try await tagsRepository.fetchTags(forItem: item.naturalKey)
            if tags.isEmpty {
                itemsWithoutTags.append(item)
            }
            
            // Check for data consistency
            let validation = try await trackingService.validateInventoryConsistency(for: item.naturalKey)
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
        if !request.tags.isEmpty, let tagsRepository = itemTagsRepository {
            let itemsWithTags = try await tagsRepository.fetchItems(withAllTags: request.tags)
            filteredItems = filteredItems.filter { itemsWithTags.contains($0.naturalKey) }
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
                request.manufacturerStatuses.contains(item.mfrStatus)
            }
        }
        
        // Filter by inventory status
        if let hasInventory = request.hasInventory,
           let trackingService = inventoryTrackingService {
            let itemsWithInventory = Set(try await trackingService.inventoryRepository.getItemsWithInventory())
            filteredItems = filteredItems.filter { item in
                let hasInv = itemsWithInventory.contains(item.naturalKey)
                return hasInv == hasInventory
            }
        }
        
        // Filter by inventory types
        if !request.inventoryTypes.isEmpty,
           let trackingService = inventoryTrackingService {
            var itemsWithTypes: Set<String> = []
            for type in request.inventoryTypes {
                let itemsOfType = try await trackingService.inventoryRepository.getItemsWithInventory(ofType: type)
                itemsWithTypes.formUnion(itemsOfType)
            }
            filteredItems = filteredItems.filter { item in
                itemsWithTypes.contains(item.naturalKey)
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
            return items.sorted { $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending }
        case .manufacturer:
            return items.sorted { 
                if $0.glassItem.manufacturer != $1.glassItem.manufacturer {
                    return $0.glassItem.manufacturer.localizedCaseInsensitiveCompare($1.glassItem.manufacturer) == .orderedAscending
                }
                return $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending
            }
        case .coe:
            return items.sorted { 
                if $0.glassItem.coe != $1.glassItem.coe {
                    return $0.glassItem.coe < $1.glassItem.coe
                }
                return $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending
            }
        case .totalQuantity:
            return items.sorted { 
                if $0.totalQuantity != $1.totalQuantity {
                    return $0.totalQuantity > $1.totalQuantity // Descending for quantity
                }
                return $0.glassItem.name.localizedCaseInsensitiveCompare($1.glassItem.name) == .orderedAscending
            }
        case .naturalKey:
            return items.sorted { $0.glassItem.naturalKey < $1.glassItem.naturalKey }
        }
    }
    
    private func getNewSystemOverview() async throws -> CatalogOverviewModel {
        guard let repository = glassItemRepository,
              let trackingService = inventoryTrackingService,
              let tagsRepository = itemTagsRepository else {
            throw CatalogServiceError.newSystemNotAvailable
        }
        
        let totalItems = try await repository.fetchItems(matching: nil).count
        let totalManufacturers = try await repository.getDistinctManufacturers().count
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
    
    private func getLegacySystemOverview() async throws -> CatalogOverviewModel {
        guard let repository = legacyCatalogRepository else {
            throw CatalogServiceError.legacySystemNotAvailable
        }
        
        let totalItems = try await repository.fetchItems(matching: nil).count
        
        return CatalogOverviewModel(
            totalItems: totalItems,
            totalManufacturers: 0,
            totalTags: 0,
            itemsWithInventory: 0,
            lowStockItems: 0,
            systemType: "Legacy"
        )
    }
}

// MARK: - Enhanced Service Models

/// Request model for creating glass items with comprehensive options
struct GlassItemCreationRequest {
    let name: String
    let sku: String
    let manufacturer: String
    let mfrNotes: String?
    let coe: Int32
    let url: String?
    let mfrStatus: String
    let customNaturalKey: String? // Optional custom natural key
    let initialInventory: [InventoryModel]
    let tags: [String]
    
    init(
        name: String,
        sku: String,
        manufacturer: String,
        mfrNotes: String? = nil,
        coe: Int32,
        url: String? = nil,
        mfrStatus: String = "available",
        customNaturalKey: String? = nil,
        initialInventory: [InventoryModel] = [],
        tags: [String] = []
    ) {
        self.name = name
        self.sku = sku
        self.manufacturer = manufacturer
        self.mfrNotes = mfrNotes
        self.coe = coe
        self.url = url
        self.mfrStatus = mfrStatus
        self.customNaturalKey = customNaturalKey
        self.initialInventory = initialInventory
        self.tags = tags
    }
}

/// Enhanced search request model with comprehensive filtering
struct GlassItemSearchRequest {
    let searchText: String?
    let tags: [String]
    let manufacturers: [String]
    let coeValues: [Int32]
    let manufacturerStatuses: [String]
    let hasInventory: Bool?
    let inventoryTypes: [String]
    let sortBy: GlassItemSortOption
    let offset: Int?
    let limit: Int?
    
    init(
        searchText: String? = nil,
        tags: [String] = [],
        manufacturers: [String] = [],
        coeValues: [Int32] = [],
        manufacturerStatuses: [String] = [],
        hasInventory: Bool? = nil,
        inventoryTypes: [String] = [],
        sortBy: GlassItemSortOption = .name,
        offset: Int? = nil,
        limit: Int? = nil
    ) {
        self.searchText = searchText
        self.tags = tags
        self.manufacturers = manufacturers
        self.coeValues = coeValues
        self.manufacturerStatuses = manufacturerStatuses
        self.hasInventory = hasInventory
        self.inventoryTypes = inventoryTypes
        self.sortBy = sortBy
        self.offset = offset
        self.limit = limit
    }
    
    func getAppliedFiltersDescription() -> String {
        var filters: [String] = []
        
        if let text = searchText, !text.isEmpty {
            filters.append("Text: '\(text)'")
        }
        if !tags.isEmpty {
            filters.append("Tags: \(tags.joined(separator: ", "))")
        }
        if !manufacturers.isEmpty {
            filters.append("Manufacturers: \(manufacturers.joined(separator: ", "))")
        }
        if !coeValues.isEmpty {
            filters.append("COE: \(coeValues.map(String.init).joined(separator: ", "))")
        }
        if !manufacturerStatuses.isEmpty {
            filters.append("Status: \(manufacturerStatuses.joined(separator: ", "))")
        }
        if let hasInv = hasInventory {
            filters.append("Has Inventory: \(hasInv ? "Yes" : "No")")
        }
        if !inventoryTypes.isEmpty {
            filters.append("Inventory Types: \(inventoryTypes.joined(separator: ", "))")
        }
        
        return filters.isEmpty ? "No filters applied" : filters.joined(separator: "; ")
    }
}

/// Search result model with metadata
struct GlassItemSearchResult {
    let items: [CompleteInventoryItemModel]
    let totalCount: Int
    let hasMore: Bool
    let appliedFilters: String
}

/// Sort options for glass items
enum GlassItemSortOption: CaseIterable {
    case name
    case manufacturer
    case coe
    case totalQuantity
    case naturalKey
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .manufacturer: return "Manufacturer" 
        case .coe: return "COE"
        case .totalQuantity: return "Total Quantity"
        case .naturalKey: return "Natural Key"
        }
    }
}

/// Migration status model
struct MigrationStatusModel {
    let migrationStage: MigrationStage
    let legacyItemCount: Int
    let newItemCount: Int
    let canMigrate: Bool
    let canRollback: Bool
    
    var description: String {
        switch migrationStage {
        case .empty:
            return "No data in either system"
        case .legacyOnly:
            return "Legacy system only (\(legacyItemCount) items)"
        case .transitional:
            return "Both systems active (Legacy: \(legacyItemCount), New: \(newItemCount))"
        case .newSystemOnly:
            return "New system only (\(newItemCount) items)"
        }
    }
}

/// Migration stages
enum MigrationStage {
    case empty
    case legacyOnly
    case transitional
    case newSystemOnly
}

/// Catalog operations for system validation
enum CatalogOperation {
    case legacyRead
    case legacyWrite
    case newRead
    case newWrite
    case migration
    case rollback
}

/// Catalog overview statistics
struct CatalogOverviewModel {
    let totalItems: Int
    let totalManufacturers: Int
    let totalTags: Int
    let itemsWithInventory: Int
    let lowStockItems: Int
    let systemType: String
}

/// Manufacturer statistics
struct ManufacturerStatisticsModel: Identifiable {
    let name: String
    let itemCount: Int
    
    var id: String { name }
}

/// Items needing attention report
struct ItemAttentionReportModel {
    let itemsWithoutInventory: [GlassItemModel]
    let itemsWithoutTags: [GlassItemModel]
    let itemsWithInconsistentData: [GlassItemModel]
    let totalItems: Int
    
    /// Total items needing some kind of attention
    var itemsNeedingAttention: Int {
        Set(itemsWithoutInventory.map { $0.naturalKey })
            .union(Set(itemsWithoutTags.map { $0.naturalKey }))
            .union(Set(itemsWithInconsistentData.map { $0.naturalKey }))
            .count
    }
}

// MARK: - Enhanced Service Errors

/// Errors that can occur in CatalogService
enum CatalogServiceError: Error, LocalizedError {
    case itemNotFound
    case legacySystemNotAvailable
    case newSystemNotAvailable
    case invalidOperation(String)
    case naturalKeyAlreadyExists(String)
    case invalidNaturalKeyFormat(String)
    case systemNotReadyForOperation(CatalogOperation, String)
    case migrationFailed(String)
    case validationFailed([String])
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Catalog item not found"
        case .legacySystemNotAvailable:
            return "Legacy catalog system not initialized"
        case .newSystemNotAvailable:
            return "New GlassItem system not initialized"
        case .invalidOperation(let message):
            return "Invalid catalog operation: \(message)"
        case .naturalKeyAlreadyExists(let naturalKey):
            return "Natural key already exists: \(naturalKey)"
        case .invalidNaturalKeyFormat(let naturalKey):
            return "Invalid natural key format: \(naturalKey)"
        case .systemNotReadyForOperation(let operation, let reason):
            return "System not ready for \(operation): \(reason)"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: "; "))"
        }
    }
}