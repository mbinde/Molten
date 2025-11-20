//
//  TestCatalogDatabaseManager.swift
//  Molten
//
//  Test-specific database manager that uses bundled SQLite database directly
//  without copying to Documents. Used by tests to access production catalog data.
//

import Foundation
import SQLite3

/// Test database manager that reads directly from bundle (no copying to Documents)
final class TestCatalogDatabaseManager: CatalogDatabaseManagerProtocol {

    // MARK: - Properties

    private let connectionLock = NSLock()
    private nonisolated(unsafe) var databaseConnection: OpaquePointer?
    private let databasePath: String

    // MARK: - Initialization

    /// Initialize with path to bundled database
    /// - Parameter databasePath: Full path to catalog.sqlite in bundle
    nonisolated init(databasePath: String) {
        self.databasePath = databasePath
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Access

    /// Initialize database (open connection)
    func initialize() throws {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        // Open database in read-only mode
        guard sqlite3_open_v2(databasePath, &databaseConnection, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let errorMessage = databaseConnection != nil ? String(cString: sqlite3_errmsg(databaseConnection)) : "Unknown error"
            throw CatalogDatabaseError.cannotOpenDatabase(errorMessage)
        }
    }

    /// Close database connection
    private nonisolated func closeDatabase() {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        if databaseConnection != nil {
            sqlite3_close(databaseConnection)
            databaseConnection = nil
        }
    }

    /// Perform a database operation with thread-safe access to the connection
    /// - Parameter operation: A closure that receives the database connection and performs operations
    /// - Returns: The result of the operation
    nonisolated func performDatabaseOperation<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        guard let connection = databaseConnection else {
            throw CatalogDatabaseError.databaseNotInitialized
        }

        return try operation(connection)
    }
}
