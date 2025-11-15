//
//  CoreDataUserTagsRepository+Helpers.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//
//  Private helper methods for Core Data user tags operations
//

@preconcurrency import CoreData
import Foundation

extension CoreDataUserTagsRepository {

    // MARK: - Private Helper Methods

    func fetchTagsSync(ownerType: TagOwnerType, ownerId: String) throws -> [String] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
        fetchRequest.predicate = NSPredicate(
            format: "owner_type == %@ AND owner_id == %@",
            ownerType.rawValue, ownerId
        )

        let coreDataItems = try backgroundContext.fetch(fetchRequest)
        return coreDataItems.compactMap { $0.value(forKey: "tag") as? String }
    }

    func tagExistsSync(_ tag: String, ownerType: TagOwnerType, ownerId: String) throws -> Bool {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
        fetchRequest.predicate = NSPredicate(
            format: "owner_type == %@ AND owner_id == %@ AND tag == %@",
            ownerType.rawValue, ownerId, tag
        )
        fetchRequest.fetchLimit = 1

        let count = try backgroundContext.count(for: fetchRequest)
        return count > 0
    }

    func calculateTagCountsSync(ownerType: TagOwnerType? = nil) throws -> [String: Int] {
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
