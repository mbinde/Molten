//
//  CoreDataItemTagsRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import CoreData
import Foundation
import OSLog

/// Core Data implementation of ItemTagsRepository
/// Provides persistent storage for item tags using Core Data
class CoreDataItemTagsRepository: ItemTagsRepository {

    // MARK: - Dependencies

    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "itemtags-repository")

    // MARK: - Initialization

    /// Initialize CoreDataItemTagsRepository with a Core Data persistent container
    /// - Parameter persistentContainer: The NSPersistentContainer to use for item tags operations
    /// - Note: In production, pass PersistenceController.shared.container
    init(itemTagsPersistentContainer persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        log.info("CoreDataItemTagsRepository initialized with persistent container")
    }

    // MARK: - Basic Tag Operations

    func fetchTags(forItem itemNaturalKey: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                    fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@", itemNaturalKey)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "tag", ascending: true)]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let tags = coreDataItems.compactMap { $0.value(forKey: "tag") as? String }

                    self.log.debug("Fetched \(tags.count) tags for item: \(itemNaturalKey)")
                    continuation.resume(returning: tags)

                } catch {
                    self.log.error("Failed to fetch tags for item: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchTagsForItems(_ itemNaturalKeys: [String]) async throws -> [String: [String]] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: [String]], Error>) in
            backgroundContext.perform {
                do {
                    guard !itemNaturalKeys.isEmpty else {
                        continuation.resume(returning: [:])
                        return
                    }

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                    fetchRequest.predicate = NSPredicate(format: "item_natural_key IN %@", itemNaturalKeys)
                    fetchRequest.sortDescriptors = [
                        NSSortDescriptor(key: "item_natural_key", ascending: true),
                        NSSortDescriptor(key: "tag", ascending: true)
                    ]

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)

                    // Group tags by item natural key
                    var tagsByItem: [String: [String]] = [:]
                    for item in coreDataItems {
                        guard let itemKey = item.value(forKey: "item_natural_key") as? String,
                              let tag = item.value(forKey: "tag") as? String else {
                            continue
                        }

                        if tagsByItem[itemKey] == nil {
                            tagsByItem[itemKey] = []
                        }
                        tagsByItem[itemKey]?.append(tag)
                    }

                    self.log.debug("Batch fetched tags for \(itemNaturalKeys.count) items, found tags for \(tagsByItem.count) items")
                    continuation.resume(returning: tagsByItem)

                } catch {
                    self.log.error("Failed to batch fetch tags for items: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func addTag(_ tag: String, toItem itemNaturalKey: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Clean and validate tag
                    let cleanTag = ItemTagModel.cleanTag(tag)
                    guard ItemTagModel.isValidTag(cleanTag) else {
                        throw CoreDataItemTagsRepositoryError.invalidTag(tag)
                    }

                    // Check if tag already exists for this item
                    if try self.tagExistsSync(cleanTag, forItem: itemNaturalKey) {
                        // Already exists, no-op (idempotent)
                        self.log.debug("Tag '\(cleanTag)' already exists for item \(itemNaturalKey)")
                        continuation.resume()
                        return
                    }

                    // Create new tag entry
                    guard let entity = NSEntityDescription.entity(forEntityName: "ItemTags", in: self.backgroundContext) else {
                        throw CoreDataItemTagsRepositoryError.entityNotFound("ItemTags")
                    }
                    let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)

                    coreDataItem.setValue(itemNaturalKey, forKey: "item_natural_key")
                    coreDataItem.setValue(cleanTag, forKey: "tag")

                    try self.backgroundContext.save()

                    self.log.info("Added tag '\(cleanTag)' to item: \(itemNaturalKey)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to add tag: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func addTags(_ tags: [String], toItem itemNaturalKey: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Clean and validate tags
                    let cleanTags = tags.compactMap { tag in
                        let cleaned = ItemTagModel.cleanTag(tag)
                        return ItemTagModel.isValidTag(cleaned) ? cleaned : nil
                    }

                    guard !cleanTags.isEmpty else {
                        self.log.debug("No valid tags to add")
                        continuation.resume()
                        return
                    }

                    // Get existing tags for this item
                    let existingTags = try self.fetchTagsSync(forItem: itemNaturalKey)
                    let existingTagsSet = Set(existingTags)

                    // Filter out tags that already exist
                    let newTags = cleanTags.filter { !existingTagsSet.contains($0) }

                    guard !newTags.isEmpty else {
                        self.log.debug("All tags already exist for item \(itemNaturalKey)")
                        continuation.resume()
                        return
                    }

                    // Create new tag entries
                    guard let entity = NSEntityDescription.entity(forEntityName: "ItemTags", in: self.backgroundContext) else {
                        throw CoreDataItemTagsRepositoryError.entityNotFound("ItemTags")
                    }

                    for tag in newTags {
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                        coreDataItem.setValue(itemNaturalKey, forKey: "item_natural_key")
                        coreDataItem.setValue(tag, forKey: "tag")
                    }

                    try self.backgroundContext.save()

                    self.log.info("Added \(newTags.count) tags to item: \(itemNaturalKey)")
                    continuation.resume()

                } catch {
                    self.log.error("Failed to add tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func removeTag(_ tag: String, fromItem itemNaturalKey: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let cleanTag = ItemTagModel.cleanTag(tag)

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                    fetchRequest.predicate = NSPredicate(
                        format: "item_natural_key == %@ AND tag == %@",
                        itemNaturalKey, cleanTag
                    )

                    let results = try self.backgroundContext.fetch(fetchRequest)

                    for item in results {
                        self.backgroundContext.delete(item)
                    }

                    if !results.isEmpty {
                        try self.backgroundContext.save()
                        self.log.info("Removed tag '\(cleanTag)' from item: \(itemNaturalKey)")
                    } else {
                        self.log.debug("Tag '\(cleanTag)' not found for item: \(itemNaturalKey)")
                    }

                    continuation.resume()

                } catch {
                    self.log.error("Failed to remove tag: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func removeAllTags(fromItem itemNaturalKey: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                    fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@", itemNaturalKey)

                    let results = try self.backgroundContext.fetch(fetchRequest)

                    for item in results {
                        self.backgroundContext.delete(item)
                    }

                    if !results.isEmpty {
                        try self.backgroundContext.save()
                        self.log.info("Removed all \(results.count) tags from item: \(itemNaturalKey)")
                    }

                    continuation.resume()

                } catch {
                    self.log.error("Failed to remove all tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func setTags(_ tags: [String], forItem itemNaturalKey: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            backgroundContext.perform {
                do {
                    // Clean and validate tags
                    let cleanTags = tags.compactMap { tag in
                        let cleaned = ItemTagModel.cleanTag(tag)
                        return ItemTagModel.isValidTag(cleaned) ? cleaned : nil
                    }
                    let cleanTagsSet = Set(cleanTags)

                    // Get existing tags
                    let existingTags = try self.fetchTagsSync(forItem: itemNaturalKey)
                    let existingTagsSet = Set(existingTags)

                    // Calculate differences
                    let tagsToAdd = cleanTagsSet.subtracting(existingTagsSet)
                    let tagsToRemove = existingTagsSet.subtracting(cleanTagsSet)

                    // Remove tags that shouldn't be there
                    if !tagsToRemove.isEmpty {
                        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                        fetchRequest.predicate = NSPredicate(
                            format: "item_natural_key == %@ AND tag IN %@",
                            itemNaturalKey, Array(tagsToRemove)
                        )

                        let itemsToDelete = try self.backgroundContext.fetch(fetchRequest)
                        for item in itemsToDelete {
                            self.backgroundContext.delete(item)
                        }
                    }

                    // Add new tags
                    if !tagsToAdd.isEmpty {
                        guard let entity = NSEntityDescription.entity(forEntityName: "ItemTags", in: self.backgroundContext) else {
                            throw CoreDataItemTagsRepositoryError.entityNotFound("ItemTags")
                        }

                        for tag in tagsToAdd {
                            let coreDataItem = NSManagedObject(entity: entity, insertInto: self.backgroundContext)
                            coreDataItem.setValue(itemNaturalKey, forKey: "item_natural_key")
                            coreDataItem.setValue(tag, forKey: "tag")
                        }
                    }

                    if !tagsToAdd.isEmpty || !tagsToRemove.isEmpty {
                        try self.backgroundContext.save()
                        self.log.info("Set tags for item \(itemNaturalKey): added \(tagsToAdd.count), removed \(tagsToRemove.count)")
                    }

                    continuation.resume()

                } catch {
                    self.log.error("Failed to set tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Tag Discovery Operations

    func getAllTags() async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)

                    let allTags = Set(coreDataItems.compactMap { $0.value(forKey: "tag") as? String })
                    let sortedTags = Array(allTags).sorted()

                    self.log.debug("Fetched \(sortedTags.count) distinct tags")
                    continuation.resume(returning: sortedTags)

                } catch {
                    self.log.error("Failed to fetch all tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getTags(withPrefix prefix: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let lowercasePrefix = prefix.lowercased()

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                    fetchRequest.predicate = NSPredicate(format: "tag BEGINSWITH[c] %@", lowercasePrefix)

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let allTags = Set(coreDataItems.compactMap { $0.value(forKey: "tag") as? String })
                    let sortedTags = Array(allTags).sorted()

                    self.log.debug("Found \(sortedTags.count) tags with prefix '\(prefix)'")
                    continuation.resume(returning: sortedTags)

                } catch {
                    self.log.error("Failed to fetch tags with prefix: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getMostUsedTags(limit: Int) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let tagCounts = try self.calculateTagCountsSync()
                    let sortedTags = tagCounts.sorted { $0.value > $1.value }
                    let limitedTags = Array(sortedTags.prefix(limit)).map { $0.key }

                    self.log.debug("Fetched top \(limitedTags.count) most used tags")
                    continuation.resume(returning: limitedTags)

                } catch {
                    self.log.error("Failed to fetch most used tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Item Discovery Operations

    func fetchItems(withTag tag: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let cleanTag = ItemTagModel.cleanTag(tag)

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                    fetchRequest.predicate = NSPredicate(format: "tag == %@", cleanTag)

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let itemKeys = coreDataItems.compactMap { $0.value(forKey: "item_natural_key") as? String }
                    let sortedKeys = Array(Set(itemKeys)).sorted()

                    self.log.debug("Found \(sortedKeys.count) items with tag '\(cleanTag)'")
                    continuation.resume(returning: sortedKeys)

                } catch {
                    self.log.error("Failed to fetch items with tag: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchItems(withAllTags tags: [String]) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let cleanTags = tags.map { ItemTagModel.cleanTag($0) }
                    guard !cleanTags.isEmpty else {
                        continuation.resume(returning: [])
                        return
                    }

                    // Fetch all ItemTags for the requested tags
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                    fetchRequest.predicate = NSPredicate(format: "tag IN %@", cleanTags)

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)

                    // Group by item_natural_key and count
                    var itemTagCounts: [String: Int] = [:]
                    for item in coreDataItems {
                        if let itemKey = item.value(forKey: "item_natural_key") as? String {
                            itemTagCounts[itemKey, default: 0] += 1
                        }
                    }

                    // Filter items that have ALL the requested tags
                    let matchingItems = itemTagCounts
                        .filter { $0.value == cleanTags.count }
                        .map { $0.key }
                        .sorted()

                    self.log.debug("Found \(matchingItems.count) items with all \(cleanTags.count) tags")
                    continuation.resume(returning: matchingItems)

                } catch {
                    self.log.error("Failed to fetch items with all tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchItems(withAnyTags tags: [String]) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let cleanTags = tags.map { ItemTagModel.cleanTag($0) }
                    guard !cleanTags.isEmpty else {
                        continuation.resume(returning: [])
                        return
                    }

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                    fetchRequest.predicate = NSPredicate(format: "tag IN %@", cleanTags)

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    let itemKeys = coreDataItems.compactMap { $0.value(forKey: "item_natural_key") as? String }
                    let sortedKeys = Array(Set(itemKeys)).sorted()

                    self.log.debug("Found \(sortedKeys.count) items with any of \(cleanTags.count) tags")
                    continuation.resume(returning: sortedKeys)

                } catch {
                    self.log.error("Failed to fetch items with any tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Tag Analytics Operations

    func getTagUsageCounts() async throws -> [String: Int] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Int], Error>) in
            backgroundContext.perform {
                do {
                    let tagCounts = try self.calculateTagCountsSync()
                    self.log.debug("Calculated usage counts for \(tagCounts.count) tags")
                    continuation.resume(returning: tagCounts)

                } catch {
                    self.log.error("Failed to get tag usage counts: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getTagsWithCounts(minCount: Int) async throws -> [(tag: String, count: Int)] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(tag: String, count: Int)], Error>) in
            backgroundContext.perform {
                do {
                    let tagCounts = try self.calculateTagCountsSync()
                    let filteredAndSorted = tagCounts
                        .filter { $0.value >= minCount }
                        .sorted { $0.value > $1.value }
                        .map { (tag: $0.key, count: $0.value) }

                    self.log.debug("Found \(filteredAndSorted.count) tags with count >= \(minCount)")
                    continuation.resume(returning: filteredAndSorted)

                } catch {
                    self.log.error("Failed to get tags with counts: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func tagExists(_ tag: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            backgroundContext.perform {
                do {
                    let cleanTag = ItemTagModel.cleanTag(tag)

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
                    fetchRequest.predicate = NSPredicate(format: "tag == %@", cleanTag)
                    fetchRequest.fetchLimit = 1

                    let count = try self.backgroundContext.count(for: fetchRequest)
                    continuation.resume(returning: count > 0)

                } catch {
                    self.log.error("Failed to check if tag exists: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    private func fetchTagsSync(forItem itemNaturalKey: String) throws -> [String] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
        fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@", itemNaturalKey)

        let coreDataItems = try backgroundContext.fetch(fetchRequest)
        return coreDataItems.compactMap { $0.value(forKey: "tag") as? String }
    }

    private func tagExistsSync(_ tag: String, forItem itemNaturalKey: String) throws -> Bool {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
        fetchRequest.predicate = NSPredicate(
            format: "item_natural_key == %@ AND tag == %@",
            itemNaturalKey, tag
        )
        fetchRequest.fetchLimit = 1

        let count = try backgroundContext.count(for: fetchRequest)
        return count > 0
    }

    private func calculateTagCountsSync() throws -> [String: Int] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
        let coreDataItems = try backgroundContext.fetch(fetchRequest)

        var tagCounts: [String: Int] = [:]
        for item in coreDataItems {
            if let tag = item.value(forKey: "tag") as? String {
                tagCounts[tag, default: 0] += 1
            }
        }

        return tagCounts
    }
}

// MARK: - Core Data Repository Errors

enum CoreDataItemTagsRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case invalidTag(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .invalidTag(let tag):
            return "Invalid tag: \(tag)"
        }
    }
}
