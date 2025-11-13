//
//  CatalogStorageService.swift
//  Molten
//
//  Created by Assistant on 11/9/25.
//  Manages local storage of catalog data
//

import Foundation
import OSLog

/// Protocol for catalog storage operations (for dependency injection)
protocol CatalogStorageServiceProtocol: Actor {
    func saveTempCatalog(_ data: Data, version: Int) throws -> URL
    func promoteTempToCurrent(tempFile: URL) throws
    func loadCurrentCatalog() -> Data?
    func cleanupTempFiles()
}

/// Manages local storage of catalog data
actor CatalogStorageService: CatalogStorageServiceProtocol {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let log = Logger(subsystem: "Molten", category: "CatalogStorage")

    // Storage paths
    private let storageDirectory: URL
    private let tempDirectory: URL
    private let currentCatalogFile: URL

    // MARK: - Initialization

    /// Initialize with default Application Support directory (production use)
    init() throws {
        let fm = FileManager.default

        // Get app support directory
        guard let appSupport = fm.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CatalogUpdateError.storageError(
                underlying: NSError(domain: "CatalogStorage", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Cannot access Application Support directory"])
            )
        }

        let baseDirectory = appSupport.appendingPathComponent("CatalogData", isDirectory: true)
        try self.init(storageDirectory: baseDirectory)
    }

    /// Initialize with custom storage directory (for testing)
    /// - Parameter storageDirectory: Base directory for catalog storage
    internal init(storageDirectory: URL) throws {
        let fm = FileManager.default

        // Setup directories
        self.storageDirectory = storageDirectory
        self.tempDirectory = storageDirectory.appendingPathComponent("Temp", isDirectory: true)
        self.currentCatalogFile = storageDirectory.appendingPathComponent("catalog.sqlite")

        // Create directories if needed
        for directory in [self.storageDirectory, self.tempDirectory] {
            if !fm.fileExists(atPath: directory.path) {
                try fm.createDirectory(at: directory,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
            }
        }

        log.info("Catalog storage initialized at: \(self.storageDirectory.path)")
    }

    // MARK: - Public API

    /// Save catalog database to temporary storage
    /// - Parameters:
    ///   - data: Catalog SQLite database data
    ///   - version: Catalog version number
    /// - Returns: URL of saved temp file
    func saveTempCatalog(_ data: Data, version: Int) throws -> URL {
        let tempFile = tempDirectory.appendingPathComponent("catalog_v\(version)_temp.sqlite")

        log.debug("Saving temp catalog database to: \(tempFile.path)")

        do {
            try data.write(to: tempFile, options: .atomic)
            log.info("Saved temp catalog database (\(data.count) bytes)")
            return tempFile
        } catch {
            log.error("Failed to save temp catalog: \(error.localizedDescription)")
            throw CatalogUpdateError.storageError(underlying: error)
        }
    }

    /// Promote temp catalog to current catalog (atomic swap)
    /// - Parameter tempFile: URL of temp catalog file
    func promoteTempToCurrent(tempFile: URL) throws {
        log.debug("Promoting temp catalog to current")

        do {
            // Remove old current catalog if exists
            if fileManager.fileExists(atPath: currentCatalogFile.path) {
                try fileManager.removeItem(at: currentCatalogFile)
            }

            // Move temp to current (atomic operation)
            try fileManager.moveItem(at: tempFile, to: currentCatalogFile)

            log.info("✅ Promoted temp catalog to current")
        } catch {
            log.error("Failed to promote temp catalog: \(error.localizedDescription)")
            throw CatalogUpdateError.storageError(underlying: error)
        }
    }

    /// Load current catalog database from storage
    /// - Returns: Catalog SQLite database data, or nil if no catalog exists
    func loadCurrentCatalog() -> Data? {
        guard fileManager.fileExists(atPath: currentCatalogFile.path) else {
            log.debug("No current catalog database file exists")
            return nil
        }

        do {
            let data = try Data(contentsOf: currentCatalogFile)
            log.debug("Loaded current catalog database (\(data.count) bytes)")
            return data
        } catch {
            log.error("Failed to load current catalog: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clean up old temp files
    func cleanupTempFiles() {
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory,
                                                               includingPropertiesForKeys: [.creationDateKey],
                                                               options: .skipsHiddenFiles)

            // Delete temp files older than 24 hours
            let cutoffDate = Date().addingTimeInterval(-86400)

            for fileURL in tempFiles {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {

                    try? fileManager.removeItem(at: fileURL)
                    log.debug("Deleted old temp file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            log.warning("Failed to cleanup temp files: \(error.localizedDescription)")
        }
    }

    /// Get size of stored catalog data
    func getStorageSize() -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: storageDirectory,
                                                   includingPropertiesForKeys: [.fileSizeKey],
                                                   options: .skipsHiddenFiles) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        }

        return totalSize
    }

}
