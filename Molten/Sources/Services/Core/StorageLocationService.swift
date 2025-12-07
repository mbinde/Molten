//
//  StorageLocationService.swift
//  Molten
//
//  Service for managing storage locations and inventory placement
//  Provides centralized business logic for:
//  - Location definitions (creating, renaming, merging storage areas)
//  - Inventory at locations (adding, moving, consuming, updating)
//
//  All StorageLocation record operations should go through this service
//  to ensure consistent handling of isTransfer, dateAdded, audit records, etc.
//

import Foundation
import OSLog

/// Service for managing storage locations and inventory placement
///
/// This service is the single source of truth for StorageLocation business logic.
/// It handles:
/// - Location definitions (the named places like "Studio", "Shelf A")
/// - Inventory records at locations (StorageLocation entities linking Inventory to locations)
/// - Audit trail (move and consumption records)
///
/// ## Key Business Rules
/// - New inventory additions have `isTransfer = false`
/// - Moved inventory has `isTransfer = true` at the destination
/// - `dateAdded` reflects when inventory was placed at a location (or moved there)
/// - Quantity changes create audit records for traceability
@MainActor
class StorageLocationService: Sendable {

    // MARK: - Dependencies

    private let definitionRepository: StorageLocationDefinitionRepository
    private let storageLocationRepository: StorageLocationRepository
    private let moveRecordRepository: InventoryMoveRecordRepository
    private let consumptionRecordRepository: InventoryConsumptionRecordRepository
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "storage-location-service")

    // MARK: - Initialization

    nonisolated init(
        definitionRepository: StorageLocationDefinitionRepository,
        storageLocationRepository: StorageLocationRepository,
        moveRecordRepository: InventoryMoveRecordRepository,
        consumptionRecordRepository: InventoryConsumptionRecordRepository
    ) {
        self.definitionRepository = definitionRepository
        self.storageLocationRepository = storageLocationRepository
        self.moveRecordRepository = moveRecordRepository
        self.consumptionRecordRepository = consumptionRecordRepository
    }

    // MARK: - Query Operations

    /// Get all storage location definitions (sorted alphabetically)
    func getAllLocations() async throws -> [StorageLocationDefinitionModel] {
        return try await definitionRepository.fetchAll()
    }

    /// Get a location by ID
    func getLocation(byId id: UUID) async throws -> StorageLocationDefinitionModel? {
        return try await definitionRepository.fetch(byId: id)
    }

    /// Get a location by name (case-insensitive)
    func getLocation(byName name: String) async throws -> StorageLocationDefinitionModel? {
        return try await definitionRepository.fetch(byName: name)
    }

    /// Get or create a location by name
    /// If a location with this name exists, returns it. Otherwise creates a new one.
    func getOrCreateLocation(named name: String) async throws -> StorageLocationDefinitionModel {
        return try await definitionRepository.getOrCreate(name: name)
    }

    /// Get usage count for a location
    func getUsageCount(for locationId: UUID) async throws -> Int {
        return try await definitionRepository.getUsageCount(for: locationId)
    }

    /// Get all locations with their usage counts
    func getLocationsWithUsageCounts() async throws -> [(location: StorageLocationDefinitionModel, usageCount: Int)] {
        let locations = try await definitionRepository.fetchAll()
        var results: [(StorageLocationDefinitionModel, Int)] = []

        for location in locations {
            let count = try await definitionRepository.getUsageCount(for: location.id)
            results.append((location, count))
        }

        return results
    }

    // MARK: - Mutation Operations

    /// Create a new storage location definition
    func createLocation(name: String, notes: String? = nil) async throws -> StorageLocationDefinitionModel {
        // Check for duplicate name
        if try await definitionRepository.nameExists(name) {
            throw StorageLocationServiceError.duplicateName(name)
        }

        let definition = StorageLocationDefinitionModel(name: name, notes: notes)
        return try await definitionRepository.create(definition)
    }

    /// Rename a storage location
    /// This updates the definition - all StorageLocation records referencing it will show the new name
    func renameLocation(id: UUID, to newName: String) async throws -> StorageLocationDefinitionModel {
        // Check for duplicate name (excluding self)
        if let existing = try await definitionRepository.fetch(byName: newName), existing.id != id {
            throw StorageLocationServiceError.duplicateName(newName)
        }

        guard var definition = try await definitionRepository.fetch(byId: id) else {
            throw StorageLocationServiceError.notFound(id)
        }

        definition.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        definition.modifiedAt = Date()

        log.info("Renaming storage location \(id) to '\(newName)'")
        return try await definitionRepository.update(definition)
    }

    /// Update notes for a storage location
    func updateNotes(for id: UUID, notes: String?) async throws -> StorageLocationDefinitionModel {
        guard var definition = try await definitionRepository.fetch(byId: id) else {
            throw StorageLocationServiceError.notFound(id)
        }

        definition.notes = notes
        definition.modifiedAt = Date()

        return try await definitionRepository.update(definition)
    }

    /// Delete a storage location (soft delete)
    /// - Parameter id: The UUID of the location to delete
    /// - Parameter force: If true, delete even if location is in use. If false, throws error if in use.
    func deleteLocation(id: UUID, force: Bool = false) async throws {
        let usageCount = try await definitionRepository.getUsageCount(for: id)

        if usageCount > 0 && !force {
            throw StorageLocationServiceError.locationInUse(id, usageCount: usageCount)
        }

        log.info("Soft-deleting storage location \(id)")
        try await definitionRepository.softDelete(id: id)
    }

    /// Restore a soft-deleted storage location
    func restoreLocation(id: UUID) async throws {
        log.info("Restoring storage location \(id)")
        try await definitionRepository.restore(id: id)
    }

    /// Merge one location into another
    /// All inventory items at the source location will be moved to the target location.
    /// The source location will be deleted.
    func mergeLocations(sourceId: UUID, intoTargetId: UUID) async throws {
        guard sourceId != intoTargetId else {
            throw StorageLocationServiceError.cannotMergeSelf
        }

        guard let source = try await definitionRepository.fetch(byId: sourceId) else {
            throw StorageLocationServiceError.notFound(sourceId)
        }

        guard let target = try await definitionRepository.fetch(byId: intoTargetId) else {
            throw StorageLocationServiceError.notFound(intoTargetId)
        }

        log.info("Merging storage location '\(source.name)' into '\(target.name)'")

        // Get all StorageLocation records that reference the source
        // and update them to reference the target instead
        let sourceRecords = try await storageLocationRepository.fetchLocations(matching:
            NSPredicate(format: "storage_location_id == %@", sourceId as CVarArg))

        for record in sourceRecords {
            // Update the record to use the target location
            let updatedRecord = StorageLocationModel(
                id: record.id,
                inventoryId: record.inventoryId,
                storageLocationId: intoTargetId,
                locationName: target.name,
                quantity: record.quantity,
                workspaceId: record.workspaceId
            )
            _ = try await storageLocationRepository.updateLocation(updatedRecord)
        }

        // Delete the source location definition
        try await definitionRepository.hardDelete(id: sourceId)

        log.info("Merged \(sourceRecords.count) records from '\(source.name)' into '\(target.name)'")
    }

    // MARK: - Inventory Record Operations
    //
    // These methods manage StorageLocation records (the actual inventory at locations).
    // They handle all business rules around isTransfer, dateAdded, and audit trail.

    /// Add inventory to a location (for new purchases/acquisitions).
    /// Creates a new StorageLocation record with `isTransfer = false`.
    ///
    /// - Parameters:
    ///   - inventoryId: The UUID of the Inventory record
    ///   - locationName: The name of the location (will be normalized and definition created if needed)
    ///   - quantity: Amount to add (count or weight in grams)
    ///   - containerCount: Optional number of containers (for weight-based types)
    ///   - dateAdded: When the inventory was added (defaults to now)
    /// - Returns: The created StorageLocation record
    /// - Throws: `StorageLocationServiceError` if operation fails
    func addInventoryToLocation(
        inventoryId: UUID,
        locationName: String?,
        quantity: Double,
        containerCount: Double? = nil,
        dateAdded: Date = Date()
    ) async throws -> StorageLocationModel {
        // Resolve location definition (create if needed)
        let (locationDefId, resolvedName) = try await resolveLocationDefinition(name: locationName)

        // Check for existing StorageLocation for this inventory+location
        let existing = try await findStorageLocation(inventoryId: inventoryId, locationDefinitionId: locationDefId)

        if let existingLocation = existing {
            // Update existing - add to quantity, keep original dateAdded and isTransfer
            let updated = StorageLocationModel(
                id: existingLocation.id,
                inventoryId: existingLocation.inventoryId,
                storageLocationId: locationDefId,
                locationName: resolvedName ?? "",
                quantity: existingLocation.quantity + quantity,
                containerCount: addContainerCounts(existingLocation.containerCount, containerCount),
                dateAdded: existingLocation.dateAdded,  // Keep original date
                dateModified: Date(),
                isTransfer: existingLocation.isTransfer,  // Keep original status
                workspaceId: existingLocation.workspaceId
            )
            log.debug("Updated existing StorageLocation \(existingLocation.id): +\(quantity) at '\(resolvedName ?? "no location")'")
            return try await storageLocationRepository.updateLocation(updated)
        } else {
            // Create new StorageLocation - this is new inventory, not a transfer
            let newLocation = StorageLocationModel(
                inventoryId: inventoryId,
                storageLocationId: locationDefId,
                locationName: resolvedName ?? "",
                quantity: quantity,
                containerCount: containerCount,
                dateAdded: dateAdded,
                dateModified: dateAdded,
                isTransfer: false  // New inventory is never a transfer
            )
            log.debug("Created new StorageLocation for inventory \(inventoryId): \(quantity) at '\(resolvedName ?? "no location")'")
            return try await storageLocationRepository.createLocation(newLocation)
        }
    }

    /// Move inventory from one location to another.
    /// Decrements source, creates/increments destination with `isTransfer = true`.
    /// Creates an InventoryMoveRecord for audit trail.
    ///
    /// - Parameters:
    ///   - sourceStorageLocationId: The StorageLocation to move from
    ///   - destinationLocationName: The location name to move to (can be nil for "no location")
    ///   - quantity: Amount to move
    ///   - containerCount: Optional containers to move
    /// - Returns: Tuple of (updated source or nil if depleted, destination StorageLocation)
    /// - Throws: `StorageLocationServiceError` if source not found or insufficient quantity
    func moveInventoryBetweenLocations(
        from sourceStorageLocationId: UUID,
        to destinationLocationName: String?,
        quantity: Double,
        containerCount: Double? = nil
    ) async throws -> (source: StorageLocationModel?, destination: StorageLocationModel) {
        // 1. Fetch and validate source
        guard let sourceLocation = try await fetchStorageLocation(byId: sourceStorageLocationId) else {
            throw StorageLocationServiceError.storageLocationNotFound(sourceStorageLocationId)
        }

        guard sourceLocation.quantity >= quantity else {
            throw StorageLocationServiceError.insufficientQuantity(
                available: sourceLocation.quantity,
                requested: quantity
            )
        }

        // 2. Resolve destination location definition
        let (destLocationDefId, destName) = try await resolveLocationDefinition(name: destinationLocationName)
        let now = Date()

        // 3. Find or create destination StorageLocation
        let existingDest = try await findStorageLocation(
            inventoryId: sourceLocation.inventoryId,
            locationDefinitionId: destLocationDefId
        )

        let destinationLocation: StorageLocationModel
        if let existingDest = existingDest {
            // Update existing destination - add quantity, keep original transfer status
            let updated = StorageLocationModel(
                id: existingDest.id,
                inventoryId: existingDest.inventoryId,
                storageLocationId: destLocationDefId,
                locationName: destName ?? "",
                quantity: existingDest.quantity + quantity,
                containerCount: addContainerCounts(existingDest.containerCount, containerCount),
                dateAdded: existingDest.dateAdded,
                dateModified: now,
                isTransfer: existingDest.isTransfer,  // Keep existing status
                workspaceId: existingDest.workspaceId
            )
            destinationLocation = try await storageLocationRepository.updateLocation(updated)
        } else {
            // Create new destination - this is a transfer
            let newDest = StorageLocationModel(
                inventoryId: sourceLocation.inventoryId,
                storageLocationId: destLocationDefId,
                locationName: destName ?? "",
                quantity: quantity,
                containerCount: containerCount,
                dateAdded: now,
                dateModified: now,
                isTransfer: true  // Moved inventory is always a transfer
            )
            destinationLocation = try await storageLocationRepository.createLocation(newDest)
        }

        // 4. Decrement source
        let updatedSource = try await decrementStorageLocation(
            sourceLocation,
            byQuantity: quantity,
            containerCount: containerCount,
            modifiedAt: now
        )

        // 5. Create audit record
        let moveRecord = InventoryMoveRecordModel(
            fromStorageLocationId: sourceStorageLocationId,
            toStorageLocationId: destinationLocation.id,
            quantity: quantity,
            containerCount: containerCount
        )
        _ = try await moveRecordRepository.createOrUpdateMoveRecord(moveRecord)

        log.info("Moved \(quantity) from \(sourceStorageLocationId) to '\(destName ?? "no location")'")
        return (source: updatedSource, destination: destinationLocation)
    }

    /// Consume inventory from a storage location (use it up).
    /// Decrements quantity and creates an InventoryConsumptionRecord for audit trail.
    ///
    /// - Parameters:
    ///   - storageLocationId: The StorageLocation to consume from
    ///   - quantity: Amount to consume
    ///   - containerCount: Optional containers consumed
    /// - Returns: Updated StorageLocation, or nil if fully consumed (deleted)
    /// - Throws: `StorageLocationServiceError` if not found or insufficient quantity
    func consumeFromLocation(
        storageLocationId: UUID,
        quantity: Double,
        containerCount: Double? = nil
    ) async throws -> StorageLocationModel? {
        // 1. Fetch and validate
        guard let location = try await fetchStorageLocation(byId: storageLocationId) else {
            throw StorageLocationServiceError.storageLocationNotFound(storageLocationId)
        }

        guard location.quantity >= quantity else {
            throw StorageLocationServiceError.insufficientQuantity(
                available: location.quantity,
                requested: quantity
            )
        }

        // 2. Create consumption audit record
        let consumptionRecord = InventoryConsumptionRecordModel(
            storageLocationId: storageLocationId,
            quantity: quantity,
            containerCount: containerCount
        )
        _ = try await consumptionRecordRepository.createOrUpdateConsumptionRecord(consumptionRecord)

        // 3. Decrement quantity
        let updated = try await decrementStorageLocation(
            location,
            byQuantity: quantity,
            containerCount: containerCount,
            modifiedAt: Date()
        )

        log.info("Consumed \(quantity) from StorageLocation \(storageLocationId)")
        return updated
    }

    /// Update the quantity at a storage location (for corrections/adjustments).
    /// Does not create audit records - use for inventory corrections only.
    ///
    /// - Parameters:
    ///   - storageLocationId: The StorageLocation to update
    ///   - newQuantity: The new quantity value
    ///   - containerCount: Optional new container count (pass nil to keep existing)
    /// - Returns: Updated StorageLocation, or nil if quantity set to 0 (deleted)
    /// - Throws: `StorageLocationServiceError` if not found or invalid quantity
    func updateLocationQuantity(
        storageLocationId: UUID,
        newQuantity: Double,
        containerCount: Double? = nil
    ) async throws -> StorageLocationModel? {
        guard let location = try await fetchStorageLocation(byId: storageLocationId) else {
            throw StorageLocationServiceError.storageLocationNotFound(storageLocationId)
        }

        guard newQuantity >= 0 else {
            throw StorageLocationServiceError.invalidQuantity(newQuantity)
        }

        if newQuantity <= 0 {
            // Delete if quantity goes to zero
            try await storageLocationRepository.deleteLocation(location)
            log.info("Deleted StorageLocation \(storageLocationId) (quantity set to 0)")
            return nil
        }

        let updated = StorageLocationModel(
            id: location.id,
            inventoryId: location.inventoryId,
            storageLocationId: location.storageLocationId,
            locationName: location.locationName,
            quantity: newQuantity,
            containerCount: containerCount ?? location.containerCount,
            dateAdded: location.dateAdded,
            dateModified: Date(),
            isTransfer: location.isTransfer,
            workspaceId: location.workspaceId
        )

        log.debug("Updated StorageLocation \(storageLocationId) quantity: \(location.quantity) -> \(newQuantity)")
        return try await storageLocationRepository.updateLocation(updated)
    }

    /// Sync a StorageLocation with inventory record changes.
    /// Used when an Inventory record's location field is updated directly.
    ///
    /// - Parameters:
    ///   - inventory: The Inventory record that was updated
    /// - Throws: If sync fails
    func syncStorageLocationWithInventory(
        inventoryId: UUID,
        locationName: String?,
        quantity: Double,
        containerCount: Double?
    ) async throws {
        let existingLocations = try await storageLocationRepository.fetchLocations(forInventory: inventoryId)

        if let name = locationName, !name.isEmpty {
            // Inventory has a location - ensure StorageLocation exists
            let (locationDefId, resolvedName) = try await resolveLocationDefinition(name: name)

            if let existing = existingLocations.first {
                // Update existing
                let updated = StorageLocationModel(
                    id: existing.id,
                    inventoryId: inventoryId,
                    storageLocationId: locationDefId,
                    locationName: resolvedName ?? "",
                    quantity: quantity,
                    containerCount: containerCount,
                    dateAdded: existing.dateAdded,
                    dateModified: Date(),
                    isTransfer: existing.isTransfer,
                    workspaceId: existing.workspaceId
                )
                _ = try await storageLocationRepository.updateLocation(updated)
            } else {
                // Create new - not a transfer since this is a sync, not a move
                let newLocation = StorageLocationModel(
                    inventoryId: inventoryId,
                    storageLocationId: locationDefId,
                    locationName: resolvedName ?? "",
                    quantity: quantity,
                    containerCount: containerCount,
                    dateAdded: Date(),
                    dateModified: Date(),
                    isTransfer: false
                )
                _ = try await storageLocationRepository.createLocation(newLocation)
            }
        } else {
            // No location - remove any StorageLocation records
            for existing in existingLocations {
                try await storageLocationRepository.deleteLocation(existing)
            }
        }
    }

    /// Fetch storage locations for an inventory record
    func fetchStorageLocations(forInventory inventoryId: UUID) async throws -> [StorageLocationModel] {
        return try await storageLocationRepository.fetchLocations(forInventory: inventoryId)
    }

    /// Fetch storage locations added on a specific date, excluding transfers.
    /// Used for "print labels for items added today" functionality.
    func fetchStorageLocationsForLabelPrinting(addedOn date: Date) async throws -> [StorageLocationModel] {
        return try await storageLocationRepository.fetchLocations(addedOn: date, excludeTransfers: true)
    }

    // MARK: - Private Helpers

    /// Resolve a location name to a definition ID and normalized name.
    /// Creates the definition if it doesn't exist.
    /// Returns (nil, nil) for nil/empty names (meaning "no location").
    private func resolveLocationDefinition(name: String?) async throws -> (UUID?, String?) {
        guard let name = name, !name.isEmpty else {
            return (nil, nil)
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let definition = try await definitionRepository.getOrCreate(name: trimmed)
        return (definition.id, definition.name)
    }

    /// Find an existing StorageLocation for an inventory+location combination
    private func findStorageLocation(inventoryId: UUID, locationDefinitionId: UUID?) async throws -> StorageLocationModel? {
        let locations = try await storageLocationRepository.fetchLocations(forInventory: inventoryId)

        if let defId = locationDefinitionId {
            return locations.first { $0.storageLocationId == defId }
        } else {
            // Looking for "no location" - find one with nil storageLocationId
            return locations.first { $0.storageLocationId == nil }
        }
    }

    /// Fetch a StorageLocation by its ID
    private func fetchStorageLocation(byId id: UUID) async throws -> StorageLocationModel? {
        let locations = try await storageLocationRepository.fetchLocations(
            matching: NSPredicate(format: "id == %@", id as CVarArg)
        )
        return locations.first
    }

    /// Decrement a storage location's quantity.
    /// Deletes the record if quantity reaches zero.
    private func decrementStorageLocation(
        _ location: StorageLocationModel,
        byQuantity quantity: Double,
        containerCount: Double?,
        modifiedAt: Date
    ) async throws -> StorageLocationModel? {
        let newQuantity = location.quantity - quantity
        let newContainerCount = subtractContainerCounts(location.containerCount, containerCount)

        if newQuantity <= 0 {
            try await storageLocationRepository.deleteLocation(location)
            return nil
        }

        let updated = StorageLocationModel(
            id: location.id,
            inventoryId: location.inventoryId,
            storageLocationId: location.storageLocationId,
            locationName: location.locationName,
            quantity: newQuantity,
            containerCount: newContainerCount,
            dateAdded: location.dateAdded,
            dateModified: modifiedAt,
            isTransfer: location.isTransfer,
            workspaceId: location.workspaceId
        )
        return try await storageLocationRepository.updateLocation(updated)
    }

    /// Add two optional container counts
    private func addContainerCounts(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case let (a?, b?): return a + b
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return nil
        }
    }

    /// Subtract container counts, returning nil if result <= 0
    private func subtractContainerCounts(_ a: Double?, _ b: Double?) -> Double? {
        guard let a = a else { return nil }
        guard let b = b else { return a }
        let result = a - b
        return result > 0 ? result : nil
    }
}

// MARK: - Errors

enum StorageLocationServiceError: Error, LocalizedError {
    // Definition errors
    case duplicateName(String)
    case notFound(UUID)
    case locationInUse(UUID, usageCount: Int)
    case cannotMergeSelf

    // Storage location record errors
    case storageLocationNotFound(UUID)
    case insufficientQuantity(available: Double, requested: Double)
    case invalidQuantity(Double)

    var errorDescription: String? {
        switch self {
        case .duplicateName(let name):
            return "A storage location named '\(name)' already exists"
        case .notFound(let id):
            return "Storage location definition not found: \(id)"
        case .locationInUse(_, let usageCount):
            return "Cannot delete location - it is used by \(usageCount) inventory item(s)"
        case .cannotMergeSelf:
            return "Cannot merge a location into itself"
        case .storageLocationNotFound(let id):
            return "Storage location record not found: \(id)"
        case .insufficientQuantity(let available, let requested):
            return "Insufficient quantity: have \(Int(available)), need \(Int(requested))"
        case .invalidQuantity(let quantity):
            return "Invalid quantity: \(quantity)"
        }
    }
}
