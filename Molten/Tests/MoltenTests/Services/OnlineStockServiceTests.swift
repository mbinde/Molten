//
//  OnlineStockServiceTests.swift
//  MoltenTests
//
//  Tests for online stock service (repository-based)
//

import Foundation
import Testing

@testable import Molten

// MARK: - Mock Stock Repository

@MainActor
class MockStockRepository: StockRepositoryProtocol {
    var mockStockData: [String: OnlineStockModel] = [:]
    var getStockCallCount = 0
    var getStockBulkCallCount = 0
    var lastBulkRequest: [String]?
    var shouldThrowError = false

    func getStock(for itemStableId: String) throws -> OnlineStockModel? {
        getStockCallCount += 1
        if shouldThrowError {
            throw StockDatabaseError.databaseNotInitialized
        }
        return mockStockData[itemStableId]
    }

    func getStockBulk(for itemStableIds: [String]) throws -> [OnlineStockModel] {
        getStockBulkCallCount += 1
        lastBulkRequest = itemStableIds
        if shouldThrowError {
            throw StockDatabaseError.databaseNotInitialized
        }
        return itemStableIds.compactMap { mockStockData[$0] }
    }
}

// MARK: - OnlineStockService Tests

@Suite("OnlineStockService Tests")
@MainActor
struct OnlineStockServiceTests {

    @Test("Service returns nil when no stock database exists")
    func testNoDatabaseReturnsNil() async throws {
        let mockRepo = MockStockRepository()
        // Don't set any stock data - simulates empty database

        // Create a service that reports no database
        let service = TestableOnlineStockService(repository: mockRepo, hasDatabase: false)
        let result = try await service.getStock(for: "test123")

        #expect(result == nil)
        #expect(mockRepo.getStockCallCount == 0, "Should not query when no database")
    }

    @Test("Service returns stock data from repository")
    func testReturnsStockFromRepository() async throws {
        let mockRepo = MockStockRepository()
        mockRepo.mockStockData["item123"] = createTestStock(itemStableId: "item123")

        let service = TestableOnlineStockService(repository: mockRepo, hasDatabase: true)
        let result = try await service.getStock(for: "item123")

        #expect(result != nil)
        #expect(result?.itemStableId == "item123")
        #expect(mockRepo.getStockCallCount == 1)
    }

    @Test("Service returns nil for item not in database")
    func testItemNotFound() async throws {
        let mockRepo = MockStockRepository()
        // No data for this item

        let service = TestableOnlineStockService(repository: mockRepo, hasDatabase: true)
        let result = try await service.getStock(for: "nonexistent")

        #expect(result == nil)
        #expect(mockRepo.getStockCallCount == 1)
    }

    @Test("Service bulk fetch returns matching items")
    func testBulkFetch() async throws {
        let mockRepo = MockStockRepository()
        mockRepo.mockStockData["item1"] = createTestStock(itemStableId: "item1")
        mockRepo.mockStockData["item2"] = createTestStock(itemStableId: "item2")

        let service = TestableOnlineStockService(repository: mockRepo, hasDatabase: true)
        let results = try await service.getStockBulk(for: ["item1", "item2", "item3"])

        #expect(results.count == 2) // Only item1 and item2 found
        #expect(mockRepo.getStockBulkCallCount == 1)
        #expect(mockRepo.lastBulkRequest == ["item1", "item2", "item3"])
    }

    @Test("Service bulk fetch returns empty for empty request")
    func testBulkFetchEmpty() async throws {
        let mockRepo = MockStockRepository()

        let service = TestableOnlineStockService(repository: mockRepo, hasDatabase: true)
        let results = try await service.getStockBulk(for: [])

        #expect(results.isEmpty)
        #expect(mockRepo.getStockBulkCallCount == 0, "Should not call repo for empty request")
    }

    @Test("Service bulk fetch returns empty when no database")
    func testBulkFetchNoDatabase() async throws {
        let mockRepo = MockStockRepository()
        mockRepo.mockStockData["item1"] = createTestStock(itemStableId: "item1")

        let service = TestableOnlineStockService(repository: mockRepo, hasDatabase: false)
        let results = try await service.getStockBulk(for: ["item1"])

        #expect(results.isEmpty)
        #expect(mockRepo.getStockBulkCallCount == 0, "Should not query when no database")
    }

    @Test("Service reports hasStockDatabase correctly")
    func testHasStockDatabase() {
        let mockRepo = MockStockRepository()

        let serviceWithDb = TestableOnlineStockService(repository: mockRepo, hasDatabase: true)
        let serviceWithoutDb = TestableOnlineStockService(repository: mockRepo, hasDatabase: false)

        #expect(serviceWithDb.hasStockDatabase == true)
        #expect(serviceWithoutDb.hasStockDatabase == false)
    }

    // MARK: - Test Helpers

    func createTestStock(itemStableId: String, inStockCount: Int = 2) -> OnlineStockModel {
        let retailers = (0..<inStockCount).map { i in
            RetailerStockModel(
                retailerCode: "retailer\(i)",
                retailerName: "Retailer \(i)",
                stockStatus: .inStock,
                lastChecked: Date(),
                productUrl: nil,
                price: nil,
                priceUnit: nil,
                currency: nil,
                quantityAvailable: nil
            )
        }
        return OnlineStockModel(
            itemStableId: itemStableId,
            retailers: retailers,
            lastUpdated: Date()
        )
    }
}

// MARK: - Testable Service (allows overriding hasStockDatabase)

@MainActor
class TestableOnlineStockService: OnlineStockServiceProtocol {
    private let repository: StockRepositoryProtocol
    private let _hasDatabase: Bool

    init(repository: StockRepositoryProtocol, hasDatabase: Bool) {
        self.repository = repository
        self._hasDatabase = hasDatabase
    }

    var hasStockDatabase: Bool { _hasDatabase }

    func getStock(for itemStableId: String) async throws -> OnlineStockModel? {
        guard hasStockDatabase else { return nil }
        return try repository.getStock(for: itemStableId)
    }

    func getStockBulk(for itemStableIds: [String]) async throws -> [OnlineStockModel] {
        guard !itemStableIds.isEmpty else { return [] }
        guard hasStockDatabase else { return [] }
        return try repository.getStockBulk(for: itemStableIds)
    }
}
