//
//  BaseSQLiteCatalogItemRepository.swift
//  Molten
//
//  Generic base class for SQLite catalog item repositories
//  Eliminates duplication across glass/coating/tool repositories
//

import Foundation
import SQLite3

// MARK: - Errors

enum SQLiteError: LocalizedError {
    case queryFailed(String)
    case invalidData(String)
    case writeOperationNotSupported(String)

    var errorDescription: String? {
        switch self {
        case .queryFailed(let message):
            return "SQLite query failed: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .writeOperationNotSupported(let message):
            return "Write operation not supported: \(message)"
        }
    }
}

// MARK: - Base Repository

/// Base class for SQLite-based catalog item repositories
/// Provides common query logic - subclasses provide item-specific parsing and table names
class BaseSQLiteCatalogItemRepository<ItemType: CatalogItem>: CatalogItemRepository, @unchecked Sendable {

    // MARK: - Properties

    let databaseManager: CatalogDatabaseManagerProtocol
    let tableName: String
    let orderByColumns: String

    // MARK: - Initialization

    nonisolated init(databaseManager: CatalogDatabaseManagerProtocol, tableName: String, orderByColumns: String = "manufacturer, name") {
        self.databaseManager = databaseManager
        self.tableName = tableName
        self.orderByColumns = orderByColumns
    }

    // MARK: - Abstract Methods (Must Override)

    /// Parse an item from a SQLite row - MUST be overridden by subclasses
    /// - Parameter statement: SQLite statement positioned at a result row
    /// - Returns: Parsed ItemType instance
    /// - Throws: SQLiteError if data is invalid or missing
    nonisolated func parseItem(from statement: OpaquePointer) throws -> ItemType {
        fatalError("parseItem(from:) must be overridden by subclass")
    }

    // MARK: - Read Operations (Common Implementation)

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ItemType] {
        // For simplicity, fetch all and filter in memory if predicate provided
        let query = "SELECT * FROM \(tableName) ORDER BY \(orderByColumns)"
        let items = try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query)
        }

        if let predicate = predicate {
            return items.filter { predicate.evaluate(with: $0) }
        }

        return items
    }

    func fetchItem(byStableId stableId: String) async throws -> ItemType? {
        let query = "SELECT * FROM \(tableName) WHERE stable_id = ? LIMIT 1"
        let items = try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [stableId])
        }
        return items.first
    }

    func searchItems(text: String) async throws -> [ItemType] {
        let searchPattern = "%\(text)%"
        let query = """
            SELECT * FROM \(tableName)
            WHERE name LIKE ? OR manufacturer LIKE ?
            ORDER BY \(orderByColumns)
            """

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [searchPattern, searchPattern])
        }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [ItemType] {
        let query = "SELECT * FROM \(tableName) WHERE manufacturer = ? ORDER BY \(orderByColumns)"

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [manufacturer])
        }
    }

    func fetchItems(byStatus status: String) async throws -> [ItemType] {
        // Default implementation - can be overridden if table has status column
        let query = "SELECT * FROM \(tableName) WHERE status = ? ORDER BY \(orderByColumns)"

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [status])
        }
    }

    func getDistinctManufacturers() async throws -> [String] {
        let query = "SELECT DISTINCT manufacturer FROM \(tableName) ORDER BY manufacturer"

        return try databaseManager.performDatabaseOperation { db in
            try executeDistinctStrings(db: db, query: query, columnIndex: 0)
        }
    }

    func getDistinctStatuses() async throws -> [String] {
        // Default implementation - can be overridden if table has status column
        let query = "SELECT DISTINCT status FROM \(tableName) ORDER BY status"

        return try databaseManager.performDatabaseOperation { db in
            try executeDistinctStrings(db: db, query: query, columnIndex: 0)
        }
    }

    func stableIdExists(_ stableId: String) async throws -> Bool {
        let item = try await fetchItem(byStableId: stableId)
        return item != nil
    }

    func generateNextNaturalKey(manufacturer: String, sku: String?) async throws -> String {
        // For bundled catalog, this shouldn't be needed
        // But provide a basic implementation for compatibility
        let baseKey = "\(manufacturer)-\(sku ?? "unknown")"
        let existingItems = try await fetchItems(byManufacturer: manufacturer)
        return "\(baseKey)-\(String(format: "%03d", existingItems.count))"
    }

    // MARK: - Write Operations (Not Supported - Read-Only Catalog)

    func createItem(_ item: ItemType) async throws -> ItemType {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func createItems(_ items: [ItemType]) async throws -> [ItemType] {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func updateItem(_ item: ItemType) async throws -> ItemType {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func deleteItem(stableId: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func deleteItems(stableIds: [String]) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    // MARK: - Helper Methods

    /// Execute a SELECT query and return ItemType instances
    /// - Parameters:
    ///   - db: SQLite database handle
    ///   - query: SQL query string
    ///   - parameters: Query parameters to bind
    /// - Returns: Array of parsed ItemType instances
    /// - Throws: SQLiteError on query failure or parse errors
    func executeQuery(db: OpaquePointer, query: String, parameters: [String] = []) throws -> [ItemType] {
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        defer {
            sqlite3_finalize(statement)
        }

        // Bind parameters
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, parameter) in parameters.enumerated() {
            let result = sqlite3_bind_text(statement, Int32(index + 1), parameter, -1, SQLITE_TRANSIENT)
            guard result == SQLITE_OK else {
                throw SQLiteError.queryFailed("Failed to bind parameter \(index): \(String(cString: sqlite3_errmsg(db)))")
            }
        }

        // Execute query and collect results
        var items: [ItemType] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let item = try parseItem(from: statement!)
            items.append(item)
        }

        return items
    }

    /// Execute a query that returns distinct string values
    /// - Parameters:
    ///   - db: SQLite database handle
    ///   - query: SQL query string (must SELECT a single string column)
    ///   - columnIndex: Column index to extract (default 0)
    /// - Returns: Array of distinct strings
    /// - Throws: SQLiteError on query failure
    func executeDistinctStrings(db: OpaquePointer, query: String, columnIndex: Int32 = 0) throws -> [String] {
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        defer {
            sqlite3_finalize(statement)
        }

        var results: [String] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, columnIndex) {
                results.append(String(cString: text))
            }
        }

        return results
    }

    /// Helper to extract text from a SQLite column
    /// - Parameters:
    ///   - statement: SQLite statement
    ///   - column: Column index
    /// - Returns: String value or nil if NULL
    nonisolated func getText(from statement: OpaquePointer, column: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, column) else {
            return nil
        }
        return String(cString: cString)
    }
}
