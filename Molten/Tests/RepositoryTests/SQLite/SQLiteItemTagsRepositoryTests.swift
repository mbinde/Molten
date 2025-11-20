//
//  SQLiteItemTagsRepositoryTests.swift
//  RepositoryTests
//
//  Tests for SQLiteItemTagsRepository to ensure item_tags table exists and works
//

import Foundation
import Testing
import SQLite3
@testable import Molten

@Suite("SQLiteItemTagsRepository Tests", .serialized)
@MainActor
struct SQLiteItemTagsRepositoryTests {

    // MARK: - Test Helpers

    final class TestCatalogDatabaseManager: CatalogDatabaseManagerProtocol, @unchecked Sendable {
        private nonisolated(unsafe) var db: OpaquePointer?
        private let dbURL: URL
        private let connectionLock = NSLock()

        init() throws {
            let tempDir = FileManager.default.temporaryDirectory
            self.dbURL = tempDir.appendingPathComponent("test-tags-\(UUID().uuidString).sqlite")

            // Create test database
            guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else {
                throw NSError(domain: "TestError", code: -1)
            }

            try createSchema()
            try insertTestData()
        }

        private func createSchema() throws {
            let schema = """
                CREATE TABLE metadata (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );

                INSERT INTO metadata (key, value) VALUES ('version', '1');

                CREATE TABLE item_tags (
                    item_stable_id TEXT NOT NULL,
                    tag TEXT NOT NULL,
                    PRIMARY KEY (item_stable_id, tag)
                );
                """

            var error: UnsafeMutablePointer<CChar>?
            guard sqlite3_exec(db, schema, nil, nil, &error) == SQLITE_OK else {
                if let error = error {
                    let errorString = String(cString: error)
                    sqlite3_free(error)
                    throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorString])
                }
                throw NSError(domain: "TestError", code: -1)
            }
        }

        private func insertTestData() throws {
            let inserts = """
                INSERT INTO item_tags (item_stable_id, tag) VALUES
                    ('abc123', 'transparent'),
                    ('abc123', 'striking'),
                    ('def456', 'opaque'),
                    ('def456', 'reactive'),
                    ('ghi789', 'transparent');
                """

            var error: UnsafeMutablePointer<CChar>?
            guard sqlite3_exec(db, inserts, nil, nil, &error) == SQLITE_OK else {
                if let error = error {
                    let errorString = String(cString: error)
                    sqlite3_free(error)
                    throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorString])
                }
                throw NSError(domain: "TestError", code: -1)
            }
        }

        nonisolated func performDatabaseOperation<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
            connectionLock.lock()
            defer { connectionLock.unlock() }

            guard let connection = db else {
                throw NSError(domain: "TestError", code: -1)
            }

            return try operation(connection)
        }

        deinit {
            if let db = db {
                sqlite3_close(db)
            }
            try? FileManager.default.removeItem(at: dbURL)
        }
    }

    // MARK: - Tests

    @Test("SQLiteItemTagsRepository can fetch tags for items")
    func testFetchTagsForItems() async throws {
        // Arrange
        let dbManager = try TestCatalogDatabaseManager()
        let repository = SQLiteItemTagsRepository(databaseManager: dbManager)

        // Act
        let tags = try await repository.fetchTagsForItems(["abc123", "def456", "ghi789", "nonexistent"])

        // Assert
        #expect(tags.count == 3, "Should return tags for 3 items")
        #expect(tags["abc123"]?.count == 2, "abc123 should have 2 tags")
        #expect(tags["abc123"]?.contains("transparent") == true, "abc123 should have 'transparent' tag")
        #expect(tags["abc123"]?.contains("striking") == true, "abc123 should have 'striking' tag")
        #expect(tags["def456"]?.count == 2, "def456 should have 2 tags")
        #expect(tags["ghi789"]?.count == 1, "ghi789 should have 1 tag")
        #expect(tags["nonexistent"] == nil, "nonexistent item should have no tags")
    }

    @Test("SQLiteItemTagsRepository handles empty item list")
    func testFetchTagsForEmptyList() async throws {
        // Arrange
        let dbManager = try TestCatalogDatabaseManager()
        let repository = SQLiteItemTagsRepository(databaseManager: dbManager)

        // Act
        let tags = try await repository.fetchTagsForItems([])

        // Assert
        #expect(tags.isEmpty, "Should return empty dictionary for empty input")
    }

    @Test("SQLiteItemTagsRepository can fetch all tags for a single item")
    func testFetchTagsForSingleItem() async throws {
        // Arrange
        let dbManager = try TestCatalogDatabaseManager()
        let repository = SQLiteItemTagsRepository(databaseManager: dbManager)

        // Act
        let tags = try await repository.fetchTagsForItems(["abc123"])

        // Assert
        #expect(tags.count == 1, "Should return tags for 1 item")
        #expect(tags["abc123"]?.count == 2, "Item should have 2 tags")
        #expect(tags["abc123"]?.sorted() == ["striking", "transparent"], "Tags should be sorted correctly")
    }

    @Test("Bundled catalog database has item_tags table")
    func testBundledDatabaseHasItemTagsTable() throws {
        // Arrange
        guard let bundleURL = Bundle.main.url(forResource: "catalog", withExtension: "sqlite") else {
            Issue.record("Bundled catalog.sqlite not found")
            return
        }

        var db: OpaquePointer?
        guard sqlite3_open(bundleURL.path, &db) == SQLITE_OK else {
            Issue.record("Could not open bundled database")
            return
        }
        defer { sqlite3_close(db) }

        // Act - Check if item_tags table exists
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='item_tags'"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            Issue.record("Could not prepare query")
            return
        }
        defer { sqlite3_finalize(statement) }

        let result = sqlite3_step(statement)

        // Assert
        #expect(result == SQLITE_ROW, "item_tags table should exist in bundled database")
    }

    @Test("Bundled catalog database has item_tags data")
    func testBundledDatabaseHasItemTagsData() throws {
        // Arrange
        guard let bundleURL = Bundle.main.url(forResource: "catalog", withExtension: "sqlite") else {
            Issue.record("Bundled catalog.sqlite not found")
            return
        }

        var db: OpaquePointer?
        guard sqlite3_open(bundleURL.path, &db) == SQLITE_OK else {
            Issue.record("Could not open bundled database")
            return
        }
        defer { sqlite3_close(db) }

        // Act - Count rows in item_tags table
        let query = "SELECT COUNT(*) FROM item_tags"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            Issue.record("Could not prepare query")
            return
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            Issue.record("Could not execute query")
            return
        }

        let count = sqlite3_column_int64(statement, 0)

        // Assert
        #expect(count > 0, "item_tags table should have data in bundled database")
    }
}
