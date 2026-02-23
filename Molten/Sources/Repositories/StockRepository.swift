//
//  StockRepository.swift
//  Molten
//
//  Repository for reading stock availability data from the local SQLite database.
//  Returns existing OnlineStockModel types to maintain UI compatibility.
//

import Foundation
import SQLite3

// SQLITE_TRANSIENT tells SQLite to make its own copy of the string
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Protocol for stock repository operations
@MainActor
protocol StockRepositoryProtocol {
    func getStock(for itemStableId: String) throws -> OnlineStockModel?
    func getStockBulk(for itemStableIds: [String]) throws -> [OnlineStockModel]
    func getInStockItemIds() throws -> Set<String>
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

    /// Get all item stable IDs that have stock available at any retailer
    /// - Returns: Set of item stable IDs with in_stock status
    func getInStockItemIds() throws -> Set<String> {
        guard databaseManager.databaseExists else {
            return []  // No database downloaded yet
        }

        return try databaseManager.performDatabaseOperation { db in
            // Single efficient query to get all items with in_stock status
            let query = """
                SELECT DISTINCT item_stable_id
                FROM stock_status
                WHERE stock_status = 'in_stock'
                """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                throw StockDatabaseError.queryFailed(error)
            }
            defer { sqlite3_finalize(statement) }

            var result = Set<String>()
            while sqlite3_step(statement) == SQLITE_ROW {
                let itemId = String(cString: sqlite3_column_text(statement, 0))
                result.insert(itemId)
            }
            return result
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

        // Use withCString to ensure proper memory lifetime for the string
        _ = itemStableId.withCString { cString in
            sqlite3_bind_text(stockStatement, 1, cString, -1, SQLITE_TRANSIENT)
        }

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

            // Convert to model price options
            let modelPriceOptions = priceOptions.map { opt in
                PriceOptionModel(
                    variantId: opt.variantId,
                    variantTitle: opt.variantTitle,
                    price: opt.price.map { Decimal($0) },
                    priceUnit: opt.priceUnit,
                    currency: opt.currency,
                    available: opt.available
                )
            }

            let quantity = priceOptions.filter { $0.available }.count

            let retailerStock = RetailerStockModel(
                retailerCode: retailerCode,
                retailerName: retailerName,
                stockStatus: stockStatus,
                lastChecked: lastChecked,
                productUrl: productUrl,
                priceOptions: modelPriceOptions,
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

        _ = code.withCString { cString in
            sqlite3_bind_text(statement, 1, cString, -1, SQLITE_TRANSIENT)
        }

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

        _ = itemStableId.withCString { cString in
            sqlite3_bind_text(statement, 1, cString, -1, SQLITE_TRANSIENT)
        }
        _ = retailerCode.withCString { cString in
            sqlite3_bind_text(statement, 2, cString, -1, SQLITE_TRANSIENT)
        }

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
