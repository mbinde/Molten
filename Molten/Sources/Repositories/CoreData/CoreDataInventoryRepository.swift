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
    let log = Logger(subsystem: "com.motleywoods.molten", category: "inventory-repository")

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
        nonisolated(unsafe) let predicateCopy = predicate
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
            fetchRequest.predicate = predicateCopy
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "item_stable_id", ascending: true),
                NSSortDescriptor(key: "type", ascending: true)
            ]

            let coreDataItems = try context.fetch(fetchRequest)
            let inventoryItems = coreDataItems.compactMap { self.convertToInventoryModel($0) }

            return inventoryItems
        }
    }

    func fetchInventory(byId id: UUID) async throws -> InventoryModel? {
        return try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            let results = try context.fetch(fetchRequest)
            let inventoryItem = results.first.flatMap { self.convertToInventoryModel($0) }

            if inventoryItem != nil {
                self.log.debug("Found inventory record with ID: \(id)")
            } else {
                self.log.debug("Inventory record not found with ID: \(id)")
            }

            return inventoryItem
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
        return try await CoreDataHelper.performAsync(on: context) { context in
            // Create new Core Data entity
            guard let entity = NSEntityDescription.entity(forEntityName: "Inventory", in: context) else {
                throw CoreDataInventoryRepositoryError.entityNotFound("Inventory")
            }
            let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

            // Create a new inventory model with a fresh ID for Core Data
            let newInventory = InventoryModel(
                id: UUID(), // Always generate new ID for Core Data persistence
                item_stable_id: inventory.item_stable_id,
                type: inventory.type,  // Use non-optional accessor
                subtype: inventory.subtype,
                subsubtype: inventory.subsubtype,
                dimensions: inventory.dimensions,
                quantity: inventory.quantity,
                containerCount: inventory.containerCount,
                location: inventory.location,
                date_added: inventory.date_added,
                date_modified: inventory.date_modified
            )

            // Set properties
            self.updateCoreDataEntity(coreDataItem, with: newInventory)

            // Save context
            try CoreDataErrorHandler.save(context: context)

            self.log.info("Created inventory record: \(newInventory.item_stable_id) - \(newInventory.type)")
            return newInventory
        }
    }

    func createInventories(_ inventories: [InventoryModel]) async throws -> [InventoryModel] {
        return try await CoreDataHelper.performAsync(on: context) { context in
            var createdInventories: [InventoryModel] = []

            for inventory in inventories {
                // Create new Core Data entity
                guard let entity = NSEntityDescription.entity(forEntityName: "Inventory", in: context) else {
                    throw CoreDataInventoryRepositoryError.entityNotFound("Inventory")
                }
                let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

                // Create a new inventory model with a fresh ID for Core Data
                let newInventory = InventoryModel(
                    id: UUID(), // Always generate new ID for Core Data persistence
                    item_stable_id: inventory.item_stable_id,
                    type: inventory.type,  // Use non-optional accessor
                    subtype: inventory.subtype,
                    subsubtype: inventory.subsubtype,
                    dimensions: inventory.dimensions,
                    quantity: inventory.quantity,
                    containerCount: inventory.containerCount,
                    location: inventory.location,
                    date_added: inventory.date_added,
                    date_modified: inventory.date_modified
                )

                // Set properties
                self.updateCoreDataEntity(coreDataItem, with: newInventory)
                createdInventories.append(newInventory)
            }

            // Save all changes at once
            try CoreDataErrorHandler.save(context: context)

            self.log.info("Created \(createdInventories.count) inventory records in batch")
            return createdInventories
        }
    }

    func updateInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        return try await CoreDataHelper.performAsync(on: context) { context in
            // Find existing item
            guard let coreDataItem = try self.fetchCoreDataItemSync(byId: inventory.id) else {
                self.log.warning("Attempted to update non-existent inventory record: \(inventory.id)")
                throw CoreDataInventoryRepositoryError.itemNotFound(inventory.id.uuidString)
            }

            // Update properties
            self.updateCoreDataEntity(coreDataItem, with: inventory)

            // Save context
            try CoreDataErrorHandler.save(context: context)

            self.log.info("Updated inventory record: \(inventory.id)")
            return inventory
        }
    }

    func deleteInventory(id: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            // Find existing item
            guard let coreDataItem = try self.fetchCoreDataItemSync(byId: id) else {
                // Item doesn't exist - this is actually success (idempotent deletion)
                // It may have been deleted by CloudKit sync or on another device
                self.log.info("Inventory record already deleted or doesn't exist: \(id)")
                return
            }

            // Delete item (this should also cascade delete any related locations)
            context.delete(coreDataItem)

            // Save context
            try CoreDataErrorHandler.save(context: context)

            self.log.info("Deleted inventory record: \(id)")
                    }
    }

    func deleteInventory(forItem item_stable_id: String) async throws {
        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
            fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@", item_stable_id)

            let itemsToDelete = try context.fetch(fetchRequest)

            for item in itemsToDelete {
                context.delete(item)
            }

            if !itemsToDelete.isEmpty {
                try CoreDataErrorHandler.save(context: context)
            }

            self.log.info("Deleted \(itemsToDelete.count) inventory records for item: \(item_stable_id)")
                    }
    }

    func deleteInventory(forItem item_stable_id: String, type: String) async throws {
        let cleanType = InventoryModel.cleanType(type)

        try await CoreDataHelper.performAsyncVoid(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
            fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@ AND type == %@", item_stable_id, cleanType)

            let itemsToDelete = try context.fetch(fetchRequest)

            for item in itemsToDelete {
                context.delete(item)
            }

            if !itemsToDelete.isEmpty {
                try CoreDataErrorHandler.save(context: context)
            }

            self.log.info("Deleted \(itemsToDelete.count) inventory records for item: \(item_stable_id) type: \(cleanType)")
                    }
    }
}
