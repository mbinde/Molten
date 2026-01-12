//
//  SQLiteCatalogFlagRepository.swift
//  Molten
//
//  SQLite-based implementation for reading bundled catalog flags.
//  This repository is READ-ONLY - flags are bundled with the app in catalog.sqlite.
//

import Foundation
import SQLite3

/// SQLite-based read-only repository for bundled catalog flags
final class SQLiteCatalogFlagRepository: CatalogFlagBundledRepository {

    // MARK: - Properties

    private let databaseManager: CatalogDatabaseManagerProtocol

    // MARK: - Initialization

    init(databaseManager: CatalogDatabaseManagerProtocol = CatalogDatabaseManager.shared) {
        self.databaseManager = databaseManager
    }

    // MARK: - Single Item Operations

    func fetchFlags(for item_stable_id: String) async throws -> [CatalogFlagBundledModel] {
        let query = """
            SELECT id, item_stable_id, flag_key, flag_value, flag_numeric
            FROM glass_item_flags
            WHERE item_stable_id = ?
            ORDER BY flag_key
            """

        return try databaseManager.performDatabaseOperation { db in
            var flags: [CatalogFlagBundledModel] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                // Table might not exist yet - return empty array
                if error.contains("no such table") {
                    return []
                }
                throw SQLiteError.queryFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Bind parameter
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            let result = sqlite3_bind_text(statement, 1, item_stable_id, -1, SQLITE_TRANSIENT)
            guard result == SQLITE_OK else {
                throw SQLiteError.queryFailed("Failed to bind parameter: \(String(cString: sqlite3_errmsg(db)))")
            }

            // Execute query and collect results
            while sqlite3_step(statement) == SQLITE_ROW {
                let flag = self.parseFlagRow(statement)
                flags.append(flag)
            }

            return flags
        }
    }

    // MARK: - Batch Operations

    func fetchFlags(for item_stable_ids: [String]) async throws -> [String: [CatalogFlagBundledModel]] {
        guard !item_stable_ids.isEmpty else {
            return [:]
        }

        // Build placeholders for IN clause
        let placeholders = item_stable_ids.map { _ in "?" }.joined(separator: ", ")
        let query = """
            SELECT id, item_stable_id, flag_key, flag_value, flag_numeric
            FROM glass_item_flags
            WHERE item_stable_id IN (\(placeholders))
            ORDER BY item_stable_id, flag_key
            """

        return try databaseManager.performDatabaseOperation { db in
            var flagsByItem: [String: [CatalogFlagBundledModel]] = [:]
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                if error.contains("no such table") {
                    return [:]
                }
                throw SQLiteError.queryFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Bind parameters
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            for (index, stableId) in item_stable_ids.enumerated() {
                let result = sqlite3_bind_text(statement, Int32(index + 1), stableId, -1, SQLITE_TRANSIENT)
                guard result == SQLITE_OK else {
                    throw SQLiteError.queryFailed("Failed to bind parameter \(index): \(String(cString: sqlite3_errmsg(db)))")
                }
            }

            // Execute query and collect results
            while sqlite3_step(statement) == SQLITE_ROW {
                let flag = self.parseFlagRow(statement)
                if flagsByItem[flag.item_stable_id] == nil {
                    flagsByItem[flag.item_stable_id] = []
                }
                flagsByItem[flag.item_stable_id]?.append(flag)
            }

            return flagsByItem
        }
    }

    func fetchAllFlags() async throws -> [CatalogFlagBundledModel] {
        let query = """
            SELECT id, item_stable_id, flag_key, flag_value, flag_numeric
            FROM glass_item_flags
            ORDER BY item_stable_id, flag_key
            """

        return try databaseManager.performDatabaseOperation { db in
            var flags: [CatalogFlagBundledModel] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                if error.contains("no such table") {
                    return []
                }
                throw SQLiteError.queryFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                let flag = self.parseFlagRow(statement)
                flags.append(flag)
            }

            return flags
        }
    }

    // MARK: - Discovery Operations

    func findItems(withFlagKey flag_key: String) async throws -> [String] {
        let query = """
            SELECT DISTINCT item_stable_id
            FROM glass_item_flags
            WHERE flag_key = ?
            ORDER BY item_stable_id
            """

        return try databaseManager.performDatabaseOperation { db in
            var stableIds: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                if error.contains("no such table") {
                    return []
                }
                throw SQLiteError.queryFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            let result = sqlite3_bind_text(statement, 1, flag_key, -1, SQLITE_TRANSIENT)
            guard result == SQLITE_OK else {
                throw SQLiteError.queryFailed("Failed to bind parameter: \(String(cString: sqlite3_errmsg(db)))")
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let stableIdText = sqlite3_column_text(statement, 0) {
                    stableIds.append(String(cString: stableIdText))
                }
            }

            return stableIds
        }
    }

    func getAllFlagKeys() async throws -> [String] {
        let query = "SELECT DISTINCT flag_key FROM glass_item_flags ORDER BY flag_key"

        return try databaseManager.performDatabaseOperation { db in
            var keys: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                if error.contains("no such table") {
                    return []
                }
                throw SQLiteError.queryFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let keyText = sqlite3_column_text(statement, 0) {
                    keys.append(String(cString: keyText))
                }
            }

            return keys
        }
    }

    func getFlagCounts() async throws -> [String: Int] {
        let query = """
            SELECT flag_key, COUNT(*) as count
            FROM glass_item_flags
            GROUP BY flag_key
            ORDER BY count DESC
            """

        return try databaseManager.performDatabaseOperation { db in
            var counts: [String: Int] = [:]
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(db))
                if error.contains("no such table") {
                    return [:]
                }
                throw SQLiteError.queryFailed(error)
            }

            defer {
                sqlite3_finalize(statement)
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let keyText = sqlite3_column_text(statement, 0) {
                    let key = String(cString: keyText)
                    let count = Int(sqlite3_column_int(statement, 1))
                    counts[key] = count
                }
            }

            return counts
        }
    }

    // MARK: - Private Helpers

    private func parseFlagRow(_ statement: OpaquePointer?) -> CatalogFlagBundledModel {
        let id = Int(sqlite3_column_int(statement, 0))

        let stableId: String
        if let text = sqlite3_column_text(statement, 1) {
            stableId = String(cString: text)
        } else {
            stableId = ""
        }

        let flagKey: String
        if let text = sqlite3_column_text(statement, 2) {
            flagKey = String(cString: text)
        } else {
            flagKey = ""
        }

        let flagValue = sqlite3_column_int(statement, 3) != 0

        let flagNumeric: Double?
        if sqlite3_column_type(statement, 4) != SQLITE_NULL {
            flagNumeric = sqlite3_column_double(statement, 4)
        } else {
            flagNumeric = nil
        }

        return CatalogFlagBundledModel(
            id: id,
            item_stable_id: stableId,
            flag_key: flagKey,
            flag_value: flagValue,
            flag_numeric: flagNumeric
        )
    }
}
