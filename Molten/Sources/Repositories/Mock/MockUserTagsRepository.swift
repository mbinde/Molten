//
//  MockUserTagsRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Foundation

/// Mock implementation of UserTagsRepository for testing
/// Provides in-memory storage for user-created tags with realistic behavior
class MockUserTagsRepository: @unchecked Sendable, UserTagsRepository {

    // MARK: - Test Data Storage

    // Storage key for owner type + owner ID
    private struct OwnerKey: Hashable {
        let ownerType: TagOwnerType
        let ownerId: String
    }

    nonisolated(unsafe) private var userTags: [OwnerKey: Set<String>] = [:] // (ownerType, ownerId) -> Set of tags
    private let queue = DispatchQueue(label: "mock.usertags.repository", attributes: .concurrent)

    nonisolated init() {}

    // MARK: - Test Configuration

    /// Controls whether operations should simulate network delays
    var simulateLatency: Bool = false

    /// Controls whether operations should randomly fail for error testing
    var shouldRandomlyFail: Bool = false

    /// Controls the probability of random failures (0.0 to 1.0)
    var failureProbability: Double = 0.1

    // MARK: - Test State Management

    /// Clear all stored data (useful for test setup)
    nonisolated func clearAllData() {
        queue.async(flags: .barrier) {
            self.userTags.removeAll()
        }
    }

    /// Get count of stored tag relationships (for testing)
    nonisolated func getTagRelationshipCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                let count = self.userTags.values.reduce(0) { $0 + $1.count }
                continuation.resume(returning: count)
            }
        }
    }

    /// Get count of all tags (for testing) - alias for compatibility
    nonisolated func getAllTagsCount() async -> Int {
        return await getTagRelationshipCount()
    }

    /// Pre-populate with test data
    func populateWithTestData() async throws {
        try await addTags(["favorite", "wishlist"], ownerType: .glassItem, ownerId: "cim-874-0")
        try await addTags(["current-project", "test"], ownerType: .glassItem, ownerId: "bullseye-001-0")
        try await addTags(["archived", "surplus"], ownerType: .glassItem, ownerId: "spectrum-96-0")
    }

    // MARK: - Generic Tag Operations (New API - Supports All Owner Types)

    func fetchTags(ownerType: TagOwnerType, ownerId: String) async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let key = OwnerKey(ownerType: ownerType, ownerId: ownerId)
                    let tags = Array(self.userTags[key] ?? []).sorted()
                    continuation.resume(returning: tags)
                }
            }
        }
    }

    func fetchTagsForOwners(ownerType: TagOwnerType, ownerIds: [String]) async throws -> [String: [String]] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    var tagsByOwner: [String: [String]] = [:]
                    for ownerId in ownerIds {
                        let key = OwnerKey(ownerType: ownerType, ownerId: ownerId)
                        if let tags = self.userTags[key], !tags.isEmpty {
                            tagsByOwner[ownerId] = Array(tags).sorted()
                        }
                    }
                    continuation.resume(returning: tagsByOwner)
                }
            }
        }
    }

    func addTag(_ tag: String, ownerType: TagOwnerType, ownerId: String) async throws {
        try await simulateOperation {
            let cleanTag = UserTagModel.cleanTag(tag)
            guard UserTagModel.isValidTag(cleanTag) else {
                throw MockUserTagsRepositoryError.invalidTag(tag)
            }

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let key = OwnerKey(ownerType: ownerType, ownerId: ownerId)
                    if self.userTags[key] == nil {
                        self.userTags[key] = Set<String>()
                    }
                    self.userTags[key]?.insert(cleanTag)
                    continuation.resume()
                }
            }
        }
    }

    func addTags(_ tags: [String], ownerType: TagOwnerType, ownerId: String) async throws {
        try await simulateOperation {
            let cleanTags = tags.compactMap { tag in
                let cleaned = UserTagModel.cleanTag(tag)
                return UserTagModel.isValidTag(cleaned) ? cleaned : nil
            }

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let key = OwnerKey(ownerType: ownerType, ownerId: ownerId)
                    if self.userTags[key] == nil {
                        self.userTags[key] = Set<String>()
                    }
                    self.userTags[key]?.formUnion(cleanTags)
                    continuation.resume()
                }
            }
        }
    }

    func removeTag(_ tag: String, ownerType: TagOwnerType, ownerId: String) async throws {
        try await simulateOperation {
            let cleanTag = UserTagModel.cleanTag(tag)

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let key = OwnerKey(ownerType: ownerType, ownerId: ownerId)
                    self.userTags[key]?.remove(cleanTag)
                    if self.userTags[key]?.isEmpty == true {
                        self.userTags.removeValue(forKey: key)
                    }
                    continuation.resume()
                }
            }
        }
    }

    func removeAllTags(ownerType: TagOwnerType, ownerId: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let key = OwnerKey(ownerType: ownerType, ownerId: ownerId)
                    self.userTags.removeValue(forKey: key)
                    continuation.resume()
                }
            }
        }
    }

    func setTags(_ tags: [String], ownerType: TagOwnerType, ownerId: String) async throws {
        try await simulateOperation {
            let cleanTags = Set(tags.compactMap { tag in
                let cleaned = UserTagModel.cleanTag(tag)
                return UserTagModel.isValidTag(cleaned) ? cleaned : nil
            })

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let key = OwnerKey(ownerType: ownerType, ownerId: ownerId)
                    if cleanTags.isEmpty {
                        self.userTags.removeValue(forKey: key)
                    } else {
                        self.userTags[key] = cleanTags
                    }
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Tag Discovery Operations (New API - With Owner Type Filtering)

    func getAllTags() async throws -> [String] {
        return try await getTags(withPrefix: "", ownerType: nil)
    }

    func getAllTags(forOwnerType ownerType: TagOwnerType) async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filteredTags = self.userTags
                        .filter { $0.key.ownerType == ownerType }
                        .values
                        .flatMap { $0 }
                    let uniqueTags = Set(filteredTags)
                    continuation.resume(returning: Array(uniqueTags).sorted())
                }
            }
        }
    }

    func getTags(withPrefix prefix: String, ownerType: TagOwnerType?) async throws -> [String] {
        return try await simulateOperation {
            let lowercasePrefix = prefix.lowercased()

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filteredValues: [Set<String>]
                    if let ownerType = ownerType {
                        filteredValues = self.userTags
                            .filter { $0.key.ownerType == ownerType }
                            .map { $0.value }
                    } else {
                        filteredValues = Array(self.userTags.values)
                    }

                    let allTags = Set(filteredValues.flatMap { $0 })
                    let matchingTags = prefix.isEmpty ? allTags : allTags.filter { $0.hasPrefix(lowercasePrefix) }
                    continuation.resume(returning: Array(matchingTags).sorted())
                }
            }
        }
    }

    func getMostUsedTags(limit: Int, ownerType: TagOwnerType?) async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let tagCounts = self.calculateTagCounts(ownerType: ownerType)
                    let sortedTags = tagCounts.sorted { $0.value > $1.value }
                    let limitedTags = Array(sortedTags.prefix(limit)).map { $0.key }
                    continuation.resume(returning: limitedTags)
                }
            }
        }
    }

    // MARK: - Owner Discovery Operations (New API)

    func fetchOwners(withTag tag: String, ownerType: TagOwnerType) async throws -> [String] {
        return try await simulateOperation {
            let cleanTag = UserTagModel.cleanTag(tag)

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingOwners = self.userTags.compactMap { (key, tags) in
                        key.ownerType == ownerType && tags.contains(cleanTag) ? key.ownerId : nil
                    }.sorted()
                    continuation.resume(returning: matchingOwners)
                }
            }
        }
    }

    func fetchOwners(withAllTags tags: [String], ownerType: TagOwnerType) async throws -> [String] {
        return try await simulateOperation {
            let cleanTags = Set(tags.map { UserTagModel.cleanTag($0) })
            guard !cleanTags.isEmpty else { return [] }

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingOwners = self.userTags.compactMap { (key, ownerTagSet) in
                        key.ownerType == ownerType && cleanTags.isSubset(of: ownerTagSet) ? key.ownerId : nil
                    }.sorted()
                    continuation.resume(returning: matchingOwners)
                }
            }
        }
    }

    func fetchOwners(withAnyTags tags: [String], ownerType: TagOwnerType) async throws -> [String] {
        return try await simulateOperation {
            let cleanTags = Set(tags.map { UserTagModel.cleanTag($0) })
            guard !cleanTags.isEmpty else { return [] }

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingOwners = self.userTags.compactMap { (key, ownerTagSet) in
                        key.ownerType == ownerType && !cleanTags.isDisjoint(with: ownerTagSet) ? key.ownerId : nil
                    }.sorted()
                    continuation.resume(returning: matchingOwners)
                }
            }
        }
    }

    // MARK: - Tag Analytics Operations (New API - With Owner Type Filtering)

    func getTagUsageCounts(ownerType: TagOwnerType?) async throws -> [String: Int] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let tagCounts = self.calculateTagCounts(ownerType: ownerType)
                    continuation.resume(returning: tagCounts)
                }
            }
        }
    }

    func getTagsWithCounts(minCount: Int, ownerType: TagOwnerType?) async throws -> [(tag: String, count: Int)] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let tagCounts = self.calculateTagCounts(ownerType: ownerType)
                    let filteredAndSorted = tagCounts
                        .filter { $0.value >= minCount }
                        .sorted { $0.value > $1.value }
                        .map { (tag: $0.key, count: $0.value) }
                    continuation.resume(returning: filteredAndSorted)
                }
            }
        }
    }

    func tagExists(_ tag: String, ownerType: TagOwnerType?) async throws -> Bool {
        return try await simulateOperation {
            let cleanTag = UserTagModel.cleanTag(tag)

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let exists: Bool
                    if let ownerType = ownerType {
                        exists = self.userTags.contains { key, tags in
                            key.ownerType == ownerType && tags.contains(cleanTag)
                        }
                    } else {
                        exists = self.userTags.values.contains { $0.contains(cleanTag) }
                    }
                    continuation.resume(returning: exists)
                }
            }
        }
    }

    // MARK: - Legacy Tag Operations (Glass Items Only - Delegates to New Generic API)

    func fetchTags(forItem itemNaturalKey: String) async throws -> [String] {
        return try await fetchTags(ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    func fetchTagsForItems(_ itemNaturalKeys: [String]) async throws -> [String: [String]] {
        return try await fetchTagsForOwners(ownerType: .glassItem, ownerIds: itemNaturalKeys)
    }

    func addTag(_ tag: String, toItem itemNaturalKey: String) async throws {
        try await addTag(tag, ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    func addTags(_ tags: [String], toItem itemNaturalKey: String) async throws {
        try await addTags(tags, ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    func removeTag(_ tag: String, fromItem itemNaturalKey: String) async throws {
        try await removeTag(tag, ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    func removeAllTags(fromItem itemNaturalKey: String) async throws {
        try await removeAllTags(ownerType: .glassItem, ownerId: itemNaturalKey)
    }

    func setTags(_ tags: [String], forItem itemNaturalKey: String) async throws {
        try await setTags(tags, ownerType: .glassItem, ownerId: itemNaturalKey)
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

    // MARK: - Private Helper Methods

    /// Simulate latency and random failures for realistic testing
    private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        // Simulate random failure if enabled
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockUserTagsRepositoryError.simulatedFailure
        }

        // Simulate network latency if enabled
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.05) // 10-50ms
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return try await operation()
    }

    /// Calculate tag usage counts
    private func calculateTagCounts(ownerType: TagOwnerType? = nil) -> [String: Int] {
        var tagCounts: [String: Int] = [:]
        let filteredTags: [(OwnerKey, Set<String>)]
        if let ownerType = ownerType {
            filteredTags = userTags.filter { $0.key.ownerType == ownerType }
        } else {
            filteredTags = Array(userTags)
        }

        for (_, tagSet) in filteredTags {
            for tag in tagSet {
                tagCounts[tag, default: 0] += 1
            }
        }
        return tagCounts
    }
}

// MARK: - Mock Repository Errors

enum MockUserTagsRepositoryError: Error, LocalizedError {
    case invalidTag(String)
    case simulatedFailure

    var errorDescription: String? {
        switch self {
        case .invalidTag(let tag):
            return "Invalid user tag: \(tag)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        }
    }
}
