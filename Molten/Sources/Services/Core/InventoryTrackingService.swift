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
///
/// ## Storage Location Operations
/// This service delegates StorageLocation record operations to `StorageLocationService`,
/// which is the single source of truth for business rules around:
/// - `isTransfer` flag (new inventory vs moved inventory)
/// - `dateAdded` handling
/// - Audit trail (move and consumption records)
actor InventoryTrackingService {

    // MARK: - Dependencies

    private let glassItemRepository: GlassItemRepository
    private let coatingItemRepository: CoatingItemRepository
    private let toolItemRepository: ToolItemRepository
    let inventoryRepository: InventoryRepository
    private let itemTagsRepository: ItemTagsRepository
    private let storageLocationDefinitionRepository: StorageLocationDefinitionRepository
    private let storageLocationRepository: StorageLocationRepository

    /// Centralized service for StorageLocation record operations.
    /// Handles all business rules for isTransfer, dateAdded, and audit records.
    private let storageLocationService: StorageLocationService

    // MARK: - Initialization

    init(
        glassItemRepository: GlassItemRepository,
        coatingItemRepository: CoatingItemRepository,
        toolItemRepository: ToolItemRepository,
        inventoryRepository: InventoryRepository,
        itemTagsRepository: ItemTagsRepository,
        storageLocationDefinitionRepository: StorageLocationDefinitionRepository,
        storageLocationRepository: StorageLocationRepository,
        storageLocationService: StorageLocationService
    ) {
        self.glassItemRepository = glassItemRepository
        self.coatingItemRepository = coatingItemRepository
        self.toolItemRepository = toolItemRepository
        self.inventoryRepository = inventoryRepository
        self.itemTagsRepository = itemTagsRepository
        self.storageLocationDefinitionRepository = storageLocationDefinitionRepository
        self.storageLocationRepository = storageLocationRepository
        self.storageLocationService = storageLocationService
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

        // 4. Get all storage locations for this item's inventory records
        var storageLocations: [StorageLocationModel] = []
        for inv in inventory {
            let locations = try await storageLocationRepository.fetchLocations(forInventory: inv.id)
            storageLocations.append(contentsOf: locations)
        }

        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            storageLocations: storageLocations,
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
        let result = try await inventoryRepository.updateInventory(inventory)

        // Sync StorageLocation record with updated location
        try await syncStorageLocationForInventory(inventory)

        return result
    }

    /// Syncs StorageLocation record with the inventory's current location.
    /// Delegates to StorageLocationService for consistent business logic.
    private func syncStorageLocationForInventory(_ inventory: InventoryModel) async throws {
        try await storageLocationService.syncStorageLocationWithInventory(
            inventoryId: inventory.id,
            locationName: inventory.location,
            quantity: inventory.quantity,
            containerCount: inventory.containerCount
        )
    }

    /// Create a new inventory record
    /// - Parameter inventory: The inventory model to create
    /// - Returns: The created inventory model with generated ID
    func createInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        let result = try await inventoryRepository.createInventory(inventory)

        // Ensure location definition exists for autocomplete
        if let locationName = inventory.location, !locationName.isEmpty {
            await ensureLocationDefinitionExists(name: locationName)
        }

        return result
    }

    // MARK: - Date-Aware Inventory Operations
    //
    // These methods support the date-based inventory model where each record represents
    // items added on a specific date. This enables:
    // - "Print labels for items added today/this week" filtering
    // - Historical tracking of when inventory was acquired
    // - LIFO (last in, first out) decrement behavior

    /// Normalize a date to the start of day (midnight) in the current calendar
    /// This ensures all inventory added on the same calendar day shares the same date_added
    private nonisolated func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Check if two dates represent the same calendar day
    private nonisolated func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Calendar.current.isDate(date1, inSameDayAs: date2)
    }

    /// Increment inventory by 1 for a specific item/type/location combination.
    /// Uses date-aware logic: finds or creates a record for TODAY's date.
    ///
    /// - Parameters:
    ///   - stableId: Item natural key
    ///   - type: Inventory type (rod, tube, frit, etc.)
    ///   - subtype: Optional subtype
    ///   - subsubtype: Optional sub-subtype
    ///   - location: Optional storage location
    /// - Returns: The updated or newly created inventory record
    func incrementInventory(
        forItem stableId: String,
        type: String,
        subtype: String? = nil,
        subsubtype: String? = nil,
        atLocation location: String? = nil
    ) async throws -> InventoryModel {
        let today = startOfDay(Date())

        // Find all matching records for this item/type/location
        let allRecords = try await inventoryRepository.fetchInventory(forItem: stableId)
        let matchingRecords = allRecords.filter { record in
            guard record.type.lowercased() == type.lowercased() else { return false }
            guard record.location == location else { return false }

            // Match subtype if specified
            // If QR code has a subtype but inventory record has nil subtype, still match
            // (nil means "I track sheets but not sizes" - it's a valid choice)
            if let sub = subtype {
                if let recordSubtype = record.subtype {
                    guard recordSubtype.lowercased() == sub.lowercased() else { return false }
                }
                // record.subtype is nil - user doesn't track sizes, include it
            } else {
                guard record.subtype == nil else { return false }
            }

            // Match subsubtype if specified
            // Same logic: nil inventory subsubtype matches any QR code subsubtype
            if let subsub = subsubtype {
                if let recordSubsubtype = record.subsubtype {
                    guard recordSubsubtype.lowercased() == subsub.lowercased() else { return false }
                }
                // record.subsubtype is nil - user doesn't track this level, include it
            } else {
                guard record.subsubtype == nil else { return false }
            }

            return true
        }

        // Find a record from today
        if let todayRecord = matchingRecords.first(where: { isSameDay($0.date_added, today) }) {
            // Update existing today's record
            let updated = InventoryModel(
                id: todayRecord.id,
                item_stable_id: todayRecord.item_stable_id,
                type: todayRecord.type,
                subtype: todayRecord.subtype,
                subsubtype: todayRecord.subsubtype,
                dimensions: todayRecord.dimensions,
                quantity: todayRecord.quantity + 1,
                containerCount: todayRecord.containerCount,
                location: todayRecord.location,
                date_added: todayRecord.date_added,
                date_modified: Date()
            )
            return try await inventoryRepository.updateInventory(updated)
        } else {
            // Create new record for today
            let newRecord = InventoryModel(
                item_stable_id: stableId,
                type: type,
                subtype: subtype,
                subsubtype: subsubtype,
                quantity: 1,
                location: location,
                date_added: today,
                date_modified: Date()
            )
            let result = try await inventoryRepository.createInventory(newRecord)

            // Ensure location definition exists for autocomplete
            if let locationName = location, !locationName.isEmpty {
                await ensureLocationDefinitionExists(name: locationName)
            }

            return result
        }
    }

    /// Decrement inventory by 1 using LIFO (Last In, First Out) strategy.
    /// Decrements from the newest record first (by date_added).
    /// Deletes records when they reach zero quantity.
    ///
    /// - Parameters:
    ///   - stableId: Item natural key
    ///   - type: Inventory type (rod, tube, frit, etc.)
    ///   - subtype: Optional subtype
    ///   - subsubtype: Optional sub-subtype
    ///   - location: Optional storage location (nil matches records with no location)
    /// - Returns: The updated inventory record, or nil if the record was deleted (hit zero)
    /// - Throws: `InventoryTrackingServiceError.invalidOperation` if no inventory exists to decrement
    func decrementInventoryLIFO(
        forItem stableId: String,
        type: String,
        subtype: String? = nil,
        subsubtype: String? = nil,
        atLocation location: String? = nil
    ) async throws -> InventoryModel? {
        // Find all matching records for this item/type/location
        let allRecords = try await inventoryRepository.fetchInventory(forItem: stableId)
        let matchingRecords = allRecords.filter { record in
            guard record.type.lowercased() == type.lowercased() else { return false }
            guard record.location == location else { return false }
            guard record.quantity > 0 else { return false }

            // Match subtype if specified
            // If QR code has a subtype but inventory record has nil subtype (legacy data), still match
            if let sub = subtype {
                if let recordSubtype = record.subtype {
                    guard recordSubtype.lowercased() == sub.lowercased() else { return false }
                }
                // record.subtype is nil - legacy record without subtype, include it
            } else {
                guard record.subtype == nil else { return false }
            }

            // Match subsubtype if specified
            // Same logic: nil inventory subsubtype matches any QR code subsubtype
            if let subsub = subsubtype {
                if let recordSubsubtype = record.subsubtype {
                    guard recordSubsubtype.lowercased() == subsub.lowercased() else { return false }
                }
                // record.subsubtype is nil - legacy record, include it
            } else {
                guard record.subsubtype == nil else { return false }
            }

            return true
        }

        // Sort by date_added descending (newest first) for LIFO
        let sortedRecords = matchingRecords.sorted { $0.date_added > $1.date_added }

        guard let newestRecord = sortedRecords.first else {
            throw InventoryTrackingServiceError.invalidOperation(
                "No inventory to decrement for \(stableId) type=\(type) location=\(location ?? "none")"
            )
        }

        let newQuantity = newestRecord.quantity - 1

        if newQuantity <= 0 {
            // Delete the record when it hits zero
            try await inventoryRepository.deleteInventory(id: newestRecord.id)
            return nil
        } else {
            // Update with decremented quantity
            let updated = InventoryModel(
                id: newestRecord.id,
                item_stable_id: newestRecord.item_stable_id,
                type: newestRecord.type,
                subtype: newestRecord.subtype,
                subsubtype: newestRecord.subsubtype,
                dimensions: newestRecord.dimensions,
                quantity: newQuantity,
                containerCount: newestRecord.containerCount,
                location: newestRecord.location,
                date_added: newestRecord.date_added,
                date_modified: Date()
            )
            return try await inventoryRepository.updateInventory(updated)
        }
    }

    /// Move one unit of inventory from one location to another.
    /// Decrements from the oldest record at source (LIFO) and increments at destination.
    ///
    /// - Parameters:
    ///   - stableId: Item natural key
    ///   - type: Inventory type (rod, tube, frit, etc.)
    ///   - subtype: Optional subtype
    ///   - subsubtype: Optional sub-subtype
    ///   - fromLocation: Source location (nil for "no location")
    ///   - toLocation: Destination location (nil for "no location")
    func moveInventory(
        forItem stableId: String,
        type: String,
        subtype: String? = nil,
        subsubtype: String? = nil,
        fromLocation: String?,
        toLocation: String?
    ) async throws {
        // 1. Find the source StorageLocation by looking up inventory records
        let allInventory = try await inventoryRepository.fetchInventory(forItem: stableId)
        let matchingInventory = allInventory.filter { inv in
            inv.type.lowercased() == type.lowercased() &&
            inv.location == fromLocation &&
            inv.subtype == subtype &&
            inv.subsubtype == subsubtype
        }

        // Find a StorageLocation from one of the matching inventory records
        var sourceStorageLocation: StorageLocationModel?
        for inv in matchingInventory {
            let locations = try await storageLocationRepository.fetchLocations(forInventory: inv.id)
            if let loc = locations.first(where: { $0.locationName == fromLocation }) {
                sourceStorageLocation = loc
                break
            }
        }

        guard let source = sourceStorageLocation else {
            throw InventoryTrackingServiceError.itemNotFound(
                "No inventory found for \(stableId) at location '\(fromLocation ?? "no location")'"
            )
        }

        // 2. Delegate to StorageLocationService for the actual move
        // This handles all business logic: decrement source, create destination with isTransfer=true, audit record
        _ = try await storageLocationService.moveInventoryBetweenLocations(
            from: source.id,
            to: toLocation,
            quantity: 1
        )

        // 3. Also update the Inventory records (legacy behavior)
        // Decrement from source
        _ = try await decrementInventoryLIFO(
            forItem: stableId,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            atLocation: fromLocation
        )

        // Increment at destination
        _ = try await incrementInventory(
            forItem: stableId,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            atLocation: toLocation
        )
    }

    /// Fetch inventory records added on or after a specific date
    /// Useful for "print labels for items added this week" filtering
    ///
    /// - Parameters:
    ///   - date: The cutoff date (records with date_added >= this date are returned)
    ///   - stableId: Optional item filter
    /// - Returns: Array of inventory records added on or after the date
    func fetchInventoryAddedSince(_ date: Date, forItem stableId: String? = nil) async throws -> [InventoryModel] {
        let cutoff = startOfDay(date)
        let allRecords: [InventoryModel]

        if let stableId = stableId {
            allRecords = try await inventoryRepository.fetchInventory(forItem: stableId)
        } else {
            allRecords = try await inventoryRepository.fetchInventory(matching: nil)
        }

        return allRecords.filter { $0.date_added >= cutoff }
    }

    /// Add inventory to an item with optional location and container count
    /// - Parameters:
    ///   - quantity: Quantity to add (weight in grams for frit/powder/enamel, count for others)
    ///   - type: Inventory type
    ///   - stableId: Item natural key
    ///   - subtype: Optional subtype
    ///   - subsubtype: Optional sub-subtype
    ///   - dimensions: Optional dimensions dictionary
    ///   - containerCount: Optional number of containers/jars (for weight-based types)
    ///   - location: Optional location where inventory is stored
    /// - Returns: Created inventory model
    func addInventory(
        quantity: Double,
        type: String,
        toItem stableId: String,
        subtype: String? = nil,
        subsubtype: String? = nil,
        dimensions: [String: Double]? = nil,
        containerCount: Double? = nil,
        atLocation location: String? = nil,
        dateAdded: Date? = nil
    ) async throws -> InventoryModel {

        // 1. Verify the catalog item exists (glass, coating, or tool)
        let catalogItem: UnifiedCatalogItem
        do {
            // Try glass items first (most common)
            if let glassItem = try await glassItemRepository.fetchItem(byStableId: stableId) {
                catalogItem = UnifiedCatalogItem(glassItem: glassItem)
            }
            // Try coatings
            else if let coatingItem = try await coatingItemRepository.fetchItem(byStableId: stableId) {
                catalogItem = UnifiedCatalogItem(coatingItem: coatingItem)
            }
            // Try tools
            else if let toolItem = try await toolItemRepository.fetchItem(byStableId: stableId) {
                catalogItem = UnifiedCatalogItem(toolItem: toolItem)
            }
            // Not found in any repository
            else {
                throw InventoryTrackingServiceError.itemNotFound(stableId)
            }
        } catch let error as InventoryTrackingServiceError {
            throw error
        } catch {
            throw InventoryTrackingServiceError.persistenceFailed(
                context: "Failed to lookup catalog item '\(stableId)'",
                underlyingError: error
            )
        }

        // 2. Validate input parameters
        // Allow quantity=0 if containerCount is provided (for jar-only tracking)
        let hasContainerCount = containerCount != nil && containerCount! > 0
        guard quantity > 0 || hasContainerCount else {
            throw InventoryTrackingServiceError.invalidOperation("Quantity must be positive (got \(quantity))")
        }

        guard !type.isEmpty else {
            throw InventoryTrackingServiceError.invalidOperation("Inventory type cannot be empty")
        }

        // 3. Create new inventory record with location, optional subtypes/dimensions, and container count
        let effectiveDate = dateAdded ?? Date()
        let newInventory = InventoryModel(
            item_stable_id: stableId,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dimensions: dimensions,
            quantity: quantity,
            containerCount: containerCount,
            location: location,
            date_added: effectiveDate,
            date_modified: effectiveDate
        )

        // 4. Attempt to save with proper error context
        do {
            let savedInventory = try await self.inventoryRepository.createInventory(newInventory)

            // 5. Always create StorageLocation record for receipt import matching
            // Even if no location is specified, we need a StorageLocation record
            // so that receipt import can find and link to this inventory
            _ = try await storageLocationService.addInventoryToLocation(
                inventoryId: savedInventory.id,
                locationName: location ?? "",
                quantity: quantity,
                containerCount: containerCount,
                dateAdded: effectiveDate
            )

            return savedInventory
        } catch {
            // Provide context about what failed, including the item name for user clarity
            throw InventoryTrackingServiceError.persistenceFailed(
                context: "Failed to save inventory for '\(catalogItem.name)' (\(stableId))",
                underlyingError: error
            )
        }
    }

    /// Ensures a StorageLocationDefinition exists for the given name.
    /// Creates one if it doesn't exist. Returns the definition's UUID, or nil if creation failed.
    private func ensureLocationDefinitionExistsAndGetId(name: String) async -> UUID? {
        do {
            // Check if definition already exists
            if let existing = try await storageLocationDefinitionRepository.fetch(byName: name) {
                return existing.id
            }

            // Create new definition
            let newDefinition = StorageLocationDefinitionModel(name: name)
            let created = try await storageLocationDefinitionRepository.create(newDefinition)
            return created.id
        } catch {
            // Log but don't fail - location definition is optional
            print("⚠️ Failed to create location definition for '\(name)': \(error)")
            return nil
        }
    }

    /// Ensures a StorageLocationDefinition exists for the given name.
    /// Creates one if it doesn't exist. Failures are logged but don't throw.
    @available(*, deprecated, message: "Use ensureLocationDefinitionExistsAndGetId instead")
    private func ensureLocationDefinitionExists(name: String) async {
        _ = await ensureLocationDefinitionExistsAndGetId(name: name)
    }

    // MARK: - Storage Location Operations (New Architecture)
    //
    // These operations use the new StorageLocation-based architecture where:
    // - StorageLocation tracks where inventory is stored, with quantity >= 0
    // - InventoryConsumptionRecord tracks consumed inventory (audit log)
    // - InventoryMoveRecord tracks moves between locations (audit log)
    //
    // This enables:
    // - "Print labels for items added today" with isTransfer=false filter
    // - Audit trail for all inventory changes
    // - Multi-location inventory tracking

    /// Consume inventory from a specific storage location.
    /// Delegates to StorageLocationService for consistent business logic.
    ///
    /// - Parameters:
    ///   - quantity: Amount to consume (weight in grams or count)
    ///   - containerCount: Optional number of containers consumed (for weight-based types)
    ///   - storageLocationId: The StorageLocation record to consume from
    /// - Returns: The updated StorageLocation, or nil if fully consumed (deleted)
    /// - Throws: If storage location not found or insufficient quantity
    func consumeFromStorageLocation(
        quantity: Double,
        containerCount: Double? = nil,
        from storageLocationId: UUID
    ) async throws -> StorageLocationModel? {
        return try await storageLocationService.consumeFromLocation(
            storageLocationId: storageLocationId,
            quantity: quantity,
            containerCount: containerCount
        )
    }

    /// Move inventory from one storage location to another.
    /// Delegates to StorageLocationService for consistent business logic.
    ///
    /// - Parameters:
    ///   - quantity: Amount to move (weight in grams or count)
    ///   - containerCount: Optional number of containers to move (for weight-based types)
    ///   - fromStorageLocationId: Source StorageLocation UUID
    ///   - toLocationDefinitionId: Destination StorageLocationDefinition UUID
    /// - Returns: Tuple of (updated source or nil if depleted, destination StorageLocation)
    /// - Throws: If source not found or insufficient quantity
    func moveInventory(
        quantity: Double,
        containerCount: Double? = nil,
        from fromStorageLocationId: UUID,
        to toLocationDefinitionId: UUID
    ) async throws -> (source: StorageLocationModel?, destination: StorageLocationModel) {
        // Look up the location name from the definition
        let locationName: String?
        if let definition = try await storageLocationDefinitionRepository.fetch(byId: toLocationDefinitionId) {
            locationName = definition.name
        } else {
            locationName = nil
        }

        // Delegate to StorageLocationService
        return try await storageLocationService.moveInventoryBetweenLocations(
            from: fromStorageLocationId,
            to: locationName,
            quantity: quantity,
            containerCount: containerCount
        )
    }

    /// Fetch storage locations added on a specific date, excluding transfers.
    /// Delegates to StorageLocationService for consistent business logic.
    ///
    /// - Parameter date: The date to filter by (time component is ignored)
    /// - Returns: Array of StorageLocationModel instances added on that date (non-transfers only)
    func fetchStorageLocationsForLabelPrinting(addedOn date: Date) async throws -> [StorageLocationModel] {
        return try await storageLocationService.fetchStorageLocationsForLabelPrinting(addedOn: date)
    }

    /// Get total quantity for an inventory record across all storage locations.
    ///
    /// - Parameter inventoryId: The UUID of the Inventory record
    /// - Returns: Total quantity summed across all StorageLocation records
    func getTotalQuantity(forInventory inventoryId: UUID) async throws -> Double {
        let locations = try await storageLocationRepository.fetchLocations(forInventory: inventoryId)
        return locations.reduce(0) { $0 + $1.quantity }
    }

    /// Get total container count for an inventory record across all storage locations.
    ///
    /// - Parameter inventoryId: The UUID of the Inventory record
    /// - Returns: Total container count summed across all StorageLocation records (nil if no containers)
    func getTotalContainerCount(forInventory inventoryId: UUID) async throws -> Double? {
        let locations = try await storageLocationRepository.fetchLocations(forInventory: inventoryId)
        let counts = locations.compactMap { $0.containerCount }
        return counts.isEmpty ? nil : counts.reduce(0, +)
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
    /// Full inventory records grouped by type (for proper display with container counts)
    let inventoryByType: [String: [InventoryModel]]

    /// Business Logic: Aggregate inventory by type and location
    /// - Parameters:
    ///   - summary: The base inventory summary
    ///   - inventory: Inventory records to aggregate
    /// - Returns: Detailed summary with location information grouped by type
    static func from(summary: InventorySummaryModel, inventory: [InventoryModel]) -> DetailedInventorySummaryModel {
        var locationDetails: [String: [(location: String, quantity: Double)]] = [:]
        var inventoryByType: [String: [InventoryModel]] = [:]

        for inventoryRecord in inventory {
            let typeKey = inventoryRecord.type

            // Store full inventory records by type
            if inventoryByType[typeKey] == nil {
                inventoryByType[typeKey] = []
            }
            inventoryByType[typeKey]?.append(inventoryRecord)

            // Also store location details for backwards compatibility
            if let location = inventoryRecord.location {
                let locationInfo = (location: location, quantity: inventoryRecord.quantity)
                if locationDetails[typeKey] == nil {
                    locationDetails[typeKey] = []
                }
                locationDetails[typeKey]?.append(locationInfo)
            }
        }

        return DetailedInventorySummaryModel(
            summary: summary,
            locationDetails: locationDetails,
            inventoryByType: inventoryByType
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
