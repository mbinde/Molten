//
//  CatalogDatabaseManager.swift
//  Molten
//
//  Manages the catalog SQLite database lifecycle including:
//  - Copying bundled database to Documents on first launch
//  - Version checking and OTA updates
//  - Database access and connection management
//

import Foundation
import SQLite3

/// Manages catalog database versioning and access
final class CatalogDatabaseManager: CatalogDatabaseManagerProtocol {

    // MARK: - Singleton

    nonisolated static let shared = CatalogDatabaseManager()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let databaseName = "catalog.sqlite"
    private let connectionLock = NSLock()
    private nonisolated(unsafe) var databaseConnection: OpaquePointer?

    /// URL of the catalog database in Documents directory
    private var documentsDatabaseURL: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(databaseName)
    }

    /// URL of the bundled catalog database in app bundle
    private var bundleDatabaseURL: URL? {
        Bundle.main.url(forResource: "catalog", withExtension: "sqlite")
    }

    // MARK: - Initialization

    private nonisolated init() {}

    deinit {
        closeDatabase()
    }

    // MARK: - Database Setup

    /// Initialize the catalog database (copy from bundle if needed)
    func initialize() async throws {
        // Check if database exists in Documents
        let databaseExists = fileManager.fileExists(atPath: documentsDatabaseURL.path)

        if !databaseExists {
            // First launch - copy from bundle
            try await copyBundleToDocuments()
        } else {
            // Check if bundle has newer version
            try await updateIfNeeded()
        }

        // Open database connection
        try openDatabase()
    }

    /// Copy bundled database to Documents directory
    private func copyBundleToDocuments() async throws {
        guard let bundleURL = bundleDatabaseURL else {
            throw CatalogDatabaseError.bundleDatabaseNotFound
        }

        // Remove any existing database (shouldn't exist, but be safe)
        if fileManager.fileExists(atPath: documentsDatabaseURL.path) {
            try fileManager.removeItem(at: documentsDatabaseURL)
        }

        // Copy bundle to Documents
        try fileManager.copyItem(at: bundleURL, to: documentsDatabaseURL)
    }

    /// Check if update is needed and perform update if necessary
    private func updateIfNeeded() async throws {
        let documentsVersion = try await getDocumentsVersion()
        let bundleVersion = try await getBundleVersion()

        // For now, only handle bundle updates (OTA updates to be added later)
        if bundleVersion > documentsVersion {
            try await copyBundleToDocuments()
        }
    }

    // MARK: - Version Management

    /// Get database version from Documents
    private func getDocumentsVersion() async throws -> Int {
        return try await getVersion(from: documentsDatabaseURL)
    }

    /// Get database version from bundle
    private func getBundleVersion() async throws -> Int {
        guard let bundleURL = bundleDatabaseURL else {
            return 0 // No bundle database
        }
        return try await getVersion(from: bundleURL)
    }

    /// Read version from a database file
    private func getVersion(from url: URL) async throws -> Int {
        var db: OpaquePointer?

        // Open database in read-only mode
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw CatalogDatabaseError.cannotOpenDatabase(errorMessage)
        }

        defer {
            sqlite3_close(db)
        }

        // Query version from metadata table
        let query = "SELECT value FROM metadata WHERE key = 'version'"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw CatalogDatabaseError.queryFailed(errorMessage)
        }

        defer {
            sqlite3_finalize(statement)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw CatalogDatabaseError.versionNotFound
        }

        let versionString = String(cString: sqlite3_column_text(statement, 0))
        guard let version = Int(versionString) else {
            throw CatalogDatabaseError.invalidVersion(versionString)
        }

        return version
    }

    // MARK: - Database Access

    /// Open database connection
    private func openDatabase() throws {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        guard sqlite3_open(documentsDatabaseURL.path, &databaseConnection) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(databaseConnection))
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

    /// Get the active database connection (for repository use)
    /// WARNING: This is unsafe for multi-threaded access. Use performDatabaseOperation instead.
    @available(*, deprecated, message: "Use performDatabaseOperation for thread-safe access")
    nonisolated func getDatabaseConnection() throws -> OpaquePointer {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        guard let connection = databaseConnection else {
            throw CatalogDatabaseError.databaseNotInitialized
        }
        return connection
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

    // MARK: - OTA Updates

    /// Replace current database with downloaded update
    /// - Parameter tempFile: URL of the downloaded database file
    func replaceDatabaseWith(tempFile: URL) async throws {
        // 1. Verify temp file is valid SQLite database
        let _ = try await getVersion(from: tempFile)

        // 2. Close current database connection
        closeDatabase()

        // 3. Backup current database (in case of failure)
        let backupURL = documentsDatabaseURL.deletingLastPathComponent()
            .appendingPathComponent("catalog_backup.sqlite")

        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }

        if fileManager.fileExists(atPath: documentsDatabaseURL.path) {
            try fileManager.moveItem(at: documentsDatabaseURL, to: backupURL)
        }

        // 4. Move temp file to Documents
        do {
            try fileManager.moveItem(at: tempFile, to: documentsDatabaseURL)

            // 5. Reopen database connection
            try openDatabase()

            // 6. Verify the new database works
            let _ = try await getDocumentsVersion()

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

            throw CatalogDatabaseError.cannotOpenDatabase("Failed to replace database: \(error.localizedDescription)")
        }
    }
}

// MARK: - Errors

enum CatalogDatabaseError: LocalizedError {
    case bundleDatabaseNotFound
    case cannotOpenDatabase(String)
    case queryFailed(String)
    case versionNotFound
    case invalidVersion(String)
    case databaseNotInitialized

    var errorDescription: String? {
        switch self {
        case .bundleDatabaseNotFound:
            return "Bundled catalog database not found in app bundle"
        case .cannotOpenDatabase(let message):
            return "Cannot open database: \(message)"
        case .queryFailed(let message):
            return "Database query failed: \(message)"
        case .versionNotFound:
            return "Database version not found in metadata"
        case .invalidVersion(let version):
            return "Invalid database version: \(version)"
        case .databaseNotInitialized:
            return "Database not initialized - call initialize() first"
        }
    }
}
