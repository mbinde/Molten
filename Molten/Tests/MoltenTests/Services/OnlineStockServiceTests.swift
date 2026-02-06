//
//  OnlineStockServiceTests.swift
//  MoltenTests
//
//  Tests for online stock service and cache
//

import Foundation
import Testing

@testable import Molten

// MARK: - OnlineStockCache Tests

@Suite("OnlineStockCache Tests")
@MainActor
struct OnlineStockCacheTests {

    @Test("Cache returns nil for missing items")
    func testCacheMiss() {
        let cache = OnlineStockCache()
        let result = cache.get("nonexistent")
        #expect(result == nil)
    }

    @Test("Cache returns stored item")
    func testCacheHit() {
        let cache = OnlineStockCache()
        let stock = createTestStock(itemStableId: "test123")

        cache.set(stock)
        let result = cache.get("test123")

        #expect(result != nil)
        #expect(result?.itemStableId == "test123")
    }

    @Test("Cache invalidates specific item")
    func testInvalidateItem() {
        let cache = OnlineStockCache()
        cache.set(createTestStock(itemStableId: "item1"))
        cache.set(createTestStock(itemStableId: "item2"))

        cache.invalidate("item1")

        #expect(cache.get("item1") == nil)
        #expect(cache.get("item2") != nil)
    }

    @Test("Cache invalidates all items")
    func testInvalidateAll() {
        let cache = OnlineStockCache()
        cache.set(createTestStock(itemStableId: "item1"))
        cache.set(createTestStock(itemStableId: "item2"))
        cache.set(createTestStock(itemStableId: "item3"))

        cache.invalidateAll()

        #expect(cache.get("item1") == nil)
        #expect(cache.get("item2") == nil)
        #expect(cache.get("item3") == nil)
    }

    @Test("Cache overwrites existing item")
    func testOverwrite() {
        let cache = OnlineStockCache()

        let oldStock = createTestStock(itemStableId: "test", inStockCount: 1)
        let newStock = createTestStock(itemStableId: "test", inStockCount: 3)

        cache.set(oldStock)
        cache.set(newStock)

        let result = cache.get("test")
        #expect(result?.retailers.count == 3)
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

// MARK: - OnlineStockService Tests

@Suite("OnlineStockService Tests")
@MainActor
struct OnlineStockServiceTests {

    @Test("Service returns cached data when available")
    func testCacheHit() async throws {
        let mockClient = MockOnlineStockAPIClient()
        let cache = OnlineStockCache()

        // Pre-populate cache
        let cachedStock = createTestStock(itemStableId: "cached123")
        cache.set(cachedStock)

        let service = OnlineStockService(apiClient: mockClient, cache: cache)
        let result = try await service.getStock(for: "cached123")

        #expect(result.itemStableId == "cached123")
        #expect(mockClient.fetchStockCallCount == 0, "Should not call API when cached")
    }

    @Test("Service fetches from API when cache miss")
    func testCacheMiss() async throws {
        let mockClient = MockOnlineStockAPIClient()
        mockClient.mockStockResponse = createTestStock(itemStableId: "api123")

        let service = OnlineStockService(apiClient: mockClient, cache: OnlineStockCache())
        let result = try await service.getStock(for: "api123")

        #expect(result.itemStableId == "api123")
        #expect(mockClient.fetchStockCallCount == 1)
    }

    @Test("Service bypasses cache when forceRefresh is true")
    func testForceRefresh() async throws {
        let mockClient = MockOnlineStockAPIClient()
        mockClient.mockStockResponse = createTestStock(itemStableId: "test", inStockCount: 5)

        let cache = OnlineStockCache()
        cache.set(createTestStock(itemStableId: "test", inStockCount: 2))

        let service = OnlineStockService(apiClient: mockClient, cache: cache)
        let result = try await service.getStock(for: "test", forceRefresh: true)

        #expect(result.retailers.count == 5, "Should have fresh data from API")
        #expect(mockClient.fetchStockCallCount == 1)
    }

    @Test("Service caches fetched data")
    func testCachesAfterFetch() async throws {
        let mockClient = MockOnlineStockAPIClient()
        mockClient.mockStockResponse = createTestStock(itemStableId: "new123")

        let cache = OnlineStockCache()
        let service = OnlineStockService(apiClient: mockClient, cache: cache)

        // First call - fetches from API
        _ = try await service.getStock(for: "new123")
        #expect(mockClient.fetchStockCallCount == 1)

        // Second call - should use cache
        _ = try await service.getStock(for: "new123")
        #expect(mockClient.fetchStockCallCount == 1, "Should use cached data")
    }

    @Test("Service bulk fetch uses cache for available items")
    func testBulkFetchWithPartialCache() async throws {
        let mockClient = MockOnlineStockAPIClient()
        mockClient.mockBulkResponse = [
            createTestStock(itemStableId: "item2"),
            createTestStock(itemStableId: "item3")
        ]

        let cache = OnlineStockCache()
        cache.set(createTestStock(itemStableId: "item1"))

        let service = OnlineStockService(apiClient: mockClient, cache: cache)
        let results = try await service.getStockBulk(for: ["item1", "item2", "item3"])

        #expect(results.count == 3)
        #expect(mockClient.fetchStockBulkCallCount == 1)
        // Should only request items not in cache
        #expect(mockClient.lastBulkRequest == ["item2", "item3"])
    }

    @Test("Service bulk fetch with forceRefresh fetches all items")
    func testBulkFetchForceRefresh() async throws {
        let mockClient = MockOnlineStockAPIClient()
        mockClient.mockBulkResponse = [
            createTestStock(itemStableId: "item1"),
            createTestStock(itemStableId: "item2")
        ]

        let cache = OnlineStockCache()
        cache.set(createTestStock(itemStableId: "item1"))

        let service = OnlineStockService(apiClient: mockClient, cache: cache)
        let results = try await service.getStockBulk(for: ["item1", "item2"], forceRefresh: true)

        #expect(results.count == 2)
        #expect(mockClient.lastBulkRequest == ["item1", "item2"])
    }

    @Test("Service handles empty bulk request")
    func testEmptyBulkRequest() async throws {
        let mockClient = MockOnlineStockAPIClient()
        let service = OnlineStockService(apiClient: mockClient, cache: OnlineStockCache())

        let results = try await service.getStockBulk(for: [])

        #expect(results.isEmpty)
        #expect(mockClient.fetchStockBulkCallCount == 0)
    }

    @Test("Service bulk fetch with all items cached skips API call")
    func testBulkFetchAllCached() async throws {
        let mockClient = MockOnlineStockAPIClient()

        let cache = OnlineStockCache()
        cache.set(createTestStock(itemStableId: "item1"))
        cache.set(createTestStock(itemStableId: "item2"))

        let service = OnlineStockService(apiClient: mockClient, cache: cache)
        let results = try await service.getStockBulk(for: ["item1", "item2"])

        #expect(results.count == 2)
        #expect(mockClient.fetchStockBulkCallCount == 0, "Should not call API when all items cached")
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

// MARK: - Mock API Client

@MainActor
class MockOnlineStockAPIClient: OnlineStockAPIClientProtocol {
    var mockStockResponse: OnlineStockModel?
    var mockBulkResponse: [OnlineStockModel] = []
    var mockError: Error?

    var fetchStockCallCount = 0
    var fetchStockBulkCallCount = 0
    var lastBulkRequest: [String]?

    func fetchStock(for itemStableId: String) async throws -> OnlineStockModel {
        fetchStockCallCount += 1

        if let error = mockError {
            throw error
        }

        guard let response = mockStockResponse else {
            throw OnlineStockAPIError.itemNotFound
        }

        return response
    }

    func fetchStockBulk(for itemStableIds: [String]) async throws -> [OnlineStockModel] {
        fetchStockBulkCallCount += 1
        lastBulkRequest = itemStableIds

        if let error = mockError {
            throw error
        }

        return mockBulkResponse
    }
}
