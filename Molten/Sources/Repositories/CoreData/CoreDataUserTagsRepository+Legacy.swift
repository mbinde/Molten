//
//  CoreDataUserTagsRepository+Legacy.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//
//  Legacy API (Glass Items Only) - Delegates to New Generic API
//  Maintained for backward compatibility with existing code
//

import Foundation

extension CoreDataUserTagsRepository {

    // MARK: - Legacy Tag Operations (Glass Items Only - Delegates to New Generic API)

    func fetchTags(forItem item_stable_id: String) async throws -> [String] {
        // Delegate to new generic API
        return try await fetchTags(ownerType: .glassItem, ownerId: item_stable_id)
    }

    func fetchTagsForItems(_ item_stable_ids: [String]) async throws -> [String: [String]] {
        // Delegate to new generic API
        return try await fetchTagsForOwners(ownerType: .glassItem, ownerIds: item_stable_ids)
    }

    func addTag(_ tag: String, toItem item_stable_id: String) async throws {
        // Delegate to new generic API
        try await addTag(tag, ownerType: .glassItem, ownerId: item_stable_id)
    }

    func addTags(_ tags: [String], toItem item_stable_id: String) async throws {
        // Delegate to new generic API
        try await addTags(tags, ownerType: .glassItem, ownerId: item_stable_id)
    }

    func removeTag(_ tag: String, fromItem item_stable_id: String) async throws {
        // Delegate to new generic API
        try await removeTag(tag, ownerType: .glassItem, ownerId: item_stable_id)
    }

    func removeAllTags(fromItem item_stable_id: String) async throws {
        // Delegate to new generic API
        try await removeAllTags(ownerType: .glassItem, ownerId: item_stable_id)
    }

    func setTags(_ tags: [String], forItem item_stable_id: String) async throws {
        // Delegate to new generic API
        try await setTags(tags, ownerType: .glassItem, ownerId: item_stable_id)
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
}
