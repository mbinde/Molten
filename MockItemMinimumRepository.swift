//
//  MockItemMinimumRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Mock implementation of ItemMinimumRepository for testing
/// Provides in-memory storage for item minimum records with realistic behavior
class MockItemMinimumRepository: ItemMinimumRepository {
    
    // MARK: - Test Data Storage
    
    private var minimums: [String: ItemMinimumModel] = [:] // key: "itemNaturalKey-type"
    private let queue = DispatchQueue(label: "mock.itemminimum.repository", attributes: .concurrent)
    
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
            self.minimums.removeAll()
        }
    }
    
    /// Get count of stored minimum records (for testing)
    func getMinimumCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.minimums.count)
            }
        }
    }
    
    /// Pre-populate with test data
    func populateWithTestData() async throws {
        let testMinimums = [
            ItemMinimumModel(itemNaturalKey: "cim-874-0", quantity: 14.8, type: "rod", store: "Frantz"),
            ItemMinimumModel(itemNaturalKey: "cim-874-0", quantity: 5.0, type: "frit", store: "Frantz"),
            ItemMinimumModel(itemNaturalKey: "bullseye-001-0", quantity: 20.0, type: "sheet", store: "Bullseye Glass"),
            ItemMinimumModel(itemNaturalKey: "spectrum-96-0", quantity: 10.0, type: "rod", store: "Spectrum Glass")
        ]
        
        _ = try await createMinimums(testMinimums)
    }
    
    // MARK: - Private Helper
    
    private func keyFor(itemNaturalKey: String, type: String) -> String {
        return "\(itemNaturalKey)-\(ItemMinimumModel.cleanStoreName(type))"
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchMinimums(matching predicate: NSPredicate?) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allMinimums = Array(self.minimums.values)
                    
                    guard let predicate = predicate else {
                        continuation.resume(returning: allMinimums.sorted { $0.itemNaturalKey < $1.itemNaturalKey })
                        return
                    }
                    
                    // Simple predicate evaluation for testing
                    let filteredMinimums = allMinimums.filter { minimum in
                        self.evaluatePredicate(predicate, for: minimum)
                    }.sorted { $0.itemNaturalKey < $1.itemNaturalKey }
                    
                    continuation.resume(returning: filteredMinimums)
                }
            }
        }
    }
    
    func fetchMinimum(forItem itemNaturalKey: String, type: String) async throws -> ItemMinimumModel? {
        return try await simulateOperation {
            let key = self.keyFor(itemNaturalKey: itemNaturalKey, type: type)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.minimums[key])
                }
            }
        }
    }
    
    func fetchMinimums(forItem itemNaturalKey: String) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let itemMinimums = self.minimums.values
                        .filter { $0.itemNaturalKey == itemNaturalKey }
                        .sorted { $0.type < $1.type }
                    continuation.resume(returning: Array(itemMinimums))
                }
            }
        }
    }
    
    func fetchMinimums(forStore store: String) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            let cleanStore = ItemMinimumModel.cleanStoreName(store)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let storeMinimums = self.minimums.values
                        .filter { $0.store == cleanStore }
                        .sorted { $0.itemNaturalKey < $1.itemNaturalKey }
                    continuation.resume(returning: Array(storeMinimums))
                }
            }
        }
    }
    
    func createMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        return try await simulateOperation {
            let key = self.keyFor(itemNaturalKey: minimum.itemNaturalKey, type: minimum.type)
            
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check for duplicate key
                    if self.minimums[key] != nil {
                        continuation.resume(throwing: MockItemMinimumRepositoryError.minimumAlreadyExists(minimum.itemNaturalKey, minimum.type))
                        return
                    }
                    
                    self.minimums[key] = minimum
                    continuation.resume(returning: minimum)
                }
            }
        }
    }
    
    func createMinimums(_ minimums: [ItemMinimumModel]) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    var createdMinimums: [ItemMinimumModel] = []
                    
                    for minimum in minimums {
                        let key = self.keyFor(itemNaturalKey: minimum.itemNaturalKey, type: minimum.type)
                        
                        // Check for duplicate key
                        if self.minimums[key] != nil {
                            continuation.resume(throwing: MockItemMinimumRepositoryError.minimumAlreadyExists(minimum.itemNaturalKey, minimum.type))
                            return
                        }
                        
                        self.minimums[key] = minimum
                        createdMinimums.append(minimum)
                    }
                    
                    continuation.resume(returning: createdMinimums)
                }
            }
        }
    }
    
    func updateMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        return try await simulateOperation {
            let key = self.keyFor(itemNaturalKey: minimum.itemNaturalKey, type: minimum.type)
            
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check if minimum exists
                    guard self.minimums[key] != nil else {
                        continuation.resume(throwing: MockItemMinimumRepositoryError.minimumNotFound(minimum.itemNaturalKey, minimum.type))
                        return
                    }
                    
                    self.minimums[key] = minimum
                    continuation.resume(returning: minimum)
                }
            }
        }
    }
    
    func deleteMinimum(forItem itemNaturalKey: String, type: String) async throws {
        try await simulateOperation {
            let key = self.keyFor(itemNaturalKey: itemNaturalKey, type: type)
            
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.minimums.removeValue(forKey: key)
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteMinimums(forItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let keysToRemove = self.minimums.compactMap { (key, minimum) in
                        minimum.itemNaturalKey == itemNaturalKey ? key : nil
                    }
                    
                    for key in keysToRemove {
                        self.minimums.removeValue(forKey: key)
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteMinimums(forStore store: String) async throws {
        try await simulateOperation {
            let cleanStore = ItemMinimumModel.cleanStoreName(store)
            
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let keysToRemove = self.minimums.compactMap { (key, minimum) in
                        minimum.store == cleanStore ? key : nil
                    }
                    
                    for key in keysToRemove {
                        self.minimums.removeValue(forKey: key)
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Shopping List Operations
    
    func generateShoppingList(forStore store: String, currentInventory: [String: [String: Double]]) async throws -> [ShoppingListItemModel] {
        return try await simulateOperation {
            let cleanStore = ItemMinimumModel.cleanStoreName(store)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let storeMinimums = self.minimums.values.filter { $0.store == cleanStore }
                    
                    let shoppingList = storeMinimums.compactMap { minimum -> ShoppingListItemModel? in
                        let currentQuantity = currentInventory[minimum.itemNaturalKey]?[minimum.type] ?? 0.0
                        
                        // Only include items where current quantity is below minimum
                        if currentQuantity < minimum.quantity {
                            return ShoppingListItemModel(
                                itemNaturalKey: minimum.itemNaturalKey,
                                type: minimum.type,
                                currentQuantity: currentQuantity,
                                minimumQuantity: minimum.quantity,
                                store: minimum.store
                            )
                        }
                        return nil
                    }.sorted { $0.itemNaturalKey < $1.itemNaturalKey }
                    
                    continuation.resume(returning: shoppingList)
                }
            }
        }
    }
    
    func generateShoppingLists(currentInventory: [String: [String: Double]]) async throws -> [String: [ShoppingListItemModel]] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let groupedByStore = Dictionary(grouping: self.minimums.values) { $0.store }
                    
                    let shoppingLists = groupedByStore.mapValues { storeMinimums in
                        storeMinimums.compactMap { minimum -> ShoppingListItemModel? in
                            let currentQuantity = currentInventory[minimum.itemNaturalKey]?[minimum.type] ?? 0.0
                            
                            // Only include items where current quantity is below minimum
                            if currentQuantity < minimum.quantity {
                                return ShoppingListItemModel(
                                    itemNaturalKey: minimum.itemNaturalKey,
                                    type: minimum.type,
                                    currentQuantity: currentQuantity,
                                    minimumQuantity: minimum.quantity,
                                    store: minimum.store
                                )
                            }
                            return nil
                        }.sorted { $0.itemNaturalKey < $1.itemNaturalKey }
                    }
                    
                    continuation.resume(returning: shoppingLists)
                }
            }
        }
    }
    
    func getLowStockItems(currentInventory: [String: [String: Double]]) async throws -> [LowStockItemModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let lowStockItems = self.minimums.values.compactMap { minimum -> LowStockItemModel? in
                        let currentQuantity = currentInventory[minimum.itemNaturalKey]?[minimum.type] ?? 0.0
                        
                        // Only include items where current quantity is below minimum
                        if currentQuantity < minimum.quantity {
                            return LowStockItemModel(
                                itemNaturalKey: minimum.itemNaturalKey,
                                type: minimum.type,
                                currentQuantity: currentQuantity,
                                minimumQuantity: minimum.quantity,
                                store: minimum.store
                            )
                        }
                        return nil
                    }.sorted { $0.shortfall > $1.shortfall } // Sort by highest shortfall first
                    
                    continuation.resume(returning: lowStockItems)
                }
            }
        }
    }
    
    func setMinimumQuantity(_ quantity: Double, forItem itemNaturalKey: String, type: String, store: String) async throws -> ItemMinimumModel {
        return try await simulateOperation {
            let minimum = ItemMinimumModel(
                itemNaturalKey: itemNaturalKey,
                quantity: quantity,
                type: type,
                store: store
            )
            
            let key = self.keyFor(itemNaturalKey: itemNaturalKey, type: type)
            
            return await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.minimums[key] = minimum
                    continuation.resume(returning: minimum)
                }
            }
        }
    }
    
    // MARK: - Store Management Operations
    
    func getDistinctStores() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let distinctStores = Set(self.minimums.values.map { $0.store })
                    continuation.resume(returning: Array(distinctStores).sorted())
                }
            }
        }
    }
    
    func getStores(withPrefix prefix: String) async throws -> [String] {
        return try await simulateOperation {
            let lowercasePrefix = prefix.lowercased()
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allStores = Set(self.minimums.values.map { $0.store })
                    let matchingStores = allStores.filter { $0.lowercased().hasPrefix(lowercasePrefix) }
                    continuation.resume(returning: Array(matchingStores).sorted())
                }
            }
        }
    }
    
    func getStoreUtilization() async throws -> [String: Int] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let utilization = Dictionary(grouping: self.minimums.values, by: { $0.store })
                        .mapValues { $0.count }
                    continuation.resume(returning: utilization)
                }
            }
        }
    }
    
    func updateStoreName(from oldStoreName: String, to newStoreName: String) async throws {
        try await simulateOperation {
            let cleanOldStore = ItemMinimumModel.cleanStoreName(oldStoreName)
            let cleanNewStore = ItemMinimumModel.cleanStoreName(newStoreName)
            
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    for (key, minimum) in self.minimums {
                        if minimum.store == cleanOldStore {
                            let updatedMinimum = ItemMinimumModel(
                                itemNaturalKey: minimum.itemNaturalKey,
                                quantity: minimum.quantity,
                                type: minimum.type,
                                store: cleanNewStore
                            )
                            self.minimums[key] = updatedMinimum
                        }
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Analytics Operations
    
    func getMinimumQuantityStatistics() async throws -> MinimumQuantityStatistics {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let statistics = MinimumQuantityStatistics(minimums: Array(self.minimums.values))
                    continuation.resume(returning: statistics)
                }
            }
        }
    }
    
    func getHighestMinimums(limit: Int) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let highest = self.minimums.values
                        .sorted { $0.quantity > $1.quantity }
                        .prefix(limit)
                    continuation.resume(returning: Array(highest))
                }
            }
        }
    }
    
    func getMostCommonTypes() async throws -> [String: Int] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let typeCounts = Dictionary(grouping: self.minimums.values, by: { $0.type })
                        .mapValues { $0.count }
                    continuation.resume(returning: typeCounts)
                }
            }
        }
    }
    
    func validateMinimumRecords(validItemKeys: Set<String>) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let invalidMinimums = self.minimums.values.filter { minimum in
                        !validItemKeys.contains(minimum.itemNaturalKey)
                    }
                    continuation.resume(returning: Array(invalidMinimums))
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Simulate latency and random failures for realistic testing
    private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        // Simulate random failure if enabled
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockItemMinimumRepositoryError.simulatedFailure
        }
        
        // Simulate network latency if enabled
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.03) // 10-30ms
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        return try await operation()
    }
    
    /// Basic predicate evaluation for testing (supports common patterns)
    private func evaluatePredicate(_ predicate: NSPredicate, for minimum: ItemMinimumModel) -> Bool {
        let predicateString = predicate.predicateFormat
        
        // Handle common predicate patterns
        if predicateString.contains("itemNaturalKey ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let itemKey = String(afterFirstQuote[..<endRange.lowerBound])
                    return minimum.itemNaturalKey == itemKey
                }
            }
        }
        
        if predicateString.contains("store ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let store = String(afterFirstQuote[..<endRange.lowerBound])
                    return minimum.store == store
                }
            }
        }
        
        if predicateString.contains("type ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let type = String(afterFirstQuote[..<endRange.lowerBound])
                    return minimum.type == type
                }
            }
        }
        
        // Default to true for unsupported predicates
        return true
    }
}

// MARK: - Mock Repository Errors

enum MockItemMinimumRepositoryError: Error, LocalizedError {
    case minimumNotFound(String, String)
    case minimumAlreadyExists(String, String)
    case simulatedFailure
    
    var errorDescription: String? {
        switch self {
        case .minimumNotFound(let itemKey, let type):
            return "Minimum not found for item: \(itemKey), type: \(type)"
        case .minimumAlreadyExists(let itemKey, let type):
            return "Minimum already exists for item: \(itemKey), type: \(type)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        }
    }
}