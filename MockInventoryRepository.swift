//
//
//  NewMockInventoryRepository.swift  
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Mock implementation of InventoryRepository for testing (NEW GLASS ITEM SYSTEM)
/// Provides in-memory storage for inventory records with realistic behavior
class MockInventoryRepository: InventoryRepository {
    
    // MARK: - Test Data Storage
    
    private var inventories: [UUID: InventoryModel] = [:]
    private let queue = DispatchQueue(label: "mock.inventory.repository", attributes: .concurrent)
    
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
            self.inventories.removeAll()
        }
    }
    
    /// Get count of stored inventory records (for testing)
    func getInventoryCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.inventories.count)
            }
        }
    }
    
    /// Pre-populate with test data
    func populateWithTestData() async throws {
        let testInventories = [
            InventoryModel(itemNaturalKey: "cim-874-0", type: "rod", quantity: 7.0),
            InventoryModel(itemNaturalKey: "cim-874-0", type: "frit", quantity: 2.5),
            InventoryModel(itemNaturalKey: "bullseye-001-0", type: "sheet", quantity: 12.0),
            InventoryModel(itemNaturalKey: "spectrum-96-0", type: "rod", quantity: 3.5),
            InventoryModel(itemNaturalKey: "spectrum-96-0", type: "powder", quantity: 1.8)
        ]
        
        _ = try await createInventories(testInventories)
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchInventory(matching predicate: NSPredicate?) async throws -> [InventoryModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let allInventories = Array(self.inventories.values)
                    
                    guard let predicate = predicate else {
                        continuation.resume(returning: allInventories.sorted { $0.itemNaturalKey < $1.itemNaturalKey })
                        return
                    }
                    
                    // Simple predicate evaluation for testing
                    let filteredInventories = allInventories.filter { inventory in
                        self.evaluatePredicate(predicate, for: inventory)
                    }.sorted { $0.itemNaturalKey < $1.itemNaturalKey }
                    
                    continuation.resume(returning: filteredInventories)
                }
            }
        }
    }
    
    func fetchInventory(byId id: UUID) async throws -> InventoryModel? {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.inventories[id])
                }
            }
        }
    }
    
    func fetchInventory(forItem itemNaturalKey: String) async throws -> [InventoryModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let itemInventories = self.inventories.values
                        .filter { $0.itemNaturalKey == itemNaturalKey }
                        .sorted { $0.type < $1.type }
                    continuation.resume(returning: Array(itemInventories))
                }
            }
        }
    }
    
    func fetchInventory(forItem itemNaturalKey: String, type: String) async throws -> [InventoryModel] {
        return try await simulateOperation {
            let cleanType = InventoryModel.cleanType(type)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let itemTypeInventories = self.inventories.values
                        .filter { $0.itemNaturalKey == itemNaturalKey && $0.type == cleanType }
                        .sorted { $0.quantity > $1.quantity }
                    continuation.resume(returning: Array(itemTypeInventories))
                }
            }
        }
    }
    
    func createInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Generate new ID if needed
                    let inventoryToStore = InventoryModel(
                        id: inventory.id,
                        itemNaturalKey: inventory.itemNaturalKey,
                        type: inventory.type,
                        quantity: inventory.quantity
                    )
                    
                    // Check for duplicate ID
                    if self.inventories[inventoryToStore.id] != nil {
                        continuation.resume(throwing: MockInventoryRepositoryError.duplicateId(inventoryToStore.id))
                        return
                    }
                    
                    self.inventories[inventoryToStore.id] = inventoryToStore
                    continuation.resume(returning: inventoryToStore)
                }
            }
        }
    }
    
    func createInventories(_ inventories: [InventoryModel]) async throws -> [InventoryModel] {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    var createdInventories: [InventoryModel] = []
                    
                    for inventory in inventories {
                        let inventoryToStore = InventoryModel(
                            id: inventory.id,
                            itemNaturalKey: inventory.itemNaturalKey,
                            type: inventory.type,
                            quantity: inventory.quantity
                        )
                        
                        // Check for duplicate ID
                        if self.inventories[inventoryToStore.id] != nil {
                            continuation.resume(throwing: MockInventoryRepositoryError.duplicateId(inventoryToStore.id))
                            return
                        }
                        
                        self.inventories[inventoryToStore.id] = inventoryToStore
                        createdInventories.append(inventoryToStore)
                    }
                    
                    continuation.resume(returning: createdInventories)
                }
            }
        }
    }
    
    func updateInventory(_ inventory: InventoryModel) async throws -> InventoryModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Check if inventory exists
                    guard self.inventories[inventory.id] != nil else {
                        continuation.resume(throwing: MockInventoryRepositoryError.inventoryNotFound(inventory.id))
                        return
                    }
                    
                    self.inventories[inventory.id] = inventory
                    continuation.resume(returning: inventory)
                }
            }
        }
    }
    
    func deleteInventory(id: UUID) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.inventories.removeValue(forKey: id)
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteInventory(forItem itemNaturalKey: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let idsToRemove = self.inventories.compactMap { (id, inventory) in
                        inventory.itemNaturalKey == itemNaturalKey ? id : nil
                    }
                    
                    for id in idsToRemove {
                        self.inventories.removeValue(forKey: id)
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteInventory(forItem itemNaturalKey: String, type: String) async throws {
        try await simulateOperation {
            let cleanType = InventoryModel.cleanType(type)
            
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    let idsToRemove = self.inventories.compactMap { (id, inventory) in
                        (inventory.itemNaturalKey == itemNaturalKey && inventory.type == cleanType) ? id : nil
                    }
                    
                    for id in idsToRemove {
                        self.inventories.removeValue(forKey: id)
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Quantity Operations
    
    func getTotalQuantity(forItem itemNaturalKey: String) async throws -> Double {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let total = self.inventories.values
                        .filter { $0.itemNaturalKey == itemNaturalKey }
                        .reduce(0.0) { $0 + $1.quantity }
                    continuation.resume(returning: total)
                }
            }
        }
    }
    
    func getTotalQuantity(forItem itemNaturalKey: String, type: String) async throws -> Double {
        return try await simulateOperation {
            let cleanType = InventoryModel.cleanType(type)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let total = self.inventories.values
                        .filter { $0.itemNaturalKey == itemNaturalKey && $0.type == cleanType }
                        .reduce(0.0) { $0 + $1.quantity }
                    continuation.resume(returning: total)
                }
            }
        }
    }
    
    func addQuantity(_ quantity: Double, toItem itemNaturalKey: String, type: String) async throws -> InventoryModel {
        return try await simulateOperation {
            let cleanType = InventoryModel.cleanType(type)
            
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Find existing inventory record or create new one
                    let existingInventory = self.inventories.values.first {
                        $0.itemNaturalKey == itemNaturalKey && $0.type == cleanType
                    }
                    
                    let updatedInventory: InventoryModel
                    if let existing = existingInventory {
                        updatedInventory = InventoryModel(
                            id: existing.id,
                            itemNaturalKey: existing.itemNaturalKey,
                            type: existing.type,
                            quantity: existing.quantity + quantity
                        )
                    } else {
                        updatedInventory = InventoryModel(
                            itemNaturalKey: itemNaturalKey,
                            type: cleanType,
                            quantity: quantity
                        )
                    }
                    
                    self.inventories[updatedInventory.id] = updatedInventory
                    continuation.resume(returning: updatedInventory)
                }
            }
        }
    }
    
    func subtractQuantity(_ quantity: Double, fromItem itemNaturalKey: String, type: String) async throws -> InventoryModel? {
        return try await simulateOperation {
            let cleanType = InventoryModel.cleanType(type)
            
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    guard let existingInventory = self.inventories.values.first(where: {
                        $0.itemNaturalKey == itemNaturalKey && $0.type == cleanType
                    }) else {
                        continuation.resume(throwing: MockInventoryRepositoryError.inventoryNotFoundForItem(itemNaturalKey, cleanType))
                        return
                    }
                    
                    let newQuantity = existingInventory.quantity - quantity
                    
                    if newQuantity <= 0 {
                        // Remove inventory record if quantity reaches zero or below
                        self.inventories.removeValue(forKey: existingInventory.id)
                        continuation.resume(returning: nil)
                    } else {
                        let updatedInventory = InventoryModel(
                            id: existingInventory.id,
                            itemNaturalKey: existingInventory.itemNaturalKey,
                            type: existingInventory.type,
                            quantity: newQuantity
                        )
                        self.inventories[updatedInventory.id] = updatedInventory
                        continuation.resume(returning: updatedInventory)
                    }
                }
            }
        }
    }
    
    func setQuantity(_ quantity: Double, forItem itemNaturalKey: String, type: String) async throws -> InventoryModel? {
        return try await simulateOperation {
            let cleanType = InventoryModel.cleanType(type)
            
            return await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Find existing inventory record
                    let existingInventory = self.inventories.values.first {
                        $0.itemNaturalKey == itemNaturalKey && $0.type == cleanType
                    }
                    
                    if quantity <= 0 {
                        // Remove inventory record if quantity is zero or negative
                        if let existing = existingInventory {
                            self.inventories.removeValue(forKey: existing.id)
                        }
                        continuation.resume(returning: nil)
                    } else {
                        let updatedInventory: InventoryModel
                        if let existing = existingInventory {
                            updatedInventory = InventoryModel(
                                id: existing.id,
                                itemNaturalKey: existing.itemNaturalKey,
                                type: existing.type,
                                quantity: quantity
                            )
                        } else {
                            updatedInventory = InventoryModel(
                                itemNaturalKey: itemNaturalKey,
                                type: cleanType,
                                quantity: quantity
                            )
                        }
                        
                        self.inventories[updatedInventory.id] = updatedInventory
                        continuation.resume(returning: updatedInventory)
                    }
                }
            }
        }
    }
    
    // MARK: - Discovery Operations
    
    func getDistinctTypes() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let distinctTypes = Set(self.inventories.values.map { $0.type })
                    continuation.resume(returning: Array(distinctTypes).sorted())
                }
            }
        }
    }
    
    func getItemsWithInventory() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let distinctItems = Set(self.inventories.values.map { $0.itemNaturalKey })
                    continuation.resume(returning: Array(distinctItems).sorted())
                }
            }
        }
    }
    
    func getItemsWithInventory(ofType type: String) async throws -> [String] {
        return try await simulateOperation {
            let cleanType = InventoryModel.cleanType(type)
            
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let itemsWithType = Set(self.inventories.values
                        .filter { $0.type == cleanType }
                        .map { $0.itemNaturalKey })
                    continuation.resume(returning: Array(itemsWithType).sorted())
                }
            }
        }
    }
    
    func getItemsWithLowInventory(threshold: Double) async throws -> [(itemNaturalKey: String, type: String, quantity: Double)] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let lowInventoryItems = self.inventories.values
                        .filter { $0.quantity > 0 && $0.quantity < threshold }
                        .map { (itemNaturalKey: $0.itemNaturalKey, type: $0.type, quantity: $0.quantity) }
                        .sorted { $0.itemNaturalKey < $1.itemNaturalKey }
                    continuation.resume(returning: lowInventoryItems)
                }
            }
        }
    }
    
    func getItemsWithZeroInventory() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    // In our mock, we don't store zero-quantity records, so return empty array
                    // In a real implementation, this might track items that previously had inventory
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // MARK: - Aggregation Operations
    
    func getInventorySummary() async throws -> [InventorySummaryModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let groupedByItem = self.inventories.values.grouped(by: \.itemNaturalKey)
                    let summaries = groupedByItem.map { (itemKey, inventories) in
                        InventorySummaryModel(itemNaturalKey: itemKey, inventories: inventories)
                    }.sorted { $0.itemNaturalKey < $1.itemNaturalKey }
                    continuation.resume(returning: summaries)
                }
            }
        }
    }
    
    func getInventorySummary(forItem itemNaturalKey: String) async throws -> InventorySummaryModel? {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let itemInventories = self.inventories.values.filter { $0.itemNaturalKey == itemNaturalKey }
                    guard !itemInventories.isEmpty else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let summary = InventorySummaryModel(itemNaturalKey: itemNaturalKey, inventories: Array(itemInventories))
                    continuation.resume(returning: summary)
                }
            }
        }
    }
    
    func estimateInventoryValue(defaultPricePerUnit: Double) async throws -> [String: Double] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let groupedByItem = self.inventories.values.grouped(by: \.itemNaturalKey)
                    let values = groupedByItem.mapValues { inventories in
                        inventories.reduce(0.0) { $0 + ($1.quantity * defaultPricePerUnit) }
                    }
                    continuation.resume(returning: values)
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Simulate latency and random failures for realistic testing
    private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        // Simulate random failure if enabled
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockInventoryRepositoryError.simulatedFailure
        }
        
        // Simulate network latency if enabled
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.05) // 10-50ms
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        return try await operation()
    }
    
    /// Basic predicate evaluation for testing (supports common patterns)
    private func evaluatePredicate(_ predicate: NSPredicate, for inventory: InventoryModel) -> Bool {
        let predicateString = predicate.predicateFormat
        
        // Handle common predicate patterns
        if predicateString.contains("itemNaturalKey ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let itemKey = String(afterFirstQuote[..<endRange.lowerBound])
                    return inventory.itemNaturalKey == itemKey
                }
            }
        }
        
        if predicateString.contains("type ==") {
            if let range = predicateString.range(of: "\"") {
                let afterFirstQuote = predicateString[range.upperBound...]
                if let endRange = afterFirstQuote.range(of: "\"") {
                    let type = String(afterFirstQuote[..<endRange.lowerBound])
                    return inventory.type == type
                }
            }
        }
        
        // Default to true for unsupported predicates
        return true
    }
}

// MARK: - Extensions for Collections

extension Collection {
    /// Group collection elements by a key path
    func grouped<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Key: [Element]] {
        return Dictionary(grouping: self, by: { $0[keyPath: keyPath] })
    }
}

// MARK: - Mock Repository Errors

enum MockInventoryRepositoryError: Error, LocalizedError {
    case inventoryNotFound(UUID)
    case inventoryNotFoundForItem(String, String)
    case duplicateId(UUID)
    case simulatedFailure
    
    var errorDescription: String? {
        switch self {
        case .inventoryNotFound(let id):
            return "Inventory not found with ID: \(id)"
        case .inventoryNotFoundForItem(let itemKey, let type):
            return "No inventory found for item: \(itemKey), type: \(type)"
        case .duplicateId(let id):
            return "Inventory already exists with ID: \(id)"
        case .simulatedFailure:
            return "Simulated repository failure for testing"
        }
    }
}