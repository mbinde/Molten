//
//  CoreDataInventoryRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of InventoryRepository
/// Provides persistent storage for inventory records using Core Data
class CoreDataInventoryRepository: @unchecked Sendable, InventoryRepository {
    
    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "inventory-repository")

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
                    try self.context.save()
                    
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
                    try self.context.save()
                    
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
                    try self.context.save()
                    
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
                    try self.context.save()
                    
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
                        try self.context.save()
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
                        try self.context.save()
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
    
    // MARK: - Quantity Operations
    
    func getTotalQuantity(forItem item_stable_id: String) async throws -> Double {
        let inventoryRecords = try await fetchInventory(forItem: item_stable_id)
        var total = 0.0
        for record in inventoryRecords {
            total += await record.quantity
        }
        return total
    }
    
    func getTotalQuantity(forItem item_stable_id: String, type: String) async throws -> Double {
        let inventoryRecords = try await fetchInventory(forItem: item_stable_id, type: type)
        var total = 0.0
        for record in inventoryRecords {
            total += await record.quantity
        }
        return total
    }
    
    func addQuantity(_ quantity: Double, toItem item_stable_id: String, type: String) async throws -> InventoryModel {
        let cleanType = InventoryModel.cleanType(type)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InventoryModel, Error>) in
            context.perform {
                do {
                    // Look for existing inventory record
                    let existingRecords = try self.fetchInventorySync(forItem: item_stable_id, type: cleanType)
                    
                    if let existingRecord = existingRecords.first {
                        // Update existing record
                        let updatedRecord = InventoryModel(
                            id: existingRecord.id,
                            item_stable_id: existingRecord.item_stable_id,
                            type: existingRecord.type,  // Use non-optional accessor
                            quantity: existingRecord.quantity + quantity,
                            date_added: existingRecord.date_added,
                            date_modified: Date() // Set to current time on update
                        )
                        
                        guard let coreDataItem = try self.fetchCoreDataItemSync(byId: existingRecord.id) else {
                            throw CoreDataInventoryRepositoryError.itemNotFound(existingRecord.id.uuidString)
                        }
                        
                        self.updateCoreDataEntity(coreDataItem, with: updatedRecord)
                        try self.context.save()
                        
                        continuation.resume(returning: updatedRecord)
                    } else {
                        // Create new record
                        let newRecord = InventoryModel(
                            item_stable_id: item_stable_id,
                            type: cleanType,
                            quantity: quantity
                        )
                        
                        guard let entity = NSEntityDescription.entity(forEntityName: "Inventory", in: self.context) else {
                            throw CoreDataInventoryRepositoryError.entityNotFound("Inventory")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.context)
                        
                        self.updateCoreDataEntity(coreDataItem, with: newRecord)
                        try self.context.save()
                        
                        continuation.resume(returning: newRecord)
                    }
                    
                } catch {
                    self.log.error("Failed to add quantity: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func subtractQuantity(_ quantity: Double, fromItem item_stable_id: String, type: String) async throws -> InventoryModel? {
        let cleanType = InventoryModel.cleanType(type)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InventoryModel?, Error>) in
            context.perform {
                do {
                    // Look for existing inventory record
                    let existingRecords = try self.fetchInventorySync(forItem: item_stable_id, type: cleanType)
                    
                    guard let existingRecord = existingRecords.first else {
                        throw CoreDataInventoryRepositoryError.itemNotFound("No inventory found for \(item_stable_id) - \(cleanType)")
                    }
                    
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: existingRecord.id) else {
                        throw CoreDataInventoryRepositoryError.itemNotFound(existingRecord.id.uuidString)
                    }
                    
                    let newQuantity = existingRecord.quantity - quantity
                    
                    if newQuantity <= 0 {
                        // Delete the record if quantity reaches zero or below
                        self.context.delete(coreDataItem)
                        try self.context.save()
                        continuation.resume(returning: nil)
                    } else {
                        // Update the record with new quantity
                        let updatedRecord = InventoryModel(
                            id: existingRecord.id,
                            item_stable_id: existingRecord.item_stable_id,
                            type: existingRecord.type,  // Use non-optional accessor
                            quantity: newQuantity,
                            date_added: existingRecord.date_added,
                            date_modified: Date() // Set to current time on update
                        )
                        
                        self.updateCoreDataEntity(coreDataItem, with: updatedRecord)
                        try self.context.save()
                        continuation.resume(returning: updatedRecord)
                    }
                    
                } catch {
                    self.log.error("Failed to subtract quantity: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func setQuantity(_ quantity: Double, forItem item_stable_id: String, type: String) async throws -> InventoryModel? {
        let cleanType = InventoryModel.cleanType(type)
        
        if quantity <= 0 {
            // Delete any existing records for this item-type combination
            try await deleteInventory(forItem: item_stable_id, type: cleanType)
            return nil
        } else {
            // Look for existing record and update, or create new one
            let existingRecords = try await fetchInventory(forItem: item_stable_id, type: cleanType)
            
            if let existingRecord = existingRecords.first {
                // Update existing record
                let updatedRecord = InventoryModel(
                    id: existingRecord.id,
                    item_stable_id: existingRecord.item_stable_id,
                    type: existingRecord.type,  // Use non-optional accessor
                    quantity: quantity,
                    date_added: existingRecord.date_added,
                    date_modified: Date() // Set to current time on update
                )
                return try await updateInventory(updatedRecord)
            } else {
                // Create new record
                let newRecord = InventoryModel(
                    item_stable_id: item_stable_id,
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
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Inventory")
                    fetchRequest.propertiesToFetch = ["type"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType
                    
                    let results = try self.context.fetch(fetchRequest)
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
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Inventory")
                    fetchRequest.propertiesToFetch = ["item_stable_id"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType
                    
                    let results = try self.context.fetch(fetchRequest)
                    let naturalKeys = results.compactMap { $0["item_stable_id"] as? String }.sorted()
                    
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
        var itemStableIds = Set<String>()
        for record in inventoryRecords {
            itemStableIds.insert(await record.item_stable_id)
        }
        return Array(itemStableIds).sorted()
    }
    
    func getItemsWithLowInventory(threshold: Double) async throws -> [(item_stable_id: String, type: String, quantity: Double)] {
        let predicate = NSPredicate(format: "quantity > 0 AND quantity < %f", threshold)
        let inventoryRecords = try await fetchInventory(matching: predicate)

        var results: [(item_stable_id: String, type: String, quantity: Double)] = []
        for record in inventoryRecords {
            results.append((
                item_stable_id: await record.item_stable_id,
                type: await record.type,
                quantity: await record.quantity
            ))
        }
        return results.sorted { $0.quantity < $1.quantity }
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
        var groupedByItem: [String: [InventoryModel]] = [:]
        for inventory in allInventory {
            let key = await inventory.item_stable_id
            groupedByItem[key, default: []].append(inventory)
        }

        var results: [InventorySummaryModel] = []
        for (naturalKey, inventories) in groupedByItem {
            results.append(InventorySummaryModel(item_stable_id: naturalKey, inventories: inventories))
        }
        return results.sorted { $0.item_stable_id < $1.item_stable_id }
    }
    
    func getInventorySummary(forItem item_stable_id: String) async throws -> InventorySummaryModel? {
        let inventories = try await fetchInventory(forItem: item_stable_id)
        guard !inventories.isEmpty else { return nil }
        
        return InventorySummaryModel(item_stable_id: item_stable_id, inventories: inventories)
    }
    
    func estimateInventoryValue(defaultPricePerUnit: Double) async throws -> [String: Double] {
        let allInventory = try await fetchInventory(matching: nil)
        var groupedByItem: [String: [InventoryModel]] = [:]
        for inventory in allInventory {
            let key = await inventory.item_stable_id
            groupedByItem[key, default: []].append(inventory)
        }

        var result: [String: Double] = [:]
        for (key, inventories) in groupedByItem {
            var totalQuantity = 0.0
            for inventory in inventories {
                totalQuantity += await inventory.quantity
            }
            result[key] = totalQuantity * defaultPricePerUnit
        }
        return result
    }

    // MARK: - Location Operations

    func fetchInventory(atLocation location: String) async throws -> [InventoryModel] {
        let cleanLocation = StorageLocationModel.cleanLocationName(location)
        let predicate = NSPredicate(format: "location == %@", cleanLocation)
        return try await fetchInventory(matching: predicate)
    }

    func getDistinctLocations() async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Inventory")
                    fetchRequest.propertiesToFetch = ["location"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType
                    fetchRequest.predicate = NSPredicate(format: "location != nil")

                    let results = try self.context.fetch(fetchRequest)
                    let locations = results.compactMap { $0["location"] as? String }.sorted()

                    self.log.debug("Found \(locations.count) distinct locations")
                    continuation.resume(returning: locations)

                } catch {
                    self.log.error("Failed to fetch distinct locations: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getLocationNames(withPrefix prefix: String) async throws -> [String] {
        let cleanPrefix = StorageLocationModel.cleanLocationName(prefix)

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "Inventory")
                    fetchRequest.propertiesToFetch = ["location"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType
                    fetchRequest.predicate = NSPredicate(format: "location BEGINSWITH[c] %@", cleanPrefix)

                    let results = try self.context.fetch(fetchRequest)
                    let locations = results.compactMap { $0["location"] as? String }.sorted()

                    self.log.debug("Found \(locations.count) locations with prefix: \(cleanPrefix)")
                    continuation.resume(returning: locations)

                } catch {
                    self.log.error("Failed to fetch location names with prefix: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getLocationUtilization(for location: String) async throws -> [String: Double] {
        let inventoryAtLocation = try await fetchInventory(atLocation: location)
        var groupedByItem: [String: [InventoryModel]] = [:]
        for inventory in inventoryAtLocation {
            let key = await inventory.item_stable_id
            groupedByItem[key, default: []].append(inventory)
        }

        var result: [String: Double] = [:]
        for (key, inventories) in groupedByItem {
            var total = 0.0
            for inventory in inventories {
                total += await inventory.quantity
            }
            result[key] = total
        }
        return result
    }

    func getAllLocationUtilization() async throws -> [String: Double] {
        let allInventory = try await fetchInventory(matching: NSPredicate(format: "location != nil"))
        var groupedByLocation: [String: [InventoryModel]] = [:]
        for inventory in allInventory {
            if let location = await inventory.location {
                groupedByLocation[location, default: []].append(inventory)
            }
        }

        var result: [String: Double] = [:]
        for (location, inventories) in groupedByLocation {
            var total = 0.0
            for inventory in inventories {
                total += await inventory.quantity
            }
            result[location] = total
        }
        return result
    }

    // MARK: - Private Helper Methods
    
    private func fetchInventorySync(forItem item_stable_id: String, type: String) throws -> [InventoryModel] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
        fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@ AND type == %@", item_stable_id, type)
        
        let results = try context.fetch(fetchRequest)
        return results.compactMap { convertToInventoryModel($0) }
    }
    
    private nonisolated func fetchCoreDataItemSync(byId id: UUID) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Inventory")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        let results = try context.fetch(fetchRequest)
        return results.first
    }
    
    private nonisolated func convertToInventoryModel(_ coreDataItem: NSManagedObject) -> InventoryModel? {
        guard let idData = coreDataItem.value(forKey: "id") as? UUID,
              let item_stable_id = coreDataItem.value(forKey: "item_stable_id") as? String,
              let type = coreDataItem.value(forKey: "type") as? String,
              let quantityNumber = coreDataItem.value(forKey: "quantity") as? NSNumber else {
            log.error("Failed to convert Core Data item to InventoryModel - missing required properties")
            return nil
        }

        // Optional fields - date_added and date_modified might not exist in older records
        let date_added = coreDataItem.value(forKey: "date_added") as? Date ?? Date()
        let date_modified = coreDataItem.value(forKey: "date_modified") as? Date ?? Date()

        // Optional new fields - subtype, subsubtype, dimensions, location
        let subtype = coreDataItem.value(forKey: "subtype") as? String
        let subsubtype = coreDataItem.value(forKey: "subsubtype") as? String
        let location = coreDataItem.value(forKey: "location") as? String

        // Deserialize dimensions from JSON string stored in dimensions_x
        var dimensions: [String: Double]? = nil
        if let dimensionsJSON = coreDataItem.value(forKey: "dimensions_x") as? String,
           !dimensionsJSON.isEmpty,
           let data = dimensionsJSON.data(using: .utf8) {
            dimensions = try? JSONDecoder().decode([String: Double].self, from: data)
        }

        return InventoryModel(
            id: idData,
            item_stable_id: item_stable_id,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dimensions: dimensions,
            quantity: quantityNumber.doubleValue,
            location: location,
            date_added: date_added,
            date_modified: date_modified
        )
    }
    
    private nonisolated func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with inventory: InventoryModel) {
        coreDataItem.setValue(inventory.id, forKey: "id")
        coreDataItem.setValue(inventory.item_stable_id, forKey: "item_stable_id")
        coreDataItem.setValue(inventory.type, forKey: "type")  // Use non-optional accessor
        coreDataItem.setValue(inventory.subtype, forKey: "subtype")
        coreDataItem.setValue(inventory.subsubtype, forKey: "subsubtype")

        // Serialize dimensions to JSON string and store in dimensions_x
        if let dimensions = inventory.dimensions, !dimensions.isEmpty {
            if let jsonData = try? JSONEncoder().encode(dimensions),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                coreDataItem.setValue(jsonString, forKey: "dimensions_x")
            }
        } else {
            coreDataItem.setValue(nil, forKey: "dimensions_x")
        }

        coreDataItem.setValue(NSNumber(value: inventory.quantity), forKey: "quantity")
        coreDataItem.setValue(inventory.location, forKey: "location")
        coreDataItem.setValue(inventory.date_added, forKey: "date_added")
        coreDataItem.setValue(inventory.date_modified, forKey: "date_modified")
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
