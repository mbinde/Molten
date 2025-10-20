//
//  MockUserTagsRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//

import Foundation

/// Mock implementation of UserTagsRepository for testing
/// Provides in-memory storage for user-created tags with realistic behavior
class MockUserTagsRepository: UserTagsRepository {

    // MARK: - Test Data Storage

    private var userTags: [String: Set<String>] = [:] // itemNaturalKey -> Set of tags
    private let queue = DispatchQueue(label: "mock.usertags.repository", attributes: .concurrent)

    // MARK: - Test Configuration

    /// Controls whether operations should simulate network delays
    var simulateLatency: Bool = false

    /// Controls whether operations should randomly fail for error testing
    var shouldRandomlyFail: Bool = false

    /// Controls the probability of random failures (0.0 to 1.0)
    var failureProbability: Double = 0.1

    // MARK: - Test State Management

    /// Clear all stored data (useful for test setup)
    func clearAllData() {
        queue.async(flags: .barrier) {
            self.userTags.removeAll()
        }
    }

    /// Get count of stored tag relationships (for testing)
    func getTagRelationshipCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                let count = self.userTags.values.reduce(0) { $0 + $1.count }
                continuation.resume(returning: count)
            }
        }
    }

    /// Get count of all tags (for testing) - alias for compatibility
    func getAllTagsCount() async -> Int {
        return await getTagRelationshipCount()
    }

    /// Pre-populate with test data
    func populateWithTestData() async throws {
        try await addTags(["favorite", "wishlist"], toItem: "cim-874-0")
        try await addTags(["current-project", "test"], toItem: "bullseye-001-0")
        try await addTags(["archived", "surplus"], toItem: "spectrum-96-0")
    }

    // MARK: - Basic Tag Operations

    func fetchTags(forItem itemNaturalKey: String) async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let tags = Array(self.userTags[itemNaturalKey] ?? []).sorted()
                    continuation.resume(returning: tags)
                }
            }
        }
    }

    func fetchTagsForItems(_ itemNaturalKeys: [String]) async throws -> [String: [String]] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    var tagsByItem: [String: [String]] = [:]
                    for itemKey in itemNaturalKeys {
                        if let tags = self.userTags[itemKey], !tags.isEmpty {
                            tagsByItem[itemKey] = Array(tags).sorted()
                        }
                    }
                    continuation.resume(returning: tagsByItem)
                }
            }
        }
    }

    func addTag(_ tag: String, toItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            let cleanTag = UserTagModel.cleanTag(tag)
            guard UserTagModel.isValidTag(cleanTag) else {
                throw MockUserTagsRepositoryError.invalidTag(tag)
            }

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    if self.userTags[itemNaturalKey] == nil {
                        self.userTags[itemNaturalKey] = Set<String>()
                    }
                    self.userTags[itemNaturalKey]?.insert(cleanTag)
                    continuation.resume()
                }
            }
        }
    }

    func addTags(_ tags: [String], toItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            let cleanTags = tags.compactMap { tag in
                let cleaned = UserTagModel.cleanTag(tag)
                return UserTagModel.isValidTag(cleaned) ? cleaned : nil
            }

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    if self.userTags[itemNaturalKey] == nil {
                        self.userTags[itemNaturalKey] = Set<String>()
                    }
                    self.userTags[itemNaturalKey]?.formUnion(cleanTags)
                    continuation.resume()
                }
            }
        }
    }

    func removeTag(_ tag: String, fromItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            let cleanTag = UserTagModel.cleanTag(tag)

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.userTags[itemNaturalKey]?.remove(cleanTag)
                    if self.userTags[itemNaturalKey]?.isEmpty == true {
                        self.userTags.removeValue(forKey: itemNaturalKey)
                    }
                    continuation.resume()
                }
            }
        }
    }

    func removeAllTags(fromItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.userTags.removeValue(forKey: itemNaturalKey)
                    continuation.resume()
                }
            }
        }
    }

    func setTags(_ tags: [String], forItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            let cleanTags = Set(tags.compactMap { tag in
                let cleaned = UserTagModel.cleanTag(tag)
                return UserTagModel.isValidTag(cleaned) ? cleaned : nil
            })

            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    if cleanTags.isEmpty {
                        self.userTags.removeValue(forKey: itemNaturalKey)
                    } else {
                        self.userTags[itemNaturalKey] = cleanTags
                    }
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Tag Discovery Operations

    func getAllTags() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allTags = Set(self.userTags.values.flatMap { $0 })
                    continuation.resume(returning: Array(allTags).sorted())
                }
            }
        }
    }

    func getTags(withPrefix prefix: String) async throws -> [String] {
        return try await simulateOperation {
            let lowercasePrefix = prefix.lowercased()

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allTags = Set(self.userTags.values.flatMap { $0 })
                    let matchingTags = allTags.filter { $0.hasPrefix(lowercasePrefix) }
                    continuation.resume(returning: Array(matchingTags).sorted())
                }
            }
        }
    }

    func getMostUsedTags(limit: Int) async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let tagCounts = self.calculateTagCounts()
                    let sortedTags = tagCounts.sorted { $0.value > $1.value }
                    let limitedTags = Array(sortedTags.prefix(limit)).map { $0.key }
                    continuation.resume(returning: limitedTags)
                }
            }
        }
    }

    // MARK: - Item Discovery Operations

    func fetchItems(withTag tag: String) async throws -> [String] {
        return try await simulateOperation {
            let cleanTag = UserTagModel.cleanTag(tag)

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingItems = self.userTags.compactMap { (itemKey, tags) in
                        tags.contains(cleanTag) ? itemKey : nil
                    }.sorted()
                    continuation.resume(returning: matchingItems)
                }
            }
        }
    }

    func fetchItems(withAllTags tags: [String]) async throws -> [String] {
        return try await simulateOperation {
            let cleanTags = Set(tags.map { UserTagModel.cleanTag($0) })
            guard !cleanTags.isEmpty else { return [] }

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingItems = self.userTags.compactMap { (itemKey, itemTagSet) in
                        cleanTags.isSubset(of: itemTagSet) ? itemKey : nil
                    }.sorted()
                    continuation.resume(returning: matchingItems)
                }
            }
        }
    }

    func fetchItems(withAnyTags tags: [String]) async throws -> [String] {
        return try await simulateOperation {
            let cleanTags = Set(tags.map { UserTagModel.cleanTag($0) })
            guard !cleanTags.isEmpty else { return [] }

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingItems = self.userTags.compactMap { (itemKey, itemTagSet) in
                        !cleanTags.isDisjoint(with: itemTagSet) ? itemKey : nil
                    }.sorted()
                    continuation.resume(returning: matchingItems)
                }
            }
        }
    }

    // MARK: - Tag Analytics Operations

    func getTagUsageCounts() async throws -> [String: Int] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let tagCounts = self.calculateTagCounts()
                    continuation.resume(returning: tagCounts)
                }
            }
        }
    }

    func getTagsWithCounts(minCount: Int) async throws -> [(tag: String, count: Int)] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let tagCounts = self.calculateTagCounts()
                    let filteredAndSorted = tagCounts
                        .filter { $0.value >= minCount }
                        .sorted { $0.value > $1.value }
                        .map { (tag: $0.key, count: $0.value) }
                    continuation.resume(returning: filteredAndSorted)
                }
            }
        }
    }

    func tagExists(_ tag: String) async throws -> Bool {
        return try await simulateOperation {
            let cleanTag = UserTagModel.cleanTag(tag)

            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let exists = self.userTags.values.contains { $0.contains(cleanTag) }
                    continuation.resume(returning: exists)
                }
            }
        }
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
    private func calculateTagCounts() -> [String: Int] {
        var tagCounts: [String: Int] = [:]
        for tagSet in userTags.values {
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
