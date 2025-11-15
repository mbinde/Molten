//
//  CoreDataUserTagsRepository+Analytics.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//
//  Tag analytics and usage statistics operations
//

@preconcurrency import CoreData
import Foundation
import OSLog

extension CoreDataUserTagsRepository {

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
}
