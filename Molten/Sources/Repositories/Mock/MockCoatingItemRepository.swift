//
//  MockCoatingItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 11/2/25.
//

@preconcurrency import Foundation
import CryptoKit

/// Mock implementation of CoatingItemRepository for testing
/// Provides in-memory storage with realistic behavior for unit tests
class MockCoatingItemRepository: @unchecked Sendable, CoatingItemRepository {

    // MARK: - Test Data Storage

    nonisolated(unsafe) private var items: [String: CoatingItemModel] = [:]
    private let queue = DispatchQueue(label: "mock.coating.repository", attributes: .concurrent)

    nonisolated init() {}

    // MARK: - Test Configuration

    /// Controls whether operations should simulate network delays
    nonisolated(unsafe) var simulateLatency: Bool = false

    /// Controls whether operations should randomly fail for error testing
    nonisolated(unsafe) var shouldRandomlyFail: Bool = false

    /// Controls the probability of random failures (0.0 to 1.0)
    nonisolated(unsafe) var failureProbability: Double = 0.1

    /// Controls whether to suppress verbose logging during tests
    nonisolated(unsafe) var suppressVerboseLogging: Bool = true

    // MARK: - Test State Management

    /// Clear all stored data (useful for test setup)
    nonisolated func clearAllData() {
        queue.async(flags: .barrier) {
            self.items.removeAll()
        }
    }

    /// Get count of stored items (for testing)
    nonisolated func getItemCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.items.count)
            }
        }
    }

    /// Pre-populate with test data that matches expected test scenarios
    func populateWithTestData() async throws {
        // TestDataSetup moved to test bundle - this function is deprecated
        // let testItems = TestDataSetup.createStandardTestCoatingItems()
        // let _ = try await createItems(testItems)
    }

    // MARK: - Basic CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [CoatingItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                nonisolated(unsafe) let predicateCopy = predicate
                self.queue.async {
                    let allItems = Array(self.items.values)

                    guard let predicate = predicateCopy else {
                        let sortedItems = allItems.sorted(by: { $0.stable_id < $1.stable_id })
                        continuation.resume(returning: sortedItems)
                        return
                    }

                    // Simple predicate evaluation for testing
                    let filteredItems = allItems.filter { item in
                        self.evaluatePredicate(predicate, for: item)
                    }.sorted(by: { $0.stable_id < $1.stable_id })

                    continuation.resume(returning: filteredItems)
                }
            }
        }
    }

    func fetchItem(byStableId stableId: String) async throws -> CoatingItemModel? {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.items[stableId])
                }
            }
        }
    }

    func createItem(_ item: CoatingItemModel) async throws -> CoatingItemModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Auto-generate stable_id if it's a placeholder
                    var finalItem = item
                    if item.stable_id == "AUTO_ID" {
                        let generatedStableId = self.generateStableId(manufacturer: item.manufacturer, sku: item.sku)
                        finalItem = CoatingItemModel(
                            stable_id: generatedStableId,
                            name: item.name,
                            sku: item.sku,
                            manufacturer: item.manufacturer,
                            mfr_notes: item.mfr_notes,
                            url: item.url,
                            mfr_status: item.mfr_status,
                            image_url: item.image_url,
                            image_path: item.image_path
                        )
                    }

                    // Check for duplicate stable ID
                    if self.items[finalItem.stable_id] != nil {
                        continuation.resume(throwing: MockRepositoryError.duplicateNaturalKey(finalItem.stable_id))
                        return
                    }

                    self.items[finalItem.stable_id] = finalItem
                    continuation.resume(returning: finalItem)
                }
            }
        }
    }

    func createItems(_ items: [CoatingItemModel]) async throws -> [CoatingItemModel] {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    var createdItems: [CoatingItemModel] = []

                    for item in items {
                        // Auto-generate stable_id if it's a placeholder
                        var finalItem = item
                        if item.stable_id == "AUTO_ID" {
                            let generatedStableId = self.generateStableId(manufacturer: item.manufacturer, sku: item.sku)
                            finalItem = CoatingItemModel(
                                stable_id: generatedStableId,
                                name: item.name,
                                sku: item.sku,
                                manufacturer: item.manufacturer,
                                mfr_notes: item.mfr_notes,
                                url: item.url,
                                mfr_status: item.mfr_status,
                                image_url: item.image_url,
                                image_path: item.image_path
                            )
                        }

                        // Check for duplicate stable ID
                        if self.items[finalItem.stable_id] != nil {
                            continuation.resume(throwing: MockRepositoryError.duplicateNaturalKey(finalItem.stable_id))
                            return
                        }

                        self.items[finalItem.stable_id] = finalItem
                        createdItems.append(finalItem)
                    }

                    continuation.resume(returning: createdItems)
                }
            }
        }
    }

    func updateItem(_ item: CoatingItemModel) async throws -> CoatingItemModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check if item exists
                    guard self.items[item.stable_id] != nil else {
                        continuation.resume(throwing: MockRepositoryError.itemNotFound(item.stable_id))
                        return
                    }

                    self.items[item.stable_id] = item
                    continuation.resume(returning: item)
                }
            }
        }
    }

    func deleteItem(stableId: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.items.removeValue(forKey: stableId)
                    continuation.resume()
                }
            }
        }
    }

    func deleteItems(stableIds: [String]) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    for stableId in stableIds {
                        self.items.removeValue(forKey: stableId)
                    }
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Search & Filter Operations

    func searchItems(text: String) async throws -> [CoatingItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    guard !text.isEmpty else {
                        let allItems = Array(self.items.values).sorted(by: { $0.stable_id < $1.stable_id })
                        continuation.resume(returning: allItems)
                        return
                    }

                    // Parse search text to determine search mode
                    let searchMode = SearchTextParser.parseSearchText(text)

                    // Filter items based on search mode
                    let values = Array(self.items.values); let filteredItems = values.filter { item in
                        // Search across name, manufacturer, SKU, and notes
                        let fields = [item.name, item.manufacturer, item.sku, item.mfr_notes]
                        return SearchTextParser.matchesAnyField(fields: fields, mode: searchMode)
                    }.sorted(by: { $0.stable_id < $1.stable_id })

                    continuation.resume(returning: filteredItems)
                }
            }
        }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [CoatingItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let values = Array(self.items.values); let filtered = values.filter { $0.manufacturer == manufacturer }
                        .sorted(by: { $0.stable_id < $1.stable_id })
                    continuation.resume(returning: filtered)
                }
            }
        }
    }


    func fetchItems(byStatus status: String) async throws -> [CoatingItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let values = Array(self.items.values); let filtered = values.filter { $0.mfr_status == status }
                        .sorted(by: { $0.stable_id < $1.stable_id })
                    continuation.resume(returning: filtered)
                }
            }
        }
    }

    // MARK: - Business Query Operations

    func getDistinctManufacturers() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let values = Array(self.items.values); let manufacturers = Array(Set(values.map { $0.manufacturer })).sorted()
                    continuation.resume(returning: manufacturers)
                }
            }
        }
    }


    func getDistinctStatuses() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let values = Array(self.items.values); let statuses = Array(Set(values.map { $0.mfr_status })).sorted()
                    continuation.resume(returning: statuses)
                }
            }
        }
    }

    func stableIdExists(_ stableId: String) async throws -> Bool {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.items[stableId] != nil)
                }
            }
        }
    }

    func generateNextNaturalKey(manufacturer: String, sku: String?) async throws -> String {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    var sequence = 0
                    var stableId: String

                    repeat {
                        // Generate hash-based stable_id (6-char hash)
                        let input = "\(manufacturer)-\(sku ?? "NO_SKU")-\(sequence)"
                        stableId = String(format: "%06d", abs(input.hashValue % 1000000))
                        sequence += 1
                    } while self.items[stableId] != nil

                    continuation.resume(returning: stableId)
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    /// Generate a stable 6-character ID from manufacturer and SKU, matching the implementation
    /// in TestHelpers.swift and Tools/Scraping Tools/update_database.py
    private func generateStableId(manufacturer: String, sku: String?) -> String {
        // Combine manufacturer and SKU for hashing (same format as Python and TestHelpers)
        // If no SKU, use manufacturer only
        let combined = if let sku = sku {
            "\(manufacturer):\(sku)"
        } else {
            "\(manufacturer):NO_SKU:\(UUID().uuidString)"
        }

        // Hash it with SHA-256
        let hash = SHA256.hash(data: combined.data(using: .utf8)!)
        let hashBytes = Data(hash)

        // Base62 character set (excluding confusing chars: I, O, l)
        let base62Chars = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz"

        // Take first 4 bytes (32 bits), convert to base62
        var num = UInt32(bigEndian: hashBytes.withUnsafeBytes { $0.load(as: UInt32.self) })

        // Generate 6-character ID
        var stableId = ""
        for _ in 0..<6 {
            let index = Int(num % UInt32(base62Chars.count))
            let char = base62Chars[base62Chars.index(base62Chars.startIndex, offsetBy: index)]
            stableId = String(char) + stableId
            num /= UInt32(base62Chars.count)
        }

        return stableId
    }

    /// Simulate latency and random failures for realistic testing
    nonisolated private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        // Simulate random failure if enabled
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockRepositoryError.simulatedFailure
        }

        // Simulate network latency if enabled
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.1) // 10-100ms
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        return try await operation()
    }

    /// Basic predicate evaluation for testing (supports common patterns)
    private func evaluatePredicate(_ predicate: NSPredicate, for item: CoatingItemModel) -> Bool {
        let predicateString = predicate.predicateFormat

        // Handle common predicate patterns
        if predicateString.contains("manufacturer ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let manufacturer = String(afterFirstQuote[..<endRange.lowerBound])
                    return item.manufacturer == manufacturer
                }
            }
        }


        return false
    }
}

// Note: MockRepositoryError is defined in MockGlassItemRepository.swift and shared across all mock repositories
