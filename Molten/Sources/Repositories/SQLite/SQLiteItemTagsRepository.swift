//
//  SQLiteItemTagsRepository.swift
//  Molten
//
//  SQLite-based implementation of ItemTagsRepository for bundled catalog tags.
//  This repository is READ-ONLY - catalog tags are bundled with the app and cannot be modified.
//

import Foundation
import SQLite3

/// SQLite-based read-only repository for catalog item tags
final class SQLiteItemTagsRepository: ItemTagsRepository {

    // MARK: - Properties

    private let databaseManager: CatalogDatabaseManagerProtocol

    // MARK: - Initialization

    init(databaseManager: CatalogDatabaseManagerProtocol = CatalogDatabaseManager.shared) {
        self.databaseManager = databaseManager
    }

    // MARK: - Read Operations

    func fetchTags(forItem item_stable_id: String) async throws -> [String] {
        let query = "SELECT tag FROM item_tags WHERE item_stable_id = ? ORDER BY tag"

        return try databaseManager.performDatabaseOperation { db in
            var tags: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
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
                if let tagText = sqlite3_column_text(statement, 0) {
                    tags.append(String(cString: tagText))
                }
            }

            return tags
        }
    }

    func fetchTagsForItems(_ item_stable_ids: [String]) async throws -> [String: [String]] {
        guard !item_stable_ids.isEmpty else {
            return [:]
        }

        // Build placeholders for IN clause
        let placeholders = item_stable_ids.map { _ in "?" }.joined(separator: ", ")
        let query = "SELECT item_stable_id, tag FROM item_tags WHERE item_stable_id IN (\(placeholders)) ORDER BY item_stable_id, tag"

        return try databaseManager.performDatabaseOperation { db in
            var tagsByItem: [String: [String]] = [:]
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
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
            var rowCount = 0
            while sqlite3_step(statement) == SQLITE_ROW {
                rowCount += 1
                guard let stableIdText = sqlite3_column_text(statement, 0),
                      let tagText = sqlite3_column_text(statement, 1) else {
                    continue
                }

                let stableId = String(cString: stableIdText)
                let tag = String(cString: tagText)

                if tagsByItem[stableId] == nil {
                    tagsByItem[stableId] = []
                }
                tagsByItem[stableId]?.append(tag)
            }

            return tagsByItem
        }
    }

    func getAllTags() async throws -> [String] {
        let query = "SELECT DISTINCT tag FROM item_tags ORDER BY tag"

        return try databaseManager.performDatabaseOperation { db in
            var tags: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let tagText = sqlite3_column_text(statement, 0) {
                    tags.append(String(cString: tagText))
                }
            }

            return tags
        }
    }

    func getTagsWithPrefix(_ prefix: String) async throws -> [String] {
        let searchPattern = "\(prefix)%"
        let query = "SELECT DISTINCT tag FROM item_tags WHERE tag LIKE ? ORDER BY tag"

        return try databaseManager.performDatabaseOperation { db in
            var tags: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Bind parameter
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            let result = sqlite3_bind_text(statement, 1, searchPattern, -1, SQLITE_TRANSIENT)
            guard result == SQLITE_OK else {
                throw SQLiteError.queryFailed("Failed to bind parameter: \(String(cString: sqlite3_errmsg(db)))")
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let tagText = sqlite3_column_text(statement, 0) {
                    tags.append(String(cString: tagText))
                }
            }

            return tags
        }
    }

    func fetchItems(withTag tag: String) async throws -> [String] {
        let query = "SELECT item_stable_id FROM item_tags WHERE tag = ? ORDER BY item_stable_id"

        return try databaseManager.performDatabaseOperation { db in
            var stableIds: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Bind parameter
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            let result = sqlite3_bind_text(statement, 1, tag, -1, SQLITE_TRANSIENT)
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

    func fetchItems(withAllTags tags: [String]) async throws -> [String] {
        guard !tags.isEmpty else {
            return []
        }

        // Build query that finds items having ALL specified tags
        let placeholders = tags.map { _ in "?" }.joined(separator: ", ")
        let query = """
            SELECT item_stable_id
            FROM item_tags
            WHERE tag IN (\(placeholders))
            GROUP BY item_stable_id
            HAVING COUNT(DISTINCT tag) = ?
            ORDER BY item_stable_id
            """

        return try databaseManager.performDatabaseOperation { db in
            var stableIds: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Bind tag parameters
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            for (index, tag) in tags.enumerated() {
                let result = sqlite3_bind_text(statement, Int32(index + 1), tag, -1, SQLITE_TRANSIENT)
                guard result == SQLITE_OK else {
                    throw SQLiteError.queryFailed("Failed to bind parameter \(index): \(String(cString: sqlite3_errmsg(db)))")
                }
            }

            // Bind count parameter (number of tags that must match)
            let countResult = sqlite3_bind_int(statement, Int32(tags.count + 1), Int32(tags.count))
            guard countResult == SQLITE_OK else {
                throw SQLiteError.queryFailed("Failed to bind count parameter: \(String(cString: sqlite3_errmsg(db)))")
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let stableIdText = sqlite3_column_text(statement, 0) {
                    stableIds.append(String(cString: stableIdText))
                }
            }

            return stableIds
        }
    }

    func fetchItems(withAnyTags tags: [String]) async throws -> [String] {
        guard !tags.isEmpty else {
            return []
        }

        // Build query that finds items having ANY specified tag
        let placeholders = tags.map { _ in "?" }.joined(separator: ", ")
        let query = "SELECT DISTINCT item_stable_id FROM item_tags WHERE tag IN (\(placeholders)) ORDER BY item_stable_id"

        return try databaseManager.performDatabaseOperation { db in
            var stableIds: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Bind parameters
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            for (index, tag) in tags.enumerated() {
                let result = sqlite3_bind_text(statement, Int32(index + 1), tag, -1, SQLITE_TRANSIENT)
                guard result == SQLITE_OK else {
                    throw SQLiteError.queryFailed("Failed to bind parameter \(index): \(String(cString: sqlite3_errmsg(db)))")
                }
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let stableIdText = sqlite3_column_text(statement, 0) {
                    stableIds.append(String(cString: stableIdText))
                }
            }

            return stableIds
        }
    }

    func getMostUsedTags(limit: Int) async throws -> [String] {
        let query = """
            SELECT tag, COUNT(*) as count
            FROM item_tags
            GROUP BY tag
            ORDER BY count DESC
            LIMIT ?
            """

        return try databaseManager.performDatabaseOperation { db in
            var tags: [String] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Bind limit parameter
            let result = sqlite3_bind_int(statement, 1, Int32(limit))
            guard result == SQLITE_OK else {
                throw SQLiteError.queryFailed("Failed to bind parameter: \(String(cString: sqlite3_errmsg(db)))")
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let tagText = sqlite3_column_text(statement, 0) {
                    tags.append(String(cString: tagText))
                }
            }

            return tags
        }
    }

    func getTagUsageCounts() async throws -> [String: Int] {
        let query = "SELECT tag, COUNT(*) as count FROM item_tags GROUP BY tag"

        return try databaseManager.performDatabaseOperation { db in
            var counts: [String: Int] = [:]
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let tagText = sqlite3_column_text(statement, 0) {
                    let tag = String(cString: tagText)
                    let count = Int(sqlite3_column_int(statement, 1))
                    counts[tag] = count
                }
            }

            return counts
        }
    }

    func getTagsWithCounts(minCount: Int = 1) async throws -> [(tag: String, count: Int)] {
        let query = """
            SELECT tag, COUNT(*) as count
            FROM item_tags
            GROUP BY tag
            HAVING count >= ?
            ORDER BY count DESC, tag ASC
            """

        return try databaseManager.performDatabaseOperation { db in
            var results: [(tag: String, count: Int)] = []
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Bind minCount parameter
            let result = sqlite3_bind_int(statement, 1, Int32(minCount))
            guard result == SQLITE_OK else {
                throw SQLiteError.queryFailed("Failed to bind parameter: \(String(cString: sqlite3_errmsg(db)))")
            }

            while sqlite3_step(statement) == SQLITE_ROW {
                if let tagText = sqlite3_column_text(statement, 0) {
                    let tag = String(cString: tagText)
                    let count = Int(sqlite3_column_int(statement, 1))
                    results.append((tag: tag, count: count))
                }
            }

            return results
        }
    }

    func tagExists(_ tag: String) async throws -> Bool {
        let query = "SELECT 1 FROM item_tags WHERE tag = ? LIMIT 1"

        return try databaseManager.performDatabaseOperation { db in
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw SQLiteError.queryFailed(String(cString: sqlite3_errmsg(db)))
            }

            defer {
                sqlite3_finalize(statement)
            }

            // Bind parameter
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            let result = sqlite3_bind_text(statement, 1, tag, -1, SQLITE_TRANSIENT)
            guard result == SQLITE_OK else {
                throw SQLiteError.queryFailed("Failed to bind parameter: \(String(cString: sqlite3_errmsg(db)))")
            }

            return sqlite3_step(statement) == SQLITE_ROW
        }
    }

    func getTags(withPrefix prefix: String) async throws -> [String] {
        return try await getTagsWithPrefix(prefix)
    }

    func addTags(_ tags: [String], toItem item_stable_id: String) async throws {
        // Read-only repository - throw error for write operations
        throw SQLiteError.writeOperationNotSupported("Catalog tags are read-only (bundled data)")
    }

    // MARK: - Write Operations (Not supported for read-only bundled catalog)

    func addTag(_ tag: String, toItem item_stable_id: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog tags are read-only (bundled data)")
    }

    func removeTag(_ tag: String, fromItem item_stable_id: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog tags are read-only (bundled data)")
    }

    func setTags(_ tags: [String], forItem item_stable_id: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog tags are read-only (bundled data)")
    }

    func removeAllTags(fromItem item_stable_id: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog tags are read-only (bundled data)")
    }

    func deleteTag(_ tag: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Catalog tags are read-only (bundled data)")
    }
}
