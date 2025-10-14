//
//  CoreDataInventoryRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import CoreData
import Foundation
import OSLog

/// Core Data implementation of InventoryRepository
/// Provides persistent storage for inventory records using Core Data
class CoreDataInventoryRepository: InventoryRepository {
    
    // MARK: - Dependencies
    
    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "inventory-repository")
    
    // MARK: - Initialization
    
    /// Initialize with a Core Data persistent container
    /// - Parameter persistentContainer: The NSPersistentContainer to use for data operations
    /// - Note: In production, pass PersistenceController.shared.container
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        log.info("CoreDataInventoryRepository initialized with persistent container")
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchInventory(matching predicate: NSPredicate?) async throws -> [InventoryModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[InventoryModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
                    fetchRequest.predicate = predicate
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "item_natural_key", ascending: true),
                        NSSortDescriptor(key: "type", ascending: true)
                    ]
                    
                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let inventoryItems = coreDataItems.compactMap { self.convertToInventoryModel($0) }
                    
                    self.log.debug("Fetched \(inventoryItems.count) inventory records from Core Data")
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
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    fetchRequest.fetchLimit = 1
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    let inventoryItem = results.first.flatMap { self.convertToInventoryModel($0) }
                    
                    if let item = inventoryItem {
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
    
    func fetchInventory(forItem itemNaturalKey: String) async throws -> [InventoryModel] {
        let predicate = NSPredicate(format: "item_natural_key == %@", itemNaturalKey)
        return try await fetchInventory(matching: predicate)
    }
    
    func fetchInventory(forItem itemNaturalKey: String, type: String) async throws -> [InventoryModel] {
        let cleanType = InventoryModel.cleanType(type)
        let predicate = NSPredicate(format: "item_natural_key == %@ AND type == %@", itemNaturalKey, cleanType)
        return try await fetchInventory(matching: predicate)
    }
    
    func createInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InventoryModel, Error>) in
            backgroundContext.perform {
                do {
                    // Create new Core Data entity
                    guard let entity = NSEntityDescription.entity(forEntityName: "Inventory", in: self.backgroundContext) else {
                        throw CoreDataInventoryRepositoryError.entityNotFound("Inventory")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                    
                    // Create a new inventory model with a fresh ID for Core Data
                    let newInventory = InventoryModel(
                        id: UUID(), // Always generate new ID for Core Data persistence
                        itemNaturalKey: inventory.itemNaturalKey,
                        type: inventory.type,
                        quantity: inventory.quantity
                    )
                    
                    // Set properties
                    self.updateCoreDataEntity(coreDataItem, with: newInventory)
                    
                    // Save context
                    try self.backgroundContext.save()
                    
                    self.log.info("Created inventory record: \(newInventory.itemNaturalKey) - \(newInventory.type)")
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
            backgroundContext.perform {
                do {
                    var createdInventories: [InventoryModel] = []
                    
                    for inventory in inventories {
                        // Create new Core Data entity
                        guard let entity = NSEntityDescription.entity(forEntityName: "Inventory", in: self.backgroundContext) else {
                            throw CoreDataInventoryRepositoryError.entityNotFound("Inventory")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                        
                        // Create a new inventory model with a fresh ID for Core Data
                        let newInventory = InventoryModel(
                            id: UUID(), // Always generate new ID for Core Data persistence
                            itemNaturalKey: inventory.itemNaturalKey,
                            type: inventory.type,
                            quantity: inventory.quantity
                        )
                        
                        // Set properties
                        self.updateCoreDataEntity(coreDataItem, with: newInventory)
                        createdInventories.append(newInventory)
                    }
                    
                    // Save all changes at once
                    try self.backgroundContext.save()
                    
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
            backgroundContext.perform {
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
                    try self.backgroundContext.save()
                    
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
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: id) else {
                        self.log.warning("Attempted to delete non-existent inventory record: \(id)")
                        continuation.resume(throwing: CoreDataInventoryRepositoryError.itemNotFound(id.uuidString))
                        return
                    }
                    
                    // Delete item (this should also cascade delete any related locations)
                    self.backgroundContext.delete(coreDataItem)
                    
                    // Save context
                    try self.backgroundContext.save()
                    
                    self.log.info("Deleted inventory record: \(id)")
                    continuation.resume()
                    
                } catch {
                    self.log.error("Failed to delete inventory record: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteInventory(forItem itemNaturalKey: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
                    fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@", itemNaturalKey)
                    
                    let itemsToDelete = try self.backgroundContext.fetch(fetchRequest)
                    
                    for item in itemsToDelete {
                        self.backgroundContext.delete(item)
                    }
                    
                    if !itemsToDelete.isEmpty {
                        try self.backgroundContext.save()
                    }
                    
                    self.log.info("Deleted \(itemsToDelete.count) inventory records for item: \(itemNaturalKey)")
                    continuation.resume()
                    
                } catch {
                    self.log.error("Failed to delete inventory records for item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteInventory(forItem itemNaturalKey: String, type: String) async throws {
        let cleanType = InventoryModel.cleanType(type)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
                    fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@ AND type == %@", itemNaturalKey, cleanType)
                    
                    let itemsToDelete = try self.backgroundContext.fetch(fetchRequest)
                    
                    for item in itemsToDelete {
                        self.backgroundContext.delete(item)
                    }
                    
                    if !itemsToDelete.isEmpty {
                        try self.backgroundContext.save()
                    }
                    
                    self.log.info("Deleted \(itemsToDelete.count) inventory records for item: \(itemNaturalKey) type: \(cleanType)")
                    continuation.resume()
                    
                } catch {
                    self.log.error("Failed to delete inventory records for item and type: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Quantity Operations
    
    func getTotalQuantity(forItem itemNaturalKey: String) async throws -> Double {
        let inventoryRecords = try await fetchInventory(forItem: itemNaturalKey)
        return inventoryRecords.reduce(0.0) { $0 + $1.quantity }
    }
    
    func getTotalQuantity(forItem itemNaturalKey: String, type: String) async throws -> Double {
        let inventoryRecords = try await fetchInventory(forItem: itemNaturalKey, type: type)
        return inventoryRecords.reduce(0.0) { $0 + $1.quantity }
    }
    
    func addQuantity(_ quantity: Double, toItem itemNaturalKey: String, type: String) async throws -> InventoryModel {
        let cleanType = InventoryModel.cleanType(type)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InventoryModel, Error>) in
            backgroundContext.perform {
                do {
                    // Look for existing inventory record
                    let existingRecords = try self.fetchInventorySync(forItem: itemNaturalKey, type: cleanType)
                    
                    if let existingRecord = existingRecords.first {
                        // Update existing record
                        let updatedRecord = InventoryModel(
                            id: existingRecord.id,
                            itemNaturalKey: existingRecord.itemNaturalKey,
                            type: existingRecord.type,
                            quantity: existingRecord.quantity + quantity
                        )
                        
                        guard let coreDataItem = try self.fetchCoreDataItemSync(byId: existingRecord.id) else {
                            throw CoreDataInventoryRepositoryError.itemNotFound(existingRecord.id.uuidString)
                        }
                        
                        self.updateCoreDataEntity(coreDataItem, with: updatedRecord)
                        try self.backgroundContext.save()
                        
                        continuation.resume(returning: updatedRecord)
                    } else {
                        // Create new record
                        let newRecord = InventoryModel(
                            itemNaturalKey: itemNaturalKey,
                            type: cleanType,
                            quantity: quantity
                        )
                        
                        guard let entity = NSEntityDescription.entity(forEntityName: "Inventory", in: self.backgroundContext) else {
                            throw CoreDataInventoryRepositoryError.entityNotFound("Inventory")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                        
                        self.updateCoreDataEntity(coreDataItem, with: newRecord)
                        try self.backgroundContext.save()
                        
                        continuation.resume(returning: newRecord)
                    }
                    
                } catch {
                    self.log.error("Failed to add quantity: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func subtractQuantity(_ quantity: Double, fromItem itemNaturalKey: String, type: String) async throws -> InventoryModel? {
        let cleanType = InventoryModel.cleanType(type)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InventoryModel?, Error>) in
            backgroundContext.perform {
                do {
                    // Look for existing inventory record
                    let existingRecords = try self.fetchInventorySync(forItem: itemNaturalKey, type: cleanType)
                    
                    guard let existingRecord = existingRecords.first else {
                        throw CoreDataInventoryRepositoryError.itemNotFound("No inventory found for \(itemNaturalKey) - \(cleanType)")
                    }
                    
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: existingRecord.id) else {
                        throw CoreDataInventoryRepositoryError.itemNotFound(existingRecord.id.uuidString)
                    }
                    
                    let newQuantity = existingRecord.quantity - quantity
                    
                    if newQuantity <= 0 {
                        // Delete the record if quantity reaches zero or below
                        self.backgroundContext.delete(coreDataItem)
                        try self.backgroundContext.save()
                        continuation.resume(returning: nil)
                    } else {
                        // Update the record with new quantity
                        let updatedRecord = InventoryModel(
                            id: existingRecord.id,
                            itemNaturalKey: existingRecord.itemNaturalKey,
                            type: existingRecord.type,
                            quantity: newQuantity
                        )
                        
                        self.updateCoreDataEntity(coreDataItem, with: updatedRecord)
                        try self.backgroundContext.save()
                        continuation.resume(returning: updatedRecord)
                    }
                    
                } catch {
                    self.log.error("Failed to subtract quantity: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func setQuantity(_ quantity: Double, forItem itemNaturalKey: String, type: String) async throws -> InventoryModel? {
        let cleanType = InventoryModel.cleanType(type)
        
        if quantity <= 0 {
            // Delete any existing records for this item-type combination
            try await deleteInventory(forItem: itemNaturalKey, type: cleanType)
            return nil
        } else {
            // Look for existing record and update, or create new one
            let existingRecords = try await fetchInventory(forItem: itemNaturalKey, type: cleanType)
            
            if let existingRecord = existingRecords.first {
                // Update existing record
                let updatedRecord = InventoryModel(
                    id: existingRecord.id,
                    itemNaturalKey: existingRecord.itemNaturalKey,
                    type: existingRecord.type,
                    quantity: quantity
                )
                return try await updateInventory(updatedRecord)
            } else {
                // Create new record
                let newRecord = InventoryModel(
                    itemNaturalKey: itemNaturalKey,
                    type: cleanType,
                    quantity: quantity
                )
                return try await createInventory(newRecord)
            }
        }
    }
    
    // MARK: - Discovery Operations
    
    func getDistinctTypes() async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Inventory")
                    fetchRequest.propertiesToFetch = ["type"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    let types = results.compactMap { $0["type"] as? String }.sorted()
                    
                    self.log.debug("Found \(types.count) distinct inventory types")
                    continuation.resume(returning: types)
                    
                } catch {
                    self.log.error("Failed to fetch distinct types: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getItemsWithInventory() async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Inventory")
                    fetchRequest.propertiesToFetch = ["item_natural_key"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    let naturalKeys = results.compactMap { $0["item_natural_key"] as? String }.sorted()
                    
                    self.log.debug("Found \(naturalKeys.count) items with inventory")
                    continuation.resume(returning: naturalKeys)
                    
                } catch {
                    self.log.error("Failed to fetch items with inventory: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getItemsWithInventory(ofType type: String) async throws -> [String] {
        let cleanType = InventoryModel.cleanType(type)
        let predicate = NSPredicate(format: "type == %@", cleanType)
        let inventoryRecords = try await fetchInventory(matching: predicate)
        return Array(Set(inventoryRecords.map { $0.itemNaturalKey })).sorted()
    }
    
    func getItemsWithLowInventory(threshold: Double) async throws -> [(itemNaturalKey: String, type: String, quantity: Double)] {
        let predicate = NSPredicate(format: "quantity > 0 AND quantity < %f", threshold)
        let inventoryRecords = try await fetchInventory(matching: predicate)
        
        return inventoryRecords.map { record in
            (itemNaturalKey: record.itemNaturalKey, type: record.type, quantity: record.quantity)
        }.sorted { $0.quantity < $1.quantity }
    }
    
    func getItemsWithZeroInventory() async throws -> [String] {
        // This is conceptually tricky - items with "zero inventory" are items that
        // had inventory records but now have zero quantity. In our model, we delete
        // zero quantity records, so this would require tracking historical data.
        // For now, returning empty array as zero quantity records are deleted.
        return []
    }
    
    // MARK: - Aggregation Operations
    
    func getInventorySummary() async throws -> [InventorySummaryModel] {
        let allInventory = try await fetchInventory(matching: nil)
        let groupedByItem = Dictionary(grouping: allInventory) { $0.itemNaturalKey }
        
        return groupedByItem.map { (naturalKey, inventories) in
            InventorySummaryModel(itemNaturalKey: naturalKey, inventories: inventories)
        }.sorted { $0.itemNaturalKey < $1.itemNaturalKey }
    }
    
    func getInventorySummary(forItem itemNaturalKey: String) async throws -> InventorySummaryModel? {
        let inventories = try await fetchInventory(forItem: itemNaturalKey)
        guard !inventories.isEmpty else { return nil }
        
        return InventorySummaryModel(itemNaturalKey: itemNaturalKey, inventories: inventories)
    }
    
    func estimateInventoryValue(defaultPricePerUnit: Double) async throws -> [String: Double] {
        let allInventory = try await fetchInventory(matching: nil)
        let groupedByItem = Dictionary(grouping: allInventory) { $0.itemNaturalKey }
        
        return groupedByItem.mapValues { inventories in
            let totalQuantity = inventories.reduce(0.0) { $0 + $1.quantity }
            return totalQuantity * defaultPricePerUnit
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchInventorySync(forItem itemNaturalKey: String, type: String) throws -> [InventoryModel] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
        fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@ AND type == %@", itemNaturalKey, type)
        
        let results = try backgroundContext.fetch(fetchRequest)
        return results.compactMap { convertToInventoryModel($0) }
    }
    
    private func fetchCoreDataItemSync(byId id: UUID) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }
    
    private func convertToInventoryModel(_ coreDataItem: NSManagedObject) -> InventoryModel? {
        guard let idData = coreDataItem.value(forKey: "id") as? UUID,
              let itemNaturalKey = coreDataItem.value(forKey: "item_natural_key") as? String,
              let type = coreDataItem.value(forKey: "type") as? String,
              let quantityNumber = coreDataItem.value(forKey: "quantity") as? NSNumber else {
            log.error("Failed to convert Core Data item to InventoryModel - missing required properties")
            return nil
        }
        
        return InventoryModel(
            id: idData,
            itemNaturalKey: itemNaturalKey,
            type: type,
            quantity: quantityNumber.doubleValue
        )
    }
    
    private func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with inventory: InventoryModel) {
        coreDataItem.setValue(inventory.id, forKey: "id")
        coreDataItem.setValue(inventory.itemNaturalKey, forKey: "item_natural_key")
        coreDataItem.setValue(inventory.type, forKey: "type")
        coreDataItem.setValue(NSNumber(value: inventory.quantity), forKey: "quantity")
    }
}

// MARK: - Core Data Repository Errors

enum CoreDataInventoryRepositoryError: Error, LocalizedError {
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
            return "Inventory item not found: \(identifier)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}