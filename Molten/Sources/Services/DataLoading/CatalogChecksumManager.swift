//
//  CatalogChecksumManager.swift
//  Molten
//
//  Created by Assistant on 2025-11-12.
//  Manages JSON file checksums for change detection
//

import Foundation
import OSLog

/// Manages catalog JSON file checksums to detect changes between app updates
final class CatalogChecksumManager: Sendable {

    // MARK: - Properties

    private let log = Logger.dataLoading
    private let checksumKey = "com.flameworker.json.checksum"
    private let resourceName: String
    private let resourceType: String

    // MARK: - Initialization

    /// Initialize with default glassitems.json resource
    init() {
        self.resourceName = "glassitems"
        self.resourceType = "json"
    }

    /// Initialize with custom resource name and type
    /// - Parameters:
    ///   - resourceName: Name of the resource file (without extension)
    ///   - resourceType: File extension (e.g., "json")
    init(resourceName: String, resourceType: String) {
        self.resourceName = resourceName
        self.resourceType = resourceType
    }

    // MARK: - Public API

    /// Check if JSON file has changed since last load
    /// - Returns: true if file has changed or is first run, false if unchanged
    /// - Throws: If file attributes cannot be read
    func hasFileChanged() throws -> Bool {
        // Get file attributes to compute checksum
        guard let filePath = Bundle.main.path(forResource: resourceName, ofType: resourceType) else {
            log.warning("Could not find \(resourceName).\(resourceType) file path, assuming changed")
            return true
        }

        let fileURL = URL(fileURLWithPath: filePath)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)

        guard let modificationDate = attributes[.modificationDate] as? Date,
              let fileSize = attributes[.size] as? Int64 else {
            log.warning("Could not read file attributes, assuming changed")
            return true
        }

        let currentChecksum = JSONChecksum(modificationDate: modificationDate, fileSize: fileSize)

        // Check stored checksum
        if let storedData = UserDefaults.standard.data(forKey: checksumKey),
           let storedChecksum = try? JSONDecoder().decode(JSONChecksum.self, from: storedData) {

            // Compare checksums
            let hasChanged = storedChecksum.modificationDate != currentChecksum.modificationDate ||
                           storedChecksum.fileSize != currentChecksum.fileSize

            if hasChanged {
                log.info("🔄 Detected JSON file change (mod date or size changed)")
            } else {
                log.info("✅ JSON file unchanged since last load, skipping")
            }

            return hasChanged
        } else {
            log.info("🆕 First run or no checksum found, will load JSON")
            return true
        }
    }

    /// Save current JSON file checksum to UserDefaults after successful load
    /// - Throws: If file attributes cannot be read
    func saveChecksum() throws {
        guard let filePath = Bundle.main.path(forResource: resourceName, ofType: resourceType) else {
            log.warning("Could not find \(resourceName).\(resourceType) file path, cannot save checksum")
            return
        }

        let fileURL = URL(fileURLWithPath: filePath)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)

        guard let modificationDate = attributes[.modificationDate] as? Date,
              let fileSize = attributes[.size] as? Int64 else {
            log.warning("Could not read file attributes, cannot save checksum")
            return
        }

        let checksum = JSONChecksum(modificationDate: modificationDate, fileSize: fileSize)
        let data = try JSONEncoder().encode(checksum)
        UserDefaults.standard.set(data, forKey: checksumKey)

        log.info("💾 Saved JSON checksum (size: \(fileSize) bytes, modified: \(modificationDate))")
    }

    /// Clear stored checksum (useful for testing or forcing a reload)
    func clearChecksum() {
        UserDefaults.standard.removeObject(forKey: checksumKey)
        log.info("🗑️ Cleared stored JSON checksum")
    }
}

// MARK: - Supporting Types

/// Store JSON file checksum in UserDefaults for change detection
private struct JSONChecksum: Codable {
    let modificationDate: Date
    let fileSize: Int64
}
