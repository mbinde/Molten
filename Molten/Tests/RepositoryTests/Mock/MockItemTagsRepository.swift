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
@MainActor
final class MockItemTagsRepository: ItemTagsRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var tags: [UUID: ItemTagModel] = [:] // Key: id

    // MARK: - Basic Tag Operations

    func fetchTags(forItem item_stable_id: String) async throws -> [String] {
        let tagsArray = Array(tags.values)
        var result: [String] = []
        for tag in tagsArray {
            let tagItemId = await tag.item_stable_id
            if tagItemId == item_stable_id {
                let tagString = await tag.tag
                result.append(tagString)
            }
        }
        return result.sorted()
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
        var exists = false
        for tagModel in tagsArray {
            let modelItemId = await tagModel.item_stable_id
            let modelTag = await tagModel.tag
            if modelItemId == item_stable_id && modelTag == cleanedTag {
                exists = true
                break
            }
        }

        if !exists {
            let model = await ItemTagModel(
                id: UUID(),
                item_stable_id: item_stable_id,
                tag: cleanedTag
            )
            let id = await model.id
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
            let modelItemId = await tagModel.item_stable_id
            let modelTag = await tagModel.tag
            if modelItemId == item_stable_id && modelTag == cleanedTag {
                self.tags.removeValue(forKey: id)
            }
        }
    }

    func removeAllTags(fromItem item_stable_id: String) async throws {
        let tagsArray = Array(tags)
        for (id, tagModel) in tagsArray {
            let modelItemId = await tagModel.item_stable_id
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
        var allTags: Set<String> = []
        for tag in tagsArray {
            let tagString = await tag.tag
            allTags.insert(tagString)
        }
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
        var itemsSet: Set<String> = []
        for tagModel in tagsArray {
            let modelTag = await tagModel.tag
            if modelTag == cleanedTag {
                let itemId = await tagModel.item_stable_id
                itemsSet.insert(itemId)
            }
        }
        return Array(itemsSet).sorted()
    }

    func fetchItems(withAllTags tags: [String]) async throws -> [String] {
        let cleanedTags = Set(tags.map { ItemTagModel.cleanTag($0) })
        let tagsArray = Array(self.tags.values)
        var itemIdsSet: Set<String> = []
        for tag in tagsArray {
            let itemId = await tag.item_stable_id
            itemIdsSet.insert(itemId)
        }
        let itemTags = try await fetchTagsForItems(Array(itemIdsSet))

        var result: [String] = []
        for (key, value) in itemTags {
            let valueTags = value
            if cleanedTags.isSubset(of: Set(valueTags)) {
                result.append(key)
            }
        }
        return result.sorted()
    }

    func fetchItems(withAnyTags tags: [String]) async throws -> [String] {
        let cleanedTags = Set(tags.map { ItemTagModel.cleanTag($0) })
        let tagsArray = Array(self.tags.values)
        var itemsSet: Set<String> = []
        for tagModel in tagsArray {
            let modelTag = await tagModel.tag
            if cleanedTags.contains(modelTag) {
                let itemId = await tagModel.item_stable_id
                itemsSet.insert(itemId)
            }
        }
        return Array(itemsSet).sorted()
    }

    // MARK: - Tag Analytics Operations

    func getTagUsageCounts() async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        let tagsArray = Array(tags.values)

        for tagModel in tagsArray {
            let tag = await tagModel.tag
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
        for tagModel in tagsArray {
            let modelTag = await tagModel.tag
            if modelTag == cleanedTag {
                return true
            }
        }
        return false
    }

    // MARK: - Test Helpers

    /// Get count of stored tags (test helper)
    func getTagCount() async -> Int {
        return tags.count
    }

    /// Get count of all tags (test helper, alias for getTagCount)
    func getAllTagsCount() async -> Int {
        return tags.count
    }

    /// Clear all tags (test helper)
    func clearAll() async {
        tags.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency with other mocks)
    nonisolated func clearAllData() {
        tags.removeAll()
    }
}
