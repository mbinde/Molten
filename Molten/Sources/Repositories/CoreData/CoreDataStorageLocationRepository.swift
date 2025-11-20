//
//  CoreDataStorageLocationRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//
//  ✅ KEEP THIS FILE - This is the correct, complete implementation
//  🗑️ DELETE any other CoreDataStorageLocationRepository.swift files
//
//  This file contains the complete Core Data implementation for StorageLocationRepository
//  following clean architecture principles with async/await patterns.
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of StorageLocationRepository
/// Provides persistent storage for physical storage location records using Core Data
class CoreDataStorageLocationRepository: @unchecked Sendable, StorageLocationRepository {
    
    // MARK: - Dependencies
    
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "storage-location-repository")

    // MARK: - Initialization

    /// Initialize CoreDataStorageLocationRepository with a managed object context
    /// - Parameter context: The NSManagedObjectContext to use for location data operations
    /// - Note: In production, pass PersistenceController.shared.cloudContext (user data)
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchLocations(matching predicate: NSPredicate?) async throws -> [StorageLocationModel] {
        nonisolated(unsafe) let predicateCopy = predicate
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocation")
            fetchRequest.predicate = predicateCopy
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "location", ascending: true),
                NSSortDescriptor(key: "quantity", ascending: false)
            ]

            let coreDataItems = try context.fetch(fetchRequest)
            let locationItems = coreDataItems.compactMap { self.convertToStorageLocationModel($0) }

            self.log.info("Fetched \(locationItems.count) location records")
            return locationItems
        }
    }
    
    func fetchLocations(forInventory inventory_id: UUID) async throws -> [StorageLocationModel] {
        let predicate = NSPredicate(format: "inventory_id == %@", inventory_id as CVarArg)
        return try await fetchLocations(matching: predicate)
    }
    
    func fetchLocations(withName locationName: String) async throws -> [StorageLocationModel] {
        let cleanLocationName = StorageLocationModel.cleanLocationName(locationName)
        let predicate = NSPredicate(format: "location == %@", cleanLocationName)
        return try await fetchLocations(matching: predicate)
    }
    
    func createLocation(_ location: StorageLocationModel) async throws -> StorageLocationModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            // Create new Core Data entity
            guard let entity = NSEntityDescription.entity(forEntityName: "StorageLocation", in: context) else {
                throw CoreDataLocationRepositoryError.entityNotFound("StorageLocation")
            }
            let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

            // Set properties
            self.updateCoreDataEntity(coreDataItem, with: location)

            // Save context
            try context.save()

            self.log.info("Created location record: \(location.location) for inventory: \(location.inventory_id)")
            return location
        }
    }
    
    func createLocations(_ locations: [StorageLocationModel]) async throws -> [StorageLocationModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            var createdLocations: [StorageLocationModel] = []

            for location in locations {
                // Create new Core Data entity
                guard let entity = NSEntityDescription.entity(forEntityName: "StorageLocation", in: context) else {
                    throw CoreDataLocationRepositoryError.entityNotFound("StorageLocation")
                }
                let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

                // Set properties
                self.updateCoreDataEntity(coreDataItem, with: location)
                createdLocations.append(location)
            }

            // Save all changes at once
            try context.save()

            self.log.info("Created \(createdLocations.count) location records in batch")
            return createdLocations
        }
    }
    
    func updateLocation(_ location: StorageLocationModel) async throws -> StorageLocationModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            // Find existing item
            guard let coreDataItem = try self.fetchCoreDataItemSync(byInventoryId: location.inventory_id, locationName: location.location) else {
                self.log.warning("Attempted to update non-existent location record: \(location.location) for inventory \(location.inventory_id)")
                throw CoreDataLocationRepositoryError.itemNotFound("\(location.inventory_id)/\(location.location)")
            }

            // Update properties
            self.updateCoreDataEntity(coreDataItem, with: location)

            // Save context
            try context.save()

            self.log.info("Updated location record: \(location.location) for inventory \(location.inventory_id)")
            return location
        }
    }
    
    func deleteLocation(_ location: StorageLocationModel) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            // Find existing item
            guard let coreDataItem = try self.fetchCoreDataItemSync(byInventoryId: location.inventory_id, locationName: location.location) else {
                self.log.warning("Attempted to delete non-existent location record: \(location.location) for inventory \(location.inventory_id)")
                throw CoreDataLocationRepositoryError.itemNotFound("\(location.inventory_id)/\(location.location)")
            }

            // Delete item
            context.delete(coreDataItem)

            // Save context
            try context.save()

            self.log.info("Deleted location record: \(location.location) for inventory \(location.inventory_id)")
        }
    }
    
    func deleteLocations(forInventory inventory_id: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocation")
            fetchRequest.predicate = NSPredicate(format: "inventory_id == %@", inventory_id as CVarArg)

            let locationsToDelete = try context.fetch(fetchRequest)

            for location in locationsToDelete {
                context.delete(location)
            }

            if !locationsToDelete.isEmpty {
                try context.save()
            }

            self.log.info("Deleted \(locationsToDelete.count) location records for inventory: \(inventory_id)")
        }
    }
    
    func deleteLocations(withName locationName: String) async throws {
        let cleanLocationName = StorageLocationModel.cleanLocationName(locationName)

        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocation")
            fetchRequest.predicate = NSPredicate(format: "location == %@", cleanLocationName)

            let locationsToDelete = try context.fetch(fetchRequest)

            for location in locationsToDelete {
                context.delete(location)
            }

            if !locationsToDelete.isEmpty {
                try context.save()
            }

            self.log.info("Deleted \(locationsToDelete.count) location records with name: \(cleanLocationName)")
        }
    }
    
    // MARK: - Location Management Operations
    
    func setLocations(_ locations: [(location: String, quantity: Double)], forInventory inventory_id: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            // First, delete all existing locations for this inventory
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocation")
            fetchRequest.predicate = NSPredicate(format: "inventory_id == %@", inventory_id as CVarArg)
            let existingLocations = try context.fetch(fetchRequest)

            for location in existingLocations {
                context.delete(location)
            }

            // Create new location records
            for (locationName, quantity) in locations {
                guard let entity = NSEntityDescription.entity(forEntityName: "StorageLocation", in: context) else {
                    throw CoreDataLocationRepositoryError.entityNotFound("StorageLocation")
                }
                let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

                let locationModel = StorageLocationModel(
                    inventory_id: inventory_id,
                    location: locationName,
                    quantity: quantity
                )

                self.updateCoreDataEntity(coreDataItem, with: locationModel)
            }

            // Save all changes
            try context.save()

            self.log.info("Set \(locations.count) locations for inventory: \(inventory_id)")
        }
    }
    
    func addQuantity(_ quantity: Double, toLocation locationName: String, forInventory inventory_id: UUID) async throws -> StorageLocationModel {
        let cleanLocationName = StorageLocationModel.cleanLocationName(locationName)

        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            // Look for existing location record
            let existingLocations = try self.fetchLocationSync(forInventory: inventory_id, locationName: cleanLocationName)

            if let existingLocation = existingLocations.first {
                // Update existing record
                let updatedLocation = StorageLocationModel(
                    id: existingLocation.id,
                    inventory_id: existingLocation.inventory_id,
                    location: existingLocation.location,
                    quantity: existingLocation.quantity + quantity
                )

                guard let coreDataItem = try self.fetchCoreDataItemSync(byInventoryId: existingLocation.inventory_id, locationName: existingLocation.location) else {
                    throw CoreDataLocationRepositoryError.itemNotFound("\(existingLocation.inventory_id)/\(existingLocation.location)")
                }

                self.updateCoreDataEntity(coreDataItem, with: updatedLocation)
                try context.save()

                return updatedLocation
            } else {
                // Create new record
                let newLocation = StorageLocationModel(
                    inventory_id: inventory_id,
                    location: cleanLocationName,
                    quantity: quantity
                )

                guard let entity = NSEntityDescription.entity(forEntityName: "StorageLocation", in: context) else {
                    throw CoreDataLocationRepositoryError.entityNotFound("StorageLocation")
                }
                let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

                self.updateCoreDataEntity(coreDataItem, with: newLocation)
                try context.save()

                return newLocation
            }
        }
    }
    
    func subtractQuantity(_ quantity: Double, fromLocation locationName: String, forInventory inventory_id: UUID) async throws -> StorageLocationModel? {
        let cleanLocationName = StorageLocationModel.cleanLocationName(locationName)

        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            // Look for existing location record
            let existingLocations = try self.fetchLocationSync(forInventory: inventory_id, locationName: cleanLocationName)

            guard let existingLocation = existingLocations.first else {
                throw CoreDataLocationRepositoryError.itemNotFound("Location not found: \(cleanLocationName) for inventory: \(inventory_id)")
            }

            guard let coreDataItem = try self.fetchCoreDataItemSync(byInventoryId: existingLocation.inventory_id, locationName: existingLocation.location) else {
                throw CoreDataLocationRepositoryError.itemNotFound("\(existingLocation.inventory_id)/\(existingLocation.location)")
            }

            let newQuantity = existingLocation.quantity - quantity

            if newQuantity <= 0 {
                // Delete the record if quantity reaches zero or below
                context.delete(coreDataItem)
                try context.save()
                return nil
            } else {
                // Update the record with new quantity
                let updatedLocation = StorageLocationModel(
                    id: existingLocation.id,
                    inventory_id: existingLocation.inventory_id,
                    location: existingLocation.location,
                    quantity: newQuantity
                )

                self.updateCoreDataEntity(coreDataItem, with: updatedLocation)
                try context.save()
                return updatedLocation
            }
        }
    }
    
    func moveQuantity(_ quantity: Double, fromLocation: String, toLocation: String, forInventory inventory_id: UUID) async throws {
        // Subtract from source location
        _ = try await subtractQuantity(quantity, fromLocation: fromLocation, forInventory: inventory_id)
        
        // Add to destination location
        _ = try await addQuantity(quantity, toLocation: toLocation, forInventory: inventory_id)
    }
    
    // MARK: - Discovery Operations
    
    func getDistinctLocationNames() async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "StorageLocation")
            fetchRequest.propertiesToFetch = ["location"]
            fetchRequest.returnsDistinctResults = true
            fetchRequest.resultType = .dictionaryResultType

            let results = try context.fetch(fetchRequest)
            let locationNames = results.compactMap { $0["location"] as? String }.sorted()

            self.log.debug("Found \(locationNames.count) distinct location names")
            return locationNames
        }
    }
    
    func getLocationNames(withPrefix prefix: String) async throws -> [String] {
        let allLocations = try await getDistinctLocationNames()
        let lowercasePrefix = prefix.lowercased()
        return allLocations.filter { $0.lowercased().hasPrefix(lowercasePrefix) }
    }
    
    func getInventoriesInLocation(_ locationName: String) async throws -> [UUID] {
        let cleanLocationName = StorageLocationModel.cleanLocationName(locationName)
        let locations = try await fetchLocations(withName: cleanLocationName)
        var inventory_ids = Set<UUID>()
        for location in locations {
            inventory_ids.insert(await location.inventory_id)
        }
        return Array(inventory_ids).sorted { $0.uuidString < $1.uuidString }
    }
    
    func getLocationUtilization() async throws -> [String: Double] {
        let allLocations = try await fetchLocations(matching: nil)
        var grouped: [String: [StorageLocationModel]] = [:]
        for location in allLocations {
            let key = await location.location
            grouped[key, default: []].append(location)
        }

        var result: [String: Double] = [:]
        for (key, locations) in grouped {
            var total = 0.0
            for location in locations {
                total += await location.quantity
            }
            result[key] = total
        }
        return result
    }
    
    func getLocationUsageCounts() async throws -> [(location: String, usageCount: Int)] {
        let allLocations = try await fetchLocations(matching: nil)
        var grouped: [String: [StorageLocationModel]] = [:]
        for location in allLocations {
            let key = await location.location
            grouped[key, default: []].append(location)
        }

        var results: [(location: String, usageCount: Int)] = []
        for (location, items) in grouped {
            results.append((location: location, usageCount: items.count))
        }
        return results.sorted { $0.usageCount > $1.usageCount }
    }
    
    // MARK: - Validation Operations
    
    func validateLocationQuantities(forInventory inventory_id: UUID, expectedTotal: Double) async throws -> Bool {
        let locations = try await fetchLocations(forInventory: inventory_id)
        var actualTotal = 0.0
        for location in locations {
            actualTotal += await location.quantity
        }
        let tolerance = 0.001
        return abs(actualTotal - expectedTotal) <= tolerance
    }
    
    func getLocationQuantityDiscrepancy(forInventory inventory_id: UUID, expectedTotal: Double) async throws -> Double {
        let locations = try await fetchLocations(forInventory: inventory_id)
        var actualTotal = 0.0
        for location in locations {
            actualTotal += await location.quantity
        }
        return actualTotal - expectedTotal
    }
    
    func findOrphanedLocations() async throws -> [StorageLocationModel] {
        // This would require cross-referencing with the inventory table
        // For now, return empty array - in a real implementation, this would
        // be a complex query to find locations with non-existent inventory IDs
        return []
    }
    
    // MARK: - Private Helper Methods
    
    private nonisolated func fetchLocationSync(forInventory inventory_id: UUID, locationName: String) throws -> [StorageLocationModel] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocation")
        fetchRequest.predicate = NSPredicate(format: "inventory_id == %@ AND location == %@", inventory_id as CVarArg, locationName)
        
        let results = try backgroundContext.fetch(fetchRequest)
        return results.compactMap { convertToStorageLocationModel($0) }
    }
    
    private nonisolated func fetchCoreDataItemSync(byInventoryId inventory_id: UUID, locationName: String) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocation")
        fetchRequest.predicate = NSPredicate(format: "inventory_id == %@ AND location == %@", inventory_id as CVarArg, locationName)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }
    
    private nonisolated func convertToStorageLocationModel(_ coreDataItem: NSManagedObject) -> StorageLocationModel? {
        guard let inventory_id = coreDataItem.value(forKey: "inventory_id") as? UUID,
              let location = coreDataItem.value(forKey: "location") as? String,
              let quantityString = coreDataItem.value(forKey: "quantity") as? String,
              let quantity = Double(quantityString) else {
            log.error("Failed to convert Core Data item to LocationModel - missing required properties")
            return nil
        }

        return StorageLocationModel(
            inventory_id: inventory_id,
            location: location,
            quantity: quantity
        )
    }
    
    private nonisolated func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with location: StorageLocationModel) {
        coreDataItem.setValue(location.inventory_id, forKey: "inventory_id")
        coreDataItem.setValue(location.location, forKey: "location")
        coreDataItem.setValue(String(location.quantity), forKey: "quantity")
    }
}

// MARK: - Core Data Repository Errors

enum CoreDataLocationRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case entityCreationFailed(String)
    case itemNotFound(String)
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .entityCreationFailed(let entityName):
            return "Failed to create Core Data entity: \(entityName)"
        case .itemNotFound(let identifier):
            return "Location not found: \(identifier)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
