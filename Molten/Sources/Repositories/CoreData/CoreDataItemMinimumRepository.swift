//
//  CoreDataItemMinimumRepository.swift
//  Molten
//
//  Created by Claude Code on 11/12/2025.
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of ItemMinimumRepository
/// Provides persistent storage for item minimum records (shopping lists, low water marks)
class CoreDataItemMinimumRepository: @unchecked Sendable, ItemMinimumRepository {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let log = Logger(subsystem: "com.molten.app", category: "item-minimum-repository")

    // MARK: - Initialization

    /// Initialize with a managed object context
    /// - Parameter context: The NSManagedObjectContext to use for data operations
    /// - Note: In production, pass PersistenceController.shared.cloudContext (user data)
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Basic CRUD Operations

    func fetchMinimums(matching predicate: NSPredicate?) async throws -> [ItemMinimumModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ItemMinimumModel], Error>) in
            nonisolated(unsafe) let predicateCopy = predicate
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemMinimum")
                    fetchRequest.predicate = predicateCopy
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "item_stable_id", ascending: true),
                        NSSortDescriptor(key: "type", ascending: true)
                    ]

                    let coreDataItems = try self.context.fetch(fetchRequest)
                    let minimums = coreDataItems.compactMap { self.convertToItemMinimumModel($0) }

                    continuation.resume(returning: minimums)

                } catch {
                    self.log.error("Failed to fetch item minimum records: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchMinimum(forItem item_stable_id: String, type: String) async throws -> ItemMinimumModel? {
        let cleanType = InventoryModel.cleanType(type)
        let predicate = NSPredicate(format: "item_stable_id == %@ AND type == %@", item_stable_id, cleanType)
        let minimums = try await fetchMinimums(matching: predicate)
        return minimums.first
    }

    func fetchMinimums(forItem item_stable_id: String) async throws -> [ItemMinimumModel] {
        let predicate = NSPredicate(format: "item_stable_id == %@", item_stable_id)
        return try await fetchMinimums(matching: predicate)
    }

    func fetchMinimums(forStore store: String) async throws -> [ItemMinimumModel] {
        let cleanStore = ItemMinimumModel.cleanStoreName(store)
        let predicate = NSPredicate(format: "store == %@", cleanStore)
        return try await fetchMinimums(matching: predicate)
    }

    func createMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ItemMinimumModel, Error>) in
            context.perform {
                do {
                    // Check for existing record with same item_stable_id + type
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemMinimum")
                    fetchRequest.predicate = NSPredicate(
                        format: "item_stable_id == %@ AND type == %@",
                        minimum.item_stable_id,
                        minimum.type
                    )
                    let existing = try self.context.fetch(fetchRequest)

                    if !existing.isEmpty {
                        throw CoreDataItemMinimumRepositoryError.minimumAlreadyExists(minimum.item_stable_id, minimum.type)
                    }

                    // Create new Core Data entity
                    let entity = NSEntityDescription.entity(forEntityName: "ItemMinimum", in: self.context)!
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.context)

                    self.updateCoreDataEntity(coreDataItem, with: minimum)

                    try self.context.save()

                    continuation.resume(returning: minimum)

                } catch {
                    self.log.error("Failed to create item minimum: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func createMinimums(_ minimums: [ItemMinimumModel]) async throws -> [ItemMinimumModel] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ItemMinimumModel], Error>) in
            context.perform {
                do {
                    var createdMinimums: [ItemMinimumModel] = []

                    for minimum in minimums {
                        // Check for existing record
                        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemMinimum")
                        fetchRequest.predicate = NSPredicate(
                            format: "item_stable_id == %@ AND type == %@",
                            minimum.item_stable_id,
                            minimum.type
                        )
                        let existing = try self.context.fetch(fetchRequest)

                        if !existing.isEmpty {
                            throw CoreDataItemMinimumRepositoryError.minimumAlreadyExists(minimum.item_stable_id, minimum.type)
                        }

                        // Create new Core Data entity
                        let entity = NSEntityDescription.entity(forEntityName: "ItemMinimum", in: self.context)!
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.context)

                        self.updateCoreDataEntity(coreDataItem, with: minimum)
                        createdMinimums.append(minimum)
                    }

                    try self.context.save()
                    continuation.resume(returning: createdMinimums)

                } catch {
                    self.log.error("Failed to create item minimums: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ItemMinimumModel, Error>) in
            context.perform {
                do {
                    // Find existing record
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemMinimum")
                    fetchRequest.predicate = NSPredicate(
                        format: "item_stable_id == %@ AND type == %@",
                        minimum.item_stable_id,
                        minimum.type
                    )
                    let results = try self.context.fetch(fetchRequest)

                    guard let coreDataItem = results.first else {
                        throw CoreDataItemMinimumRepositoryError.minimumNotFound(minimum.item_stable_id, minimum.type)
                    }

                    self.updateCoreDataEntity(coreDataItem, with: minimum)

                    try self.context.save()

                    continuation.resume(returning: minimum)

                } catch {
                    self.log.error("Failed to update item minimum: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteMinimum(forItem item_stable_id: String, type: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let cleanType = InventoryModel.cleanType(type)
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemMinimum")
                    fetchRequest.predicate = NSPredicate(
                        format: "item_stable_id == %@ AND type == %@",
                        item_stable_id,
                        cleanType
                    )
                    let results = try self.context.fetch(fetchRequest)

                    for item in results {
                        self.context.delete(item)
                    }

                    try self.context.save()
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete item minimum: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteMinimums(forItem item_stable_id: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemMinimum")
                    fetchRequest.predicate = NSPredicate(format: "item_stable_id == %@", item_stable_id)
                    let results = try self.context.fetch(fetchRequest)

                    for item in results {
                        self.context.delete(item)
                    }

                    try self.context.save()
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete item minimums: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteMinimums(forStore store: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let cleanStore = ItemMinimumModel.cleanStoreName(store)
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemMinimum")
                    fetchRequest.predicate = NSPredicate(format: "store == %@", cleanStore)
                    let results = try self.context.fetch(fetchRequest)

                    for item in results {
                        self.context.delete(item)
                    }

                    try self.context.save()
                    continuation.resume()

                } catch {
                    self.log.error("Failed to delete store minimums: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Shopping List Operations

    func generateShoppingList(forStore store: String, currentInventory: [String: [String: Double]]) async throws -> [ShoppingListItemModel] {
        let minimums = try await fetchMinimums(forStore: store)

        let shoppingList = minimums.compactMap { minimum -> ShoppingListItemModel? in
            let currentQuantity = currentInventory[minimum.item_stable_id]?[minimum.type] ?? 0.0

            // Only include items where current quantity is below minimum
            if currentQuantity < minimum.quantity {
                return ShoppingListItemModel(
                    item_stable_id: minimum.item_stable_id,
                    type: minimum.type,
                    currentQuantity: currentQuantity,
                    minimumQuantity: minimum.quantity,
                    store: minimum.store
                )
            }
            return nil
        }.sorted()

        return shoppingList
    }

    func generateShoppingLists(currentInventory: [String: [String: Double]]) async throws -> [String: [ShoppingListItemModel]] {
        let allMinimums = try await fetchMinimums(matching: nil)

        let groupedByStore = Dictionary(grouping: allMinimums) { $0.store }

        let shoppingLists = groupedByStore.mapValues { storeMinimums in
            storeMinimums.compactMap { minimum -> ShoppingListItemModel? in
                let currentQuantity = currentInventory[minimum.item_stable_id]?[minimum.type] ?? 0.0

                // Only include items where current quantity is below minimum
                if currentQuantity < minimum.quantity {
                    return ShoppingListItemModel(
                        item_stable_id: minimum.item_stable_id,
                        type: minimum.type,
                        currentQuantity: currentQuantity,
                        minimumQuantity: minimum.quantity,
                        store: minimum.store
                    )
                }
                return nil
            }.sorted()
        }

        return shoppingLists
    }

    func getLowStockItems(currentInventory: [String: [String: Double]]) async throws -> [LowStockItemModel] {
        let allMinimums = try await fetchMinimums(matching: nil)

        let lowStockItems = allMinimums.compactMap { minimum -> LowStockItemModel? in
            let currentQuantity = currentInventory[minimum.item_stable_id]?[minimum.type] ?? 0.0

            // Only include items where current quantity is below minimum
            if currentQuantity < minimum.quantity {
                return LowStockItemModel(
                    item_stable_id: minimum.item_stable_id,
                    type: minimum.type,
                    currentQuantity: currentQuantity,
                    minimumQuantity: minimum.quantity,
                    store: minimum.store
                )
            }
            return nil
        }.sorted()

        return lowStockItems
    }

    func setMinimumQuantity(_ quantity: Double, forItem item_stable_id: String, type: String, store: String) async throws -> ItemMinimumModel {
        let cleanType = InventoryModel.cleanType(type)
        let cleanStore = ItemMinimumModel.cleanStoreName(store)

        // Check if minimum exists
        if let existing = try await fetchMinimum(forItem: item_stable_id, type: cleanType) {
            // Update existing
            let updated = ItemMinimumModel(
                id: existing.id,
                item_stable_id: item_stable_id,
                quantity: quantity,
                type: cleanType,
                store: cleanStore
            )
            return try await updateMinimum(updated)
        } else {
            // Create new
            let newMinimum = ItemMinimumModel(
                item_stable_id: item_stable_id,
                quantity: quantity,
                type: cleanType,
                store: cleanStore
            )
            return try await createMinimum(newMinimum)
        }
    }

    // MARK: - Store Management Operations

    func getDistinctStores() async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemMinimum")
                    fetchRequest.propertiesToFetch = ["store"]
                    fetchRequest.returnsDistinctResults = true
                    fetchRequest.resultType = .dictionaryResultType

                    let results = try self.context.fetch(fetchRequest)
                    let stores = results.compactMap { $0.value(forKey: "store") as? String }

                    continuation.resume(returning: stores.sorted())

                } catch {
                    self.log.error("Failed to fetch distinct stores: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getStores(withPrefix prefix: String) async throws -> [String] {
        let allStores = try await getDistinctStores()
        let lowercasePrefix = prefix.lowercased()
        let matchingStores = allStores.filter { $0.lowercased().hasPrefix(lowercasePrefix) }
        return matchingStores.sorted()
    }

    func getStoreUtilization() async throws -> [String: Int] {
        let allMinimums = try await fetchMinimums(matching: nil)
        let utilization = Dictionary(grouping: allMinimums, by: { $0.store })
            .mapValues { $0.count }
        return utilization
    }

    func updateStoreName(from oldStoreName: String, to newStoreName: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let cleanOldStore = ItemMinimumModel.cleanStoreName(oldStoreName)
                    let cleanNewStore = ItemMinimumModel.cleanStoreName(newStoreName)

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemMinimum")
                    fetchRequest.predicate = NSPredicate(format: "store == %@", cleanOldStore)
                    let results = try self.context.fetch(fetchRequest)

                    for item in results {
                        item.setValue(cleanNewStore, forKey: "store")
                    }

                    try self.context.save()
                    continuation.resume()

                } catch {
                    self.log.error("Failed to update store name: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Analytics Operations

    func getMinimumQuantityStatistics() async throws -> MinimumQuantityStatistics {
        let allMinimums = try await fetchMinimums(matching: nil)
        return MinimumQuantityStatistics(minimums: allMinimums)
    }

    func getHighestMinimums(limit: Int) async throws -> [ItemMinimumModel] {
        let allMinimums = try await fetchMinimums(matching: nil)
        let highest = allMinimums.sorted { $0.quantity > $1.quantity }.prefix(limit)
        return Array(highest)
    }

    func getMostCommonTypes() async throws -> [String: Int] {
        let allMinimums = try await fetchMinimums(matching: nil)
        let typeCounts = Dictionary(grouping: allMinimums, by: { $0.type })
            .mapValues { $0.count }
        return typeCounts
    }

    func validateMinimumRecords(validItemKeys: Set<String>) async throws -> [ItemMinimumModel] {
        let allMinimums = try await fetchMinimums(matching: nil)
        let invalidMinimums = allMinimums.filter { minimum in
            !validItemKeys.contains(minimum.item_stable_id)
        }
        return invalidMinimums
    }

    // MARK: - Private Helpers

    /// Convert Core Data NSManagedObject to ItemMinimumModel
    /// Note: ItemMinimum entity doesn't have a UUID field, so we generate one for Identifiable conformance
    private nonisolated func convertToItemMinimumModel(_ coreDataItem: NSManagedObject) -> ItemMinimumModel? {
        guard let item_stable_id = coreDataItem.value(forKey: "item_stable_id") as? String,
              let type = coreDataItem.value(forKey: "type") as? String,
              let store = coreDataItem.value(forKey: "store") as? String,
              let quantityNumber = coreDataItem.value(forKey: "quantity") as? NSNumber else {
            log.error("Failed to convert Core Data item to ItemMinimumModel - missing required properties")
            return nil
        }

        // Generate deterministic UUID from composite key (item_stable_id + type)
        // This ensures the same item+type always gets the same UUID
        let compositeKey = "\(item_stable_id)-\(type)"
        let uuid = UUID(uuidString: compositeKey.sha256AsUUIDString()) ?? UUID()

        return ItemMinimumModel(
            id: uuid,
            item_stable_id: item_stable_id,
            quantity: quantityNumber.doubleValue,
            type: type,
            store: store
        )
    }

    /// Update Core Data entity with values from ItemMinimumModel
    private nonisolated func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with minimum: ItemMinimumModel) {
        coreDataItem.setValue(minimum.item_stable_id, forKey: "item_stable_id")
        coreDataItem.setValue(minimum.type, forKey: "type")
        coreDataItem.setValue(minimum.quantity, forKey: "quantity")
        coreDataItem.setValue(minimum.store, forKey: "store")
        // Note: dimensions and subtype fields exist in schema but are not used by ItemMinimumModel
    }
}

// MARK: - Repository Errors

enum CoreDataItemMinimumRepositoryError: Error, LocalizedError {
    case minimumNotFound(String, String)
    case minimumAlreadyExists(String, String)

    var errorDescription: String? {
        switch self {
        case .minimumNotFound(let itemKey, let type):
            return "Minimum not found for item: \(itemKey), type: \(type)"
        case .minimumAlreadyExists(let itemKey, let type):
            return "Minimum already exists for item: \(itemKey), type: \(type)"
        }
    }
}

// MARK: - String Hashing Extension for Deterministic UUID Generation

extension String {
    /// Converts a string to a deterministic UUID string by hashing it
    func sha256AsUUIDString() -> String {
        // Simple hash to UUID conversion (for deterministic ID generation)
        // This is a simplified approach - in production, consider using CryptoKit
        let hash = self.hashValue
        let uuidString = String(format: "%08x-0000-0000-0000-%012x", hash, abs(hash))
        return uuidString
    }
}
