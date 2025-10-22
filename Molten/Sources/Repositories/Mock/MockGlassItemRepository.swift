//
//  MockGlassItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

@preconcurrency import Foundation

/// Mock implementation of GlassItemRepository for testing
/// Provides in-memory storage with realistic behavior for unit tests
class MockGlassItemRepository: @unchecked Sendable, GlassItemRepository {

    // MARK: - Test Data Storage

    private var items: [String: GlassItemModel] = [:]
    private let queue = DispatchQueue(label: "mock.glass.repository", attributes: .concurrent)

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
        // let testItems = TestDataSetup.createStandardTestGlassItems()
        // let _ = try await createItems(testItems)
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allItems = Array(self.items.values)
                    
                    guard let predicate = predicate else {
                        let sortedItems = allItems.sorted(by: { $0.natural_key < $1.natural_key })
                        continuation.resume(returning: sortedItems)
                        return
                    }
                    
                    // Simple predicate evaluation for testing
                    let filteredItems = allItems.filter { item in
                        self.evaluatePredicate(predicate, for: item)
                    }.sorted(by: { $0.natural_key < $1.natural_key })
                    
                    continuation.resume(returning: filteredItems)
                }
            }
        }
    }
    
    func fetchItem(byNaturalKey naturalKey: String) async throws -> GlassItemModel? {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.items[naturalKey])
                }
            }
        }
    }
    
    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check for duplicate natural key
                    if self.items[item.natural_key] != nil {
                        continuation.resume(throwing: MockRepositoryError.duplicateNaturalKey(item.natural_key))
                        return
                    }
                    
                    self.items[item.natural_key] = item
                    continuation.resume(returning: item)
                }
            }
        }
    }
    
    func createItems(_ items: [GlassItemModel]) async throws -> [GlassItemModel] {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    var createdItems: [GlassItemModel] = []
                    
                    for item in items {
                        // Check for duplicate natural key
                        if self.items[item.natural_key] != nil {
                            continuation.resume(throwing: MockRepositoryError.duplicateNaturalKey(item.natural_key))
                            return
                        }
                        
                        self.items[item.natural_key] = item
                        createdItems.append(item)
                    }
                    
                    continuation.resume(returning: createdItems)
                }
            }
        }
    }
    
    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check if item exists
                    guard self.items[item.natural_key] != nil else {
                        continuation.resume(throwing: MockRepositoryError.itemNotFound(item.natural_key))
                        return
                    }
                    
                    self.items[item.natural_key] = item
                    continuation.resume(returning: item)
                }
            }
        }
    }
    
    func deleteItem(naturalKey: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.items.removeValue(forKey: naturalKey)
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteItems(naturalKeys: [String]) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    for naturalKey in naturalKeys {
                        self.items.removeValue(forKey: naturalKey)
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Search & Filter Operations
    
    func searchItems(text: String) async throws -> [GlassItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    guard !text.isEmpty else {
                        let allItems = Array(self.items.values).sorted(by: { $0.natural_key < $1.natural_key })
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
                    }.sorted(by: { $0.natural_key < $1.natural_key })

                    continuation.resume(returning: filteredItems)
                }
            }
        }
    }
    
    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let values = Array(self.items.values); let filtered = values.filter { $0.manufacturer == manufacturer }
                        .sorted(by: { $0.natural_key < $1.natural_key })
                    continuation.resume(returning: filtered)
                }
            }
        }
    }
    
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let values = Array(self.items.values); let filtered = values.filter { $0.coe == coe }
                        .sorted(by: { $0.natural_key < $1.natural_key })
                    continuation.resume(returning: filtered)
                }
            }
        }
    }
    
    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let values = Array(self.items.values); let filtered = values.filter { $0.mfr_status == status }
                        .sorted(by: { $0.natural_key < $1.natural_key })
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
    
    func getDistinctCOEValues() async throws -> [Int32] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let values = Array(self.items.values); let coeValues = Array(Set(values.map { $0.coe })).sorted()
                    continuation.resume(returning: coeValues)
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
    
    func naturalKeyExists(_ naturalKey: String) async throws -> Bool {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.items[naturalKey] != nil)
                }
            }
        }
    }
    
    func generateNextNaturalKey(manufacturer: String, sku: String) async throws -> String {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    var sequence = 0
                    var naturalKey: String
                    
                    repeat {
                        naturalKey = GlassItemModel.createNaturalKey(
                            manufacturer: manufacturer,
                            sku: sku,
                            sequence: sequence
                        )
                        sequence += 1
                    } while self.items[naturalKey] != nil
                    
                    continuation.resume(returning: naturalKey)
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
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
    private func evaluatePredicate(_ predicate: NSPredicate, for item: GlassItemModel) -> Bool {
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
        
        if predicateString.contains("coe ==") {
            let components = predicateString.components(separatedBy: " ")
            if let index = components.firstIndex(of: "=="),
               index + 1 < components.count,
               let coe = Int32(components[index + 1]) {
                return item.coe == coe
            }
        }
        
        if predicateString.contains("mfr_status ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let status = String(afterFirstQuote[..<endRange.lowerBound])
                    return item.mfr_status == status
                }
            }
        }
        
        // Default to true for unsupported predicates
        return true
    }
}

// MARK: - Mock Repository Errors

enum MockRepositoryError: Error, LocalizedError {
    case itemNotFound(String)
    case duplicateNaturalKey(String)
    case simulatedFailure
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound(let naturalKey):
            return "Item not found with natural key: \(naturalKey)"
        case .duplicateNaturalKey(let naturalKey):
            return "Item already exists with natural key: \(naturalKey)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        }
    }
}
