//
//  MockItemMinimumRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

@preconcurrency import Foundation

/// Mock implementation of ItemMinimumRepository for testing
/// Provides in-memory storage for item minimum records with realistic behavior
class MockItemMinimumRepository: @unchecked Sendable, ItemMinimumRepository {

    // MARK: - Test Data Storage

    nonisolated(unsafe) private var minimums: [String: ItemMinimumModel] = [:] // key: "item_stable_id-type"
    private let queue = DispatchQueue(label: "mock.itemminimum.repository", attributes: .concurrent)

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
            self.minimums.removeAll()
        }
    }

    /// Get count of stored minimum records (for testing)
    nonisolated func getMinimumCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.minimums.count)
            }
        }
    }

    /// Pre-populate with test data
    func populateWithTestData() async throws {
        let testMinimums = [
            ItemMinimumModel(item_stable_id: "cim-874-0", quantity: 14.8, type: "rod", store: "Frantz"),
            ItemMinimumModel(item_stable_id: "cim-874-0", quantity: 5.0, type: "frit", store: "Frantz"),
            ItemMinimumModel(item_stable_id: "bullseye-001-0", quantity: 20.0, type: "sheet", store: "Bullseye Glass"),
            ItemMinimumModel(item_stable_id: "spectrum-96-0", quantity: 10.0, type: "rod", store: "Spectrum Glass")
        ]

        _ = try await createMinimums(testMinimums)
    }
    
    // MARK: - Private Helper

    nonisolated private func keyFor(item_stable_id: String, type: String) -> String {
        return "\(item_stable_id)-\(ItemMinimumModel.cleanStoreName(type))"
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchMinimums(matching predicate: NSPredicate?) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                nonisolated(unsafe) let predicateCopy = predicate
                self.queue.async {
                    let allMinimums = Array(self.minimums.values)

                    guard let predicate = predicateCopy else {
                        continuation.resume(returning: allMinimums.sorted { $0.item_stable_id < $1.item_stable_id })
                        return
                    }
                    
                    // Simple predicate evaluation for testing
                    let filteredMinimums = allMinimums.filter { minimum in
                        self.evaluatePredicate(predicate, for: minimum)
                    }.sorted { $0.item_stable_id < $1.item_stable_id }
                    
                    continuation.resume(returning: filteredMinimums)
                }
            }
        }
    }
    
    func fetchMinimum(forItem item_stable_id: String, type: String) async throws -> ItemMinimumModel? {
        return try await simulateOperation {
            let key = self.keyFor(item_stable_id: item_stable_id, type: type)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.minimums[key])
                }
            }
        }
    }
    
    func fetchMinimums(forItem item_stable_id: String) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let itemMinimums = self.minimums.values
                        .filter { $0.item_stable_id == item_stable_id }
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
                        .sorted { $0.item_stable_id < $1.item_stable_id }
                    continuation.resume(returning: Array(storeMinimums))
                }
            }
        }
    }
    
    func createMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        return try await simulateOperation {
            let key = self.keyFor(item_stable_id: minimum.item_stable_id, type: minimum.type)
            
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check for duplicate key
                    if self.minimums[key] != nil {
                        continuation.resume(throwing: MockItemMinimumRepositoryError.minimumAlreadyExists(minimum.item_stable_id, minimum.type))
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
                        let key = self.keyFor(item_stable_id: minimum.item_stable_id, type: minimum.type)
                        
                        // Check for duplicate key
                        if self.minimums[key] != nil {
                            continuation.resume(throwing: MockItemMinimumRepositoryError.minimumAlreadyExists(minimum.item_stable_id, minimum.type))
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
            let key = self.keyFor(item_stable_id: minimum.item_stable_id, type: minimum.type)
            
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check if minimum exists
                    guard self.minimums[key] != nil else {
                        continuation.resume(throwing: MockItemMinimumRepositoryError.minimumNotFound(minimum.item_stable_id, minimum.type))
                        return
                    }
                    
                    self.minimums[key] = minimum
                    continuation.resume(returning: minimum)
                }
            }
        }
    }
    
    func deleteMinimum(forItem item_stable_id: String, type: String) async throws {
        try await simulateOperation {
            let key = self.keyFor(item_stable_id: item_stable_id, type: type)
            
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.minimums.removeValue(forKey: key)
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteMinimums(forItem item_stable_id: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let keysToRemove = self.minimums.compactMap { (key, minimum) in
                        minimum.item_stable_id == item_stable_id ? key : nil
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
                    let values = Array(self.minimums.values); let storeMinimums = values.filter { $0.store == cleanStore }
                    
                    let shoppingList = storeMinimums.compactMap { minimum -> ShoppingListItemModel? in
                        let currentQuantity = currentInventory[minimum.item_stable_id]?[minimum.type] ?? 0.0
                        
                        // Only include items where current quantity is below minimum
                        if currentQuantity < minimum.quantity {
                            return ShoppingListItemModel(
                                item_stable_id: minimum.item_stable_id,
                                type: minimum.type,
                                currentQuantity: currentQuantity,
                                minimumQuantity: minimum.quantity,
                                store: minimum.store
                            )
                        }
                        return nil
                    }.sorted { $0.item_stable_id < $1.item_stable_id }
                    
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
                            let currentQuantity = currentInventory[minimum.item_stable_id]?[minimum.type] ?? 0.0
                            
                            // Only include items where current quantity is below minimum
                            if currentQuantity < minimum.quantity {
                                return ShoppingListItemModel(
                                    item_stable_id: minimum.item_stable_id,
                                    type: minimum.type,
                                    currentQuantity: currentQuantity,
                                    minimumQuantity: minimum.quantity,
                                    store: minimum.store
                                )
                            }
                            return nil
                        }.sorted { $0.item_stable_id < $1.item_stable_id }
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
                    let values = Array(self.minimums.values); let lowStockItems = values.compactMap { minimum -> LowStockItemModel? in
                        let currentQuantity = currentInventory[minimum.item_stable_id]?[minimum.type] ?? 0.0
                        
                        // Only include items where current quantity is below minimum
                        if currentQuantity < minimum.quantity {
                            return LowStockItemModel(
                                item_stable_id: minimum.item_stable_id,
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
    
    func setMinimumQuantity(_ quantity: Double, forItem item_stable_id: String, type: String, store: String) async throws -> ItemMinimumModel {
        return try await simulateOperation {
            let minimum = ItemMinimumModel(
                item_stable_id: item_stable_id,
                quantity: quantity,
                type: type,
                store: store
            )
            
            let key = self.keyFor(item_stable_id: item_stable_id, type: type)
            
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
                    let values = Array(self.minimums.values); let distinctStores = Set(values.map { $0.store })
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
                    let values = Array(self.minimums.values); let allStores = Set(values.map { $0.store })
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
                                item_stable_id: minimum.item_stable_id,
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
                    let values = Array(self.minimums.values); let invalidMinimums = values.filter { minimum in
                        !validItemKeys.contains(minimum.item_stable_id)
                    }
                    continuation.resume(returning: Array(invalidMinimums))
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods

    /// Simulate latency and random failures for realistic testing
    nonisolated private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
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
    nonisolated private func evaluatePredicate(_ predicate: NSPredicate, for minimum: ItemMinimumModel) -> Bool {
        let predicateString = predicate.predicateFormat
        
        // Handle common predicate patterns
        if predicateString.contains("item_stable_id ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let itemKey = String(afterFirstQuote[..<endRange.lowerBound])
                    return minimum.item_stable_id == itemKey
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