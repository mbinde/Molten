//
//  StockDatabaseManager.swift
//  Molten
//
//  Manages the stock SQLite database lifecycle including:
//  - Version checking from metadata table
//  - Database access and connection management
//  - Atomic database replacement for updates
//

import Foundation
import SQLite3

/// Protocol for stock database manager operations
protocol StockDatabaseManagerProtocol {
    func initialize() async throws
    func replaceDatabaseWith(tempFile: URL) async throws
    nonisolated func performDatabaseOperation<T>(_ operation: (OpaquePointer) throws -> T) throws -> T
    var databaseExists: Bool { get }
}

/// Manages stock database versioning and access
final class StockDatabaseManager: StockDatabaseManagerProtocol {

    // MARK: - Singleton

    nonisolated static let shared = StockDatabaseManager()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let databaseName = "stock.sqlite"
    private let connectionLock = NSLock()
    private nonisolated(unsafe) var databaseConnection: OpaquePointer?

    /// URL of the stock database in Documents directory (computed once, thread-safe)
    private nonisolated var documentsDatabaseURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(databaseName)
    }

    /// Whether the stock database file exists (thread-safe)
    nonisolated var databaseExists: Bool {
        FileManager.default.fileExists(atPath: documentsDatabaseURL.path)
    }

    // MARK: - Initialization

    private nonisolated init() {}

    deinit {
        closeDatabase()
    }

    // MARK: - Database Setup

    /// Initialize the stock database connection (if database exists)
    func initialize() async throws {
        // Stock database starts empty - no bundled database
        // Only open connection if database exists (after first sync)
        if databaseExists {
            try openDatabase()
        }
    }

    // MARK: - Version Management

    /// Read version from the database's metadata table
    /// - Returns: Version number, or 0 if no database or version not found
    func getVersion() async throws -> Int {
        guard databaseExists else {
            return 0
        }

        var db: OpaquePointer?

        // Open database in read-only mode
        guard sqlite3_open_v2(documentsDatabaseURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw StockDatabaseError.cannotOpenDatabase(errorMessage)
        }

        defer {
            sqlite3_close(db)
        }

        // Query version from metadata table
        let query = "SELECT value FROM metadata WHERE key = 'version'"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            // Table might not exist yet - that's OK, return 0
            return 0
        }

        defer {
            sqlite3_finalize(statement)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0  // No version found
        }

        let versionString = String(cString: sqlite3_column_text(statement, 0))
        return Int(versionString) ?? 0
    }

    // MARK: - Database Access

    /// Open database connection
    private func openDatabase() throws {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        guard sqlite3_open_v2(
            documentsDatabaseURL.path,
            &databaseConnection,
            SQLITE_OPEN_READONLY,  // Read-only for stock data
            nil
        ) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(databaseConnection))
            throw StockDatabaseError.cannotOpenDatabase(errorMessage)
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

        // Lazily open connection if database exists but connection isn't open
        if databaseConnection == nil && databaseExists {
            guard sqlite3_open_v2(
                documentsDatabaseURL.path,
                &databaseConnection,
                SQLITE_OPEN_READONLY,
                nil
            ) == SQLITE_OK else {
                let errorMessage = String(cString: sqlite3_errmsg(databaseConnection))
                throw StockDatabaseError.cannotOpenDatabase(errorMessage)
            }
        }

        guard let connection = databaseConnection else {
            throw StockDatabaseError.databaseNotInitialized
        }

        return try operation(connection)
    }

    // MARK: - OTA Updates

    /// Replace current database with downloaded update
    /// - Parameter tempFile: URL of the downloaded database file
    func replaceDatabaseWith(tempFile: URL) async throws {
        // 1. Verify temp file is valid SQLite database with proper tables
        try await verifyDatabaseStructure(at: tempFile)

        // 2. Close current database connection (if open)
        closeDatabase()

        // 3. Backup current database (if exists)
        let backupURL = documentsDatabaseURL.deletingLastPathComponent()
            .appendingPathComponent("stock_backup.sqlite")

        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }

        if fileManager.fileExists(atPath: documentsDatabaseURL.path) {
            try fileManager.moveItem(at: documentsDatabaseURL, to: backupURL)
        }

        // 4. Move temp file to Documents
        do {
            try fileManager.moveItem(at: tempFile, to: documentsDatabaseURL)

            // 5. Open database connection
            try openDatabase()

            // 6. Verify the new database works
            let version = try await getVersion()
            guard version > 0 else {
                throw StockDatabaseError.invalidVersion("0")
            }

            // 7. Remove backup on success
            if fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.removeItem(at: backupURL)
            }

        } catch {
            // Restore backup if replacement failed
            if fileManager.fileExists(atPath: backupURL.path) {
                if fileManager.fileExists(atPath: documentsDatabaseURL.path) {
                    try? fileManager.removeItem(at: documentsDatabaseURL)
                }
                try fileManager.moveItem(at: backupURL, to: documentsDatabaseURL)
                try openDatabase()
            }

            throw StockDatabaseError.cannotOpenDatabase("Failed to replace database: \(error.localizedDescription)")
        }
    }

    /// Verify database has expected structure
    private func verifyDatabaseStructure(at url: URL) async throws {
        var db: OpaquePointer?

        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw StockDatabaseError.cannotOpenDatabase(errorMessage)
        }

        defer {
            sqlite3_close(db)
        }

        // Check for required tables using simple query (no parameter binding issues)
        let query = "SELECT name FROM sqlite_master WHERE type='table'"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw StockDatabaseError.queryFailed("Failed to prepare table check query")
        }

        defer {
            sqlite3_finalize(statement)
        }

        var foundTables = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let namePtr = sqlite3_column_text(statement, 0) {
                foundTables.insert(String(cString: namePtr))
            }
        }

        let requiredTables: Set<String> = ["stock_status", "metadata"]
        let missingTables = requiredTables.subtracting(foundTables)

        if !missingTables.isEmpty {
            throw StockDatabaseError.invalidStructure("Missing required table: \(missingTables.first!)")
        }
    }
}

// MARK: - Errors

enum StockDatabaseError: LocalizedError {
    case cannotOpenDatabase(String)
    case queryFailed(String)
    case versionNotFound
    case invalidVersion(String)
    case databaseNotInitialized
    case invalidStructure(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpenDatabase(let message):
            return "Cannot open stock database: \(message)"
        case .queryFailed(let message):
            return "Database query failed: \(message)"
        case .versionNotFound:
            return "Database version not found in metadata"
        case .invalidVersion(let version):
            return "Invalid database version: \(version)"
        case .databaseNotInitialized:
            return "Stock database not initialized - no database downloaded yet"
        case .invalidStructure(let message):
            return "Invalid database structure: \(message)"
        }
    }
}
