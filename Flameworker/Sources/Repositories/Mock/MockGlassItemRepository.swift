//
//  MockGlassItemRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Mock implementation of GlassItemRepository for testing
/// Provides in-memory storage with realistic behavior for unit tests
class MockGlassItemRepository: GlassItemRepository {
    
    // MARK: - Test Data Storage
    
    private var items: [String: GlassItemModel] = [:]
    private let queue = DispatchQueue(label: "mock.glass.repository", attributes: .concurrent)
    
    // MARK: - Test Configuration
    
    /// Controls whether operations should simulate network delays
    var simulateLatency: Bool = false
    
    /// Controls whether operations should randomly fail for error testing
    var shouldRandomlyFail: Bool = false
    
    /// Controls the probability of random failures (0.0 to 1.0)
    var failureProbability: Double = 0.1
    
    /// Controls whether to suppress verbose logging during tests
    var suppressVerboseLogging: Bool = true
    
    // MARK: - Test State Management
    
    /// Clear all stored data (useful for test setup)
    func clearAllData() {
        queue.async(flags: .barrier) {
            self.items.removeAll()
        }
    }
    
    /// Get count of stored items (for testing)
    func getItemCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.items.count)
            }
        }
    }
    
    /// Pre-populate with test data that matches expected test scenarios
    func populateWithTestData() async throws {
        let testItems = TestDataSetup.createStandardTestGlassItems()
        let _ = try await createItems(testItems)
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allItems = Array(self.items.values)
                    
                    guard let predicate = predicate else {
                        continuation.resume(returning: allItems.sorted { $0.naturalKey < $1.naturalKey })
                        return
                    }
                    
                    // Simple predicate evaluation for testing
                    let filteredItems = allItems.filter { item in
                        self.evaluatePredicate(predicate, for: item)
                    }.sorted { $0.naturalKey < $1.naturalKey }
                    
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
                    if self.items[item.naturalKey] != nil {
                        continuation.resume(throwing: MockRepositoryError.duplicateNaturalKey(item.naturalKey))
                        return
                    }
                    
                    self.items[item.naturalKey] = item
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
                        if self.items[item.naturalKey] != nil {
                            continuation.resume(throwing: MockRepositoryError.duplicateNaturalKey(item.naturalKey))
                            return
                        }
                        
                        self.items[item.naturalKey] = item
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
                    guard self.items[item.naturalKey] != nil else {
                        continuation.resume(throwing: MockRepositoryError.itemNotFound(item.naturalKey))
                        return
                    }
                    
                    self.items[item.naturalKey] = item
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
                        let allItems = Array(self.items.values).sorted { $0.naturalKey < $1.naturalKey }
                        continuation.resume(returning: allItems)
                        return
                    }
                    
                    let searchText = text.lowercased()
                    let filteredItems = self.items.values.filter { item in
                        item.name.lowercased().contains(searchText) ||
                        item.manufacturer.lowercased().contains(searchText) ||
                        (item.mfrNotes?.lowercased().contains(searchText) ?? false)
                    }.sorted { $0.naturalKey < $1.naturalKey }
                    
                    continuation.resume(returning: filteredItems)
                }
            }
        }
    }
    
    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filtered = self.items.values.filter { $0.manufacturer == manufacturer }
                        .sorted { $0.naturalKey < $1.naturalKey }
                    continuation.resume(returning: filtered)
                }
            }
        }
    }
    
    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filtered = self.items.values.filter { $0.coe == coe }
                        .sorted { $0.naturalKey < $1.naturalKey }
                    continuation.resume(returning: filtered)
                }
            }
        }
    }
    
    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filtered = self.items.values.filter { $0.mfrStatus == status }
                        .sorted { $0.naturalKey < $1.naturalKey }
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
                    let manufacturers = Array(Set(self.items.values.map { $0.manufacturer })).sorted()
                    continuation.resume(returning: manufacturers)
                }
            }
        }
    }
    
    func getDistinctCOEValues() async throws -> [Int32] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let coeValues = Array(Set(self.items.values.map { $0.coe })).sorted()
                    continuation.resume(returning: coeValues)
                }
            }
        }
    }
    
    func getDistinctStatuses() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let statuses = Array(Set(self.items.values.map { $0.mfrStatus })).sorted()
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
    private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
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
        
        if predicateString.contains("mfrStatus ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let status = String(afterFirstQuote[..<endRange.lowerBound])
                    return item.mfrStatus == status
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