//
//  CoreDataShoppingListRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import CoreData
import Foundation
import OSLog

/// Core Data implementation of ShoppingListRepository
/// Provides persistent storage for shopping list items using Core Data (ItemShopping entity)
class CoreDataShoppingListRepository: ShoppingListRepository {

    // MARK: - Dependencies

    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "shopping-list-repository")

    // MARK: - Initialization

    /// Initialize CoreDataShoppingListRepository with a Core Data persistent container
    /// - Parameter persistentContainer: The NSPersistentContainer to use for shopping list operations
    /// - Note: In production, pass PersistenceController.shared.container
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        log.info("CoreDataShoppingListRepository initialized with persistent container")
    }

    // MARK: - Basic CRUD Operations

    func fetchAllItems() async throws -> [ItemShoppingModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ItemShoppingModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let items = coreDataItems.compactMap { self.convertToModel($0) }

                    self.log.debug("Fetched \(items.count) shopping list items from Core Data")
                    continuation.resume(returning: items)

                } catch {
                    self.log.error("Failed to fetch all shopping list items: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ItemShoppingModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ItemShoppingModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
                    fetchRequest.predicate = predicate
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let items = coreDataItems.compactMap { self.convertToModel($0) }

                    self.log.debug("Fetched \(items.count) shopping list items with predicate")
                    continuation.resume(returning: items)

                } catch {
                    self.log.error("Failed to fetch shopping list items with predicate: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchItem(byId id: UUID) async throws -> ItemShoppingModel? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ItemShoppingModel?, Error>) in
            backgroundContext.perform {
                do {
                    let result = try self.fetchCoreDataItemSync(byId: id)
                    let model = result.flatMap { self.convertToModel($0) }
                    continuation.resume(returning: model)
                } catch {
                    self.log.error("Failed to fetch shopping list item by ID: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchItem(forItem item_natural_key: String) async throws -> ItemShoppingModel? {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ItemShoppingModel?, Error>) in
            backgroundContext.perform {
                do {
                    let result = try self.fetchCoreDataItemSync(forItem: item_natural_key)
                    let model = result.flatMap { self.convertToModel($0) }
                    continuation.resume(returning: model)
                } catch {
                    self.log.error("Failed to fetch shopping list item for item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchItems(forStore store: String) async throws -> [ItemShoppingModel] {
        let predicate = NSPredicate(format: "store ==[cd] %@", store)
        return try await fetchItems(matching: predicate)
    }

    func createItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ItemShoppingModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate item
                    guard item.isValid else {
                        throw CoreDataShoppingListRepositoryError.invalidData(item.validationErrors.joined(separator: ", "))
                    }

                    // Check if item already exists
                    if let existing = try self.fetchCoreDataItemSync(forItem: item.item_natural_key) {
                        throw CoreDataShoppingListRepositoryError.itemAlreadyExists(item.item_natural_key)
                    }

                    // Create new Core Data entity
                    guard let entity = NSEntityDescription.entity(forEntityName: "ItemShopping", in: self.backgroundContext) else {
                        throw CoreDataShoppingListRepositoryError.entityNotFound("ItemShopping")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                    // Set properties
                    self.updateCoreDataEntity(coreDataItem, with: item)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Created shopping list item for: \(item.item_natural_key)")
                    continuation.resume(returning: item)

                } catch {
                    self.log.error("Failed to create shopping list item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ItemShoppingModel, Error>) in
            backgroundContext.perform {
                do {
                    // Validate item
                    guard item.isValid else {
                        throw CoreDataShoppingListRepositoryError.invalidData(item.validationErrors.joined(separator: ", "))
                    }

                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: item.id) else {
                        self.log.warning("Attempted to update non-existent shopping list item: \(item.id)")
                        throw CoreDataShoppingListRepositoryError.itemNotFound(item.id.uuidString)
                    }

                    // Update properties
                    self.updateCoreDataEntity(coreDataItem, with: item)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Updated shopping list item: \(item.item_natural_key)")
                    continuation.resume(returning: item)

                } catch {
                    self.log.error("Failed to update shopping list item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteItem(id: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: id) else {
                        self.log.warning("Attempted to delete non-existent shopping list item: \(id)")
                        // Not throwing error - idempotent delete
                        continuation.resume()
                        return
                    }

                    // Delete item
                    self.backgroundContext.delete(coreDataItem)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Deleted shopping list item by ID: \(id)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete shopping list item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteItem(forItem item_natural_key: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: item_natural_key) else {
                        self.log.warning("Attempted to delete non-existent shopping list item: \(item_natural_key)")
                        // Not throwing error - idempotent delete
                        continuation.resume()
                        return
                    }

                    // Delete item
                    self.backgroundContext.delete(coreDataItem)

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Deleted shopping list item for: \(item_natural_key)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete shopping list item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteAllItems() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
                    let allItems = try self.backgroundContext.fetch(fetchRequest)

                    for item in allItems {
                        self.backgroundContext.delete(item)
                    }

                    if !allItems.isEmpty {
                        try self.backgroundContext.save()
                    }

                    self.log.info("Deleted all \(allItems.count) shopping list items")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete all shopping list items: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Quantity Operations

    func updateQuantity(_ quantity: Double, forItem item_natural_key: String) async throws -> ItemShoppingModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ItemShoppingModel, Error>) in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: item_natural_key) else {
                        throw CoreDataShoppingListRepositoryError.itemNotFound(item_natural_key)
                    }

                    // Update quantity
                    coreDataItem.setValue(max(0, quantity), forKey: "quantity")

                    // Save context
                    try self.backgroundContext.save()

                    guard let updatedModel = self.convertToModel(coreDataItem) else {
                        throw CoreDataShoppingListRepositoryError.conversionFailed
                    }

                    self.log.info("Updated quantity for shopping list item: \(item_natural_key)")
                    continuation.resume(returning: updatedModel)

                } catch {
                    self.log.error("Failed to update quantity: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func addQuantity(_ quantity: Double, toItem item_natural_key: String, store: String?) async throws -> ItemShoppingModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ItemShoppingModel, Error>) in
            backgroundContext.perform {
                do {
                    if let existingItem = try self.fetchCoreDataItemSync(forItem: item_natural_key) {
                        // Add to existing quantity
                        let currentQuantity = existingItem.value(forKey: "quantity") as? Double ?? 0
                        existingItem.setValue(currentQuantity + quantity, forKey: "quantity")

                        try self.backgroundContext.save()

                        guard let updatedModel = self.convertToModel(existingItem) else {
                            throw CoreDataShoppingListRepositoryError.conversionFailed
                        }

                        self.log.info("Added quantity to existing shopping list item: \(item_natural_key)")
                        continuation.resume(returning: updatedModel)

                    } else {
                        // Create new item
                        let newItem = ItemShoppingModel(
                            item_natural_key: item_natural_key,
                            quantity: quantity,
                            store: store
                        )

                        guard let entity = NSEntityDescription.entity(forEntityName: "ItemShopping", in: self.backgroundContext) else {
                            throw CoreDataShoppingListRepositoryError.entityNotFound("ItemShopping")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                        self.updateCoreDataEntity(coreDataItem, with: newItem)
                        try self.backgroundContext.save()

                        self.log.info("Created new shopping list item: \(item_natural_key)")
                        continuation.resume(returning: newItem)
                    }

                } catch {
                    self.log.error("Failed to add quantity: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Store Operations

    func updateStore(_ store: String?, forItem item_natural_key: String) async throws -> ItemShoppingModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ItemShoppingModel, Error>) in
            backgroundContext.perform {
                do {
                    // Find existing item
                    guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: item_natural_key) else {
                        throw CoreDataShoppingListRepositoryError.itemNotFound(item_natural_key)
                    }

                    // Update store
                    coreDataItem.setValue(store, forKey: "store")

                    // Save context
                    try self.backgroundContext.save()

                    guard let updatedModel = self.convertToModel(coreDataItem) else {
                        throw CoreDataShoppingListRepositoryError.conversionFailed
                    }

                    self.log.info("Updated store for shopping list item: \(item_natural_key)")
                    continuation.resume(returning: updatedModel)

                } catch {
                    self.log.error("Failed to update store: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getDistinctStores() async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
                    let items = try self.backgroundContext.fetch(fetchRequest)

                    let stores = Set(items.compactMap { $0.value(forKey: "store") as? String })
                    let sortedStores = stores.sorted()

                    continuation.resume(returning: sortedStores)

                } catch {
                    self.log.error("Failed to get distinct stores: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getItemCountByStore() async throws -> [String: Int] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Int], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
                    let items = try self.backgroundContext.fetch(fetchRequest)

                    var countByStore: [String: Int] = [:]
                    for item in items {
                        if let store = item.value(forKey: "store") as? String {
                            countByStore[store, default: 0] += 1
                        }
                    }

                    continuation.resume(returning: countByStore)

                } catch {
                    self.log.error("Failed to get item count by store: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Discovery Operations

    func isItemInList(_ item_natural_key: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            backgroundContext.perform {
                do {
                    let exists = try self.fetchCoreDataItemSync(forItem: item_natural_key) != nil
                    continuation.resume(returning: exists)
                } catch {
                    self.log.error("Failed to check if item is in list: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getItemCount() async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
                    let count = try self.backgroundContext.count(for: fetchRequest)

                    continuation.resume(returning: count)

                } catch {
                    self.log.error("Failed to get item count: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getItemCount(forStore store: String) async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
                    fetchRequest.predicate = NSPredicate(format: "store ==[cd] %@", store)
                    let count = try self.backgroundContext.count(for: fetchRequest)

                    continuation.resume(returning: count)

                } catch {
                    self.log.error("Failed to get item count for store: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getItemsSortedByDate(ascending: Bool) async throws -> [ItemShoppingModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ItemShoppingModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: ascending)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let items = coreDataItems.compactMap { self.convertToModel($0) }

                    continuation.resume(returning: items)

                } catch {
                    self.log.error("Failed to get items sorted by date: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getItemsSortedByQuantity(ascending: Bool) async throws -> [ItemShoppingModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ItemShoppingModel], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "quantity", ascending: ascending)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let items = coreDataItems.compactMap { self.convertToModel($0) }

                    continuation.resume(returning: items)

                } catch {
                    self.log.error("Failed to get items sorted by quantity: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Batch Operations

    func addItems(_ items: [ItemShoppingModel]) async throws -> [ItemShoppingModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ItemShoppingModel], Error>) in
            backgroundContext.perform {
                do {
                    guard let entity = NSEntityDescription.entity(forEntityName: "ItemShopping", in: self.backgroundContext) else {
                        throw CoreDataShoppingListRepositoryError.entityNotFound("ItemShopping")
                    }

                    var createdItems: [ItemShoppingModel] = []

                    for item in items {
                        // Validate item
                        guard item.isValid else {
                            throw CoreDataShoppingListRepositoryError.invalidData(item.validationErrors.joined(separator: ", "))
                        }

                        // Create Core Data entity
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                        self.updateCoreDataEntity(coreDataItem, with: item)
                        createdItems.append(item)
                    }

                    // Save context
                    try self.backgroundContext.save()

                    self.log.info("Created \(createdItems.count) shopping list items in batch")
                    continuation.resume(returning: createdItems)

                } catch {
                    self.log.error("Failed to add items in batch: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteItems(ids: [UUID]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    for id in ids {
                        if let coreDataItem = try self.fetchCoreDataItemSync(byId: id) {
                            self.backgroundContext.delete(coreDataItem)
                        }
                    }

                    try self.backgroundContext.save()

                    self.log.info("Deleted \(ids.count) shopping list items in batch")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete items in batch: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteItems(forStore store: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
                    fetchRequest.predicate = NSPredicate(format: "store ==[cd] %@", store)
                    let items = try self.backgroundContext.fetch(fetchRequest)

                    for item in items {
                        self.backgroundContext.delete(item)
                    }

                    if !items.isEmpty {
                        try self.backgroundContext.save()
                    }

                    self.log.info("Deleted \(items.count) shopping list items for store: \(store)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete items for store: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    private func fetchCoreDataItemSync(byId id: UUID) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }

    private func fetchCoreDataItemSync(forItem item_natural_key: String) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
        fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@", item_natural_key)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }

    private func convertToModel(_ coreDataItem: NSManagedObject) -> ItemShoppingModel? {
        guard let id = coreDataItem.value(forKey: "id") as? UUID,
              let item_natural_key = coreDataItem.value(forKey: "item_natural_key") as? String,
              let quantity = coreDataItem.value(forKey: "quantity") as? Double else {
            log.error("Failed to convert Core Data item to ItemShoppingModel - missing required properties")
            return nil
        }

        let store = coreDataItem.value(forKey: "store") as? String
        let type = coreDataItem.value(forKey: "type") as? String
        let subtype = coreDataItem.value(forKey: "subtype") as? String
        let subsubtype = coreDataItem.value(forKey: "subsubtype") as? String
        let dateAdded = coreDataItem.value(forKey: "dateAdded") as? Date ?? Date()

        return ItemShoppingModel(
            id: id,
            item_natural_key: item_natural_key,
            quantity: quantity,
            store: store,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dateAdded: dateAdded
        )
    }

    private func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with item: ItemShoppingModel) {
        coreDataItem.setValue(item.id, forKey: "id")
        coreDataItem.setValue(item.item_natural_key, forKey: "item_natural_key")
        coreDataItem.setValue(item.quantity, forKey: "quantity")
        coreDataItem.setValue(item.store, forKey: "store")
        coreDataItem.setValue(item.type, forKey: "type")
        coreDataItem.setValue(item.subtype, forKey: "subtype")
        coreDataItem.setValue(item.subsubtype, forKey: "subsubtype")
        coreDataItem.setValue(item.dateAdded, forKey: "dateAdded")
    }
}

// MARK: - Core Data Repository Errors

enum CoreDataShoppingListRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case itemNotFound(String)
    case itemAlreadyExists(String)
    case invalidData(String)
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .itemNotFound(let itemKey):
            return "Shopping list item not found: \(itemKey)"
        case .itemAlreadyExists(let itemKey):
            return "Shopping list item already exists: \(itemKey)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .conversionFailed:
            return "Failed to convert Core Data entity to model"
        }
    }
}
