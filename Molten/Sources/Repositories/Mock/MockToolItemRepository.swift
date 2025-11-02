//
//  MockToolItemRepository.swift
//  Molten
//
//  Mock implementation of ToolItemRepository for testing
//

@preconcurrency import Foundation
@preconcurrency import CryptoKit

/// Mock implementation of ToolItemRepository for testing
/// Provides in-memory storage with realistic behavior for unit tests
class MockToolItemRepository: @unchecked Sendable, ToolItemRepository {

    // MARK: - Test Data Storage

    nonisolated(unsafe) private var items: [String: ToolItemModel] = [:]
    private let queue = DispatchQueue(label: "mock.tool.repository", attributes: .concurrent)

    nonisolated init() {}

    // MARK: - Test Configuration

    /// Controls whether operations should simulate network delays
    nonisolated(unsafe) var simulateLatency: Bool = false

    /// Controls whether operations should randomly fail for error testing
    nonisolated(unsafe) var shouldRandomlyFail: Bool = false

    /// Controls the probability of random failures (0.0 to 1.0)
    nonisolated(unsafe) var failureProbability: Double = 0.1

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

    // MARK: - Basic CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ToolItemModel] {
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

    func fetchItem(byStableId stableId: String) async throws -> ToolItemModel? {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.items[stableId])
                }
            }
        }
    }

    func createItem(_ item: ToolItemModel) async throws -> ToolItemModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check for duplicate stable_id
                    if self.items[item.stable_id] != nil {
                        continuation.resume(throwing: MockRepositoryError.duplicateNaturalKey(item.stable_id))
                        return
                    }

                    self.items[item.stable_id] = item
                    continuation.resume(returning: item)
                }
            }
        }
    }

    func createItems(_ items: [ToolItemModel]) async throws -> [ToolItemModel] {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    var createdItems: [ToolItemModel] = []

                    for item in items {
                        // Check for duplicates
                        if self.items[item.stable_id] != nil {
                            continuation.resume(throwing: MockRepositoryError.duplicateNaturalKey(item.stable_id))
                            return
                        }

                        self.items[item.stable_id] = item
                        createdItems.append(item)
                    }

                    continuation.resume(returning: createdItems)
                }
            }
        }
    }

    func updateItem(_ item: ToolItemModel) async throws -> ToolItemModel {
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
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    guard self.items[stableId] != nil else {
                        continuation.resume(throwing: MockRepositoryError.itemNotFound(stableId))
                        return
                    }

                    self.items.removeValue(forKey: stableId)
                    continuation.resume()
                }
            }
        }
    }

    func deleteItems(stableIds: [String]) async throws {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
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

    func searchItems(text: String) async throws -> [ToolItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let searchText = text.lowercased()
                    let filteredItems = self.items.values.filter { item in
                        item.name.lowercased().contains(searchText) ||
                        item.manufacturer.lowercased().contains(searchText) ||
                        (item.mfr_notes?.lowercased().contains(searchText) ?? false)
                    }.sorted(by: { $0.stable_id < $1.stable_id })

                    continuation.resume(returning: filteredItems)
                }
            }
        }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [ToolItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filteredItems = self.items.values.filter { item in
                        item.manufacturer == manufacturer
                    }.sorted(by: { $0.stable_id < $1.stable_id })

                    continuation.resume(returning: filteredItems)
                }
            }
        }
    }

    func fetchItems(byStatus status: String) async throws -> [ToolItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filteredItems = self.items.values.filter { item in
                        item.mfr_status == status
                    }.sorted(by: { $0.stable_id < $1.stable_id })

                    continuation.resume(returning: filteredItems)
                }
            }
        }
    }

    // MARK: - Business Query Operations

    func getDistinctManufacturers() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let manufacturers = Set(self.items.values.map { $0.manufacturer })
                    continuation.resume(returning: Array(manufacturers).sorted())
                }
            }
        }
    }

    func getDistinctStatuses() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let statuses = Set(self.items.values.map { $0.mfr_status })
                    continuation.resume(returning: Array(statuses).sorted())
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
        // Generate a simple stable_id based on manufacturer + SKU + timestamp
        let baseString = "\(manufacturer)-\(sku ?? "nosqu")-\(Date().timeIntervalSince1970)"
        return generateStableId(from: baseString)
    }

    // MARK: - Private Helpers

    /// Simulate async operation with optional latency and random failures
    private func simulateOperation<T>(_ operation: @Sendable () async throws -> T) async throws -> T {
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockRepositoryError.simulatedFailure
        }

        if simulateLatency {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        return try await operation()
    }

    /// Generate a 6-character stable ID from a string using SHA256
    private func generateStableId(from string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return String(hashString.prefix(6))
    }

    /// Simple predicate evaluation for testing
    private func evaluatePredicate(_ predicate: NSPredicate, for item: ToolItemModel) -> Bool {
        // Convert ToolItemModel to NSDictionary for predicate evaluation
        let dict: [String: Any?] = [
            "stable_id": item.stable_id,
            "name": item.name,
            "sku": item.sku as Any,
            "manufacturer": item.manufacturer,
            "mfr_notes": item.mfr_notes as Any,
            "url": item.url as Any,
            "uri": item.uri,
            "mfr_status": item.mfr_status,
            "image_url": item.image_url as Any,
            "image_path": item.image_path as Any
        ]

        return predicate.evaluate(with: dict)
    }
}

// Note: MockRepositoryError is defined in MockGlassItemRepository.swift and shared across all mock repositories
