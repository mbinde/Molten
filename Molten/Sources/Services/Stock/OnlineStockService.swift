//
//  OnlineStockService.swift
//  Molten
//
//  Service for providing online stock availability data.
//  Now reads from local SQLite database synced periodically from server.
//

import Foundation
import os

/// Protocol for online stock service operations
@MainActor
protocol OnlineStockServiceProtocol {
    func getStock(for itemStableId: String) async throws -> OnlineStockModel?
    func getStockBulk(for itemStableIds: [String]) async throws -> [OnlineStockModel]
    func getInStockItemIds() async throws -> Set<String>
    var hasStockDatabase: Bool { get }
}

/// Service that provides online stock availability data from local database
@MainActor
class OnlineStockService: OnlineStockServiceProtocol {
    private let repository: StockRepositoryProtocol
    private let log = Logger(subsystem: "Molten", category: "OnlineStockService")

    /// Initialize the service
    /// - Parameter repository: Repository for reading stock data from local database
    init(repository: StockRepositoryProtocol? = nil) {
        self.repository = repository ?? StockRepository()
    }

    /// Whether we have a stock database downloaded
    var hasStockDatabase: Bool {
        StockUpdatePreferences.shared.hasStockDatabase
    }

    /// Get stock availability for a single item
    /// - Parameter itemStableId: The item's stable ID
    /// - Returns: Stock availability data, or nil if not found or no database
    func getStock(for itemStableId: String) async throws -> OnlineStockModel? {
        guard hasStockDatabase else {
            log.debug("No stock database available yet")
            return nil
        }

        do {
            let stock = try repository.getStock(for: itemStableId)
            if stock != nil {
                log.debug("Found stock data for item: \(itemStableId)")
            } else {
                log.debug("No stock data found for item: \(itemStableId)")
            }
            return stock
        } catch StockDatabaseError.databaseNotInitialized {
            // Database file missing or not initialized - treat as no database
            log.debug("Stock database not initialized, treating as unavailable")
            return nil
        } catch {
            log.error("Error reading stock data: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get stock availability for multiple items
    /// - Parameter itemStableIds: Array of item stable IDs
    /// - Returns: Array of stock availability data (only items found in database)
    func getStockBulk(for itemStableIds: [String]) async throws -> [OnlineStockModel] {
        guard !itemStableIds.isEmpty else {
            return []
        }

        guard hasStockDatabase else {
            log.debug("No stock database available yet")
            return []
        }

        do {
            let results = try repository.getStockBulk(for: itemStableIds)
            log.debug("Found stock data for \(results.count) of \(itemStableIds.count) items")
            return results
        } catch StockDatabaseError.databaseNotInitialized {
            // Database file missing or not initialized - treat as no database
            log.debug("Stock database not initialized, treating as unavailable")
            return []
        } catch {
            log.error("Error reading bulk stock data: \(error.localizedDescription)")
            throw error
        }
    }

    /// Get all item stable IDs that have stock available at any retailer
    /// - Returns: Set of item stable IDs with in_stock status
    func getInStockItemIds() async throws -> Set<String> {
        guard hasStockDatabase else {
            log.debug("No stock database available yet")
            return []
        }

        do {
            let results = try repository.getInStockItemIds()
            log.debug("Found \(results.count) items with online stock")
            return results
        } catch StockDatabaseError.databaseNotInitialized {
            log.debug("Stock database not initialized, treating as unavailable")
            return []
        } catch {
            log.error("Error reading in-stock item IDs: \(error.localizedDescription)")
            throw error
        }
    }
}
