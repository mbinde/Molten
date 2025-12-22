//
//  CoreDataCatalogFlagUserRepository.swift
//  Molten
//
//  Created on 2025-12-21.
//
//  Core Data implementation for user catalog flags
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of CatalogFlagUserRepository
class CoreDataCatalogFlagUserRepository: @unchecked Sendable, CatalogFlagUserRepository {

    // MARK: - Dependencies

    let context: NSManagedObjectContext
    let backgroundContext: NSManagedObjectContext
    let log = Logger(subsystem: "com.motleywoods.molten", category: "catalog-flag-user-repository")

    // MARK: - Initialization

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Single Item Operations

    func fetchFlags(for item_stable_id: String) async throws -> [CatalogFlagUserModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagUser")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND deleted_at == nil",
                item_stable_id
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "flag_key", ascending: true)]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.modelFromManagedObject($0) }
        }
    }

    func saveFlag(_ flag: CatalogFlagUserModel) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            // Check if flag already exists for this item + key
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagUser")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND flag_key == %@ AND deleted_at == nil",
                flag.item_stable_id, flag.flag_key
            )

            let existingFlags = try context.fetch(fetchRequest)

            let managedObject: NSManagedObject
            if let existing = existingFlags.first {
                // Update existing flag
                managedObject = existing
                self.log.debug("Updating existing user flag \(flag.flag_key) for \(flag.item_stable_id)")
            } else {
                // Create new flag
                guard let entity = NSEntityDescription.entity(forEntityName: "CatalogFlagUser", in: context) else {
                    throw CatalogFlagRepositoryError.entityNotFound("CatalogFlagUser")
                }
                managedObject = NSManagedObject(entity: entity, insertInto: context)
                managedObject.setValue(flag.id, forKey: "id")
                managedObject.setValue(flag.created_at, forKey: "created_at")
                self.log.debug("Creating new user flag \(flag.flag_key) for \(flag.item_stable_id)")
            }

            managedObject.setValue(flag.item_stable_id, forKey: "item_stable_id")
            managedObject.setValue(flag.flag_key, forKey: "flag_key")
            managedObject.setValue(flag.flag_value, forKey: "flag_value")
            if let numeric = flag.flag_numeric {
                managedObject.setValue(numeric, forKey: "flag_numeric")
            } else {
                managedObject.setValue(nil, forKey: "flag_numeric")
            }
            managedObject.setValue(Date(), forKey: "updated_at")

            try context.save()
        }
    }

    func removeFlag(_ flagId: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagUser")
            fetchRequest.predicate = NSPredicate(format: "id == %@", flagId as CVarArg)

            let results = try context.fetch(fetchRequest)
            guard let flagToDelete = results.first else {
                return // Already deleted, no-op
            }

            // Soft delete for CloudKit sync
            flagToDelete.setValue(Date(), forKey: "deleted_at")
            try context.save()

            self.log.info("Soft deleted user flag \(flagId)")
        }
    }

    func removeFlag(item_stable_id: String, flag_key: String) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagUser")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND flag_key == %@ AND deleted_at == nil",
                item_stable_id, flag_key
            )

            let results = try context.fetch(fetchRequest)
            for flag in results {
                flag.setValue(Date(), forKey: "deleted_at")
            }

            if !results.isEmpty {
                try context.save()
                self.log.info("Soft deleted user flag \(flag_key) for \(item_stable_id)")
            }
        }
    }

    // MARK: - Batch Operations

    func fetchFlags(for item_stable_ids: [String]) async throws -> [String: [CatalogFlagUserModel]] {
        guard !item_stable_ids.isEmpty else { return [:] }

        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagUser")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id IN %@ AND deleted_at == nil",
                item_stable_ids
            )
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "item_stable_id", ascending: true),
                NSSortDescriptor(key: "flag_key", ascending: true)
            ]

            let results = try context.fetch(fetchRequest)

            var flagsByItem: [String: [CatalogFlagUserModel]] = [:]
            for result in results {
                guard let model = self.modelFromManagedObject(result) else { continue }
                flagsByItem[model.item_stable_id, default: []].append(model)
            }

            return flagsByItem
        }
    }

    func fetchAllFlags() async throws -> [CatalogFlagUserModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagUser")
            fetchRequest.predicate = NSPredicate(format: "deleted_at == nil")
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "item_stable_id", ascending: true),
                NSSortDescriptor(key: "flag_key", ascending: true)
            ]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.modelFromManagedObject($0) }
        }
    }

    // MARK: - Discovery Operations

    func findItems(withFlagKey flag_key: String) async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagUser")
            fetchRequest.predicate = NSPredicate(
                format: "flag_key == %@ AND deleted_at == nil",
                flag_key
            )
            fetchRequest.propertiesToFetch = ["item_stable_id"]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { $0.value(forKey: "item_stable_id") as? String }
        }
    }

    func findItems(withFlagKey flag_key: String, value: Bool) async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagUser")
            fetchRequest.predicate = NSPredicate(
                format: "flag_key == %@ AND flag_value == %@ AND deleted_at == nil",
                flag_key, NSNumber(value: value)
            )
            fetchRequest.propertiesToFetch = ["item_stable_id"]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { $0.value(forKey: "item_stable_id") as? String }
        }
    }

    // MARK: - Private Helpers

    private func modelFromManagedObject(_ object: NSManagedObject) -> CatalogFlagUserModel? {
        guard let id = object.value(forKey: "id") as? UUID,
              let item_stable_id = object.value(forKey: "item_stable_id") as? String,
              let flag_key = object.value(forKey: "flag_key") as? String,
              let created_at = object.value(forKey: "created_at") as? Date,
              let updated_at = object.value(forKey: "updated_at") as? Date else {
            return nil
        }

        let flag_value = object.value(forKey: "flag_value") as? Bool ?? true
        let flag_numeric = object.value(forKey: "flag_numeric") as? Double

        return CatalogFlagUserModel(
            id: id,
            item_stable_id: item_stable_id,
            flag_key: flag_key,
            flag_value: flag_value,
            flag_numeric: flag_numeric,
            created_at: created_at,
            updated_at: updated_at
        )
    }
}
