//
//  MockItemMinimumRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/14/25.
//

import Foundation

/// Mock implementation of ItemMinimumRepository for testing
class MockItemMinimumRepository: ItemMinimumRepository {
    
    // MARK: - Test Data Storage
    
    private var minimums: [UUID: ItemMinimumModel] = [:]
    private let queue = DispatchQueue(label: "mock.minimum.repository", attributes: .concurrent)
    
    // MARK: - Test Configuration
    
    var simulateLatency: Bool = false
    var shouldRandomlyFail: Bool = false
    var failureProbability: Double = 0.1
    
    // MARK: - Test State Management
    
    func clearAllData() {
        queue.async(flags: .barrier) {
            self.minimums.removeAll()
        }
    }
    
    // MARK: - Basic CRUD Operations
    
    func createMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.minimums[minimum.id] = minimum
                    continuation.resume(returning: minimum)
                }
            }
        }
    }
    
    func createMinimums(_ minimums: [ItemMinimumModel]) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    for minimum in minimums {
                        self.minimums[minimum.id] = minimum
                    }
                    continuation.resume(returning: minimums)
                }
            }
        }
    }
    
    func updateMinimum(_ minimum: ItemMinimumModel) async throws -> ItemMinimumModel {
        return try await simulateOperation {
            return try await withCheckedThrowingContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    guard self.minimums[minimum.id] != nil else {
                        continuation.resume(throwing: MockRepositoryError.itemNotFound(minimum.id.uuidString))
                        return
                    }
                    self.minimums[minimum.id] = minimum
                    continuation.resume(returning: minimum)
                }
            }
        }
    }
    
    func deleteMinimum(id: UUID) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.minimums.removeValue(forKey: id)
                    continuation.resume()
                }
            }
        }
    }
    
    func getMinimum(id: UUID) async throws -> ItemMinimumModel? {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: self.minimums[id])
                }
            }
        }
    }
    
    // MARK: - Query Operations
    
    func getMinimums(forItem naturalKey: String) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filtered = self.minimums.values.filter { $0.itemNaturalKey == naturalKey }
                    continuation.resume(returning: Array(filtered))
                }
            }
        }
    }
    
    func getMinimums(forStore storeName: String) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filtered = self.minimums.values.filter { $0.store == storeName }
                    continuation.resume(returning: Array(filtered))
                }
            }
        }
    }
    
    func getMinimums(forType typeName: String) async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let filtered = self.minimums.values.filter { $0.type == typeName }
                    continuation.resume(returning: Array(filtered))
                }
            }
        }
    }
    
    func getDistinctStores() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let stores = Set(self.minimums.values.map { $0.store })
                    continuation.resume(returning: Array(stores).sorted())
                }
            }
        }
    }
    
    func getDistinctTypes() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let types = Set(self.minimums.values.map { $0.type })
                    continuation.resume(returning: Array(types).sorted())
                }
            }
        }
    }
    
    func getItemsWithMinimums() async throws -> [String] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    let naturalKeys = Set(self.minimums.values.map { $0.itemNaturalKey })
                    continuation.resume(returning: Array(naturalKeys).sorted())
                }
            }
        }
    }
    
    func getAllMinimums() async throws -> [ItemMinimumModel] {
        return try await simulateOperation {
            return await withCheckedContinuation { continuation in
                self.queue.async {
                    continuation.resume(returning: Array(self.minimums.values))
                }
            }
        }
    }
    
    // MARK: - Shopping List Operations
    
    func getShoppingList(forStore storeName: String) async throws -> [ItemMinimumModel] {
        return try await getMinimums(forStore: storeName)
    }
    
    func getItemsBelowMinimum() async throws -> [String] {
        return try await simulateOperation {
            // This would require comparison with current inventory
            // For mock purposes, return empty array
            return []
        }
    }
    
    // MARK: - Batch Operations
    
    func setMinimum(forItem naturalKey: String, type: String, quantity: Double, store: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    // Remove existing minimum for this item/type combination
                    self.minimums = self.minimums.filter { _, minimum in
                        !(minimum.itemNaturalKey == naturalKey && minimum.type == type)
                    }
                    
                    // Add new minimum
                    let minimum = ItemMinimumModel(
                        itemNaturalKey: naturalKey,
                        quantity: quantity,
                        type: type,
                        store: store
                    )
                    self.minimums[minimum.id] = minimum
                    
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteAllMinimums(forItem naturalKey: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.minimums = self.minimums.filter { _, minimum in
                        minimum.itemNaturalKey != naturalKey
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteAllMinimums(forStore storeName: String) async throws {
        try await simulateOperation {
            await withCheckedContinuation { continuation in
                self.queue.async(flags: .barrier) {
                    self.minimums = self.minimums.filter { _, minimum in
                        minimum.store != storeName
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func simulateOperation<T>(_ operation: () async throws -> T) async throws -> T {
        if shouldRandomlyFail && Double.random(in: 0...1) < failureProbability {
            throw MockRepositoryError.simulatedFailure
        }
        
        if simulateLatency {
            let delay = Double.random(in: 0.01...0.1)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        return try await operation()
    }
}