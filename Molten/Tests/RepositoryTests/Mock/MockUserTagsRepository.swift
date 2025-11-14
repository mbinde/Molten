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
        return tags.values
            .filter { $0.ownerType == ownerType && $0.ownerId == ownerId }
            .map { $0.tag }
            .sorted()
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
        let model = UserTagModel(ownerType: ownerType, ownerId: ownerId, tag: cleanedTag)
        tags[model.id] = model
    }

    func addTags(_ tags: [String], ownerType: TagOwnerType, ownerId: String) async throws {
        for tag in tags {
            try await addTag(tag, ownerType: ownerType, ownerId: ownerId)
        }
    }

    func removeTag(_ tag: String, ownerType: TagOwnerType, ownerId: String) async throws {
        let cleanedTag = UserTagModel.cleanTag(tag)
        tags = tags.filter {
            !($0.value.ownerType == ownerType && $0.value.ownerId == ownerId && $0.value.tag == cleanedTag)
        }
    }

    func removeAllTags(ownerType: TagOwnerType, ownerId: String) async throws {
        tags = tags.filter { !($0.value.ownerType == ownerType && $0.value.ownerId == ownerId) }
    }

    func setTags(_ tags: [String], ownerType: TagOwnerType, ownerId: String) async throws {
        try await removeAllTags(ownerType: ownerType, ownerId: ownerId)
        try await addTags(tags, ownerType: ownerType, ownerId: ownerId)
    }

    // MARK: - Tag Discovery Operations

    func getAllTags() async throws -> [String] {
        let allTags = Set(tags.values.map { $0.tag })
        return allTags.sorted()
    }

    func getAllTags(forOwnerType ownerType: TagOwnerType) async throws -> [String] {
        let typeTags = Set(tags.values.filter { $0.ownerType == ownerType }.map { $0.tag })
        return typeTags.sorted()
    }

    func getTags(withPrefix prefix: String, ownerType: TagOwnerType?) async throws -> [String] {
        let allTags = tags.values
            .filter { ownerType == nil || $0.ownerType == ownerType }
            .map { $0.tag }
            .filter { $0.hasPrefix(prefix.lowercased()) }
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
        let owners = tags.values
            .filter { $0.ownerType == ownerType && $0.tag == cleanedTag }
            .map { $0.ownerId }
        return Array(Set(owners)).sorted()
    }

    func fetchOwners(withAllTags tags: [String], ownerType: TagOwnerType) async throws -> [String] {
        let cleanedTags = Set(tags.map { UserTagModel.cleanTag($0) })
        let ownerTags = try await fetchTagsForOwners(
            ownerType: ownerType,
            ownerIds: Array(Set(self.tags.values.filter { $0.ownerType == ownerType }.map { $0.ownerId }))
        )

        return ownerTags
            .filter { cleanedTags.isSubset(of: Set($0.value)) }
            .map { $0.key }
            .sorted()
    }

    func fetchOwners(withAnyTags tags: [String], ownerType: TagOwnerType) async throws -> [String] {
        let cleanedTags = Set(tags.map { UserTagModel.cleanTag($0) })
        let owners = self.tags.values
            .filter { $0.ownerType == ownerType && cleanedTags.contains($0.tag) }
            .map { $0.ownerId }
        return Array(Set(owners)).sorted()
    }

    // MARK: - Tag Analytics Operations

    func getTagUsageCounts(ownerType: TagOwnerType?) async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        let filteredTags = tags.values.filter { ownerType == nil || $0.ownerType == ownerType }

        for tagModel in filteredTags {
            counts[tagModel.tag, default: 0] += 1
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
        return tags.values.contains {
            $0.tag == cleanedTag && (ownerType == nil || $0.ownerType == ownerType)
        }
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
