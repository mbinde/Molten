//
//  StockRepository.swift
//  Molten
//
//  Repository for reading stock availability data from the local SQLite database.
//  Returns existing OnlineStockModel types to maintain UI compatibility.
//

import Foundation
import SQLite3

/// Protocol for stock repository operations
@MainActor
protocol StockRepositoryProtocol {
    func getStock(for itemStableId: String) throws -> OnlineStockModel?
    func getStockBulk(for itemStableIds: [String]) throws -> [OnlineStockModel]
}

/// Repository for reading stock data from local SQLite database
@MainActor
class StockRepository: StockRepositoryProtocol {

    private let databaseManager: StockDatabaseManagerProtocol

    init(databaseManager: StockDatabaseManagerProtocol = StockDatabaseManager.shared) {
        self.databaseManager = databaseManager
    }

    /// Get stock availability for a single item
    /// - Parameter itemStableId: The item's stable ID
    /// - Returns: Stock availability data, or nil if not found or no database
    func getStock(for itemStableId: String) throws -> OnlineStockModel? {
        guard databaseManager.databaseExists else {
            return nil  // No database downloaded yet
        }

        return try databaseManager.performDatabaseOperation { db in
            try fetchStock(db: db, itemStableId: itemStableId)
        }
    }

    /// Get stock availability for multiple items
    /// - Parameter itemStableIds: Array of item stable IDs
    /// - Returns: Array of stock availability data (only items found in database)
    func getStockBulk(for itemStableIds: [String]) throws -> [OnlineStockModel] {
        guard !itemStableIds.isEmpty else {
            return []
        }

        guard databaseManager.databaseExists else {
            return []  // No database downloaded yet
        }

        return try databaseManager.performDatabaseOperation { db in
            var results: [OnlineStockModel] = []
            for id in itemStableIds {
                if let stock = try fetchStock(db: db, itemStableId: id) {
                    results.append(stock)
                }
            }
            return results
        }
    }

    // MARK: - Private Helpers

    private func fetchStock(db: OpaquePointer, itemStableId: String) throws -> OnlineStockModel? {
        // First, get all retailer stock entries for this item
        let stockQuery = """
            SELECT retailer_code, stock_status, last_checked, product_url
            FROM stock_status
            WHERE item_stable_id = ?
            """

        var stockStatement: OpaquePointer?
        guard sqlite3_prepare_v2(db, stockQuery, -1, &stockStatement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw StockDatabaseError.queryFailed(error)
        }
        defer { sqlite3_finalize(stockStatement) }

        sqlite3_bind_text(stockStatement, 1, itemStableId, -1, nil)

        var retailers: [RetailerStockModel] = []
        var latestUpdate: Date = .distantPast

        while sqlite3_step(stockStatement) == SQLITE_ROW {
            let retailerCode = String(cString: sqlite3_column_text(stockStatement, 0))
            let stockStatusRaw = String(cString: sqlite3_column_text(stockStatement, 1))
            let lastCheckedStr = String(cString: sqlite3_column_text(stockStatement, 2))
            let productUrl: String? = sqlite3_column_type(stockStatement, 3) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(stockStatement, 3))
                : nil

            // Parse stock status
            let stockStatus = StockStatus(rawValue: stockStatusRaw) ?? .unknown

            // Parse last checked date (ISO8601)
            let lastChecked = ISO8601DateFormatter().date(from: lastCheckedStr) ?? Date()
            if lastChecked > latestUpdate {
                latestUpdate = lastChecked
            }

            // Get retailer name from retailers table
            let retailerName = try getRetailerName(db: db, code: retailerCode) ?? retailerCode

            // Get price options for this item/retailer
            let priceOptions = try getPriceOptions(db: db, itemStableId: itemStableId, retailerCode: retailerCode)

            // Use first available price option for the retailer model
            let firstOption = priceOptions.first
            let price: Decimal? = firstOption.flatMap { $0.price.map { Decimal($0) } }
            let priceUnit = firstOption?.priceUnit
            let currency = firstOption?.currency
            let quantity = priceOptions.filter { $0.available }.count

            let retailerStock = RetailerStockModel(
                retailerCode: retailerCode,
                retailerName: retailerName,
                stockStatus: stockStatus,
                lastChecked: lastChecked,
                productUrl: productUrl,
                price: price,
                priceUnit: priceUnit,
                currency: currency,
                quantityAvailable: quantity > 0 ? quantity : nil
            )
            retailers.append(retailerStock)
        }

        guard !retailers.isEmpty else {
            return nil  // Item not in stock database
        }

        return OnlineStockModel(
            itemStableId: itemStableId,
            retailers: retailers,
            lastUpdated: latestUpdate
        )
    }

    private func getRetailerName(db: OpaquePointer, code: String) throws -> String? {
        let query = "SELECT name FROM retailers WHERE code = ?"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, code, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return String(cString: sqlite3_column_text(statement, 0))
    }

    private func getPriceOptions(db: OpaquePointer, itemStableId: String, retailerCode: String) throws -> [PriceOption] {
        let query = """
            SELECT variant_id, variant_title, price, price_unit, currency, available
            FROM price_options
            WHERE item_stable_id = ? AND retailer_code = ?
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []  // Table might not exist, return empty
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, itemStableId, -1, nil)
        sqlite3_bind_text(statement, 2, retailerCode, -1, nil)

        var options: [PriceOption] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let variantId: String? = sqlite3_column_type(statement, 0) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 0))
                : nil
            let variantTitle: String? = sqlite3_column_type(statement, 1) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 1))
                : nil
            let price: Double? = sqlite3_column_type(statement, 2) != SQLITE_NULL
                ? sqlite3_column_double(statement, 2)
                : nil
            let priceUnit: String? = sqlite3_column_type(statement, 3) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 3))
                : nil
            let currency: String? = sqlite3_column_type(statement, 4) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 4))
                : nil
            let available = sqlite3_column_int(statement, 5) != 0

            options.append(PriceOption(
                variantId: variantId,
                variantTitle: variantTitle,
                price: price,
                priceUnit: priceUnit,
                currency: currency,
                available: available
            ))
        }

        return options
    }
}

// MARK: - Internal Types

private struct PriceOption {
    let variantId: String?
    let variantTitle: String?
    let price: Double?
    let priceUnit: String?
    let currency: String?
    let available: Bool
}
