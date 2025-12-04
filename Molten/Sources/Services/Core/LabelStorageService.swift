//
//  LabelStorageService.swift
//  Molten
//
//  Manages local storage of label database data
//

import Foundation
import OSLog

/// Protocol for label storage operations (for dependency injection)
protocol LabelStorageServiceProtocol: Actor {
    func saveTempDatabase(_ data: Data, version: Int) throws -> URL
    func getCurrentDatabaseURL() -> URL
    func cleanupTempFiles()
}

/// Manages local storage of label database
actor LabelStorageService: LabelStorageServiceProtocol {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let log = Logger(subsystem: "Molten", category: "LabelStorage")

    // Storage paths
    private let storageDirectory: URL
    private let tempDirectory: URL
    private let currentDatabaseFile: URL

    // MARK: - Initialization

    /// Initialize with default Application Support directory (production use)
    init() throws {
        let fm = FileManager.default

        // Get app support directory
        guard let appSupport = fm.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw LabelUpdateError.storageError(
                underlying: NSError(domain: "LabelStorage", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Cannot access Application Support directory"])
            )
        }

        let baseDirectory = appSupport.appendingPathComponent("LabelData", isDirectory: true)
        try self.init(storageDirectory: baseDirectory)
    }

    /// Initialize with custom storage directory (for testing)
    /// - Parameter storageDirectory: Base directory for label storage
    internal init(storageDirectory: URL) throws {
        let fm = FileManager.default

        // Setup directories
        self.storageDirectory = storageDirectory
        self.tempDirectory = storageDirectory.appendingPathComponent("Temp", isDirectory: true)
        self.currentDatabaseFile = storageDirectory.appendingPathComponent("labels.db")

        // Create directories if needed
        for directory in [self.storageDirectory, self.tempDirectory] {
            if !fm.fileExists(atPath: directory.path) {
                try fm.createDirectory(at: directory,
                                      withIntermediateDirectories: true,
                                      attributes: nil)
            }
        }

        log.info("Label storage initialized at: \(self.storageDirectory.path)")
    }

    // MARK: - Public API

    /// Save label database to temporary storage
    /// - Parameters:
    ///   - data: Label SQLite database data
    ///   - version: Database version number
    /// - Returns: URL of saved temp file
    func saveTempDatabase(_ data: Data, version: Int) throws -> URL {
        let tempFile = tempDirectory.appendingPathComponent("labels_v\(version)_temp.db")

        log.debug("Saving temp label database to: \(tempFile.path)")

        do {
            try data.write(to: tempFile, options: .atomic)
            log.info("Saved temp label database (\(data.count) bytes)")
            return tempFile
        } catch {
            log.error("Failed to save temp label database: \(error.localizedDescription)")
            throw LabelUpdateError.storageError(underlying: error)
        }
    }

    /// Get URL for current (downloaded) database
    /// Note: May not exist if using bundled database
    func getCurrentDatabaseURL() -> URL {
        return currentDatabaseFile
    }

    /// Check if a downloaded database exists
    func hasDownloadedDatabase() -> Bool {
        return fileManager.fileExists(atPath: currentDatabaseFile.path)
    }

    /// Promote temp database to current (atomic swap)
    /// - Parameter tempFile: URL of temp database file
    func promoteTempToCurrent(tempFile: URL) throws {
        log.debug("Promoting temp label database to current")

        do {
            // Remove old current database if exists
            if fileManager.fileExists(atPath: currentDatabaseFile.path) {
                try fileManager.removeItem(at: currentDatabaseFile)
            }

            // Move temp to current (atomic operation)
            try fileManager.moveItem(at: tempFile, to: currentDatabaseFile)

            log.info("✅ Promoted temp label database to current")
        } catch {
            log.error("Failed to promote temp label database: \(error.localizedDescription)")
            throw LabelUpdateError.storageError(underlying: error)
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

    /// Get size of stored label data
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
