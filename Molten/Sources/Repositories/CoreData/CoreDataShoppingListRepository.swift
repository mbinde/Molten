//
//  CoreDataShoppingListRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

@preconcurrency import CoreData
@preconcurrency import Foundation
import OSLog

/// Core Data implementation of ShoppingListRepository
/// Provides persistent storage for shopping list items using Core Data (ItemShopping entity)
class CoreDataShoppingListRepository: @unchecked Sendable, ShoppingListRepository {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "shopping-list-repository")

    // MARK: - Initialization

    /// Initialize CoreDataShoppingListRepository with a Core Data persistent container
    /// - Parameter context: The NSManagedObjectContext to use for shopping list operations
    /// - Note: In production, pass PersistenceController.shared.cloudContext (user data)
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Basic CRUD Operations

    func fetchAllItems() async throws -> [ItemShoppingModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

            let coreDataItems = try context.fetch(fetchRequest)
            let items = coreDataItems.compactMap { self.convertToModel($0) }

            return items
        }
    }

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ItemShoppingModel] {
        nonisolated(unsafe) let predicateCopy = predicate
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            fetchRequest.predicate = predicateCopy
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

            let coreDataItems = try context.fetch(fetchRequest)
            let items = coreDataItems.compactMap { self.convertToModel($0) }

            return items
        }
    }

    func fetchItem(byId id: UUID) async throws -> ItemShoppingModel? {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let result = try self.fetchCoreDataItemSync(byId: id)
            let model = result.flatMap { self.convertToModel($0) }
            return model
        }
    }

    func fetchItem(forItem item_stable_id: String) async throws -> ItemShoppingModel? {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let result = try self.fetchCoreDataItemSync(forItem: item_stable_id)
            let model = result.flatMap { self.convertToModel($0) }
            return model
        }
    }

    func fetchItems(forStore store: String) async throws -> [ItemShoppingModel] {
        // Trim store name to match ItemShoppingModel.init behavior
        let trimmedStore = store.trimmingCharacters(in: .whitespacesAndNewlines)
        let predicate = NSPredicate(format: "store ==[cd] %@", trimmedStore)
        return try await fetchItems(matching: predicate)
    }

    func createItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            // Validate item
            guard item.isValid else {
            throw CoreDataShoppingListRepositoryError.invalidData(item.validationErrors.joined(separator: ", "))
            }

            // Check if item already exists - shopping list items are unique per (item_stable_id, store) tuple
            // Same item can exist in different stores
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            if let store = item.store {
            fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@ AND store == %@",
            item.item_stable_id,
            store)
            } else {
            fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@ AND store == NULL",
            item.item_stable_id)
            }
            fetchRequest.fetchLimit = 1
            if try context.fetch(fetchRequest).first != nil {
            throw CoreDataShoppingListRepositoryError.itemAlreadyExists(item.item_stable_id)
            }

            // Create new Core Data entity
            guard let entity = NSEntityDescription.entity(forEntityName: "ItemShopping", in: context) else {
            throw CoreDataShoppingListRepositoryError.entityNotFound("ItemShopping")
            }
            let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

            // Set properties
            self.updateCoreDataEntity(coreDataItem, with: item)

            // Save context
            try context.save()

            self.log.info("Created shopping list item for: \(item.item_stable_id)")
            return item
        }
    }

    func updateItem(_ item: ItemShoppingModel) async throws -> ItemShoppingModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
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
            try context.save()

            self.log.info("Updated shopping list item: \(item.item_stable_id)")
            return item
        }
    }

    func deleteItem(id: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            // Find existing item
            guard let coreDataItem = try self.fetchCoreDataItemSync(byId: id) else {
            self.log.warning("Attempted to delete non-existent shopping list item: \(id)")
            // Not throwing error - idempotent delete
            return
            }

            // Delete item
            context.delete(coreDataItem)

            // Save context
            try context.save()

            self.log.info("Deleted shopping list item by ID: \(id)")
        }
    }

    func deleteItem(forItem item_stable_id: String) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            // Find existing item
            guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: item_stable_id) else {
            self.log.warning("Attempted to delete non-existent shopping list item: \(item_stable_id)")
            // Not throwing error - idempotent delete
            return
            }

            // Delete item
            context.delete(coreDataItem)

            // Save context
            try context.save()

            self.log.info("Deleted shopping list item for: \(item_stable_id)")

        }
    }

    func deleteAllItems() async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            let allItems = try context.fetch(fetchRequest)

            for item in allItems {
            context.delete(item)
            }

            if !allItems.isEmpty {
            try context.save()
            }

            self.log.info("Deleted all \(allItems.count) shopping list items")

        }
    }

    // MARK: - Quantity Operations

    func updateQuantity(_ quantity: Double, forItem item_stable_id: String) async throws -> ItemShoppingModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            // Find existing item
            guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: item_stable_id) else {
            throw CoreDataShoppingListRepositoryError.itemNotFound(item_stable_id)
            }

            // Update quantity
            coreDataItem.setValue(max(0, quantity), forKey: "quantity")

            // Save context
            try context.save()

            guard let updatedModel = self.convertToModel(coreDataItem) else {
            throw CoreDataShoppingListRepositoryError.conversionFailed
            }

            self.log.info("Updated quantity for shopping list item: \(item_stable_id)")
            return updatedModel

        }
    }

    func updateNeededQuantity(forItem item_stable_id: String, neededQuantity: Double) async throws -> ItemShoppingModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            // Find existing item
            guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: item_stable_id) else {
                throw CoreDataShoppingListRepositoryError.itemNotFound(item_stable_id)
            }

            // Update needed quantity (stored in the quantity field for ItemShopping)
            coreDataItem.setValue(max(0, neededQuantity), forKey: "quantity")

            // Save context
            try context.save()

            guard let updatedModel = self.convertToModel(coreDataItem) else {
                throw CoreDataShoppingListRepositoryError.conversionFailed
            }

            self.log.info("Updated needed quantity for shopping list item: \(item_stable_id) to \(neededQuantity)")
            return updatedModel
        }
    }

    func addQuantity(_ quantity: Double, toItem item_stable_id: String, store: String?) async throws -> ItemShoppingModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            if let existingItem = try self.fetchCoreDataItemSync(forItem: item_stable_id) {
            // Add to existing quantity
            let currentQuantity = existingItem.value(forKey: "quantity") as? Double ?? 0
            existingItem.setValue(currentQuantity + quantity, forKey: "quantity")

            try context.save()

            guard let updatedModel = self.convertToModel(existingItem) else {
            throw CoreDataShoppingListRepositoryError.conversionFailed
            }

            self.log.info("Added quantity to existing shopping list item: \(item_stable_id)")
            return updatedModel

            } else {
            // Create new item
            let newItem = ItemShoppingModel(
            item_stable_id: item_stable_id,
            quantity: quantity,
            store: store
            )

            guard let entity = NSEntityDescription.entity(forEntityName: "ItemShopping", in: context) else {
            throw CoreDataShoppingListRepositoryError.entityNotFound("ItemShopping")
            }
            let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

            self.updateCoreDataEntity(coreDataItem, with: newItem)
            try context.save()

            self.log.info("Created new shopping list item: \(item_stable_id)")
            return newItem
            }

        }
    }

    // MARK: - Store Operations

    func updateStore(_ store: String?, forItem item_stable_id: String) async throws -> ItemShoppingModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            // Find existing item
            guard let coreDataItem = try self.fetchCoreDataItemSync(forItem: item_stable_id) else {
            throw CoreDataShoppingListRepositoryError.itemNotFound(item_stable_id)
            }

            // Update store
            coreDataItem.setValue(store, forKey: "store")

            // Save context
            try context.save()

            guard let updatedModel = self.convertToModel(coreDataItem) else {
            throw CoreDataShoppingListRepositoryError.conversionFailed
            }

            self.log.info("Updated store for shopping list item: \(item_stable_id)")
            return updatedModel

        }
    }

    func getDistinctStores() async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            let items = try context.fetch(fetchRequest)

            let stores = Set(items.compactMap { $0.value(forKey: "store") as? String })
            let sortedStores = stores.sorted()

            return sortedStores

        }
    }

    func getItemCountByStore() async throws -> [String: Int] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            let items = try context.fetch(fetchRequest)

            var countByStore: [String: Int] = [:]
            for item in items {
            if let store = item.value(forKey: "store") as? String {
            countByStore[store, default: 0] += 1
            }
            }

            return countByStore

        }
    }

    // MARK: - Discovery Operations

    func isItemInList(_ item_stable_id: String) async throws -> Bool {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let exists = try self.fetchCoreDataItemSync(forItem: item_stable_id) != nil
            return exists
        }
    }

    func getItemCount() async throws -> Int {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            let count = try context.count(for: fetchRequest)

            return count

        }
    }

    func getItemCount(forStore store: String) async throws -> Int {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            // Trim store name to match ItemShoppingModel.init behavior
            let trimmedStore = store.trimmingCharacters(in: .whitespacesAndNewlines)
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            fetchRequest.predicate = NSPredicate(format: "store ==[cd] %@", trimmedStore)
            let count = try context.count(for: fetchRequest)

            return count

        }
    }

    func getItemsSortedByDate(ascending: Bool) async throws -> [ItemShoppingModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: ascending)]

            let coreDataItems = try context.fetch(fetchRequest)
            let items = coreDataItems.compactMap { self.convertToModel($0) }

            return items

        }
    }

    func getItemsSortedByQuantity(ascending: Bool) async throws -> [ItemShoppingModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "quantity", ascending: ascending)]

            let coreDataItems = try context.fetch(fetchRequest)
            let items = coreDataItems.compactMap { self.convertToModel($0) }

            return items

        }
    }

    // MARK: - Batch Operations

    func addItems(_ items: [ItemShoppingModel]) async throws -> [ItemShoppingModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            guard let entity = NSEntityDescription.entity(forEntityName: "ItemShopping", in: context) else {
            throw CoreDataShoppingListRepositoryError.entityNotFound("ItemShopping")
            }

            var createdItems: [ItemShoppingModel] = []

            for item in items {
            // Validate item
            guard item.isValid else {
            throw CoreDataShoppingListRepositoryError.invalidData(item.validationErrors.joined(separator: ", "))
            }

            // Create Core Data entity
            let coreDataItem = NSManagedObject(entity: entity, insertInto: context)
            self.updateCoreDataEntity(coreDataItem, with: item)
            createdItems.append(item)
            }

            // Save context
            try context.save()

            self.log.info("Created \(createdItems.count) shopping list items in batch")
            return createdItems

        }
    }

    func deleteItems(ids: [UUID]) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            for id in ids {
            if let coreDataItem = try self.fetchCoreDataItemSync(byId: id) {
            context.delete(coreDataItem)
            }
            }

            try context.save()

            self.log.info("Deleted \(ids.count) shopping list items in batch")

        }
    }

    func deleteItems(forStore store: String) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            // Trim store name to match ItemShoppingModel.init behavior
            let trimmedStore = store.trimmingCharacters(in: .whitespacesAndNewlines)
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
            fetchRequest.predicate = NSPredicate(format: "store ==[cd] %@", trimmedStore)
            let items = try context.fetch(fetchRequest)

            for item in items {
            context.delete(item)
            }

            if !items.isEmpty {
            try context.save()
            }

            self.log.info("Deleted \(items.count) shopping list items for store: \(trimmedStore)")

        }
    }

    // MARK: - Private Helper Methods

    private nonisolated func fetchCoreDataItemSync(byId id: UUID) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }

    private nonisolated func fetchCoreDataItemSync(forItem item_stable_id: String) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemShopping")
        fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@", item_stable_id)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }

    private nonisolated func convertToModel(_ coreDataItem: NSManagedObject) -> ItemShoppingModel? {
        guard let id = coreDataItem.value(forKey: "id") as? UUID,
              let item_stable_id = coreDataItem.value(forKey: "item_stable_id") as? String,
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
            item_stable_id: item_stable_id,
            quantity: quantity,
            store: store,
            type: type,
            subtype: subtype,
            subsubtype: subsubtype,
            dateAdded: dateAdded
        )
    }

    private nonisolated func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with item: ItemShoppingModel) {
        coreDataItem.setValue(item.id, forKey: "id")
        coreDataItem.setValue(item.item_stable_id, forKey: "item_stable_id")
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
