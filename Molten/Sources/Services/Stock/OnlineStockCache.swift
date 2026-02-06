//
//  OnlineStockCache.swift
//  Molten
//
//  In-memory cache for online stock availability data
//

import Foundation

/// In-memory cache for online stock availability data
/// Since stock data is updated daily on the backend, we can cache aggressively
@MainActor
class OnlineStockCache {
    private var cache: [String: CachedStock] = [:]
    private let maxAge: TimeInterval

    /// Cached stock data with fetch timestamp
    struct CachedStock {
        let data: OnlineStockModel
        let fetchedAt: Date

        func isExpired(maxAge: TimeInterval) -> Bool {
            Date().timeIntervalSince(fetchedAt) > maxAge
        }
    }

    /// Initialize cache with optional max age
    /// - Parameter maxAge: Time in seconds before cached data expires (default 4 hours)
    init(maxAge: TimeInterval = 3600 * 4) {
        self.maxAge = maxAge
    }

    /// Get cached stock data for an item
    /// - Parameter itemStableId: The item's stable ID
    /// - Returns: Cached stock data if available and not expired, nil otherwise
    func get(_ itemStableId: String) -> OnlineStockModel? {
        guard let cached = cache[itemStableId] else { return nil }
        if cached.isExpired(maxAge: maxAge) {
            cache.removeValue(forKey: itemStableId)
            return nil
        }
        return cached.data
    }

    /// Store stock data in cache
    /// - Parameter stock: The stock data to cache
    func set(_ stock: OnlineStockModel) {
        cache[stock.itemStableId] = CachedStock(data: stock, fetchedAt: Date())
    }

    /// Remove a specific item from cache
    /// - Parameter itemStableId: The item's stable ID to invalidate
    func invalidate(_ itemStableId: String) {
        cache.removeValue(forKey: itemStableId)
    }

    /// Remove all items from cache
    func invalidateAll() {
        cache.removeAll()
    }
}
