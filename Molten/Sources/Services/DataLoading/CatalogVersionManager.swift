//
//  CatalogVersionManager.swift
//  Molten
//
//  Created by Assistant on 2025-11-12.
//  Manages catalog data versioning and wipes when schema changes
//

import Foundation
import OSLog

/// Manages catalog data versioning to detect breaking changes that require data wipes
final class CatalogVersionManager: Sendable {

    // MARK: - Properties

    private let catalogDataVersionKey = "com.flameworker.catalog.data.version"
    nonisolated private let jsonLoader: any JSONDataLoading
    nonisolated private let catalogService: CatalogService

    // MARK: - Initialization

    /// Initialize version manager with dependencies
    /// - Parameters:
    ///   - jsonLoader: Loader for accessing catalog JSON data
    ///   - catalogService: Service for wiping catalog data
    nonisolated init(jsonLoader: any JSONDataLoading, catalogService: CatalogService) {
        self.jsonLoader = jsonLoader
        self.catalogService = catalogService
    }

    // MARK: - Public API

    /// Check if JSON has a newer catalog_data_version that requires wiping and reloading all data
    /// - Returns: true if JSON version > stored version (need to wipe and reload)
    /// - Throws: If JSON data cannot be loaded or parsed
    func needsCatalogDataWipe() throws -> Bool {
        // Load JSON to check version
        let data = try jsonLoader.findCatalogJSONData()

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jsonVersion = json["catalog_data_version"] as? Int else {
            Logger.dataLoading.warning("JSON does not contain catalog_data_version, assuming no wipe needed")
            return false
        }

        // Get stored version (defaults to 0 if never set)
        let storedVersion = UserDefaults.standard.integer(forKey: catalogDataVersionKey)

        if jsonVersion > storedVersion {
            Logger.dataLoading.warning("🔄 Catalog data version increased (\(storedVersion) → \(jsonVersion)), will wipe and reload")
            return true
        } else {
            Logger.dataLoading.info("✅ Catalog data version unchanged (\(storedVersion))")
            return false
        }
    }

    /// Save current catalog data version after successful load
    /// - Throws: If JSON data cannot be loaded or parsed
    func saveCatalogDataVersion() throws {
        let data = try jsonLoader.findCatalogJSONData()

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["catalog_data_version"] as? Int else {
            Logger.dataLoading.warning("JSON does not contain catalog_data_version, cannot save")
            return
        }

        UserDefaults.standard.set(version, forKey: catalogDataVersionKey)
        Logger.dataLoading.info("💾 Saved catalog data version: \(version)")
    }

    /// Get current catalog data version from JSON
    /// - Returns: Version number from JSON, or nil if not found
    /// - Throws: If JSON data cannot be loaded or parsed
    func getCurrentVersion() throws -> Int? {
        let data = try jsonLoader.findCatalogJSONData()

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["catalog_data_version"] as? Int else {
            return nil
        }

        return version
    }

    /// Get stored catalog data version
    /// - Returns: Stored version number, or 0 if never set
    func getStoredVersion() -> Int {
        UserDefaults.standard.integer(forKey: catalogDataVersionKey)
    }

    /// Delete all catalog-related data (GlassItems and tags)
    /// - Throws: If deletion fails
    func wipeCatalogData() async throws {
        Logger.dataLoading.warning("🗑️ Wiping all catalog data (GlassItems and tags)...")

        // Delete all GlassItems
        let allItems = try await catalogService.getAllGlassItems()
        Logger.dataLoading.info("Deleting \(allItems.count) GlassItems...")

        for item in allItems {
            try await catalogService.deleteGlassItem(stableId: item.glassItem.stable_id)
        }

        Logger.dataLoading.info("✅ All catalog data wiped")
    }

    /// Clear stored version (useful for testing or forcing a reload)
    func clearStoredVersion() {
        UserDefaults.standard.removeObject(forKey: catalogDataVersionKey)
        Logger.dataLoading.info("🗑️ Cleared stored catalog data version")
    }
}
