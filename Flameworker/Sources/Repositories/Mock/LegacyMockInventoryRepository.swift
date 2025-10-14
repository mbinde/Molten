//
//  LegacyMockInventoryRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Mock implementation of LegacyInventoryItemRepository for testing
/// LEGACY: This will be replaced by the new GlassItem-based repository system
class LegacyMockInventoryRepository: LegacyInventoryItemRepository {
    
    // MARK: - Test Data Storage
    
    private var items: [String: InventoryItemModel] = [:]
    private let queue = DispatchQueue(label: "legacy.mock.inventory.repository", attributes: .concurrent)
    
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
    
    /// Add test items directly (for testing convenience)
    func addTestItems(_ items: [InventoryItemModel]) {
        queue.sync(flags: .barrier) {
            for item in items {
                self.items[item.id] = item
            }
        }
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [InventoryItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allItems = Array(self.items.values)
                    
                    guard let predicate = predicate else {
                        continuation.resume(returning: allItems.sorted { $0.catalogCode < $1.catalogCode })
                        return
                    }
                    
                    // Simple predicate evaluation for testing
                    let filteredItems = allItems.filter { item in
                        self.evaluatePredicate(predicate, for: item)
                    }.sorted { $0.catalogCode < $1.catalogCode }
                    
                    continuation.resume(returning: filteredItems)
                }
            }
        }
    }
    
    func fetchItem(byId id: String) async throws -> InventoryItemModel? {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.items[id])
                }
            }
        }
    }
    
    func createItem(_ item: InventoryItemModel) async throws -> InventoryItemModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check for duplicate ID
                    if self.items[item.id] != nil {
                        continuation.resume(throwing: LegacyMockInventoryRepositoryError.duplicateId(item.id))
                        return
                    }
                    
                    self.items[item.id] = item
                    continuation.resume(returning: item)
                }
            }
        }
    }
    
    func updateItem(_ item: InventoryItemModel) async throws -> InventoryItemModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check if item exists
                    guard self.items[item.id] != nil else {
                        continuation.resume(throwing: LegacyMockInventoryRepositoryError.itemNotFound(item.id))
                        return
                    }
                    
                    self.items[item.id] = item
                    continuation.resume(returning: item)
                }
            }
        }
    }
    
    func deleteItem(id: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.items.removeValue(forKey: id)
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    func createItems(_ items: [InventoryItemModel]) async throws -> [InventoryItemModel] {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    var createdItems: [InventoryItemModel] = []
                    
                    for item in items {
                        // Check for duplicate ID
                        if self.items[item.id] != nil {
                            continuation.resume(throwing: LegacyMockInventoryRepositoryError.duplicateId(item.id))
                            return
                        }
                        
                        self.items[item.id] = item
                        createdItems.append(item)
                    }
                    
                    continuation.resume(returning: createdItems)
                }
            }
        }
    }
    
    func deleteItems(ids: [String]) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    for id in ids {
                        self.items.removeValue(forKey: id)
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteItems(byCatalogCode catalogCode: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let idsToRemove = self.items.compactMap { (id, item) in
                        item.catalogCode == catalogCode ? id : nil
                    }
                    
                    for id in idsToRemove {
                        self.items.removeValue(forKey: id)
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Search & Filter Operations
    
    func searchItems(text: String) async throws -> [InventoryItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    guard !text.isEmpty else {
                        let allItems = Array(self.items.values).sorted { $0.catalogCode < $1.catalogCode }
                        continuation.resume(returning: allItems)
                        return
                    }
                    
                    let searchText = text.lowercased()
                    let filteredItems = self.items.values.filter { item in
                        item.catalogCode.lowercased().contains(searchText) ||
                        (item.notes?.lowercased().contains(searchText) ?? false)
                    }.sorted { $0.catalogCode < $1.catalogCode }
                    
                    continuation.resume(returning: Array(filteredItems))
                }
            }
        }
    }
    
    func fetchItems(byType type: InventoryItemType) async throws -> [InventoryItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filteredItems = self.items.values
                        .filter { $0.type == type }
                        .sorted { $0.catalogCode < $1.catalogCode }
                    continuation.resume(returning: Array(filteredItems))
                }
            }
        }
    }
    
    func fetchItems(byCatalogCode catalogCode: String) async throws -> [InventoryItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filteredItems = self.items.values
                        .filter { $0.catalogCode == catalogCode }
                        .sorted { $0.dateAdded < $1.dateAdded }
                    continuation.resume(returning: Array(filteredItems))
                }
            }
        }
    }
    
    // MARK: - Business Logic Operations
    
    func getTotalQuantity(forCatalogCode catalogCode: String, type: InventoryItemType) async throws -> Double {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let total = self.items.values
                        .filter { $0.catalogCode == catalogCode && $0.type == type }
                        .reduce(0.0) { $0 + $1.quantity }
                    continuation.resume(returning: total)
                }
            }
        }
    }
    
    func getDistinctCatalogCodes() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let distinctCodes = Set(self.items.values.map { $0.catalogCode })
                    continuation.resume(returning: Array(distinctCodes).sorted())
                }
            }
        }
    }
    
    func consolidateItems(byCatalogCode: Bool) async throws -> [ConsolidatedInventoryModel] {
        return try await simulateOperation {
            guard byCatalogCode else { return [] }
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let groupedItems = Dictionary(grouping: self.items.values) { $0.catalogCode }
                    let consolidated = groupedItems.map { (catalogCode, items) in
                        ConsolidatedInventoryModel(catalogCode: catalogCode, items: items)
                    }.sorted { $0.catalogCode < $1.catalogCode }
                    
                    continuation.resume(returning: consolidated)
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Simulate latency and random failures for realistic testing
    private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        // Simulate random failure if enabled
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw LegacyMockInventoryRepositoryError.simulatedFailure
        }
        
        // Simulate network latency if enabled
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.05) // 10-50ms
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        return try await operation()
    }
    
    /// Basic predicate evaluation for testing (supports common patterns)
    private func evaluatePredicate(_ predicate: NSPredicate, for item: InventoryItemModel) -> Bool {
        let predicateString = predicate.predicateFormat
        
        // Handle common predicate patterns
        if predicateString.contains("catalogCode ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let catalogCode = String(afterFirstQuote[..<endRange.lowerBound])
                    return item.catalogCode == catalogCode
                }
            }
        }
        
        if predicateString.contains("type ==") {
            let components = predicateString.components(separatedBy: " ")
            if let index = components.firstIndex(of: "=="),
               index + 1 < components.count,
               let typeRawValue = Int16(components[index + 1]),
               let type = InventoryItemType(rawValue: typeRawValue) {
                return item.type == type
            }
        }
        
        // Default to true for unsupported predicates
        return true
    }
}

// MARK: - Legacy Mock Repository Errors

enum LegacyMockInventoryRepositoryError: Error, LocalizedError {
    case itemNotFound(String)
    case duplicateId(String)
    case simulatedFailure
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound(let id):
            return "Item not found with ID: \(id)"
        case .duplicateId(let id):
            return "Item already exists with ID: \(id)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        }
    }
}