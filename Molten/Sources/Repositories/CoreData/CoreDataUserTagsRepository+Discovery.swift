//
//  CoreDataUserTagsRepository+Discovery.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//
//  Tag discovery and owner discovery operations
//

@preconcurrency import CoreData
import Foundation
import OSLog

extension CoreDataUserTagsRepository {

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
                    let cleanTag = CoreDataUserTagsRepository.cleanTag(tag)

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
                    let cleanTags = tags.map { CoreDataUserTagsRepository.cleanTag($0) }
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
                    let cleanTags = tags.map { CoreDataUserTagsRepository.cleanTag($0) }
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
}
