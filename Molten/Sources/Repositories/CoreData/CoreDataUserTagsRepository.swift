//
//  CoreDataUserTagsRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//
//  Core CRUD operations for user tags
//  Extensions: +Legacy, +Discovery, +Analytics, +Migration, +Helpers
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of UserTagsRepository
/// Provides persistent storage for user-created tags using Core Data
///
/// Architecture:
/// - CoreDataUserTagsRepository.swift: Core CRUD operations (add, remove, set tags)
/// - +Legacy: Legacy API for glass items (delegates to generic API)
/// - +Discovery: Tag discovery and owner discovery
/// - +Analytics: Tag usage counts and statistics
/// - +Migration: Schema migration (old → new schema)
/// - +Helpers: Private helper methods and errors
class CoreDataUserTagsRepository: @unchecked Sendable, UserTagsRepository {

    // MARK: - Dependencies

    let context: NSManagedObjectContext
    let backgroundContext: NSManagedObjectContext
    let log = Logger(subsystem: "com.flameworker.app", category: "usertags-repository")

    // MARK: - Initialization

    /// Initialize CoreDataUserTagsRepository with a Core Data context
    /// - Parameter context: The NSManagedObjectContext to use for user tags operations
    /// - Note: In production, pass PersistenceController.shared.cloudContext
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        // Kick off background migration of old records
        Task.detached { [weak backgroundContext] in
            guard let context = backgroundContext else { return }
            try? await Self.migrateAllRecordsIfNeeded(context: context)
        }
    }

    // MARK: - Generic Tag Operations (New API - Supports All Owner Types)

    func fetchTags(ownerType: TagOwnerType, ownerId: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                    fetchRequest.predicate = NSPredicate(
                        format: "owner_type == %@ AND owner_id == %@",
                        ownerType.rawValue, ownerId
                    )
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tag", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)

                    // Lazy migration fallback (shouldn't be needed if background migration worked)
                    try self.migrateEntitiesIfNeeded(coreDataItems, context: self.backgroundContext, log: self.log)

                    let tags = coreDataItems.compactMap { $0.value(forKey: "tag") as? String }
                    continuation.resume(returning: tags)

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchTagsForOwners(ownerType: TagOwnerType, ownerIds: [String]) async throws -> [String: [String]] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: [String]], Error>) in
            backgroundContext.perform {
                do {
                    guard !ownerIds.isEmpty else {
                        continuation.resume(returning: [:])
                        return
                    }

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                    fetchRequest.predicate = NSPredicate(
                        format: "owner_type == %@ AND owner_id IN %@",
                        ownerType.rawValue, ownerIds
                    )
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "owner_id", ascending: true),
                        NSSortDescriptor(key: "tag", ascending: true)
                    ]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)

                    // Lazy migration fallback
                    try self.migrateEntitiesIfNeeded(coreDataItems, context: self.backgroundContext, log: self.log)

                    // Group tags by owner ID
                    var tagsByOwner: [String: [String]] = [:]
                    for item in coreDataItems {
                        guard let ownerId = item.value(forKey: "owner_id") as? String,
                              let tag = item.value(forKey: "tag") as? String else {
                            continue
                        }

                        if tagsByOwner[ownerId] == nil {
                            tagsByOwner[ownerId] = []
                        }
                        tagsByOwner[ownerId]?.append(tag)
                    }

                    continuation.resume(returning: tagsByOwner)

                } catch {
                    self.log.error("Failed to batch fetch user tags for owners: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func addTag(_ tag: String, ownerType: TagOwnerType, ownerId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Clean and validate tag
                    let cleanTag = UserTagModel.cleanTag(tag)
                    guard UserTagModel.isValidTag(cleanTag) else {
                        throw CoreDataUserTagsRepositoryError.invalidTag(tag)
                    }

                    // Check if tag already exists for this owner
                    if try self.tagExistsSync(cleanTag, ownerType: ownerType, ownerId: ownerId) {
                        // Already exists, no-op (idempotent)
                        self.log.debug("User tag '\(cleanTag)' already exists for \(ownerType.rawValue):\(ownerId)")
                        continuation.resume()
                        return
                    }

                    // Create new tag entry
                    guard let entity = NSEntityDescription.entity(forEntityName: "UserTags", in: self.backgroundContext) else {
                        throw CoreDataUserTagsRepositoryError.entityNotFound("UserTags")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                    coreDataItem.setValue(ownerType.rawValue, forKey: "owner_type")
                    coreDataItem.setValue(ownerId, forKey: "owner_id")
                    coreDataItem.setValue(cleanTag, forKey: "tag")

                    try self.backgroundContext.save()

                    continuation.resume()

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func addTags(_ tags: [String], ownerType: TagOwnerType, ownerId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Clean and validate tags
                    let cleanTags = tags.compactMap { tag in
                        let cleaned = UserTagModel.cleanTag(tag)
                        return UserTagModel.isValidTag(cleaned) ? cleaned : nil
                    }

                    guard !cleanTags.isEmpty else {
                        self.log.debug("No valid user tags to add")
                        continuation.resume()
                        return
                    }

                    // Get existing tags for this owner
                    let existingTags = try self.fetchTagsSync(ownerType: ownerType, ownerId: ownerId)
                    let existingTagsSet = Set(existingTags)

                    // Filter out tags that already exist
                    let newTags = cleanTags.filter { !existingTagsSet.contains($0) }

                    guard !newTags.isEmpty else {
                        self.log.debug("All user tags already exist for \(ownerType.rawValue):\(ownerId)")
                        continuation.resume()
                        return
                    }

                    // Create new tag entries
                    guard let entity = NSEntityDescription.entity(forEntityName: "UserTags", in: self.backgroundContext) else {
                        throw CoreDataUserTagsRepositoryError.entityNotFound("UserTags")
                    }

                    for tag in newTags {
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                        coreDataItem.setValue(ownerType.rawValue, forKey: "owner_type")
                        coreDataItem.setValue(ownerId, forKey: "owner_id")
                        coreDataItem.setValue(tag, forKey: "tag")
                    }

                    try self.backgroundContext.save()

                    self.log.info("Added \(newTags.count) user tags to \(ownerType.rawValue):\(ownerId)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to add user tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func removeTag(_ tag: String, ownerType: TagOwnerType, ownerId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let cleanTag = UserTagModel.cleanTag(tag)

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                    fetchRequest.predicate = NSPredicate(
                        format: "owner_type == %@ AND owner_id == %@ AND tag == %@",
                        ownerType.rawValue, ownerId, cleanTag
                    )

                    let results = try self.backgroundContext.fetch(fetchRequest)

                    for item in results {
                        self.backgroundContext.delete(item)
                    }

                    if !results.isEmpty {
                        try self.backgroundContext.save()
                        self.log.info("Removed user tag '\(cleanTag)' from \(ownerType.rawValue):\(ownerId)")
                    } else {
                        self.log.debug("User tag '\(cleanTag)' not found for \(ownerType.rawValue):\(ownerId)")
                    }

                    continuation.resume()

                } catch {
                    self.log.error("Failed to remove user tag: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func removeAllTags(ownerType: TagOwnerType, ownerId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                    fetchRequest.predicate = NSPredicate(
                        format: "owner_type == %@ AND owner_id == %@",
                        ownerType.rawValue, ownerId
                    )

                    let results = try self.backgroundContext.fetch(fetchRequest)

                    for item in results {
                        self.backgroundContext.delete(item)
                    }

                    if !results.isEmpty {
                        try self.backgroundContext.save()
                        self.log.info("Removed all \(results.count) user tags from \(ownerType.rawValue):\(ownerId)")
                    }

                    continuation.resume()

                } catch {
                    self.log.error("Failed to remove all user tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func setTags(_ tags: [String], ownerType: TagOwnerType, ownerId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Clean and validate tags
                    let cleanTags = tags.compactMap { tag in
                        let cleaned = UserTagModel.cleanTag(tag)
                        return UserTagModel.isValidTag(cleaned) ? cleaned : nil
                    }
                    let cleanTagsSet = Set(cleanTags)

                    // Get existing tags
                    let existingTags = try self.fetchTagsSync(ownerType: ownerType, ownerId: ownerId)
                    let existingTagsSet = Set(existingTags)

                    // Calculate differences
                    let tagsToAdd = cleanTagsSet.subtracting(existingTagsSet)
                    let tagsToRemove = existingTagsSet.subtracting(cleanTagsSet)

                    // Remove tags that shouldn't be there
                    if !tagsToRemove.isEmpty {
                        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                        fetchRequest.predicate = NSPredicate(
                            format: "owner_type == %@ AND owner_id == %@ AND tag IN %@",
                            ownerType.rawValue, ownerId, Array(tagsToRemove)
                        )

                        let itemsToDelete = try self.backgroundContext.fetch(fetchRequest)
                        for item in itemsToDelete {
                            self.backgroundContext.delete(item)
                        }
                    }

                    // Add new tags
                    if !tagsToAdd.isEmpty {
                        guard let entity = NSEntityDescription.entity(forEntityName: "UserTags", in: self.backgroundContext) else {
                            throw CoreDataUserTagsRepositoryError.entityNotFound("UserTags")
                        }

                        for tag in tagsToAdd {
                            let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                            coreDataItem.setValue(ownerType.rawValue, forKey: "owner_type")
                            coreDataItem.setValue(ownerId, forKey: "owner_id")
                            coreDataItem.setValue(tag, forKey: "tag")
                        }
                    }

                    if !tagsToAdd.isEmpty || !tagsToRemove.isEmpty {
                        try self.backgroundContext.save()
                        self.log.info("Set user tags for \(ownerType.rawValue):\(ownerId): added \(tagsToAdd.count), removed \(tagsToRemove.count)")
                    }

                    continuation.resume()

                } catch {
                    self.log.error("Failed to set user tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
