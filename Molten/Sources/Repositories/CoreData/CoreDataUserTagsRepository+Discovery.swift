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
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
            fetchRequest.predicate = NSPredicate(format: "owner_type == %@", ownerType.rawValue)

            let coreDataItems = try context.fetch(fetchRequest)
            try self.migrateEntitiesIfNeeded(coreDataItems, context: context, log: self.log)

            let allTags = Set(coreDataItems.compactMap { $0.value(forKey: "tag") as? String })
            let sortedTags = Array(allTags).sorted()

            return sortedTags
        }
    }

    func getTags(withPrefix prefix: String, ownerType: TagOwnerType?) async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
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

            let coreDataItems = try context.fetch(fetchRequest)
            try self.migrateEntitiesIfNeeded(coreDataItems, context: context, log: self.log)

            let allTags = Set(coreDataItems.compactMap { $0.value(forKey: "tag") as? String })
            let sortedTags = Array(allTags).sorted()

            self.log.debug("Found \(sortedTags.count) user tags with prefix '\(prefix)'")
            return sortedTags
        }
    }

    func getMostUsedTags(limit: Int, ownerType: TagOwnerType?) async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let tagCounts = try self.calculateTagCountsSync(ownerType: ownerType)
            let sortedTags = tagCounts.sorted { $0.value > $1.value }
            let limitedTags = Array(sortedTags.prefix(limit)).map { $0.key }

            return limitedTags
        }
    }

    // MARK: - Owner Discovery Operations (New API)

    func fetchOwners(withTag tag: String, ownerType: TagOwnerType) async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let cleanTag = CoreDataUserTagsRepository.cleanTag(tag)

            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
            fetchRequest.predicate = NSPredicate(
                format: "owner_type == %@ AND tag == %@",
                ownerType.rawValue, cleanTag
            )

            let coreDataItems = try context.fetch(fetchRequest)
            try self.migrateEntitiesIfNeeded(coreDataItems, context: context, log: self.log)

            let ownerIds = coreDataItems.compactMap { $0.value(forKey: "owner_id") as? String }
            let sortedIds = Array(Set(ownerIds)).sorted()

            self.log.debug("Found \(sortedIds.count) \(ownerType.rawValue)s with user tag '\(cleanTag)'")
            return sortedIds
        }
    }

    func fetchOwners(withAllTags tags: [String], ownerType: TagOwnerType) async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let cleanTags = tags.map { CoreDataUserTagsRepository.cleanTag($0) }
            guard !cleanTags.isEmpty else {
                return []
            }

            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
            fetchRequest.predicate = NSPredicate(
                format: "owner_type == %@ AND tag IN %@",
                ownerType.rawValue, cleanTags
            )

            let coreDataItems = try context.fetch(fetchRequest)
            try self.migrateEntitiesIfNeeded(coreDataItems, context: context, log: self.log)

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
            return matchingOwners
        }
    }

    func fetchOwners(withAnyTags tags: [String], ownerType: TagOwnerType) async throws -> [String] {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let cleanTags = tags.map { CoreDataUserTagsRepository.cleanTag($0) }
            guard !cleanTags.isEmpty else {
                return []
            }

            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
            fetchRequest.predicate = NSPredicate(
                format: "owner_type == %@ AND tag IN %@",
                ownerType.rawValue, cleanTags
            )

            let coreDataItems = try context.fetch(fetchRequest)
            try self.migrateEntitiesIfNeeded(coreDataItems, context: context, log: self.log)

            let ownerIds = coreDataItems.compactMap { $0.value(forKey: "owner_id") as? String }
            let sortedIds = Array(Set(ownerIds)).sorted()

            self.log.debug("Found \(sortedIds.count) \(ownerType.rawValue)s with any of \(cleanTags.count) user tags")
            return sortedIds
        }
    }
}
