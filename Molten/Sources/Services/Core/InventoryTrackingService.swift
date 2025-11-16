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
actor InventoryTrackingService {

    // MARK: - Dependencies

    private let glassItemRepository: GlassItemRepository
    let inventoryRepository: InventoryRepository
    private let itemTagsRepository: ItemTagsRepository

    // MARK: - Initialization

    init(
        glassItemRepository: GlassItemRepository,
        inventoryRepository: InventoryRepository,
        itemTagsRepository: ItemTagsRepository
    ) {
        self.glassItemRepository = glassItemRepository
        self.inventoryRepository = inventoryRepository
        self.itemTagsRepository = itemTagsRepository
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

        // 2. Add tags if provided (deduplicate first)
        if !tags.isEmpty {
            let uniqueTags = Array(Set(tags))
            try await itemTagsRepository.addTags(uniqueTags, toItem: createdGlassItem.stable_id)
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
        let createdTags = try await itemTagsRepository.fetchTags(forItem: createdGlassItem.stable_id)

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
        let tags = try await itemTagsRepository.fetchTags(forItem: stableId)

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
            try await itemTagsRepository.setTags(newTags, forItem: stableId)
        }
        
        // 3. Get complete updated information
        guard let completeItem = try await getCompleteItem(stableId: stableId) else {
            throw InventoryTrackingServiceError.itemNotFound(stableId)
        }
        
        return completeItem
    }
    
    // MARK: - Inventory Management Operations

    /// Fetch all inventory records (for bulk operations like data import)
    /// - Parameter predicate: Optional predicate to filter results, nil fetches all
    /// - Returns: Array of inventory models
    func fetchAllInventory(matching predicate: NSPredicate? = nil) async throws -> [InventoryModel] {
        return try await inventoryRepository.fetchInventory(matching: predicate)
    }

    /// Fetch inventory for a specific item
    /// - Parameter stableId: Item natural key
    /// - Returns: Array of inventory records for this item
    func fetchInventory(forItem stableId: String) async throws -> [InventoryModel] {
        return try await inventoryRepository.fetchInventory(forItem: stableId)
    }

    /// Delete inventory record by ID
    /// - Parameter id: UUID of inventory record to delete
    func deleteInventory(id: UUID) async throws {
        try await inventoryRepository.deleteInventory(id: id)
    }

    /// Add quantity to existing inventory or create new record
    /// - Parameters:
    ///   - quantity: Quantity to add
    ///   - stableId: Item natural key
    ///   - type: Inventory type (rod, tube, frit, etc.)
    /// - Returns: Updated inventory model
    func addQuantityToInventory(_ quantity: Double, toItem stableId: String, type: String) async throws -> InventoryModel {
        return try await inventoryRepository.addQuantity(quantity, toItem: stableId, type: type)
    }

    /// Delete all inventory for a specific item
    /// - Parameter stableId: Item natural key
    func deleteInventory(forItem stableId: String) async throws {
        try await inventoryRepository.deleteInventory(forItem: stableId)
    }

    /// Get all items that have inventory
    /// - Returns: Array of item stable IDs
    func getItemsWithInventory() async throws -> [String] {
        return try await inventoryRepository.getItemsWithInventory()
    }

    /// Update an existing inventory record
    /// - Parameter inventory: The inventory model with updated values
    /// - Returns: The updated inventory model
    func updateInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        return try await inventoryRepository.updateInventory(inventory)
    }

    /// Create a new inventory record
    /// - Parameter inventory: The inventory model to create
    /// - Returns: The created inventory model with generated ID
    func createInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        return try await inventoryRepository.createInventory(inventory)
    }

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

        // 1. Verify the glass item exists (keep reference for error messages)
        let glassItem: GlassItemModel
        do {
            if let item = try await glassItemRepository.fetchItem(byStableId: stableId) {
                glassItem = item
            } else {
                throw InventoryTrackingServiceError.itemNotFound(stableId)
            }
        } catch let error as InventoryTrackingServiceError {
            throw error
        } catch {
            throw InventoryTrackingServiceError.persistenceFailed(
                context: "Failed to lookup glass item '\(stableId)'",
                underlyingError: error
            )
        }

        // 2. Validate input parameters
        guard quantity > 0 else {
            throw InventoryTrackingServiceError.invalidOperation("Quantity must be positive (got \(quantity))")
        }

        guard !type.isEmpty else {
            throw InventoryTrackingServiceError.invalidOperation("Inventory type cannot be empty")
        }

        // 3. Create new inventory record with location
        let newInventory = InventoryModel(
            item_stable_id: stableId,
            type: type,
            quantity: quantity,
            location: location
        )

        // 4. Attempt to save with proper error context
        do {
            return try await self.inventoryRepository.createInventory(newInventory)
        } catch {
            // Provide context about what failed, including the glass item name for user clarity
            throw InventoryTrackingServiceError.persistenceFailed(
                context: "Failed to save inventory for '\(glassItem.name)' (\(stableId))",
                underlyingError: error
            )
        }
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

        // Use business logic from model
        return DetailedInventorySummaryModel.from(summary: summary, inventory: inventory)
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
        
        // 2. Filter by tags if specified
        if !tags.isEmpty {
            let itemsWithTags = try await itemTagsRepository.fetchItems(withAllTags: tags)
            candidateItems = candidateItems.filter { item in
                itemsWithTags.contains(item.stable_id)
            }
        }
        
        // 3. Filter by inventory requirements if specified
        // FIXED: hasInventory: false now means "no filtering" for backward compatibility
        if let requiresInventory = hasInventory, requiresInventory == true {
            let itemsWithInventory = Set(try await self.inventoryRepository.getItemsWithInventory())
            candidateItems = candidateItems.filter { item in
                let hasInv = itemsWithInventory.contains(item.stable_id)
                return hasInv
            }
        }
        
        // 4. Filter by inventory types if specified
        if !inventoryTypes.isEmpty {
            var itemsWithTypes: Set<String> = []
            for type in inventoryTypes {
                let itemsOfType = try await self.inventoryRepository.getItemsWithInventory(ofType: type)
                itemsWithTypes.formUnion(itemsOfType)
            }
            candidateItems = candidateItems.filter { item in
                itemsWithTypes.contains(item.stable_id)
            }
        }
        
        // 5. Build complete models for results
        var results: [CompleteInventoryItemModel] = []
        for glassItem in candidateItems {
            if let completeItem = try await getCompleteItem(stableId: glassItem.stable_id) {
                results.append(completeItem)
            }
        }
        
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
                let tags = try await itemTagsRepository.fetchTags(forItem: stableId)
                
                results.append(LowStockDetailModel(
                    glassItem: glassItem,
                    type: type,
                    currentQuantity: quantity,
                    threshold: defaultThreshold,
                    tags: tags
                ))
            }
        }
        
        return results.sorted() // Uses Comparable conformance from model
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

        // Note: Negative quantity validation now enforced in InventoryModel.init
        // No need to check here as model guarantees non-negative quantities

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

    /// Business Logic: Aggregate inventory by type and location
    /// - Parameters:
    ///   - summary: The base inventory summary
    ///   - inventory: Inventory records to aggregate
    /// - Returns: Detailed summary with location information grouped by type
    static func from(summary: InventorySummaryModel, inventory: [InventoryModel]) -> DetailedInventorySummaryModel {
        var locationDetails: [String: [(location: String, quantity: Double)]] = [:]

        for inventoryRecord in inventory {
            if let location = inventoryRecord.location {
                let locationInfo = (location: location, quantity: inventoryRecord.quantity)
                let typeKey = inventoryRecord.type
                if locationDetails[typeKey] == nil {
                    locationDetails[typeKey] = []
                }
                locationDetails[typeKey]?.append(locationInfo)
            }
        }

        return DetailedInventorySummaryModel(
            summary: summary,
            locationDetails: locationDetails
        )
    }
}

// MARK: - Service Models
// Models moved to Models/Domain/InventoryDetailModels.swift for proper architecture layering

// MARK: - Service Errors

enum InventoryTrackingServiceError: Error, LocalizedError {
    case itemNotFound(String)
    case inconsistentData(String)
    case invalidOperation(String)
    case persistenceFailed(context: String, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .itemNotFound(let stableId):
            return "Glass item not found: \(stableId)"
        case .inconsistentData(let message):
            return "Data inconsistency detected: \(message)"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        case .persistenceFailed(let context, let underlyingError):
            return "\(context)\n\nUnderlying error: \(underlyingError.localizedDescription)"
        }
    }
}
