//
//  SQLiteCoatingItemRepository.swift
//  Molten
//
//  Repository for reading coating items from bundled SQLite catalog database
//

import Foundation
import SQLite3

/// SQLite-based repository for CoatingItem data (read-only bundled catalog)
///
/// This repository reads from the bundled catalog.sqlite database shipped with the app.
/// Write operations are not supported - the catalog is read-only.
struct SQLiteCoatingItemRepository: CoatingItemRepository {
    private let databaseManager: CatalogDatabaseManager

    init(databaseManager: CatalogDatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    // MARK: - Read Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [CoatingItemModel] {
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

    func fetchItem(byStableId stableId: String) async throws -> CoatingItemModel? {
        let query = "SELECT * FROM coatings WHERE stable_id = ? LIMIT 1"

        return try databaseManager.performDatabaseOperation { db in
            let items = try executeQuery(db: db, query: query, parameters: [stableId])
            return items.first
        }
    }

    func searchItems(text: String) async throws -> [CoatingItemModel] {
        let searchPattern = "%\(text)%"
        let query = """
            SELECT * FROM coatings
            WHERE name LIKE ? OR manufacturer LIKE ? OR manufacturer_description LIKE ?
            ORDER BY manufacturer, name
            """

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [searchPattern, searchPattern, searchPattern])
        }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [CoatingItemModel] {
        let query = "SELECT * FROM coatings WHERE manufacturer = ? ORDER BY name"

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query, parameters: [manufacturer])
        }
    }

    func fetchItems(byStatus status: String) async throws -> [CoatingItemModel] {
        // Since coatings table doesn't have a status column, return all items for "available"
        // and empty array for other statuses
        if status == "available" {
            return try await fetchAllItems()
        }
        return []
    }

    func getDistinctManufacturers() async throws -> [String] {
        let query = "SELECT DISTINCT manufacturer FROM coatings ORDER BY manufacturer"

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
        // Since coatings table doesn't have a status column, return default
        return ["available"]
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

    func createItem(_ item: CoatingItemModel) async throws -> CoatingItemModel {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func createItems(_ items: [CoatingItemModel]) async throws -> [CoatingItemModel] {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func updateItem(_ item: CoatingItemModel) async throws -> CoatingItemModel {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func deleteItem(stableId: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func deleteItems(stableIds: [String]) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    // MARK: - Helper Methods

    private func fetchAllItems() async throws -> [CoatingItemModel] {
        let query = "SELECT * FROM coatings ORDER BY manufacturer, name"

        return try databaseManager.performDatabaseOperation { db in
            try executeQuery(db: db, query: query)
        }
    }

    /// Execute a SELECT query and return CoatingItemModel instances
    private func executeQuery(db: OpaquePointer, query: String, parameters: [String] = []) throws -> [CoatingItemModel] {
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
        var items: [CoatingItemModel] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let item = try parseCoatingItem(from: statement!)
            items.append(item)
        }

        return items
    }

    /// Parse a CoatingItemModel from a SQLite row
    private func parseCoatingItem(from statement: OpaquePointer) throws -> CoatingItemModel {
        // Column indices from schema:
        // 0=stable_id, 1=code, 2=name, 3=manufacturer, 4=manufacturer_description,
        // 5=tags, 6=image_url, 7=image_path, 8=manufacturer_url, 9=product_type, 10=coe

        func getText(_ column: Int32) -> String? {
            guard let cString = sqlite3_column_text(statement, column) else {
                return nil
            }
            return String(cString: cString)
        }

        guard let stable_id = getText(0) else {
            throw SQLiteError.invalidData("Missing stable_id")
        }

        guard let name = getText(2) else {
            throw SQLiteError.invalidData("Missing name")
        }

        guard let manufacturer = getText(3) else {
            throw SQLiteError.invalidData("Missing manufacturer")
        }

        let sku = getText(1)  // code -> sku
        let mfr_notes = getText(4)  // manufacturer_description -> mfr_notes
        let url = getText(8)  // manufacturer_url -> url
        let mfr_status = "available"  // Default since no status column in database
        let image_url = getText(6)
        let image_path = getText(7)

        return CoatingItemModel(
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
