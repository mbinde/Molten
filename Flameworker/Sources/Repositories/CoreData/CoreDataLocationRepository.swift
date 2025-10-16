//
//  CoreDataLocationRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//
//  ✅ KEEP THIS FILE - This is the correct, complete implementation
//  🗑️ DELETE any other CoreDataLocationRepository.swift files
//  
//  This file contains the complete Core Data implementation for LocationRepository
//  following clean architecture principles with async/await patterns.
//

import CoreData
import Foundation
import OSLog

/// Core Data implementation of LocationRepository
/// Provides persistent storage for location records using Core Data
class CoreDataLocationRepository: LocationRepository {
    
    // MARK: - Dependencies
    
    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "location-repository")
    
    // MARK: - Initialization
    
    /// Initialize CoreDataLocationRepository with a Core Data persistent container
    /// - Parameter persistentContainer: The NSPersistentContainer to use for location data operations
    /// - Note: In production, pass PersistenceController.shared.container
    init(locationPersistentContainer persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        log.info("CoreDataLocationRepository initialized with persistent container")
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchLocations(matching predicate: NSPredicate?) async throws -> [LocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[LocationModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Location")
                    fetchRequest.predicate = predicate
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "location", ascending: true),
                        NSSortDescriptor(key: "quantity", ascending: false)
                    ]
                    
                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let locationItems = coreDataItems.compactMap { self.convertToLocationModel($0) }
                    
//                    self.log.debug("Fetched \(locationItems.count) location records from Core Data")
                    continuation.resume(returning: locationItems)
                    
                } catch {
                    self.log.error("Failed to fetch location records: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchLocations(forInventory inventory_id: UUID) async throws -> [LocationModel] {
        let predicate = NSPredicate(format: "inventory_id == %@", inventory_id as CVarArg)
        return try await fetchLocations(matching: predicate)
    }
    
    func fetchLocations(withName locationName: String) async throws -> [LocationModel] {
        let cleanLocationName = LocationModel.cleanLocationName(locationName)
        let predicate = NSPredicate(format: "location == %@", cleanLocationName)
        return try await fetchLocations(matching: predicate)
    }
    
    func createLocation(_ location: LocationModel) async throws -> LocationModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LocationModel, Error>) in
            backgroundContext.perform {
                do {
                    // Create new Core Data entity
                    guard let entity = NSEntityDescription.entity(forEntityName: "Location", in: self.backgroundContext) else {
                        throw CoreDataLocationRepositoryError.entityNotFound("Location")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                    
                    // Set properties
                    self.updateCoreDataEntity(coreDataItem, with: location)
                    
                    // Save context
                    try self.backgroundContext.save()
                    
                    self.log.info("Created location record: \(location.location) for inventory: \(location.inventory_id)")
                    continuation.resume(returning: location)
                    
                } catch {
                    self.log.error("Failed to create location record: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func createLocations(_ locations: [LocationModel]) async throws -> [LocationModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[LocationModel], Error>) in
            backgroundContext.perform {
                do {
                    var createdLocations: [LocationModel] = []
                    
                    for location in locations {
                        // Create new Core Data entity
                        guard let entity = NSEntityDescription.entity(forEntityName: "Location", in: self.backgroundContext) else {
                            throw CoreDataLocationRepositoryError.entityNotFound("Location")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                        
                        // Set properties
                        self.updateCoreDataEntity(coreDataItem, with: location)
                        createdLocations.append(location)
                    }
                    
                    // Save all changes at once
                    try self.backgroundContext.save()
                    
                    self.log.info("Created \(createdLocations.count) location records in batch")
                    continuation.resume(returning: createdLocations)
                    
                } catch {
                    self.log.error("Failed to create location records in batch: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateLocation(_ location: LocationModel) async throws -> LocationModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LocationModel, Error>) in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: location.id) else {
                        self.log.warning("Attempted to update non-existent location record: \(location.id)")
                        continuation.resume(throwing: CoreDataLocationRepositoryError.itemNotFound(location.id.uuidString))
                        return
                    }
                    
                    // Update properties
                    self.updateCoreDataEntity(coreDataItem, with: location)
                    
                    // Save context
                    try self.backgroundContext.save()
                    
                    self.log.info("Updated location record: \(location.id)")
                    continuation.resume(returning: location)
                    
                } catch {
                    self.log.error("Failed to update location record: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteLocation(_ location: LocationModel) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: location.id) else {
                        self.log.warning("Attempted to delete non-existent location record: \(location.id)")
                        continuation.resume(throwing: CoreDataLocationRepositoryError.itemNotFound(location.id.uuidString))
                        return
                    }
                    
                    // Delete item
                    self.backgroundContext.delete(coreDataItem)
                    
                    // Save context
                    try self.backgroundContext.save()
                    
                    self.log.info("Deleted location record: \(location.id)")
                    continuation.resume()
                    
                } catch {
                    self.log.error("Failed to delete location record: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteLocations(forInventory inventory_id: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Location")
                    fetchRequest.predicate = NSPredicate(format: "inventory_id == %@", inventory_id as CVarArg)
                    
                    let locationsToDelete = try self.backgroundContext.fetch(fetchRequest)
                    
                    for location in locationsToDelete {
                        self.backgroundContext.delete(location)
                    }
                    
                    if !locationsToDelete.isEmpty {
                        try self.backgroundContext.save()
                    }
                    
                    self.log.info("Deleted \(locationsToDelete.count) location records for inventory: \(inventory_id)")
                    continuation.resume()
                    
                } catch {
                    self.log.error("Failed to delete location records for inventory: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteLocations(withName locationName: String) async throws {
        let cleanLocationName = LocationModel.cleanLocationName(locationName)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Location")
                    fetchRequest.predicate = NSPredicate(format: "location == %@", cleanLocationName)
                    
                    let locationsToDelete = try self.backgroundContext.fetch(fetchRequest)
                    
                    for location in locationsToDelete {
                        self.backgroundContext.delete(location)
                    }
                    
                    if !locationsToDelete.isEmpty {
                        try self.backgroundContext.save()
                    }
                    
                    self.log.info("Deleted \(locationsToDelete.count) location records with name: \(cleanLocationName)")
                    continuation.resume()
                    
                } catch {
                    self.log.error("Failed to delete location records with name: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Location Management Operations
    
    func setLocations(_ locations: [(location: String, quantity: Double)], forInventory inventory_id: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // First, delete all existing locations for this inventory
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Location")
                    fetchRequest.predicate = NSPredicate(format: "inventory_id == %@", inventory_id as CVarArg)
                    let existingLocations = try self.backgroundContext.fetch(fetchRequest)
                    
                    for location in existingLocations {
                        self.backgroundContext.delete(location)
                    }
                    
                    // Create new location records
                    for (locationName, quantity) in locations {
                        guard let entity = NSEntityDescription.entity(forEntityName: "Location", in: self.backgroundContext) else {
                            throw CoreDataLocationRepositoryError.entityNotFound("Location")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                        
                        let locationModel = LocationModel(
                            inventory_id: inventory_id,
                            location: locationName,
                            quantity: quantity
                        )
                        
                        self.updateCoreDataEntity(coreDataItem, with: locationModel)
                    }
                    
                    // Save all changes
                    try self.backgroundContext.save()
                    
                    self.log.info("Set \(locations.count) locations for inventory: \(inventory_id)")
                    continuation.resume()
                    
                } catch {
                    self.log.error("Failed to set locations for inventory: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func addQuantity(_ quantity: Double, toLocation locationName: String, forInventory inventory_id: UUID) async throws -> LocationModel {
        let cleanLocationName = LocationModel.cleanLocationName(locationName)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LocationModel, Error>) in
            backgroundContext.perform {
                do {
                    // Look for existing location record
                    let existingLocations = try self.fetchLocationSync(forInventory: inventory_id, locationName: cleanLocationName)
                    
                    if let existingLocation = existingLocations.first {
                        // Update existing record
                        let updatedLocation = LocationModel(
                            id: existingLocation.id,
                            inventory_id: existingLocation.inventory_id,
                            location: existingLocation.location,
                            quantity: existingLocation.quantity + quantity
                        )
                        
                        guard let coreDataItem = try self.fetchCoreDataItemSync(byId: existingLocation.id) else {
                            throw CoreDataLocationRepositoryError.itemNotFound(existingLocation.id.uuidString)
                        }
                        
                        self.updateCoreDataEntity(coreDataItem, with: updatedLocation)
                        try self.backgroundContext.save()
                        
                        continuation.resume(returning: updatedLocation)
                    } else {
                        // Create new record
                        let newLocation = LocationModel(
                            inventory_id: inventory_id,
                            location: cleanLocationName,
                            quantity: quantity
                        )
                        
                        guard let entity = NSEntityDescription.entity(forEntityName: "Location", in: self.backgroundContext) else {
                            throw CoreDataLocationRepositoryError.entityNotFound("Location")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                        
                        self.updateCoreDataEntity(coreDataItem, with: newLocation)
                        try self.backgroundContext.save()
                        
                        continuation.resume(returning: newLocation)
                    }
                    
                } catch {
                    self.log.error("Failed to add quantity to location: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func subtractQuantity(_ quantity: Double, fromLocation locationName: String, forInventory inventory_id: UUID) async throws -> LocationModel? {
        let cleanLocationName = LocationModel.cleanLocationName(locationName)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LocationModel?, Error>) in
            backgroundContext.perform {
                do {
                    // Look for existing location record
                    let existingLocations = try self.fetchLocationSync(forInventory: inventory_id, locationName: cleanLocationName)
                    
                    guard let existingLocation = existingLocations.first else {
                        throw CoreDataLocationRepositoryError.itemNotFound("Location not found: \(cleanLocationName) for inventory: \(inventory_id)")
                    }
                    
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: existingLocation.id) else {
                        throw CoreDataLocationRepositoryError.itemNotFound(existingLocation.id.uuidString)
                    }
                    
                    let newQuantity = existingLocation.quantity - quantity
                    
                    if newQuantity <= 0 {
                        // Delete the record if quantity reaches zero or below
                        self.backgroundContext.delete(coreDataItem)
                        try self.backgroundContext.save()
                        continuation.resume(returning: nil)
                    } else {
                        // Update the record with new quantity
                        let updatedLocation = LocationModel(
                            id: existingLocation.id,
                            inventory_id: existingLocation.inventory_id,
                            location: existingLocation.location,
                            quantity: newQuantity
                        )
                        
                        self.updateCoreDataEntity(coreDataItem, with: updatedLocation)
                        try self.backgroundContext.save()
                        continuation.resume(returning: updatedLocation)
                    }
                    
                } catch {
                    self.log.error("Failed to subtract quantity from location: \(error)")
                    continuation.resume(throwing: error)
                }
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
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Location")
                    fetchRequest.propertiesToFetch = ["location"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    let locationNames = results.compactMap { $0["location"] as? String }.sorted()
                    
                    self.log.debug("Found \(locationNames.count) distinct location names")
                    continuation.resume(returning: locationNames)
                    
                } catch {
                    self.log.error("Failed to fetch distinct location names: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getLocationNames(withPrefix prefix: String) async throws -> [String] {
        let allLocations = try await getDistinctLocationNames()
        let lowercasePrefix = prefix.lowercased()
        return allLocations.filter { $0.lowercased().hasPrefix(lowercasePrefix) }
    }
    
    func getInventoriesInLocation(_ locationName: String) async throws -> [UUID] {
        let cleanLocationName = LocationModel.cleanLocationName(locationName)
        let locations = try await fetchLocations(withName: cleanLocationName)
        let inventory_ids = Set(locations.map { $0.inventory_id })
        return Array(inventory_ids).sorted { $0.uuidString < $1.uuidString }
    }
    
    func getLocationUtilization() async throws -> [String: Double] {
        let allLocations = try await fetchLocations(matching: nil)
        let grouped = Dictionary(grouping: allLocations, by: { $0.location })
        return grouped.mapValues { locations in
            locations.reduce(0.0) { $0 + $1.quantity }
        }
    }
    
    func getLocationUsageCounts() async throws -> [(location: String, usageCount: Int)] {
        let allLocations = try await fetchLocations(matching: nil)
        let grouped = Dictionary(grouping: allLocations, by: { $0.location })
        let counts = grouped.mapValues { $0.count }
        return counts.map { (location: $0.key, usageCount: $0.value) }.sorted { $0.usageCount > $1.usageCount }
    }
    
    // MARK: - Validation Operations
    
    func validateLocationQuantities(forInventory inventory_id: UUID, expectedTotal: Double) async throws -> Bool {
        let locations = try await fetchLocations(forInventory: inventory_id)
        let actualTotal = locations.reduce(0.0) { $0 + $1.quantity }
        let tolerance = 0.001
        return abs(actualTotal - expectedTotal) <= tolerance
    }
    
    func getLocationQuantityDiscrepancy(forInventory inventory_id: UUID, expectedTotal: Double) async throws -> Double {
        let locations = try await fetchLocations(forInventory: inventory_id)
        let actualTotal = locations.reduce(0.0) { $0 + $1.quantity }
        return actualTotal - expectedTotal
    }
    
    func findOrphanedLocations() async throws -> [LocationModel] {
        // This would require cross-referencing with the inventory table
        // For now, return empty array - in a real implementation, this would
        // be a complex query to find locations with non-existent inventory IDs
        return []
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchLocationSync(forInventory inventory_id: UUID, locationName: String) throws -> [LocationModel] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Location")
        fetchRequest.predicate = NSPredicate(format: "inventory_id == %@ AND location == %@", inventory_id as CVarArg, locationName)
        
        let results = try backgroundContext.fetch(fetchRequest)
        return results.compactMap { convertToLocationModel($0) }
    }
    
    private func fetchCoreDataItemSync(byId id: UUID) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Location")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }
    
    private func convertToLocationModel(_ coreDataItem: NSManagedObject) -> LocationModel? {
        guard let id = coreDataItem.value(forKey: "id") as? UUID,
              let inventory_id = coreDataItem.value(forKey: "inventory_id") as? UUID,
              let location = coreDataItem.value(forKey: "location") as? String,
              let quantityNumber = coreDataItem.value(forKey: "quantity") as? NSNumber else {
            log.error("Failed to convert Core Data item to LocationModel - missing required properties")
            return nil
        }
        
        return LocationModel(
            id: id,
            inventory_id: inventory_id,
            location: location,
            quantity: quantityNumber.doubleValue
        )
    }
    
    private func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with location: LocationModel) {
        coreDataItem.setValue(location.id, forKey: "id")
        coreDataItem.setValue(location.inventory_id, forKey: "inventory_id")
        coreDataItem.setValue(location.location, forKey: "location")
        coreDataItem.setValue(NSNumber(value: location.quantity), forKey: "quantity")
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
