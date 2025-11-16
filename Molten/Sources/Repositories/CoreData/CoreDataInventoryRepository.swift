//
//  CoreDataInventoryRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//
//  Core CRUD operations for inventory management
//  Extensions: +Quantities, +Locations, +Aggregations, +Helpers
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of InventoryRepository
/// Provides persistent storage for inventory records using Core Data
///
/// Architecture:
/// - CoreDataInventoryRepository.swift: Core CRUD operations
/// - +Quantities: Quantity manipulation (add, subtract, set)
/// - +Locations: Location queries and utilization
/// - +Aggregations: Discovery, summaries, value estimation
/// - +Helpers: Private conversion methods and errors
class CoreDataInventoryRepository: @unchecked Sendable, InventoryRepository {

    // MARK: - Dependencies

    let context: NSManagedObjectContext
    let log = Logger(subsystem: "com.flameworker.app", category: "inventory-repository")

    // MARK: - Initialization

    /// Initialize with a managed object context
    /// - Parameter context: The NSManagedObjectContext to use for data operations
    /// - Note: In production, pass PersistenceController.shared.cloudContext (user data)
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Basic CRUD Operations

    func fetchInventory(matching predicate: NSPredicate?) async throws -> [InventoryModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[InventoryModel], Error>) in
            nonisolated(unsafe) let predicateCopy = predicate
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
                    fetchRequest.predicate = predicateCopy
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "item_stable_id", ascending: true),
                        NSSortDescriptor(key: "type", ascending: true)
                    ]

                    let coreDataItems = try self.context.fetch(fetchRequest)
                    let inventoryItems = coreDataItems.compactMap { self.convertToInventoryModel($0) }

                    continuation.resume(returning: inventoryItems)

                } catch {
                    self.log.error("Failed to fetch inventory records: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchInventory(byId id: UUID) async throws -> InventoryModel? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InventoryModel?, Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    fetchRequest.fetchLimit = 1

                    let results = try self.context.fetch(fetchRequest)
                    let inventoryItem = results.first.flatMap { self.convertToInventoryModel($0) }

                    if inventoryItem != nil {
                        self.log.debug("Found inventory record with ID: \(id)")
                    } else {
                        self.log.debug("Inventory record not found with ID: \(id)")
                    }

                    continuation.resume(returning: inventoryItem)

                } catch {
                    self.log.error("Failed to fetch inventory record by ID: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchInventory(forItem item_stable_id: String) async throws -> [InventoryModel] {
        let predicate = NSPredicate(format: "item_stable_id == %@", item_stable_id)
        return try await fetchInventory(matching: predicate)
    }

    func fetchInventory(forItem item_stable_id: String, type: String) async throws -> [InventoryModel] {
        let cleanType = InventoryModel.cleanType(type)
        let predicate = NSPredicate(format: "item_stable_id == %@ AND type == %@", item_stable_id, cleanType)
        return try await fetchInventory(matching: predicate)
    }

    func createInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InventoryModel, Error>) in
            context.perform {
                do {
                    // Create new Core Data entity
                    guard let entity = NSEntityDescription.entity(forEntityName: "Inventory", in: self.context) else {
                        throw CoreDataInventoryRepositoryError.entityNotFound("Inventory")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.context)

                    // Create a new inventory model with a fresh ID for Core Data
                    let newInventory = InventoryModel(
                        id: UUID(), // Always generate new ID for Core Data persistence
                        item_stable_id: inventory.item_stable_id,
                        type: inventory.type,  // Use non-optional accessor
                        subtype: inventory.subtype,
                        subsubtype: inventory.subsubtype,
                        dimensions: inventory.dimensions,
                        quantity: inventory.quantity,
                        location: inventory.location,
                        date_added: inventory.date_added,
                        date_modified: inventory.date_modified
                    )

                    // Set properties
                    self.updateCoreDataEntity(coreDataItem, with: newInventory)

                    // Save context
                    try CoreDataErrorHandler.save(context: self.context)

                    self.log.info("Created inventory record: \(newInventory.item_stable_id) - \(newInventory.type)")
                    continuation.resume(returning: newInventory)

                } catch {
                    self.log.error("Failed to create inventory record: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createInventories(_ inventories: [InventoryModel]) async throws -> [InventoryModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[InventoryModel], Error>) in
            context.perform {
                do {
                    var createdInventories: [InventoryModel] = []

                    for inventory in inventories {
                        // Create new Core Data entity
                        guard let entity = NSEntityDescription.entity(forEntityName: "Inventory", in: self.context) else {
                            throw CoreDataInventoryRepositoryError.entityNotFound("Inventory")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.context)

                        // Create a new inventory model with a fresh ID for Core Data
                        let newInventory = InventoryModel(
                            id: UUID(), // Always generate new ID for Core Data persistence
                            item_stable_id: inventory.item_stable_id,
                            type: inventory.type,  // Use non-optional accessor
                            subtype: inventory.subtype,
                            subsubtype: inventory.subsubtype,
                            dimensions: inventory.dimensions,
                            quantity: inventory.quantity,
                            location: inventory.location,
                            date_added: inventory.date_added,
                            date_modified: inventory.date_modified
                        )

                        // Set properties
                        self.updateCoreDataEntity(coreDataItem, with: newInventory)
                        createdInventories.append(newInventory)
                    }

                    // Save all changes at once
                    try CoreDataErrorHandler.save(context: self.context)

                    self.log.info("Created \(createdInventories.count) inventory records in batch")
                    continuation.resume(returning: createdInventories)

                } catch {
                    self.log.error("Failed to create inventory records in batch: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InventoryModel, Error>) in
            context.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: inventory.id) else {
                        self.log.warning("Attempted to update non-existent inventory record: \(inventory.id)")
                        continuation.resume(throwing: CoreDataInventoryRepositoryError.itemNotFound(inventory.id.uuidString))
                        return
                    }

                    // Update properties
                    self.updateCoreDataEntity(coreDataItem, with: inventory)

                    // Save context
                    try CoreDataErrorHandler.save(context: self.context)

                    self.log.info("Updated inventory record: \(inventory.id)")
                    continuation.resume(returning: inventory)

                } catch {
                    self.log.error("Failed to update inventory record: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteInventory(id: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: id) else {
                        self.log.warning("Attempted to delete non-existent inventory record: \(id)")
                        continuation.resume(throwing: CoreDataInventoryRepositoryError.itemNotFound(id.uuidString))
                        return
                    }

                    // Delete item (this should also cascade delete any related locations)
                    self.context.delete(coreDataItem)

                    // Save context
                    try CoreDataErrorHandler.save(context: self.context)

                    self.log.info("Deleted inventory record: \(id)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete inventory record: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteInventory(forItem item_stable_id: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
                    fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@", item_stable_id)

                    let itemsToDelete = try self.context.fetch(fetchRequest)

                    for item in itemsToDelete {
                        self.context.delete(item)
                    }

                    if !itemsToDelete.isEmpty {
                        try CoreDataErrorHandler.save(context: self.context)
                    }

                    self.log.info("Deleted \(itemsToDelete.count) inventory records for item: \(item_stable_id)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete inventory records for item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteInventory(forItem item_stable_id: String, type: String) async throws {
        let cleanType = InventoryModel.cleanType(type)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
                    fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@ AND type == %@", item_stable_id, cleanType)

                    let itemsToDelete = try self.context.fetch(fetchRequest)

                    for item in itemsToDelete {
                        self.context.delete(item)
                    }

                    if !itemsToDelete.isEmpty {
                        try CoreDataErrorHandler.save(context: self.context)
                    }

                    self.log.info("Deleted \(itemsToDelete.count) inventory records for item: \(item_stable_id) type: \(cleanType)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete inventory records for item and type: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
