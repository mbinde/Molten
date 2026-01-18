//
//  CoreDataCatalogTagAdminRepository.swift
//  Molten
//
//  Core Data implementation for admin catalog tags
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of CatalogTagAdminRepository
class CoreDataCatalogTagAdminRepository: @unchecked Sendable, CatalogTagAdminRepository {

    // MARK: - Dependencies

    let context: NSManagedObjectContext
    let backgroundContext: NSManagedObjectContext
    let log = Logger(subsystem: "com.motleywoods.molten", category: "catalog-tag-admin-repository")

    // MARK: - Initialization

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Single Item Operations

    func fetchTags(for item_stable_id: String) async throws -> [CatalogTagAdminModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND deleted_at == nil",
                item_stable_id
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tag", ascending: true)]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.modelFromManagedObject($0) }
        }
    }

    func fetchTagAdditions(for item_stable_id: String) async throws -> [CatalogTagAdminModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND deleted_at == nil AND is_removal == NO",
                item_stable_id
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tag", ascending: true)]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.modelFromManagedObject($0) }
        }
    }

    func fetchTagRemovals(for item_stable_id: String) async throws -> [CatalogTagAdminModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND deleted_at == nil AND is_removal == YES",
                item_stable_id
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tag", ascending: true)]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.modelFromManagedObject($0) }
        }
    }

    func addTag(_ tag: String, to item_stable_id: String) async throws {
        let cleanedTag = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !cleanedTag.isEmpty else { return }

        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            // Check if tag already exists for this item (as addition)
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND tag == %@ AND deleted_at == nil AND is_removal == NO",
                item_stable_id, cleanedTag
            )

            let existingTags = try context.fetch(fetchRequest)
            if !existingTags.isEmpty {
                self.log.debug("Tag '\(cleanedTag)' already exists for \(item_stable_id)")
                return // Already exists, no-op
            }

            // If there's a removal record for this tag, delete it instead of adding
            let removalRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            removalRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND tag == %@ AND deleted_at == nil AND is_removal == YES",
                item_stable_id, cleanedTag
            )
            let existingRemovals = try context.fetch(removalRequest)
            if !existingRemovals.isEmpty {
                // Remove the removal record (un-remove the tag)
                for removal in existingRemovals {
                    removal.setValue(Date(), forKey: "deleted_at")
                }
                try context.save()
                self.log.debug("Removed removal record for tag '\(cleanedTag)' for \(item_stable_id)")
                return
            }

            // Create new tag addition
            guard let entity = NSEntityDescription.entity(forEntityName: "CatalogTagAdmin", in: context) else {
                throw CatalogTagRepositoryError.entityNotFound("CatalogTagAdmin")
            }

            let managedObject = NSManagedObject(entity: entity, insertInto: context)
            managedObject.setValue(UUID(), forKey: "id")
            managedObject.setValue(item_stable_id, forKey: "item_stable_id")
            managedObject.setValue(cleanedTag, forKey: "tag")
            managedObject.setValue(false, forKey: "is_removal")
            managedObject.setValue(Date(), forKey: "created_at")
            managedObject.setValue(Date(), forKey: "updated_at")

            try context.save()
            self.log.debug("Added tag '\(cleanedTag)' for \(item_stable_id)")
        }
    }

    func markTagForRemoval(_ tag: String, from item_stable_id: String) async throws {
        let cleanedTag = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !cleanedTag.isEmpty else { return }

        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            // Check if removal already exists
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND tag == %@ AND deleted_at == nil AND is_removal == YES",
                item_stable_id, cleanedTag
            )

            let existingRemovals = try context.fetch(fetchRequest)
            if !existingRemovals.isEmpty {
                self.log.debug("Removal for tag '\(cleanedTag)' already exists for \(item_stable_id)")
                return // Already marked for removal
            }

            // Create removal record
            guard let entity = NSEntityDescription.entity(forEntityName: "CatalogTagAdmin", in: context) else {
                throw CatalogTagRepositoryError.entityNotFound("CatalogTagAdmin")
            }

            let managedObject = NSManagedObject(entity: entity, insertInto: context)
            managedObject.setValue(UUID(), forKey: "id")
            managedObject.setValue(item_stable_id, forKey: "item_stable_id")
            managedObject.setValue(cleanedTag, forKey: "tag")
            managedObject.setValue(true, forKey: "is_removal")
            managedObject.setValue(Date(), forKey: "created_at")
            managedObject.setValue(Date(), forKey: "updated_at")

            try context.save()
            self.log.debug("Marked tag '\(cleanedTag)' for removal from \(item_stable_id)")
        }
    }

    func removeAdminTag(_ tagId: UUID) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(format: "id == %@", tagId as CVarArg)

            let results = try context.fetch(fetchRequest)
            guard let tagToDelete = results.first else {
                return // Already deleted, no-op
            }

            // Soft delete for CloudKit sync
            tagToDelete.setValue(Date(), forKey: "deleted_at")
            try context.save()

            self.log.info("Soft deleted admin tag \(tagId)")
        }
    }

    func removeAdminTag(item_stable_id: String, tag: String) async throws {
        let cleanedTag = tag.trimmingCharacters(in: .whitespaces).lowercased()

        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id == %@ AND tag == %@ AND deleted_at == nil",
                item_stable_id, cleanedTag
            )

            let results = try context.fetch(fetchRequest)
            for tagRecord in results {
                tagRecord.setValue(Date(), forKey: "deleted_at")
            }

            if !results.isEmpty {
                try context.save()
                self.log.info("Soft deleted admin tag '\(cleanedTag)' for \(item_stable_id)")
            }
        }
    }

    // MARK: - Batch Operations

    func fetchTags(for item_stable_ids: [String]) async throws -> [String: [CatalogTagAdminModel]] {
        guard !item_stable_ids.isEmpty else { return [:] }

        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "item_stable_id IN %@ AND deleted_at == nil",
                item_stable_ids
            )
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "item_stable_id", ascending: true),
                NSSortDescriptor(key: "tag", ascending: true)
            ]

            let results = try context.fetch(fetchRequest)

            var tagsByItem: [String: [CatalogTagAdminModel]] = [:]
            for result in results {
                guard let model = self.modelFromManagedObject(result) else { continue }
                tagsByItem[model.item_stable_id, default: []].append(model)
            }

            return tagsByItem
        }
    }

    func fetchAllTags() async throws -> [CatalogTagAdminModel] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(format: "deleted_at == nil")
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "item_stable_id", ascending: true),
                NSSortDescriptor(key: "tag", ascending: true)
            ]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.modelFromManagedObject($0) }
        }
    }

    // MARK: - Discovery Operations

    func getAllTags() async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(format: "deleted_at == nil")
            fetchRequest.propertiesToFetch = ["tag"]
            fetchRequest.returnsDistinctResults = true

            let results = try context.fetch(fetchRequest)
            let tags = results.compactMap { $0.value(forKey: "tag") as? String }
            return Array(Set(tags)).sorted()
        }
    }

    func getTagUsageCounts() async throws -> [String: Int] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(format: "deleted_at == nil")

            let results = try context.fetch(fetchRequest)

            var counts: [String: Int] = [:]
            for result in results {
                if let tag = result.value(forKey: "tag") as? String {
                    counts[tag, default: 0] += 1
                }
            }

            return counts
        }
    }

    func findItems(withTag tag: String) async throws -> [String] {
        let cleanedTag = tag.trimmingCharacters(in: .whitespaces).lowercased()

        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CatalogTagAdmin")
            fetchRequest.predicate = NSPredicate(
                format: "tag == %@ AND deleted_at == nil",
                cleanedTag
            )
            fetchRequest.propertiesToFetch = ["item_stable_id"]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { $0.value(forKey: "item_stable_id") as? String }
        }
    }

    // MARK: - Private Helpers

    private func modelFromManagedObject(_ object: NSManagedObject) -> CatalogTagAdminModel? {
        guard let id = object.value(forKey: "id") as? UUID,
              let item_stable_id = object.value(forKey: "item_stable_id") as? String,
              let tag = object.value(forKey: "tag") as? String,
              let created_at = object.value(forKey: "created_at") as? Date,
              let updated_at = object.value(forKey: "updated_at") as? Date else {
            return nil
        }

        let is_removal = object.value(forKey: "is_removal") as? Bool ?? false
        let deleted_at = object.value(forKey: "deleted_at") as? Date

        return CatalogTagAdminModel(
            id: id,
            item_stable_id: item_stable_id,
            tag: tag,
            is_removal: is_removal,
            created_at: created_at,
            updated_at: updated_at,
            deleted_at: deleted_at
        )
    }
}

// MARK: - Errors

enum CatalogTagRepositoryError: Error, LocalizedError {
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
