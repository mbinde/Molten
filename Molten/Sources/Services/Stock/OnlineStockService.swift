//
//  OnlineStockService.swift
//  Molten
//
//  Service for fetching and caching online stock availability data
//

import Foundation
import os

/// Service that provides online stock availability data with caching
@MainActor
class OnlineStockService {
    private let apiClient: OnlineStockAPIClientProtocol
    private let cache: OnlineStockCache
    private let log = Logger(subsystem: "Molten", category: "OnlineStockService")

    /// Initialize the service
    /// - Parameters:
    ///   - apiClient: API client for fetching stock data (defaults to production client)
    ///   - cache: Cache for storing fetched data (defaults to new cache instance)
    init(
        apiClient: OnlineStockAPIClientProtocol? = nil,
        cache: OnlineStockCache = OnlineStockCache()
    ) {
        self.apiClient = apiClient ?? OnlineStockAPIClient()
        self.cache = cache
    }

    /// Get stock availability for a single item
    /// - Parameters:
    ///   - itemStableId: The item's stable ID
    ///   - forceRefresh: If true, bypasses cache and fetches fresh data
    /// - Returns: Stock availability data
    func getStock(for itemStableId: String, forceRefresh: Bool = false) async throws -> OnlineStockModel {
        // Check cache first (unless force refresh)
        if !forceRefresh, let cached = cache.get(itemStableId) {
            log.debug("Cache hit for item: \(itemStableId)")
            return cached
        }

        // Fetch from API
        log.debug("Fetching stock from API for item: \(itemStableId)")
        let stock = try await apiClient.fetchStock(for: itemStableId)
        cache.set(stock)
        return stock
    }

    /// Get stock availability for multiple items
    /// - Parameters:
    ///   - itemStableIds: Array of item stable IDs
    ///   - forceRefresh: If true, bypasses cache and fetches all items fresh
    /// - Returns: Array of stock availability data
    func getStockBulk(for itemStableIds: [String], forceRefresh: Bool = false) async throws -> [OnlineStockModel] {
        guard !itemStableIds.isEmpty else {
            return []
        }

        var results: [OnlineStockModel] = []
        var toFetch: [String] = []

        // Check cache for each item (unless force refresh)
        if !forceRefresh {
            for id in itemStableIds {
                if let cached = cache.get(id) {
                    results.append(cached)
                } else {
                    toFetch.append(id)
                }
            }
        } else {
            toFetch = itemStableIds
        }

        // Fetch missing items from API
        if !toFetch.isEmpty {
            log.debug("Bulk fetching \(toFetch.count) items from API")
            let fetched = try await apiClient.fetchStockBulk(for: toFetch)
            for stock in fetched {
                cache.set(stock)
                results.append(stock)
            }
        }

        return results
    }

    /// Invalidate cached data for a specific item
    /// - Parameter itemStableId: The item's stable ID
    func invalidateCache(for itemStableId: String) {
        cache.invalidate(itemStableId)
    }

    /// Invalidate all cached stock data
    func invalidateAllCache() {
        cache.invalidateAll()
    }
}
