//
//  MockUserTagsRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of UserTagsRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of UserTagsRepository for testing
/// Stores user tags in memory using a dictionary
final class MockUserTagsRepository: UserTagsRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var tags: [UUID: UserTagModel] = [:]

    // MARK: - Helper Methods

    private func makeKey(ownerType: TagOwnerType, ownerId: String, tag: String) -> String {
        return "\(ownerType.rawValue)-\(ownerId)-\(tag)"
    }

    // MARK: - Generic Tag Operations

    func fetchTags(ownerType: TagOwnerType, ownerId: String) async throws -> [String] {
        var result: [String] = []
        for tag in tags.values {
            let tagOwnerType = await tag.ownerType
            let tagOwnerId = await tag.ownerId
            if tagOwnerType == ownerType && tagOwnerId == ownerId {
                let tagString = await tag.tag
                result.append(tagString)
            }
        }
        return result.sorted()
    }

    func fetchTagsForOwners(ownerType: TagOwnerType, ownerIds: [String]) async throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        for ownerId in ownerIds {
            result[ownerId] = try await fetchTags(ownerType: ownerType, ownerId: ownerId)
        }
        return result
    }

    func addTag(_ tag: String, ownerType: TagOwnerType, ownerId: String) async throws {
        let cleanedTag = UserTagModel.cleanTag(tag)
        let model = await UserTagModel(ownerType: ownerType, ownerId: ownerId, tag: cleanedTag)
        let modelId = await model.id
        tags[modelId] = model
    }

    func addTags(_ tags: [String], ownerType: TagOwnerType, ownerId: String) async throws {
        for tag in tags {
            try await addTag(tag, ownerType: ownerType, ownerId: ownerId)
        }
    }

    func removeTag(_ tag: String, ownerType: TagOwnerType, ownerId: String) async throws {
        let cleanedTag = UserTagModel.cleanTag(tag)
        var newTags: [UUID: UserTagModel] = [:]
        for (key, value) in tags {
            let valueOwnerType = await value.ownerType
            let valueOwnerId = await value.ownerId
            let valueTag = await value.tag
            if !(valueOwnerType == ownerType && valueOwnerId == ownerId && valueTag == cleanedTag) {
                newTags[key] = value
            }
        }
        tags = newTags
    }

    func removeAllTags(ownerType: TagOwnerType, ownerId: String) async throws {
        var newTags: [UUID: UserTagModel] = [:]
        for (key, value) in tags {
            let valueOwnerType = await value.ownerType
            let valueOwnerId = await value.ownerId
            if !(valueOwnerType == ownerType && valueOwnerId == ownerId) {
                newTags[key] = value
            }
        }
        tags = newTags
    }

    func setTags(_ tags: [String], ownerType: TagOwnerType, ownerId: String) async throws {
        try await removeAllTags(ownerType: ownerType, ownerId: ownerId)
        try await addTags(tags, ownerType: ownerType, ownerId: ownerId)
    }

    // MARK: - Tag Discovery Operations

    func getAllTags() async throws -> [String] {
        var allTags: Set<String> = []
        for tag in tags.values {
            let tagString = await tag.tag
            allTags.insert(tagString)
        }
        return allTags.sorted()
    }

    func getAllTags(forOwnerType ownerType: TagOwnerType) async throws -> [String] {
        var typeTags: Set<String> = []
        for tag in tags.values {
            let tagOwnerType = await tag.ownerType
            if tagOwnerType == ownerType {
                let tagString = await tag.tag
                typeTags.insert(tagString)
            }
        }
        return typeTags.sorted()
    }

    func getTags(withPrefix prefix: String, ownerType: TagOwnerType?) async throws -> [String] {
        var allTags: [String] = []
        let lowercasedPrefix = prefix.lowercased()
        for tag in tags.values {
            let tagOwnerType = await tag.ownerType
            if ownerType == nil || tagOwnerType == ownerType {
                let tagString = await tag.tag
                if tagString.hasPrefix(lowercasedPrefix) {
                    allTags.append(tagString)
                }
            }
        }
        return Array(Set(allTags)).sorted()
    }

    func getMostUsedTags(limit: Int, ownerType: TagOwnerType?) async throws -> [String] {
        let counts = try await getTagUsageCounts(ownerType: ownerType)
        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    // MARK: - Owner Discovery Operations

    func fetchOwners(withTag tag: String, ownerType: TagOwnerType) async throws -> [String] {
        let cleanedTag = UserTagModel.cleanTag(tag)
        var owners: [String] = []
        for tagModel in tags.values {
            let tagModelOwnerType = await tagModel.ownerType
            let tagModelTag = await tagModel.tag
            if tagModelOwnerType == ownerType && tagModelTag == cleanedTag {
                let tagModelOwnerId = await tagModel.ownerId
                owners.append(tagModelOwnerId)
            }
        }
        return Array(Set(owners)).sorted()
    }

    func fetchOwners(withAllTags tags: [String], ownerType: TagOwnerType) async throws -> [String] {
        let cleanedTags = Set(tags.map { UserTagModel.cleanTag($0) })

        // Collect all owner IDs for the given owner type
        var ownerIds: Set<String> = []
        for tag in self.tags.values {
            let tagOwnerType = await tag.ownerType
            if tagOwnerType == ownerType {
                let tagOwnerId = await tag.ownerId
                ownerIds.insert(tagOwnerId)
            }
        }

        let ownerTags = try await fetchTagsForOwners(
            ownerType: ownerType,
            ownerIds: Array(ownerIds)
        )

        // Filter owners that have all tags
        var result: [String] = []
        for (ownerId, ownerTagList) in ownerTags {
            if cleanedTags.isSubset(of: Set(ownerTagList)) {
                result.append(ownerId)
            }
        }
        return result.sorted()
    }

    func fetchOwners(withAnyTags tags: [String], ownerType: TagOwnerType) async throws -> [String] {
        let cleanedTags = Set(tags.map { UserTagModel.cleanTag($0) })
        var owners: [String] = []
        for tag in self.tags.values {
            let tagOwnerType = await tag.ownerType
            let tagString = await tag.tag
            if tagOwnerType == ownerType && cleanedTags.contains(tagString) {
                let ownerId = await tag.ownerId
                owners.append(ownerId)
            }
        }
        return Array(Set(owners)).sorted()
    }

    // MARK: - Tag Analytics Operations

    func getTagUsageCounts(ownerType: TagOwnerType?) async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for tag in tags.values {
            let tagOwnerType = await tag.ownerType
            if ownerType == nil || tagOwnerType == ownerType {
                let tagString = await tag.tag
                counts[tagString, default: 0] += 1
            }
        }
        return counts
    }

    func getTagsWithCounts(minCount: Int, ownerType: TagOwnerType?) async throws -> [(tag: String, count: Int)] {
        let counts = try await getTagUsageCounts(ownerType: ownerType)
        return counts
            .filter { $0.value >= minCount }
            .map { (tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    func tagExists(_ tag: String, ownerType: TagOwnerType?) async throws -> Bool {
        let cleanedTag = UserTagModel.cleanTag(tag)
        for tagModel in tags.values {
            let modelTag = await tagModel.tag
            let modelOwnerType = await tagModel.ownerType
            if modelTag == cleanedTag && (ownerType == nil || modelOwnerType == ownerType) {
                return true
            }
        }
        return false
    }

    // MARK: - Legacy Support (for backward compatibility with glass items)

    func fetchTags(forItem item_stable_id: String) async throws -> [String] {
        return try await fetchTags(ownerType: .glassItem, ownerId: item_stable_id)
    }

    func fetchTagsForItems(_ item_stable_ids: [String]) async throws -> [String: [String]] {
        return try await fetchTagsForOwners(ownerType: .glassItem, ownerIds: item_stable_ids)
    }

    func addTag(_ tag: String, toItem item_stable_id: String) async throws {
        try await addTag(tag, ownerType: .glassItem, ownerId: item_stable_id)
    }

    func addTags(_ tags: [String], toItem item_stable_id: String) async throws {
        try await addTags(tags, ownerType: .glassItem, ownerId: item_stable_id)
    }

    func removeTag(_ tag: String, fromItem item_stable_id: String) async throws {
        try await removeTag(tag, ownerType: .glassItem, ownerId: item_stable_id)
    }

    func removeAllTags(fromItem item_stable_id: String) async throws {
        try await removeAllTags(ownerType: .glassItem, ownerId: item_stable_id)
    }

    func setTags(_ tags: [String], forItem item_stable_id: String) async throws {
        try await setTags(tags, ownerType: .glassItem, ownerId: item_stable_id)
    }

    func fetchItems(withTag tag: String) async throws -> [String] {
        return try await fetchOwners(withTag: tag, ownerType: .glassItem)
    }

    func fetchItems(withAllTags tags: [String]) async throws -> [String] {
        return try await fetchOwners(withAllTags: tags, ownerType: .glassItem)
    }

    func fetchItems(withAnyTags tags: [String]) async throws -> [String] {
        return try await fetchOwners(withAnyTags: tags, ownerType: .glassItem)
    }

    // MARK: - Test Helpers

    /// Get count of stored tags (test helper)
    func getTagCount() async -> Int {
        return tags.count
    }

    /// Clear all tags (test helper)
    func clearAll() async {
        tags.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency with other mocks)
    func clearAllData() {
        tags.removeAll()
    }
}
