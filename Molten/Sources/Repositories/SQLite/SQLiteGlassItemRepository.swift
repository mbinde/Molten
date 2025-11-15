//
//  SQLiteGlassItemRepository.swift
//  Molten
//
//  SQLite-based implementation of GlassItemRepository for bundled catalog data.
//  This repository is READ-ONLY - catalog data is bundled with the app and cannot be modified.
//

import Foundation
import SQLite3

/// SQLite-based read-only repository for catalog glass items
final class SQLiteGlassItemRepository: GlassItemRepository {

    // MARK: - Properties

    private let databaseManager: CatalogDatabaseManager

    // MARK: - Initialization

    init(databaseManager: CatalogDatabaseManager = .shared) {
        self.databaseManager = databaseManager
    }

    // MARK: - Read Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        let db = try databaseManager.getDatabaseConnection()

        // For now, fetch all items (predicate support can be added later)
        let query = "SELECT * FROM glass_items ORDER BY manufacturer, code"

        return try await executeQuery(db: db, query: query)
    }

    func fetchItem(byStableId stableId: String) async throws -> GlassItemModel? {
        let db = try databaseManager.getDatabaseConnection()
        let query = "SELECT * FROM glass_items WHERE stable_id = ?"

        let items = try await executeQuery(db: db, query: query, parameters: [stableId])
        return items.first
    }

    func searchItems(text: String) async throws -> [GlassItemModel] {
        let db = try databaseManager.getDatabaseConnection()
        let searchPattern = "%\(text)%"

        let query = """
            SELECT * FROM glass_items
            WHERE name LIKE ? OR manufacturer LIKE ? OR code LIKE ?
            ORDER BY manufacturer, code
            """

        return try await executeQuery(db: db, query: query, parameters: [searchPattern, searchPattern, searchPattern])
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        let db = try databaseManager.getDatabaseConnection()
        let query = "SELECT * FROM glass_items WHERE manufacturer = ? ORDER BY code"

        return try await executeQuery(db: db, query: query, parameters: [manufacturer])
    }

    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        let db = try databaseManager.getDatabaseConnection()
        let query = "SELECT * FROM glass_items WHERE coe = ? ORDER BY manufacturer, code"

        return try await executeQuery(db: db, query: query, parameters: [String(coe)])
    }

    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        let db = try databaseManager.getDatabaseConnection()
        let query = "SELECT * FROM glass_items WHERE status = ? ORDER BY manufacturer, code"

        return try await executeQuery(db: db, query: query, parameters: [status])
    }

    func getDistinctManufacturers() async throws -> [String] {
        let db = try databaseManager.getDatabaseConnection()
        let query = "SELECT DISTINCT manufacturer FROM glass_items ORDER BY manufacturer"

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

    func getDistinctCOEValues() async throws -> [Int32] {
        let db = try databaseManager.getDatabaseConnection()
        let query = "SELECT DISTINCT coe FROM glass_items WHERE coe IS NOT NULL AND coe != '' ORDER BY CAST(coe AS INTEGER)"

        var coeValues: [Int32] = []
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        defer {
            sqlite3_finalize(statement)
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let coeText = sqlite3_column_text(statement, 0) {
                let coeString = String(cString: coeText)
                if let coeValue = Int32(coeString) {
                    coeValues.append(coeValue)
                }
            }
        }

        return coeValues
    }

    func getDistinctStatuses() async throws -> [String] {
        let db = try databaseManager.getDatabaseConnection()
        let query = "SELECT DISTINCT status FROM glass_items ORDER BY status"

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

    func stableIdExists(_ stableId: String) async throws -> Bool {
        let item = try await fetchItem(byStableId: stableId)
        return item != nil
    }

    func generateNextNaturalKey(manufacturer: String, sku: String?) async throws -> String {
        // For bundled catalog, this shouldn't be needed
        // But provide a basic implementation for compatibility
        let baseKey = "\(manufacturer)-\(sku ?? "unknown")"
        let existingItems = try await fetchItems(byManufacturer: manufacturer)
        var matchingItems: [GlassItemModel] = []
        for item in existingItems {
            let uri = await item.uri
            if uri.hasPrefix(baseKey) {
                matchingItems.append(item)
            }
        }

        if matchingItems.isEmpty {
            return "\(baseKey)-000"
        } else {
            let nextIndex = matchingItems.count
            return String(format: "%@-%03d", baseKey, nextIndex)
        }
    }

    // MARK: - Kiln Schedule Operations (Not supported for bundled catalog)

    func getRecommendedSchedules(forGlassItem stableId: String) async throws -> [UUID] {
        // Bundled catalog doesn't support kiln schedule relationships
        return []
    }

    func addRecommendedSchedule(scheduleId: UUID, toGlassItem stableId: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Kiln schedules not supported in bundled catalog")
    }

    func removeRecommendedSchedule(scheduleId: UUID, fromGlassItem stableId: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Kiln schedules not supported in bundled catalog")
    }

    // MARK: - Write Operations (Not supported for read-only bundled catalog)

    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func createItems(_ items: [GlassItemModel]) async throws -> [GlassItemModel] {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func deleteItem(stableId: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    func deleteItems(stableIds: [String]) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog is read-only (bundled data)")
    }

    // MARK: - Helper Methods

    /// Execute a SELECT query and return GlassItemModel instances
    private func executeQuery(db: OpaquePointer, query: String, parameters: [String] = []) async throws -> [GlassItemModel] {
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        defer {
            sqlite3_finalize(statement)
        }

        // Bind parameters
        for (index, parameter) in parameters.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), parameter, -1, nil)
        }

        // Execute query and collect results
        var items: [GlassItemModel] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let item = try parseGlassItem(from: statement!)
            items.append(item)
        }

        return items
    }

    /// Parse a GlassItemModel from a SQLite row
    private func parseGlassItem(from statement: OpaquePointer) throws -> GlassItemModel {
        // Column indices (match schema from build script):
        // 0=stable_id, 1=status, 2=added_date, 3=last_seen, 4=discontinued_date,
        // 5=manufacturer, 6=code, 7=name, 8=start_date, 9=end_date,
        // 10=manufacturer_description, 11=tags, 12=synonyms, 13=coe, 14=type,
        // 15=manufacturer_url, 16=image_path, 17=image_url, 18=stock_type

        func getText(_ column: Int32) -> String? {
            guard let cString = sqlite3_column_text(statement, column) else {
                return nil
            }
            return String(cString: cString)
        }

        guard let stable_id = getText(0) else {
            throw SQLiteError.invalidData("Missing stable_id")
        }

        guard let name = getText(7) else {
            throw SQLiteError.invalidData("Missing name")
        }

        guard let manufacturer = getText(5) else {
            throw SQLiteError.invalidData("Missing manufacturer")
        }

        let sku = getText(6)  // code -> sku
        let mfr_notes = getText(10)  // manufacturer_description -> mfr_notes

        // Parse COE (required field, default to 90 if missing)
        let coe: Int32
        if let coeText = getText(13), let coeValue = Int32(coeText) {
            coe = coeValue
        } else {
            coe = 90  // Default COE
        }

        let url = getText(15)  // manufacturer_url -> url
        let mfr_status = getText(1) ?? "available"  // status -> mfr_status
        let image_path = getText(16)
        let image_thumb_path = getText(17)
        let image_url = getText(18)

        // DEBUG: Log what we're reading for a few items
        if ["2HC89p", "5bfSaX", "6pXaLx"].contains(stable_id) {
            print("🔍 [SQLiteRepo] Parsing \(stable_id): image_path=\(image_path ?? "nil"), image_thumb_path=\(image_thumb_path ?? "nil")")
        }

        return GlassItemModel(
            stable_id: stable_id,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: mfr_notes,
            coe: coe,
            url: url,
            mfr_status: mfr_status,
            image_url: image_url,
            image_path: image_path,
            image_thumb_path: image_thumb_path
        )
    }
}

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
