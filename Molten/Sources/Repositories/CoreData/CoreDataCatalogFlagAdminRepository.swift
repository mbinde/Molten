//
//  CoreDataCatalogFlagAdminRepository.swift
//  Molten
//
//  Created on 2025-12-21.
//
//  Core Data implementation for admin catalog flags
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of CatalogFlagAdminRepository
class CoreDataCatalogFlagAdminRepository: @unchecked Sendable, CatalogFlagAdminRepository {

    // MARK: - Dependencies

    let context: NSManagedObjectContext
    let backgroundContext: NSManagedObjectContext
    let log = Logger(subsystem: "com.motleywoods.molten", category: "catalog-flag-admin-repository")

    // MARK: - Initialization

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Single Item Operations

    func fetchFlags(for item_stable_id: String) async throws -> [CatalogFlagAdminModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND deleted_at == nil",
                item_stable_id
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "flag_key", ascending: true)]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.modelFromManagedObject($0) }
        }
    }

    func fetchFlagAdditions(for item_stable_id: String) async throws -> [CatalogFlagAdminModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND deleted_at == nil AND is_removal == NO",
                item_stable_id
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "flag_key", ascending: true)]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.modelFromManagedObject($0) }
        }
    }

    func fetchFlagRemovals(for item_stable_id: String) async throws -> [CatalogFlagAdminModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND deleted_at == nil AND is_removal == YES",
                item_stable_id
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "flag_key", ascending: true)]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.modelFromManagedObject($0) }
        }
    }

    func saveFlag(_ flag: CatalogFlagAdminModel) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            // Check if flag already exists for this item + key
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND flag_key == %@ AND deleted_at == nil",
                flag.item_stable_id, flag.flag_key
            )

            let existingFlags = try context.fetch(fetchRequest)

            let managedObject: NSManagedObject
            if let existing = existingFlags.first {
                // Update existing flag
                managedObject = existing
                self.log.debug("Updating existing admin flag \(flag.flag_key) for \(flag.item_stable_id)")
            } else {
                // Create new flag
                guard let entity = NSEntityDescription.entity(forEntityName: "CatalogFlagAdmin", in: context) else {
                    throw CatalogFlagRepositoryError.entityNotFound("CatalogFlagAdmin")
                }
                managedObject = NSManagedObject(entity: entity, insertInto: context)
                managedObject.setValue(flag.id, forKey: "id")
                managedObject.setValue(flag.created_at, forKey: "created_at")
                self.log.debug("Creating new admin flag \(flag.flag_key) for \(flag.item_stable_id)")
            }

            managedObject.setValue(flag.item_stable_id, forKey: "item_stable_id")
            managedObject.setValue(flag.flag_key, forKey: "flag_key")
            managedObject.setValue(flag.flag_value, forKey: "flag_value")
            managedObject.setValue(flag.is_removal, forKey: "is_removal")
            if let numeric = flag.flag_numeric {
                managedObject.setValue(numeric, forKey: "flag_numeric")
            } else {
                managedObject.setValue(nil, forKey: "flag_numeric")
            }
            if let descReplacement = flag.description_replacement {
                managedObject.setValue(descReplacement, forKey: "description_replacement")
            } else {
                managedObject.setValue(nil, forKey: "description_replacement")
            }
            managedObject.setValue(Date(), forKey: "updated_at")

            try context.save()
        }
    }

    func markFlagForRemoval(item_stable_id: String, flag_key: String) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            // Check if a removal record already exists
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND flag_key == %@ AND is_removal == YES AND deleted_at == nil",
                item_stable_id, flag_key
            )

            let existingRemovals = try context.fetch(fetchRequest)
            if !existingRemovals.isEmpty {
                self.log.debug("Flag removal record already exists for \(flag_key) on \(item_stable_id)")
                return
            }

            // Create new removal record
            guard let entity = NSEntityDescription.entity(forEntityName: "CatalogFlagAdmin", in: context) else {
                throw CatalogFlagRepositoryError.entityNotFound("CatalogFlagAdmin")
            }

            let managedObject = NSManagedObject(entity: entity, insertInto: context)
            managedObject.setValue(UUID(), forKey: "id")
            managedObject.setValue(item_stable_id, forKey: "item_stable_id")
            managedObject.setValue(flag_key, forKey: "flag_key")
            managedObject.setValue(true, forKey: "flag_value")
            managedObject.setValue(true, forKey: "is_removal")
            managedObject.setValue(Date(), forKey: "created_at")
            managedObject.setValue(Date(), forKey: "updated_at")

            try context.save()
            self.log.info("Created removal record for flag \(flag_key) on \(item_stable_id)")
        }
    }

    func removeAdminFlag(_ flagId: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
            fetchRequest.predicate = NSPredicate(format: "id == %@", flagId as CVarArg)

            let results = try context.fetch(fetchRequest)
            guard let flagToDelete = results.first else {
                return // Already deleted, no-op
            }

            // Soft delete for CloudKit sync
            flagToDelete.setValue(Date(), forKey: "deleted_at")
            try context.save()

            self.log.info("Soft deleted admin flag \(flagId)")
        }
    }

    func removeAdminFlag(item_stable_id: String, flag_key: String) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
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
                self.log.info("Soft deleted admin flag \(flag_key) for \(item_stable_id)")
            }
        }
    }

    // MARK: - Batch Operations

    func fetchFlags(for item_stable_ids: [String]) async throws -> [String: [CatalogFlagAdminModel]] {
        guard !item_stable_ids.isEmpty else { return [:] }

        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id IN %@ AND deleted_at == nil",
                item_stable_ids
            )
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "item_stable_id", ascending: true),
                NSSortDescriptor(key: "flag_key", ascending: true)
            ]

            let results = try context.fetch(fetchRequest)

            var flagsByItem: [String: [CatalogFlagAdminModel]] = [:]
            for result in results {
                guard let model = self.modelFromManagedObject(result) else { continue }
                flagsByItem[model.item_stable_id, default: []].append(model)
            }

            return flagsByItem
        }
    }

    func fetchAllFlags() async throws -> [CatalogFlagAdminModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
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
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
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
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogFlagAdmin")
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

    private func modelFromManagedObject(_ object: NSManagedObject) -> CatalogFlagAdminModel? {
        guard let id = object.value(forKey: "id") as? UUID,
              let item_stable_id = object.value(forKey: "item_stable_id") as? String,
              let flag_key = object.value(forKey: "flag_key") as? String,
              let created_at = object.value(forKey: "created_at") as? Date,
              let updated_at = object.value(forKey: "updated_at") as? Date else {
            return nil
        }

        let flag_value = object.value(forKey: "flag_value") as? Bool ?? true
        let flag_numeric = object.value(forKey: "flag_numeric") as? Double
        let description_replacement = object.value(forKey: "description_replacement") as? String
        let is_removal = object.value(forKey: "is_removal") as? Bool ?? false

        return CatalogFlagAdminModel(
            id: id,
            item_stable_id: item_stable_id,
            flag_key: flag_key,
            flag_value: flag_value,
            flag_numeric: flag_numeric,
            description_replacement: description_replacement,
            is_removal: is_removal,
            created_at: created_at,
            updated_at: updated_at
        )
    }
}

// MARK: - Errors

enum CatalogFlagRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let name):
            return "Entity '\(name)' not found in Core Data model"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
