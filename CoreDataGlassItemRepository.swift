//
//  CoreDataGlassItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import CoreData
import Foundation
import OSLog

/// Core Data implementation of GlassItemRepository
/// Provides persistent storage for glass items using Core Data
class CoreDataGlassItemRepository: GlassItemRepository {
    
    // MARK: - Dependencies
    
    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "glass-item-repository")
    
    // MARK: - Initialization
    
    init(persistentContainer: NSPersistentContainer = PersistenceController.shared.container) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        log.info("CoreDataGlassItemRepository initialized with persistent container")
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    guard let fetchRequest = CoreDataEntityHelpers.safeFetchRequest(
                        for: "GlassItem",
                        in: self.backgroundContext,
                        type: NSManagedObject.self
                    ) else {
                        throw CoreDataGlassItemRepositoryError.entityNotFound("GlassItem")
                    }
                    
                    fetchRequest.predicate = predicate
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "naturalKey", ascending: true)
                    ]
                    
                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let glassItems = coreDataItems.compactMap { self.convertToGlassItemModel($0) }
                    
                    self.log.debug("Fetched \(glassItems.count) glass items from Core Data")
                    continuation.resume(returning: glassItems)
                    
                } catch {
                    self.log.error("Failed to fetch glass items: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchItem(byNaturalKey naturalKey: String) async throws -> GlassItemModel? {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    guard let fetchRequest = CoreDataEntityHelpers.safeFetchRequest(
                        for: "GlassItem",
                        in: self.backgroundContext,
                        type: NSManagedObject.self
                    ) else {
                        throw CoreDataGlassItemRepositoryError.entityNotFound("GlassItem")
                    }
                    
                    fetchRequest.predicate = NSPredicate(format: "naturalKey == %@", naturalKey)
                    fetchRequest.fetchLimit = 1
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    let glassItem = results.first.flatMap { self.convertToGlassItemModel($0) }
                    
                    if let item = glassItem {
                        self.log.debug("Found glass item with natural key: \(naturalKey)")
                    } else {
                        self.log.debug("Glass item not found with natural key: \(naturalKey)")
                    }
                    
                    continuation.resume(returning: glassItem)
                    
                } catch {
                    self.log.error("Failed to fetch glass item by natural key: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    // Check if item already exists
                    if let existingItem = try self.fetchItemSync(byNaturalKey: item.naturalKey) {
                        self.log.warning("Attempted to create duplicate glass item: \(item.naturalKey)")
                        continuation.resume(throwing: CoreDataGlassItemRepositoryError.itemAlreadyExists(item.naturalKey))
                        return
                    }
                    
                    // Create new Core Data entity
                    guard let coreDataItem = CoreDataEntityHelpers.safeEntityCreation(
                        entityName: "GlassItem",
                        in: self.backgroundContext,
                        type: NSManagedObject.self
                    ) else {
                        throw CoreDataGlassItemRepositoryError.entityCreationFailed("GlassItem")
                    }
                    
                    // Set properties
                    self.updateCoreDataEntity(coreDataItem, with: item)
                    
                    // Save context
                    try self.backgroundContext.save()
                    
                    self.log.info("Created glass item: \(item.naturalKey)")
                    continuation.resume(returning: item)
                    
                } catch {
                    self.log.error("Failed to create glass item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func createItems(_ items: [GlassItemModel]) async throws -> [GlassItemModel] {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    var createdItems: [GlassItemModel] = []
                    
                    for item in items {
                        // Check if item already exists
                        if let _ = try self.fetchItemSync(byNaturalKey: item.naturalKey) {
                            self.log.warning("Skipping duplicate glass item: \(item.naturalKey)")
                            throw CoreDataGlassItemRepositoryError.itemAlreadyExists(item.naturalKey)
                        }
                        
                        // Create new Core Data entity
                        guard let coreDataItem = CoreDataEntityHelpers.safeEntityCreation(
                            entityName: "GlassItem",
                            in: self.backgroundContext,
                            type: NSManagedObject.self
                        ) else {
                            throw CoreDataGlassItemRepositoryError.entityCreationFailed("GlassItem")
                        }
                        
                        // Set properties
                        self.updateCoreDataEntity(coreDataItem, with: item)
                        createdItems.append(item)
                    }
                    
                    // Save all changes at once
                    try self.backgroundContext.save()
                    
                    self.log.info("Created \(createdItems.count) glass items in batch")
                    continuation.resume(returning: createdItems)
                    
                } catch {
                    self.log.error("Failed to create glass items in batch: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byNaturalKey: item.naturalKey) else {
                        self.log.warning("Attempted to update non-existent glass item: \(item.naturalKey)")
                        continuation.resume(throwing: CoreDataGlassItemRepositoryError.itemNotFound(item.naturalKey))
                        return
                    }
                    
                    // Update properties
                    self.updateCoreDataEntity(coreDataItem, with: item)
                    
                    // Save context
                    try self.backgroundContext.save()
                    
                    self.log.info("Updated glass item: \(item.naturalKey)")
                    continuation.resume(returning: item)
                    
                } catch {
                    self.log.error("Failed to update glass item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteItem(naturalKey: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byNaturalKey: naturalKey) else {
                        self.log.warning("Attempted to delete non-existent glass item: \(naturalKey)")
                        continuation.resume(throwing: CoreDataGlassItemRepositoryError.itemNotFound(naturalKey))
                        return
                    }
                    
                    // Delete item
                    self.backgroundContext.delete(coreDataItem)
                    
                    // Save context
                    try self.backgroundContext.save()
                    
                    self.log.info("Deleted glass item: \(naturalKey)")
                    continuation.resume()
                    
                } catch {
                    self.log.error("Failed to delete glass item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteItems(naturalKeys: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    var deletedCount = 0
                    
                    for naturalKey in naturalKeys {
                        if let coreDataItem = try self.fetchCoreDataItemSync(byNaturalKey: naturalKey) {
                            self.backgroundContext.delete(coreDataItem)
                            deletedCount += 1
                        } else {
                            self.log.warning("Could not find glass item to delete: \(naturalKey)")
                        }
                    }
                    
                    // Save all deletions at once
                    if deletedCount > 0 {
                        try self.backgroundContext.save()
                    }
                    
                    self.log.info("Deleted \(deletedCount) glass items in batch")
                    continuation.resume()
                    
                } catch {
                    self.log.error("Failed to delete glass items in batch: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Search & Filter Operations
    
    func searchItems(text: String) async throws -> [GlassItemModel] {
        let searchText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else {
            return try await fetchItems(matching: nil)
        }
        
        let predicate = NSPredicate(format: "name CONTAINS[cd] %@ OR manufacturer CONTAINS[cd] %@ OR mfrNotes CONTAINS[cd] %@",
                                  searchText, searchText, searchText)
        return try await fetchItems(matching: predicate)
    }
    
    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        let predicate = NSPredicate(format: "manufacturer == %@", manufacturer)
        return try await fetchItems(matching: predicate)
    }
    
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        let predicate = NSPredicate(format: "coe == %d", coe)
        return try await fetchItems(matching: predicate)
    }
    
    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        let predicate = NSPredicate(format: "mfrStatus == %@", status)
        return try await fetchItems(matching: predicate)
    }
    
    // MARK: - Business Query Operations
    
    func getDistinctManufacturers() async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSString>(entityName: "GlassItem")
                    fetchRequest.propertiesToFetch = ["manufacturer"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType
                    
                    let results = try self.backgroundContext.fetch(fetchRequest) as! [[String: Any]]
                    let manufacturers = results.compactMap { $0["manufacturer"] as? String }.sorted()
                    
                    self.log.debug("Found \(manufacturers.count) distinct manufacturers")
                    continuation.resume(returning: manufacturers)
                    
                } catch {
                    self.log.error("Failed to fetch distinct manufacturers: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getDistinctCOEValues() async throws -> [Int32] {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "GlassItem")
                    fetchRequest.propertiesToFetch = ["coe"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    let coeValues = results.compactMap { ($0["coe"] as? NSNumber)?.int32Value }.sorted()
                    
                    self.log.debug("Found \(coeValues.count) distinct COE values")
                    continuation.resume(returning: coeValues)
                    
                } catch {
                    self.log.error("Failed to fetch distinct COE values: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getDistinctStatuses() async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "GlassItem")
                    fetchRequest.propertiesToFetch = ["mfrStatus"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    let statuses = results.compactMap { $0["mfrStatus"] as? String }.sorted()
                    
                    self.log.debug("Found \(statuses.count) distinct statuses")
                    continuation.resume(returning: statuses)
                    
                } catch {
                    self.log.error("Failed to fetch distinct statuses: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func naturalKeyExists(_ naturalKey: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSNumber>(entityName: "GlassItem")
                    fetchRequest.predicate = NSPredicate(format: "naturalKey == %@", naturalKey)
                    fetchRequest.includesPropertyValues = false
                    
                    let count = try self.backgroundContext.count(for: fetchRequest)
                    continuation.resume(returning: count > 0)
                    
                } catch {
                    self.log.error("Failed to check if natural key exists: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func generateNextNaturalKey(manufacturer: String, sku: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    // Find the highest sequence number for this manufacturer-SKU combination
                    let baseKey = "\(manufacturer)-\(sku)"
                    let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "GlassItem")
                    fetchRequest.predicate = NSPredicate(format: "naturalKey BEGINSWITH %@", baseKey)
                    fetchRequest.propertiesToFetch = ["naturalKey"]
                    fetchRequest.resultType = .dictionaryResultType
                    
                    let results = try self.backgroundContext.fetch(fetchRequest)
                    let existingKeys = results.compactMap { $0["naturalKey"] as? String }
                    
                    // Find the highest sequence number
                    var highestSequence = -1
                    for key in existingKeys {
                        if let parsed = GlassItemModel.parseNaturalKey(key),
                           parsed.manufacturer == manufacturer && parsed.sku == sku {
                            highestSequence = max(highestSequence, parsed.sequence)
                        }
                    }
                    
                    let nextSequence = highestSequence + 1
                    let nextKey = GlassItemModel.createNaturalKey(
                        manufacturer: manufacturer,
                        sku: sku,
                        sequence: nextSequence
                    )
                    
                    self.log.debug("Generated next natural key: \(nextKey)")
                    continuation.resume(returning: nextKey)
                    
                } catch {
                    self.log.error("Failed to generate next natural key: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchItemSync(byNaturalKey naturalKey: String) throws -> GlassItemModel? {
        guard let fetchRequest = CoreDataEntityHelpers.safeFetchRequest(
            for: "GlassItem",
            in: backgroundContext,
            type: NSManagedObject.self
        ) else {
            throw CoreDataGlassItemRepositoryError.entityNotFound("GlassItem")
        }
        
        fetchRequest.predicate = NSPredicate(format: "naturalKey == %@", naturalKey)
        fetchRequest.fetchLimit = 1
        
        let results = try backgroundContext.fetch(fetchRequest)
        return results.first.flatMap { convertToGlassItemModel($0) }
    }
    
    private func fetchCoreDataItemSync(byNaturalKey naturalKey: String) throws -> NSManagedObject? {
        guard let fetchRequest = CoreDataEntityHelpers.safeFetchRequest(
            for: "GlassItem",
            in: backgroundContext,
            type: NSManagedObject.self
        ) else {
            throw CoreDataGlassItemRepositoryError.entityNotFound("GlassItem")
        }
        
        fetchRequest.predicate = NSPredicate(format: "naturalKey == %@", naturalKey)
        fetchRequest.fetchLimit = 1
        
        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }
    
    private func convertToGlassItemModel(_ coreDataItem: NSManagedObject) -> GlassItemModel? {
        guard let naturalKey = coreDataItem.value(forKey: "naturalKey") as? String,
              let name = coreDataItem.value(forKey: "name") as? String,
              let sku = coreDataItem.value(forKey: "sku") as? String,
              let manufacturer = coreDataItem.value(forKey: "manufacturer") as? String,
              let coeNumber = coreDataItem.value(forKey: "coe") as? NSNumber,
              let mfrStatus = coreDataItem.value(forKey: "mfrStatus") as? String else {
            log.error("Failed to convert Core Data item to GlassItemModel - missing required properties")
            return nil
        }
        
        let mfrNotes = coreDataItem.value(forKey: "mfrNotes") as? String
        let url = coreDataItem.value(forKey: "url") as? String
        
        return GlassItemModel(
            naturalKey: naturalKey,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfrNotes: mfrNotes,
            coe: coeNumber.int32Value,
            url: url,
            mfrStatus: mfrStatus
        )
    }
    
    private func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with item: GlassItemModel) {
        coreDataItem.setValue(item.naturalKey, forKey: "naturalKey")
        coreDataItem.setValue(item.name, forKey: "name")
        coreDataItem.setValue(item.sku, forKey: "sku")
        coreDataItem.setValue(item.manufacturer, forKey: "manufacturer")
        coreDataItem.setValue(item.mfrNotes, forKey: "mfrNotes")
        coreDataItem.setValue(NSNumber(value: item.coe), forKey: "coe")
        coreDataItem.setValue(item.url, forKey: "url")
        coreDataItem.setValue(item.uri, forKey: "uri")
        coreDataItem.setValue(item.mfrStatus, forKey: "mfrStatus")
    }
}

// MARK: - Core Data Repository Errors

enum CoreDataGlassItemRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case entityCreationFailed(String)
    case itemNotFound(String)
    case itemAlreadyExists(String)
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .entityCreationFailed(let entityName):
            return "Failed to create Core Data entity: \(entityName)"
        case .itemNotFound(let naturalKey):
            return "Glass item not found: \(naturalKey)"
        case .itemAlreadyExists(let naturalKey):
            return "Glass item already exists: \(naturalKey)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}