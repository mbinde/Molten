//
//  InventoryTrackingService.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Service for orchestrating inventory operations across multiple repositories
/// Coordinates GlassItem, Inventory, Location, and ItemTags data
/// Follows clean architecture: orchestrates repositories, delegates business logic to models
@preconcurrency
class InventoryTrackingService {
    
    // MARK: - Dependencies

    nonisolated(unsafe) private let glassItemRepository: GlassItemRepository
    nonisolated(unsafe) private let _inventoryRepository: InventoryRepository
    nonisolated(unsafe) private let _itemTagsRepository: ItemTagsRepository

    // MARK: - Exposed Dependencies for Advanced Operations

    /// Direct access to inventory repository for advanced inventory operations
    /// This allows the CatalogService and other external services to perform complex inventory queries
    nonisolated var inventoryRepository: InventoryRepository {
        return _inventoryRepository
    }

    /// Direct access to item tags repository for advanced tag operations
    /// This allows external services to perform complex tag queries
    nonisolated var itemTagsRepository: ItemTagsRepository {
        return _itemTagsRepository
    }

    // MARK: - Initialization

    nonisolated init(
        glassItemRepository: GlassItemRepository,
        inventoryRepository: InventoryRepository,
        itemTagsRepository: ItemTagsRepository
    ) {
        self.glassItemRepository = glassItemRepository
        self._inventoryRepository = inventoryRepository
        self._itemTagsRepository = itemTagsRepository
    }
    
    // MARK: - Complete Item Operations
    
    /// Create a complete glass item with inventory and tags
    /// - Parameters:
    ///   - glassItem: The glass item to create
    ///   - initialInventory: Optional initial inventory records
    ///   - tags: Optional initial tags
    /// - Returns: Complete inventory tracking model
    func createCompleteItem(
        _ glassItem: GlassItemModel,
        initialInventory: [InventoryModel] = [],
        tags: [String] = []
    ) async throws -> CompleteInventoryItemModel {
        
        // 1. Create the glass item
        let createdGlassItem = try await glassItemRepository.createItem(glassItem)
        
        // 2. Add tags if provided
        if !tags.isEmpty {
            try await _itemTagsRepository.addTags(tags, toItem: createdGlassItem.stable_id)
        }
        
        // 3. Create inventory records if provided
        var createdInventory: [InventoryModel] = []
        if !initialInventory.isEmpty {
            // Update inventory records to use the created item's stable_id
            let updatedInventoryRecords = initialInventory.map { inventory in
                InventoryModel(
                    id: inventory.id,
                    item_stable_id: createdGlassItem.stable_id,
                    type: inventory.type,
                    quantity: inventory.quantity,
                    location: inventory.location
                )
            }
            createdInventory = try await self.inventoryRepository.createInventories(updatedInventoryRecords)
        }

        // 4. Get the tags that were created
        let createdTags = try await _itemTagsRepository.fetchTags(forItem: createdGlassItem.stable_id)

        // 5. Return complete model (locations are now part of inventory records)
        return CompleteInventoryItemModel(
            glassItem: createdGlassItem,
            inventory: createdInventory,
            tags: createdTags,
            userTags: []
        )
    }
    
    /// Get complete item information with all associated data
    /// - Parameter stableId: The natural key of the glass item
    /// - Returns: Complete inventory tracking model or nil if not found
    func getCompleteItem(stableId: String) async throws -> CompleteInventoryItemModel? {
        // 1. Get the glass item
        guard let glassItem = try await glassItemRepository.fetchItem(byStableId: stableId) else {
            return nil
        }

        // 2. Get all inventory for this item (includes locations as part of each record)
        let inventory = try await self.inventoryRepository.fetchInventory(forItem: stableId)

        // 3. Get all tags for this item
        let tags = try await _itemTagsRepository.fetchTags(forItem: stableId)

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: tags,
            userTags: []
        )
    }
    
    /// Update complete item information
    /// - Parameters:
    ///   - stableId: The natural key of the glass item
    ///   - updatedGlassItem: Updated glass item information
    ///   - updatedTags: New set of tags (replaces existing)
    /// - Returns: Updated complete inventory tracking model
    func updateCompleteItem(
        stableId: String,
        updatedGlassItem: GlassItemModel,
        updatedTags: [String]? = nil
    ) async throws -> CompleteInventoryItemModel {

        // 1. Update the glass item
        _ = try await glassItemRepository.updateItem(updatedGlassItem)

        // 2. Update tags if provided
        if let newTags = updatedTags {
            try await _itemTagsRepository.setTags(newTags, forItem: stableId)
        }
        
        // 3. Get complete updated information
        guard let completeItem = try await getCompleteItem(stableId: stableId) else {
            throw InventoryTrackingServiceError.itemNotFound(stableId)
        }
        
        return completeItem
    }
    
    // MARK: - Inventory Management Operations
    
    /// Add inventory to an item with optional location
    /// - Parameters:
    ///   - quantity: Quantity to add
    ///   - type: Inventory type
    ///   - stableId: Item natural key
    ///   - location: Optional location where inventory is stored
    /// - Returns: Updated inventory model
    func addInventory(
        quantity: Double,
        type: String,
        toItem stableId: String,
        atLocation location: String? = nil
    ) async throws -> InventoryModel {

        // 1. Verify the glass item exists
        guard let _ = try await glassItemRepository.fetchItem(byStableId: stableId) else {
            throw InventoryTrackingServiceError.itemNotFound(stableId)
        }

        // 2. Create new inventory record with location
        let newInventory = InventoryModel(
            item_stable_id: stableId,
            type: type,
            quantity: quantity,
            location: location
        )

        return try await self.inventoryRepository.createInventory(newInventory)
    }
    
    /// Get inventory summary for an item
    /// - Parameter stableId: Item natural key
    /// - Returns: Inventory summary with location details
    func getInventorySummary(for stableId: String) async throws -> DetailedInventorySummaryModel? {
        guard let summary = try await self.inventoryRepository.getInventorySummary(forItem: stableId) else {
            return nil
        }

        // Get detailed location information from inventory records
        let inventory = try await self.inventoryRepository.fetchInventory(forItem: stableId)
        var locationDetails: [String: [(location: String, quantity: Double)]] = [:]

        for inventoryRecord in inventory {
            if let location = inventoryRecord.location {
                let locationInfo = (location: location, quantity: inventoryRecord.quantity)
                if locationDetails[inventoryRecord.type] == nil {
                    locationDetails[inventoryRecord.type] = []
                }
                locationDetails[inventoryRecord.type]?.append(locationInfo)
            }
        }

        return DetailedInventorySummaryModel(
            summary: summary,
            locationDetails: locationDetails
        )
    }
    
    // MARK: - Search and Discovery Operations
    
    /// Search for items with inventory, including tag and inventory filtering  
    /// - Parameters:
    ///   - searchText: Text to search in item names, manufacturers, notes
    ///   - tags: Optional tags to filter by
    ///   - hasInventory: Inventory filtering (true=only with inventory, false=no filtering, nil=no filtering)
    ///   - inventoryTypes: Optional filter by inventory types
    /// - Returns: Array of complete inventory items matching criteria
    ///
    /// Note: hasInventory parameter semantics for backward compatibility:
    /// - nil: No inventory filtering (include all items) 
    /// - true: Only items that have inventory
    /// - false: No inventory filtering (same as nil, for backward compatibility)
    func searchItems(
        text searchText: String,
        withTags tags: [String] = [],
        hasInventory: Bool? = nil,
        inventoryTypes: [String] = []
    ) async throws -> [CompleteInventoryItemModel] {
        
        // 1. Search glass items by text - this should always work
        var candidateItems = try await glassItemRepository.searchItems(text: searchText)
        
        print("🔍 SEARCH DEBUG: Initial search for '\(searchText)' found \(candidateItems.count) items")
        for item in candidateItems {
            print("  - '\(item.name)' (key: \(item.stable_id))")
        }
        
        // 2. Filter by tags if specified
        if !tags.isEmpty {
            print("🔍 SEARCH DEBUG: Filtering by tags: \(tags)")
            let itemsWithTags = try await _itemTagsRepository.fetchItems(withAllTags: tags)
            print("🔍 SEARCH DEBUG: Items with all required tags: \(itemsWithTags)")
            candidateItems = candidateItems.filter { item in
                itemsWithTags.contains(item.stable_id)
            }
            print("🔍 SEARCH DEBUG: After tag filtering: \(candidateItems.count) items")
        }
        
        // 3. Filter by inventory requirements if specified
        // FIXED: hasInventory: false now means "no filtering" for backward compatibility
        if let requiresInventory = hasInventory, requiresInventory == true {
            print("🔍 SEARCH DEBUG: Filtering to only items WITH inventory")
            let itemsWithInventory = Set(try await self.inventoryRepository.getItemsWithInventory())
            print("🔍 SEARCH DEBUG: Items with inventory: \(itemsWithInventory)")
            candidateItems = candidateItems.filter { item in
                let hasInv = itemsWithInventory.contains(item.stable_id)
                print("🔍 SEARCH DEBUG: Item '\(item.name)' hasInventory=\(hasInv), keeping=\(hasInv)")
                return hasInv
            }
            print("🔍 SEARCH DEBUG: After inventory filtering: \(candidateItems.count) items")
        } else {
            print("🔍 SEARCH DEBUG: No inventory filtering (hasInventory = \(hasInventory?.description ?? "nil"))")
        }
        
        // 4. Filter by inventory types if specified
        if !inventoryTypes.isEmpty {
            print("🔍 SEARCH DEBUG: Filtering by inventory types: \(inventoryTypes)")
            var itemsWithTypes: Set<String> = []
            for type in inventoryTypes {
                let itemsOfType = try await self.inventoryRepository.getItemsWithInventory(ofType: type)
                itemsWithTypes.formUnion(itemsOfType)
            }
            print("🔍 SEARCH DEBUG: Items with specified inventory types: \(itemsWithTypes)")
            candidateItems = candidateItems.filter { item in
                itemsWithTypes.contains(item.stable_id)
            }
            print("🔍 SEARCH DEBUG: After inventory type filtering: \(candidateItems.count) items")
        } else {
            print("🔍 SEARCH DEBUG: No inventory type filtering")
        }
        
        print("🔍 SEARCH DEBUG: Final candidate items: \(candidateItems.count)")
        
        // 5. Build complete models for results
        var results: [CompleteInventoryItemModel] = []
        for glassItem in candidateItems {
            if let completeItem = try await getCompleteItem(stableId: glassItem.stable_id) {
                results.append(completeItem)
                print("🔍 SEARCH DEBUG: Added complete item: '\(completeItem.glassItem.name)'")
            } else {
                print("🔍 SEARCH DEBUG: Failed to get complete item for: '\(glassItem.name)'")
            }
        }
        
        print("🔍 SEARCH DEBUG: Final results: \(results.count) complete items")
        return results
    }
    
    /// Get low stock items based on minimums
    /// - Parameter threshold: Optional override threshold
    /// - Returns: Array of low stock items with details
    func getLowStockItems(threshold: Double? = nil) async throws -> [LowStockDetailModel] {
        // Get items with low inventory
        let defaultThreshold = threshold ?? 5.0 // Default low stock threshold
        let lowInventoryItems = try await self.inventoryRepository.getItemsWithLowInventory(threshold: defaultThreshold)
        
        var results: [LowStockDetailModel] = []
        
        for (stableId, type, quantity) in lowInventoryItems {
            // Get the glass item details
            if let glassItem = try await glassItemRepository.fetchItem(byStableId: stableId) {
                // Get tags for context
                let tags = try await _itemTagsRepository.fetchTags(forItem: stableId)
                
                results.append(LowStockDetailModel(
                    glassItem: glassItem,
                    type: type,
                    currentQuantity: quantity,
                    threshold: defaultThreshold,
                    tags: tags
                ))
            }
        }
        
        return results.sorted { $0.currentQuantity < $1.currentQuantity }
    }
    
    // MARK: - Validation Operations
    
    /// Validate inventory consistency across repositories
    /// - Parameter stableId: Item to validate
    /// - Returns: Validation result with any discrepancies
    func validateInventoryConsistency(for stableId: String) async throws -> InventoryConsistencyValidation {
        guard try await glassItemRepository.fetchItem(byStableId: stableId) != nil else {
            return InventoryConsistencyValidation(
                stableId: stableId,
                isValid: false,
                errors: ["Glass item not found"]
            )
        }

        let inventory = try await self.inventoryRepository.fetchInventory(forItem: stableId)
        var errors: [String] = []

        // Check for negative quantities
        for inventoryRecord in inventory {
            if inventoryRecord.quantity < 0 {
                errors.append("Inventory record \(inventoryRecord.id) has negative quantity: \(inventoryRecord.quantity)")
            }
        }

        return InventoryConsistencyValidation(
            stableId: stableId,
            isValid: errors.isEmpty,
            errors: errors
        )
    }
}

/// Detailed inventory summary with location information
nonisolated struct DetailedInventorySummaryModel {
    let summary: InventorySummaryModel
    let locationDetails: [String: [(location: String, quantity: Double)]]
}

/// Low stock item with contextual information
nonisolated struct LowStockDetailModel {
    let glassItem: GlassItemModel
    let type: String
    let currentQuantity: Double
    let threshold: Double
    let tags: [String]

    nonisolated var shortfall: Double {
        threshold - currentQuantity
    }
}

/// Inventory consistency validation result
nonisolated struct InventoryConsistencyValidation {
    let stableId: String
    let isValid: Bool
    let errors: [String]
}

// MARK: - Service Errors

enum InventoryTrackingServiceError: Error, LocalizedError {
    case itemNotFound(String)
    case inconsistentData(String)
    case invalidOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound(let stableId):
            return "Glass item not found: \(stableId)"
        case .inconsistentData(let message):
            return "Data inconsistency detected: \(message)"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        }
    }
}
