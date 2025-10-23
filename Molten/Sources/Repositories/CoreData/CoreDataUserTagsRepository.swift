//
//  CoreDataUserTagsRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of UserTagsRepository
/// Provides persistent storage for user-created tags using Core Data
class CoreDataUserTagsRepository: UserTagsRepository {

    // MARK: - Dependencies

    private let persistentContainer: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.flameworker.app", category: "usertags-repository")

    // MARK: - Initialization

    /// Initialize CoreDataUserTagsRepository with a Core Data persistent container
    /// - Parameter persistentContainer: The NSPersistentContainer to use for user tags operations
    /// - Note: In production, pass PersistenceController.shared.container
    nonisolated init(userTagsPersistentContainer persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.backgroundContext = persistentContainer.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        // Kick off background migration of old records
        Task.detached { [weak backgroundContext] in
            guard let context = backgroundContext else { return }
            try? await Self.migrateAllRecordsIfNeeded(context: context)
        }
    }

    // MARK: - Legacy Tag Operations (Glass Items Only - Delegates to New Generic API)

    func fetchTags(forItem itemNaturalKey: String) async throws -> [String] {
        // Delegate to new generic API
        return try await fetchTags(ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    func fetchTagsForItems(_ itemNaturalKeys: [String]) async throws -> [String: [String]] {
        // Delegate to new generic API
        return try await fetchTagsForOwners(ownerType: .glassItem, ownerIds: itemNaturalKeys)
    }

    func addTag(_ tag: String, toItem itemNaturalKey: String) async throws {
        // Delegate to new generic API
        try await addTag(tag, ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    func addTags(_ tags: [String], toItem itemNaturalKey: String) async throws {
        // Delegate to new generic API
        try await addTags(tags, ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    func removeTag(_ tag: String, fromItem itemNaturalKey: String) async throws {
        // Delegate to new generic API
        try await removeTag(tag, ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    func removeAllTags(fromItem itemNaturalKey: String) async throws {
        // Delegate to new generic API
        try await removeAllTags(ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    func setTags(_ tags: [String], forItem itemNaturalKey: String) async throws {
        // Delegate to new generic API
        try await setTags(tags, ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    // MARK: - Legacy Tag Discovery Operations (Delegates to New API)

    func getAllTags() async throws -> [String] {
        // Delegate to new generic API (all owner types)
        return try await getTags(withPrefix: "", ownerType: nil)
    }

    func getTags(withPrefix prefix: String) async throws -> [String] {
        // Delegate to new generic API (all owner types)
        return try await getTags(withPrefix: prefix, ownerType: nil)
    }

    func getMostUsedTags(limit: Int) async throws -> [String] {
        // Delegate to new generic API (all owner types)
        return try await getMostUsedTags(limit: limit, ownerType: nil)
    }

    // MARK: - Legacy Item Discovery Operations (Glass Items Only - Delegates to New API)

    func fetchItems(withTag tag: String) async throws -> [String] {
        // Delegate to new generic API
        return try await fetchOwners(withTag: tag, ownerType: .glassItem)
    }

    func fetchItems(withAllTags tags: [String]) async throws -> [String] {
        // Delegate to new generic API
        return try await fetchOwners(withAllTags: tags, ownerType: .glassItem)
    }

    func fetchItems(withAnyTags tags: [String]) async throws -> [String] {
        // Delegate to new generic API
        return try await fetchOwners(withAnyTags: tags, ownerType: .glassItem)
    }

    // MARK: - Legacy Tag Analytics Operations (Delegates to New API)

    func getTagUsageCounts() async throws -> [String: Int] {
        // Delegate to new generic API (all owner types)
        return try await getTagUsageCounts(ownerType: nil)
    }

    func getTagsWithCounts(minCount: Int) async throws -> [(tag: String, count: Int)] {
        // Delegate to new generic API (all owner types)
        return try await getTagsWithCounts(minCount: minCount, ownerType: nil)
    }

    func tagExists(_ tag: String) async throws -> Bool {
        // Delegate to new generic API (all owner types)
        return try await tagExists(tag, ownerType: nil)
    }

    // MARK: - Migration Support (Old Schema → New Schema)

    /// Check if a UserTags entity needs migration
    private nonisolated static func needsMigration(_ entity: NSManagedObject) -> Bool {
        return entity.value(forKey: "owner_type") == nil
    }

    /// Migrate a single UserTags entity from old to new schema
    /// Old schema: item_natural_key only
    /// New schema: owner_type + owner_id
    private nonisolated static func migrateEntity(_ entity: NSManagedObject, context: NSManagedObjectContext, log: Logger) throws {
        guard needsMigration(entity) else { return }

        // Old records only have item_natural_key, so they're all glass items
        if let itemKey = entity.value(forKey: "item_natural_key") as? String {
            entity.setValue("glassItem", forKey: "owner_type")
            entity.setValue(itemKey, forKey: "owner_id")
            log.debug("Migrated UserTag: \(itemKey)")
        } else {
            // Invalid record (no item_natural_key), delete it
            context.delete(entity)
            log.warning("Deleted invalid UserTag record (no item_natural_key)")
        }
    }

    /// Migrate all unmigrated UserTags records (runs in background on init)
    private static func migrateAllRecordsIfNeeded(context: NSManagedObjectContext) async throws {
        let log = Logger(subsystem: "com.flameworker.app", category: "usertags-migration")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                    fetchRequest.predicate = NSPredicate(format: "owner_type == nil")

                    let unmigrated = try context.fetch(fetchRequest)

                    guard !unmigrated.isEmpty else {
                        log.info("No UserTags records need migration")
                        continuation.resume()
                        return
                    }

                    log.info("Migrating \(unmigrated.count) UserTags records...")

                    for entity in unmigrated {
                        try self.migrateEntity(entity, context: context, log: log)
                    }

                    try context.save()
                    log.info("UserTags migration complete: \(unmigrated.count) records migrated")

                    continuation.resume()
                } catch {
                    log.error("UserTags migration failed: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Migrate entities on-demand when accessed (lazy migration fallback)
    private nonisolated func migrateEntitiesIfNeeded(_ entities: [NSManagedObject], context: NSManagedObjectContext, log: Logger) throws {
        var needsSave = false

        for entity in entities {
            if Self.needsMigration(entity) {
                try Self.migrateEntity(entity, context: context, log: log)
                needsSave = true
            }
        }

        if needsSave {
            try context.save()
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
                    // Set item_natural_key for backward compatibility (if owner is glass item)
                    if ownerType == .glassItem {
                        coreDataItem.setValue(ownerId, forKey: "item_natural_key")
                    }

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
                        // Set item_natural_key for backward compatibility (if owner is glass item)
                        if ownerType == .glassItem {
                            coreDataItem.setValue(ownerId, forKey: "item_natural_key")
                        }
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
                            // Set item_natural_key for backward compatibility (if owner is glass item)
                            if ownerType == .glassItem {
                                coreDataItem.setValue(ownerId, forKey: "item_natural_key")
                            }
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

    // MARK: - Tag Discovery Operations (New API - With Owner Type Filtering)

    func getAllTags(forOwnerType ownerType: TagOwnerType) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                    fetchRequest.predicate = NSPredicate(format: "owner_type == %@", ownerType.rawValue)

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    try self.migrateEntitiesIfNeeded(coreDataItems, context: self.backgroundContext, log: self.log)

                    let allTags = Set(coreDataItems.compactMap { $0.value(forKey: "tag") as? String })
                    let sortedTags = Array(allTags).sorted()

                    continuation.resume(returning: sortedTags)

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getTags(withPrefix prefix: String, ownerType: TagOwnerType?) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")

                    var predicates: [NSPredicate] = []

                    // Add owner type filter if specified
                    if let ownerType = ownerType {
                        predicates.append(NSPredicate(format: "owner_type == %@", ownerType.rawValue))
                    }

                    // Add prefix filter if not empty
                    if !prefix.isEmpty {
                        let lowercasePrefix = prefix.lowercased()
                        predicates.append(NSPredicate(format: "tag BEGINSWITH[c] %@", lowercasePrefix))
                    }

                    if !predicates.isEmpty {
                        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                    }

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    try self.migrateEntitiesIfNeeded(coreDataItems, context: self.backgroundContext, log: self.log)

                    let allTags = Set(coreDataItems.compactMap { $0.value(forKey: "tag") as? String })
                    let sortedTags = Array(allTags).sorted()

                    self.log.debug("Found \(sortedTags.count) user tags with prefix '\(prefix)'")
                    continuation.resume(returning: sortedTags)

                } catch {
                    self.log.error("Failed to fetch user tags with prefix: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getMostUsedTags(limit: Int, ownerType: TagOwnerType?) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let tagCounts = try self.calculateTagCountsSync(ownerType: ownerType)
                    let sortedTags = tagCounts.sorted { $0.value > $1.value }
                    let limitedTags = Array(sortedTags.prefix(limit)).map { $0.key }

                    continuation.resume(returning: limitedTags)

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Owner Discovery Operations (New API)

    func fetchOwners(withTag tag: String, ownerType: TagOwnerType) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let cleanTag = UserTagModel.cleanTag(tag)

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                    fetchRequest.predicate = NSPredicate(
                        format: "owner_type == %@ AND tag == %@",
                        ownerType.rawValue, cleanTag
                    )

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    try self.migrateEntitiesIfNeeded(coreDataItems, context: self.backgroundContext, log: self.log)

                    let ownerIds = coreDataItems.compactMap { $0.value(forKey: "owner_id") as? String }
                    let sortedIds = Array(Set(ownerIds)).sorted()

                    self.log.debug("Found \(sortedIds.count) \(ownerType.rawValue)s with user tag '\(cleanTag)'")
                    continuation.resume(returning: sortedIds)

                } catch {
                    self.log.error("Failed to fetch owners with user tag: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchOwners(withAllTags tags: [String], ownerType: TagOwnerType) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let cleanTags = tags.map { UserTagModel.cleanTag($0) }
                    guard !cleanTags.isEmpty else {
                        continuation.resume(returning: [])
                        return
                    }

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                    fetchRequest.predicate = NSPredicate(
                        format: "owner_type == %@ AND tag IN %@",
                        ownerType.rawValue, cleanTags
                    )

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    try self.migrateEntitiesIfNeeded(coreDataItems, context: self.backgroundContext, log: self.log)

                    // Group by owner_id and count
                    var ownerTagCounts: [String: Int] = [:]
                    for item in coreDataItems {
                        if let ownerId = item.value(forKey: "owner_id") as? String {
                            ownerTagCounts[ownerId, default: 0] += 1
                        }
                    }

                    // Filter owners that have ALL the requested tags
                    let matchingOwners = ownerTagCounts
                        .filter { $0.value == cleanTags.count }
                        .map { $0.key }
                        .sorted()

                    self.log.debug("Found \(matchingOwners.count) \(ownerType.rawValue)s with all \(cleanTags.count) user tags")
                    continuation.resume(returning: matchingOwners)

                } catch {
                    self.log.error("Failed to fetch owners with all user tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchOwners(withAnyTags tags: [String], ownerType: TagOwnerType) async throws -> [String] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            backgroundContext.perform {
                do {
                    let cleanTags = tags.map { UserTagModel.cleanTag($0) }
                    guard !cleanTags.isEmpty else {
                        continuation.resume(returning: [])
                        return
                    }

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                    fetchRequest.predicate = NSPredicate(
                        format: "owner_type == %@ AND tag IN %@",
                        ownerType.rawValue, cleanTags
                    )

                    let coreDataItems = try self.backgroundContext.fetch(fetchRequest)
                    try self.migrateEntitiesIfNeeded(coreDataItems, context: self.backgroundContext, log: self.log)

                    let ownerIds = coreDataItems.compactMap { $0.value(forKey: "owner_id") as? String }
                    let sortedIds = Array(Set(ownerIds)).sorted()

                    self.log.debug("Found \(sortedIds.count) \(ownerType.rawValue)s with any of \(cleanTags.count) user tags")
                    continuation.resume(returning: sortedIds)

                } catch {
                    self.log.error("Failed to fetch owners with any user tags: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Tag Analytics Operations (New API - With Owner Type Filtering)

    func getTagUsageCounts(ownerType: TagOwnerType?) async throws -> [String: Int] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Int], Error>) in
            backgroundContext.perform {
                do {
                    let tagCounts = try self.calculateTagCountsSync(ownerType: ownerType)
                    self.log.debug("Calculated usage counts for \(tagCounts.count) user tags")
                    continuation.resume(returning: tagCounts)

                } catch {
                    self.log.error("Failed to get user tag usage counts: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getTagsWithCounts(minCount: Int, ownerType: TagOwnerType?) async throws -> [(tag: String, count: Int)] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(tag: String, count: Int)], Error>) in
            backgroundContext.perform {
                do {
                    let tagCounts = try self.calculateTagCountsSync(ownerType: ownerType)
                    let filteredAndSorted = tagCounts
                        .filter { $0.value >= minCount }
                        .sorted { $0.value > $1.value }
                        .map { (tag: $0.key, count: $0.value) }

                    self.log.debug("Found \(filteredAndSorted.count) user tags with count >= \(minCount)")
                    continuation.resume(returning: filteredAndSorted)

                } catch {
                    self.log.error("Failed to get user tags with counts: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func tagExists(_ tag: String, ownerType: TagOwnerType?) async throws -> Bool {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            backgroundContext.perform {
                do {
                    let cleanTag = UserTagModel.cleanTag(tag)

                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")

                    if let ownerType = ownerType {
                        fetchRequest.predicate = NSPredicate(
                            format: "owner_type == %@ AND tag == %@",
                            ownerType.rawValue, cleanTag
                        )
                    } else {
                        fetchRequest.predicate = NSPredicate(format: "tag == %@", cleanTag)
                    }

                    fetchRequest.fetchLimit = 1

                    let count = try self.backgroundContext.count(for: fetchRequest)
                    continuation.resume(returning: count > 0)

                } catch {
                    self.log.error("Failed to check if user tag exists: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helper Methods (Updated for New Schema)

    private func fetchTagsSync(ownerType: TagOwnerType, ownerId: String) throws -> [String] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
        fetchRequest.predicate = NSPredicate(
            format: "owner_type == %@ AND owner_id == %@",
            ownerType.rawValue, ownerId
        )

        let coreDataItems = try backgroundContext.fetch(fetchRequest)
        return coreDataItems.compactMap { $0.value(forKey: "tag") as? String }
    }

    private func tagExistsSync(_ tag: String, ownerType: TagOwnerType, ownerId: String) throws -> Bool {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
        fetchRequest.predicate = NSPredicate(
            format: "owner_type == %@ AND owner_id == %@ AND tag == %@",
            ownerType.rawValue, ownerId, tag
        )
        fetchRequest.fetchLimit = 1

        let count = try backgroundContext.count(for: fetchRequest)
        return count > 0
    }

    private func calculateTagCountsSync(ownerType: TagOwnerType? = nil) throws -> [String: Int] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")

        if let ownerType = ownerType {
            fetchRequest.predicate = NSPredicate(format: "owner_type == %@", ownerType.rawValue)
        }

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

enum CoreDataUserTagsRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case invalidTag(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .invalidTag(let tag):
            return "Invalid user tag: \(tag)"
        }
    }
}
