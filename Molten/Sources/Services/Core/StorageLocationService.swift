//
//  StorageLocationService.swift
//  Molten
//
//  Service for managing storage location definitions
//  Provides business logic for creating, renaming, and merging locations
//

import Foundation
import OSLog

/// Service for managing storage location definitions
/// Handles business logic around storage locations including rename and merge operations
@MainActor
class StorageLocationService: Sendable {

    // MARK: - Dependencies

    private let definitionRepository: StorageLocationDefinitionRepository
    private let storageLocationRepository: StorageLocationRepository
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "storage-location-service")

    // MARK: - Initialization

    nonisolated init(
        definitionRepository: StorageLocationDefinitionRepository,
        storageLocationRepository: StorageLocationRepository
    ) {
        self.definitionRepository = definitionRepository
        self.storageLocationRepository = storageLocationRepository
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

        for var record in sourceRecords {
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
}

// MARK: - Errors

enum StorageLocationServiceError: Error, LocalizedError {
    case duplicateName(String)
    case notFound(UUID)
    case locationInUse(UUID, usageCount: Int)
    case cannotMergeSelf

    var errorDescription: String? {
        switch self {
        case .duplicateName(let name):
            return "A storage location named '\(name)' already exists"
        case .notFound(let id):
            return "Storage location not found: \(id)"
        case .locationInUse(_, let usageCount):
            return "Cannot delete location - it is used by \(usageCount) inventory item(s)"
        case .cannotMergeSelf:
            return "Cannot merge a location into itself"
        }
    }
}
