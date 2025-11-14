//
//  MockItemTagsRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of ItemTagsRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of ItemTagsRepository for testing
/// Stores tags in memory using a dictionary
final class MockItemTagsRepository: ItemTagsRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var tags: [UUID: ItemTagModel] = [:] // Key: id

    // MARK: - Basic Tag Operations

    func fetchTags(forItem item_stable_id: String) async throws -> [String] {
        let tagsArray = Array(tags.values)
        return tagsArray
            .filter { (tag: ItemTagModel) in
                let tagItemId = tag.item_stable_id
                return tagItemId == item_stable_id
            }
            .map { (tag: ItemTagModel) in tag.tag }
            .sorted()
    }

    func fetchTagsForItems(_ item_stable_ids: [String]) async throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        for stableId in item_stable_ids {
            result[stableId] = try await fetchTags(forItem: stableId)
        }
        return result
    }

    func addTag(_ tag: String, toItem item_stable_id: String) async throws {
        let cleanedTag = ItemTagModel.cleanTag(tag)

        // Check if already exists
        let tagsArray = Array(tags.values)
        let exists = tagsArray.contains { (tagModel: ItemTagModel) in
            let modelItemId = tagModel.item_stable_id
            let modelTag = tagModel.tag
            return modelItemId == item_stable_id && modelTag == cleanedTag
        }

        if !exists {
            let model = ItemTagModel(
                id: UUID(),
                item_stable_id: item_stable_id,
                tag: cleanedTag
            )
            let id = model.id
            tags[id] = model
        }
    }

    func addTags(_ tags: [String], toItem item_stable_id: String) async throws {
        for tag in tags {
            try await addTag(tag, toItem: item_stable_id)
        }
    }

    func removeTag(_ tag: String, fromItem item_stable_id: String) async throws {
        let cleanedTag = ItemTagModel.cleanTag(tag)
        let tagsArray = Array(self.tags)

        for (id, tagModel) in tagsArray {
            let modelItemId = tagModel.item_stable_id
            let modelTag = tagModel.tag
            if modelItemId == item_stable_id && modelTag == cleanedTag {
                self.tags.removeValue(forKey: id)
            }
        }
    }

    func removeAllTags(fromItem item_stable_id: String) async throws {
        let tagsArray = Array(tags)
        for (id, tagModel) in tagsArray {
            let modelItemId = tagModel.item_stable_id
            if modelItemId == item_stable_id {
                tags.removeValue(forKey: id)
            }
        }
    }

    func setTags(_ tags: [String], forItem item_stable_id: String) async throws {
        try await removeAllTags(fromItem: item_stable_id)
        try await addTags(tags, toItem: item_stable_id)
    }

    // MARK: - Tag Discovery Operations

    func getAllTags() async throws -> [String] {
        let tagsArray = Array(tags.values)
        let allTags = Set(tagsArray.map { (tag: ItemTagModel) in tag.tag })
        return allTags.sorted()
    }

    func getTags(withPrefix prefix: String) async throws -> [String] {
        let allTags = try await getAllTags()
        return allTags.filter { $0.hasPrefix(prefix.lowercased()) }
    }

    func getMostUsedTags(limit: Int) async throws -> [String] {
        let counts = try await getTagUsageCounts()
        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    // MARK: - Item Discovery Operations

    func fetchItems(withTag tag: String) async throws -> [String] {
        let cleanedTag = ItemTagModel.cleanTag(tag)
        let tagsArray = Array(tags.values)
        let items = tagsArray
            .filter { (tagModel: ItemTagModel) in
                let modelTag = tagModel.tag
                return modelTag == cleanedTag
            }
            .map { (tagModel: ItemTagModel) in tagModel.item_stable_id }
        return Array(Set(items)).sorted()
    }

    func fetchItems(withAllTags tags: [String]) async throws -> [String] {
        let cleanedTags = Set(tags.map { ItemTagModel.cleanTag($0) })
        let itemTags = try await fetchTagsForItems(
            Array(Set(self.tags.values.map { (tag: ItemTagModel) in tag.item_stable_id }))
        )

        return itemTags
            .filter { cleanedTags.isSubset(of: Set($0.value)) }
            .map { $0.key }
            .sorted()
    }

    func fetchItems(withAnyTags tags: [String]) async throws -> [String] {
        let cleanedTags = Set(tags.map { ItemTagModel.cleanTag($0) })
        let tagsArray = Array(self.tags.values)
        let items = tagsArray
            .filter { (tagModel: ItemTagModel) in
                let modelTag = tagModel.tag
                return cleanedTags.contains(modelTag)
            }
            .map { (tagModel: ItemTagModel) in tagModel.item_stable_id }
        return Array(Set(items)).sorted()
    }

    // MARK: - Tag Analytics Operations

    func getTagUsageCounts() async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        let tagsArray = Array(tags.values)

        for tagModel in tagsArray {
            let tag = tagModel.tag
            counts[tag, default: 0] += 1
        }

        return counts
    }

    func getTagsWithCounts(minCount: Int) async throws -> [(tag: String, count: Int)] {
        let counts = try await getTagUsageCounts()
        return counts
            .filter { $0.value >= minCount }
            .map { (tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    func tagExists(_ tag: String) async throws -> Bool {
        let cleanedTag = ItemTagModel.cleanTag(tag)
        let tagsArray = Array(tags.values)
        return tagsArray.contains { (tagModel: ItemTagModel) in
            let modelTag = tagModel.tag
            return modelTag == cleanedTag
        }
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
}
