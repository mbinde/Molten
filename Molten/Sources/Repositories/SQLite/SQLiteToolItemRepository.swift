//
//  SQLiteToolItemRepository.swift
//  Molten
//
//  Repository for reading tool items from bundled SQLite catalog database
//

import Foundation
import SQLite3

/// SQLite-based repository for ToolItem data (read-only bundled catalog)
///
/// This repository reads from the bundled catalog.sqlite database shipped with the app.
/// Write operations are not supported - the catalog is read-only.
struct SQLiteToolItemRepository: ToolItemRepository {
    private let databaseManager: CatalogDatabaseManagerProtocol

    init(databaseManager: CatalogDatabaseManagerProtocol = CatalogDatabaseManager.shared) {
        self.databaseManager = databaseManager
    }

    // MARK: - Read Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ToolItemModel] {
        // For simplicity, fetch all and filter in memory
        // NSPredicate is a Core Data concept, not directly translatable to SQLite
        let allItems = try await fetchAllItems()

        if let predicate = predicate {
            return allItems.filter { item in
                predicate.evaluate(with: item)
            }
        }

        return allItems
    }

    func fetchItem(byStableId stableId: String) async throws -> ToolItemModel? {
        let query = "SELECT * FROM tools WHERE stable_id = ? LIMIT 1"

        return try databaseManager.performDatabaseOperation { db in
            let items = try executeQuery(db: db, query: query, parameters: [stableId])
            return items.first
        }
    }

    func searchItems(text: String) async throws -> [ToolItemModel] {
        let searchPattern = "%\(text)%"
        let query = """
            SELECT * FROM tools
            WHERE name LIKE ? OR manufacturer LIKE ? OR description LIKE ?
            ORDER BY manufacturer, name
            """

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [searchPattern, searchPattern, searchPattern])
        }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [ToolItemModel] {
        let query = "SELECT * FROM tools WHERE manufacturer = ? ORDER BY name"

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [manufacturer])
        }
    }

    func fetchItems(byStatus status: String) async throws -> [ToolItemModel] {
        let query = "SELECT * FROM tools WHERE status = ? ORDER BY manufacturer, name"

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [status])
        }
    }

    func getDistinctManufacturers() async throws -> [String] {
        let query = "SELECT DISTINCT manufacturer FROM tools ORDER BY manufacturer"

        return try databaseManager.performDatabaseOperation { db in
            var manufacturers: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let manufacturer = sqlite3_column_text(statement, 0) {
                    manufacturers.append(String(cString: manufacturer))
                }
            }

            return manufacturers
        }
    }

    func getDistinctStatuses() async throws -> [String] {
        let query = "SELECT DISTINCT status FROM tools WHERE status IS NOT NULL ORDER BY status"

        return try databaseManager.performDatabaseOperation { db in
            var statuses: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let status = sqlite3_column_text(statement, 0) {
                    statuses.append(String(cString: status))
                }
            }

            return statuses
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

    // MARK: - Write Operations (Not supported for read-only bundled catalog)

    func createItem(_ item: ToolItemModel) async throws -> ToolItemModel {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func createItems(_ items: [ToolItemModel]) async throws -> [ToolItemModel] {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func updateItem(_ item: ToolItemModel) async throws -> ToolItemModel {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func deleteItem(stableId: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func deleteItems(stableIds: [String]) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    // MARK: - Helper Methods

    private func fetchAllItems() async throws -> [ToolItemModel] {
        let query = "SELECT * FROM tools ORDER BY manufacturer, name"

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query)
        }
    }

    /// Execute a SELECT query and return ToolItemModel instances
    private func executeQuery(db: OpaquePointer, query: String, parameters: [String] = []) throws -> [ToolItemModel] {
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
        var items: [ToolItemModel] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let item = try parseToolItem(from: statement!)
            items.append(item)
        }

        return items
    }

    /// Parse a ToolItemModel from a SQLite row
    private func parseToolItem(from statement: OpaquePointer) throws -> ToolItemModel {
        // Column indices from schema:
        // 0=stable_id, 1=name, 2=sku, 3=description, 4=price, 5=category,
        // 6=image_url, 7=product_url, 8=status, 9=manufacturer

        func getText(_ column: Int32) -> String? {
            guard let cString = sqlite3_column_text(statement, column) else {
                return nil
            }
            return String(cString: cString)
        }

        guard let stable_id = getText(0) else {
            throw SQLiteError.invalidData("Missing stable_id")
        }

        guard let name = getText(1) else {
            throw SQLiteError.invalidData("Missing name")
        }

        guard let manufacturer = getText(9) else {
            throw SQLiteError.invalidData("Missing manufacturer")
        }

        let sku = getText(2)
        let mfr_notes = getText(3)  // description -> mfr_notes
        let url = getText(7)  // product_url -> url
        let mfr_status = getText(8) ?? "available"  // status -> mfr_status
        let image_url = getText(6)
        let image_path: String? = nil  // Not in database

        return ToolItemModel(
            stable_id: stable_id,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: mfr_notes,
            url: url,
            mfr_status: mfr_status,
            image_url: image_url,
            image_path: image_path
        )
    }
}
