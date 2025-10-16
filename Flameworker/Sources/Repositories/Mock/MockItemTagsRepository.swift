//
//  MockItemTagsRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Mock implementation of ItemTagsRepository for testing
/// Provides in-memory storage for item tags with realistic behavior
class MockItemTagsRepository: ItemTagsRepository {
    
    // MARK: - Test Data Storage
    
    private var itemTags: [String: Set<String>] = [:] // itemNaturalKey -> Set of tags
    private let queue = DispatchQueue(label: "mock.itemtags.repository", attributes: .concurrent)
    
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
            self.itemTags.removeAll()
        }
    }
    
    /// Get count of stored tag relationships (for testing)
    func getTagRelationshipCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                let count = self.itemTags.values.reduce(0) { $0 + $1.count }
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
        try await addTags(["brown", "gray", "opaque"], toItem: "cim-874-0")
        try await addTags(["clear", "transparent"], toItem: "bullseye-001-0")
        try await addTags(["white", "opaque", "base"], toItem: "spectrum-96-0")
    }
    
    // MARK: - Basic Tag Operations
    
    func fetchTags(forItem itemNaturalKey: String) async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let tags = Array(self.itemTags[itemNaturalKey] ?? []).sorted()
                    continuation.resume(returning: tags)
                }
            }
        }
    }
    
    func addTag(_ tag: String, toItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            let cleanTag = ItemTagModel.cleanTag(tag)
            guard ItemTagModel.isValidTag(cleanTag) else {
                throw MockItemTagsRepositoryError.invalidTag(tag)
            }
            
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    if self.itemTags[itemNaturalKey] == nil {
                        self.itemTags[itemNaturalKey] = Set<String>()
                    }
                    self.itemTags[itemNaturalKey]?.insert(cleanTag)
                    continuation.resume()
                }
            }
        }
    }
    
    func addTags(_ tags: [String], toItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            let cleanTags = tags.compactMap { tag in
                let cleaned = ItemTagModel.cleanTag(tag)
                return ItemTagModel.isValidTag(cleaned) ? cleaned : nil
            }
            
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    if self.itemTags[itemNaturalKey] == nil {
                        self.itemTags[itemNaturalKey] = Set<String>()
                    }
                    self.itemTags[itemNaturalKey]?.formUnion(cleanTags)
                    continuation.resume()
                }
            }
        }
    }
    
    func removeTag(_ tag: String, fromItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            let cleanTag = ItemTagModel.cleanTag(tag)
            
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.itemTags[itemNaturalKey]?.remove(cleanTag)
                    if self.itemTags[itemNaturalKey]?.isEmpty == true {
                        self.itemTags.removeValue(forKey: itemNaturalKey)
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
                    self.itemTags.removeValue(forKey: itemNaturalKey)
                    continuation.resume()
                }
            }
        }
    }
    
    func setTags(_ tags: [String], forItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            let cleanTags = Set(tags.compactMap { tag in
                let cleaned = ItemTagModel.cleanTag(tag)
                return ItemTagModel.isValidTag(cleaned) ? cleaned : nil
            })
            
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    if cleanTags.isEmpty {
                        self.itemTags.removeValue(forKey: itemNaturalKey)
                    } else {
                        self.itemTags[itemNaturalKey] = cleanTags
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
                    let allTags = Set(self.itemTags.values.flatMap { $0 })
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
                    let allTags = Set(self.itemTags.values.flatMap { $0 })
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
            let cleanTag = ItemTagModel.cleanTag(tag)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingItems = self.itemTags.compactMap { (itemKey, tags) in
                        tags.contains(cleanTag) ? itemKey : nil
                    }.sorted()
                    continuation.resume(returning: matchingItems)
                }
            }
        }
    }
    
    func fetchItems(withAllTags tags: [String]) async throws -> [String] {
        return try await simulateOperation {
            let cleanTags = Set(tags.map { ItemTagModel.cleanTag($0) })
            guard !cleanTags.isEmpty else { return [] }
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingItems = self.itemTags.compactMap { (itemKey, itemTagSet) in
                        cleanTags.isSubset(of: itemTagSet) ? itemKey : nil
                    }.sorted()
                    continuation.resume(returning: matchingItems)
                }
            }
        }
    }
    
    func fetchItems(withAnyTags tags: [String]) async throws -> [String] {
        return try await simulateOperation {
            let cleanTags = Set(tags.map { ItemTagModel.cleanTag($0) })
            guard !cleanTags.isEmpty else { return [] }
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let matchingItems = self.itemTags.compactMap { (itemKey, itemTagSet) in
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
            let cleanTag = ItemTagModel.cleanTag(tag)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let exists = self.itemTags.values.contains { $0.contains(cleanTag) }
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
            throw MockItemTagsRepositoryError.simulatedFailure
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
        for tagSet in itemTags.values {
            for tag in tagSet {
                tagCounts[tag, default: 0] += 1
            }
        }
        return tagCounts
    }
}

// MARK: - Mock Repository Errors

enum MockItemTagsRepositoryError: Error, LocalizedError {
    case invalidTag(String)
    case simulatedFailure
    
    var errorDescription: String? {
        switch self {
        case .invalidTag(let tag):
            return "Invalid tag: \(tag)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        }
    }
}