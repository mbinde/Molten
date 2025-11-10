//
//  JSONDataLoader.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import Foundation
import OSLog

// MARK: - JSON Data Loading Errors

/// Errors that can occur during JSON data loading
enum JSONDataLoadingError: Error, LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let message):
            return "File not found: \(message)"
        case .decodingFailed(let message):
            return "Decoding failed: \(message)"
        }
    }
}

// MARK: - Debug Logging Control
// Set this to true to enable detailed JSON parsing logs
nonisolated private let enableJSONParsingDebugLogs = true

/// Handles finding, loading, and decoding JSON data from the app bundle
struct JSONDataLoader {
    private let logger = Logger(subsystem: "com.flameworker.jsonDataLoader", category: "JSONDataLoader")
    
    // MARK: - Private Logging Helper

    nonisolated private func debugLog(_ message: String) {
        if enableJSONParsingDebugLogs {
            logger.info("\(message)")
        }
    }

    /// Finds and loads JSON data for a specific catalog type from common bundle locations
    /// - Parameter catalogType: The type of catalog to load ("glass", "coating", etc.)
    /// - Returns: The raw JSON data
    nonisolated func findCatalogJSONData(catalogType: String = "glass") throws -> Data {
        // Debug bundle contents
        debugBundleContents()

        // Build candidate resource paths based on catalog type
        let baseNames: [String]
        switch catalogType {
        case "glass":
            baseNames = ["glassitems.json", "glass_catalog.json"]
        case "coating":
            baseNames = ["coatings.json", "coatings_catalog.json"]
        default:
            baseNames = ["\(catalogType).json", "\(catalogType)_catalog.json"]
        }

        // Try each base name with and without subdirectory paths
        var candidateNames: [String] = []
        for baseName in baseNames {
            candidateNames.append(baseName)
            candidateNames.append("Sources/Resources/\(baseName)")
        }

        for name in candidateNames {
            if let data = try? loadDataFromBundle(resourceName: name) {
                debugLog("Successfully loaded \(name), size: \(data.count) bytes")
                return data
            }
        }

        throw JSONDataLoadingError.fileNotFound("Could not find \(catalogType) catalog JSON in bundle. Tried: \(candidateNames.joined(separator: ", "))")
    }

    /// Legacy method for backward compatibility - loads glass catalog
    nonisolated func findCatalogJSONData() throws -> Data {
        return try findCatalogJSONData(catalogType: "glass")
    }
    
    /// Decodes catalog items from JSON format
    /// Also extracts and stores metadata (version, generated timestamp) for bug reports
    /// Supports demo mode filtering via -DemoDataMode launch argument for glass items
    /// - Parameters:
    ///   - data: The JSON data to decode
    ///   - catalogType: The type of catalog ("glass", "coating", etc.)
    /// - Returns: Array of catalog item data
    nonisolated func decodeCatalogItems(from data: Data, catalogType: String = "glass") throws -> [CatalogItemData] {
        let decoder = JSONDecoder()

        do {
            let metadata: CatalogMetadata
            let items: [CatalogItemData]

            // Decode based on catalog type
            switch catalogType {
            case "glass":
                // Decode format: { "version": "1.0", "generated": "...", "glassitems": [...] }
                let wrapped = try decoder.decode(WrappedGlassItemsData.self, from: data)
                metadata = wrapped.metadata
                items = wrapped.glassitems
                debugLog("Decoded glass items JSON structure with \(items.count) items")

            case "coating":
                // Decode format: { "version": "1.0", "generated": "...", "coatings": [...] }
                let wrapped = try decoder.decode(WrappedCoatingsData.self, from: data)
                metadata = wrapped.metadata
                items = wrapped.coatings
                debugLog("Decoded coatings JSON structure with \(items.count) items")

            default:
                throw JSONDataLoadingError.decodingFailed("Unknown catalog type: \(catalogType)")
            }

            debugLog("Version: \(metadata.version), Generated: \(metadata.generated)")

            // Store metadata for debugging/bug reports
            storeMetadata(metadata, catalogType: catalogType)

            // Check for demo data mode (used for screenshots and documentation)
            // Note: Only applies to glass items for now
            let isDemoMode = ProcessInfo.processInfo.arguments.contains("-DemoDataMode")

            if isDemoMode && catalogType == "glass" {
                // Filter to only include demo manufacturers (always uses latest data!)
                let demoManufacturers: Set<String> = ["EF", "DH", "GA"]  // Effetre, Double Helix, Glass Alchemy
                let filteredItems = items.filter { item in
                    if let manufacturer = item.manufacturer {
                        return demoManufacturers.contains(manufacturer)
                    }
                    return false
                }

                debugLog("🎬 Demo Data Mode: Filtered to \(filteredItems.count) items from \(demoManufacturers.sorted().joined(separator: ", "))")
                return filteredItems
            }

            return items
        } catch {
            // Log a preview of the JSON to help debug
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.error("Failed to decode JSON. First 500 characters: \(String(jsonString.prefix(500)))")
            }

            let expectedFormat = catalogType == "glass"
                ? "{ \"version\": \"1.0\", \"generated\": \"...\", \"glassitems\": [...] }"
                : "{ \"version\": \"1.0\", \"generated\": \"...\", \"coatings\": [...] }"

            throw JSONDataLoadingError.decodingFailed("Expected JSON format: \(expectedFormat). Error: \(error.localizedDescription)")
        }
    }

    /// Legacy method for backward compatibility - decodes glass catalog
    nonisolated func decodeCatalogItems(from data: Data) throws -> [CatalogItemData] {
        return try decodeCatalogItems(from: data, catalogType: "glass")
    }

    /// Store catalog metadata in UserDefaults for bug reports
    /// - Parameters:
    ///   - metadata: The catalog metadata to store
    ///   - catalogType: The type of catalog (used for logging only; keys are not prefixed for backward compatibility)
    nonisolated private func storeMetadata(_ metadata: CatalogMetadata, catalogType: String = "glass") {
        let defaults = UserDefaults.standard
        // Store without prefix for backward compatibility with existing tests and consumers
        defaults.set(metadata.version, forKey: "CatalogDataVersion")
        defaults.set(metadata.generated, forKey: "CatalogDataGenerated")
        if let itemCount = metadata.itemCount {
            defaults.set(itemCount, forKey: "CatalogDataItemCount")
        }
        debugLog("Stored \(catalogType) catalog metadata: version=\(metadata.version), generated=\(metadata.generated)")
    }

    // MARK: - Private Helpers

    nonisolated private func debugBundleContents() {
        guard let bundlePath = Bundle.main.resourcePath else { return }
        
        logger.debug("Bundle path: \(bundlePath)")
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            let jsonFiles = contents.filter { $0.hasSuffix(".json") }
            logger.debug("JSON files in bundle root: \(jsonFiles)")
            
            // Also check Data subdirectory
            let dataPath = (bundlePath as NSString).appendingPathComponent("Data")
            if FileManager.default.fileExists(atPath: dataPath) {
                let dataContents = try FileManager.default.contentsOfDirectory(atPath: dataPath)
                let dataJsonFiles = dataContents.filter { $0.hasSuffix(".json") }
                logger.debug("JSON files in Data folder: \(dataJsonFiles)")
            }
        } catch {
            logger.error("Error reading bundle contents: \(String(describing: error))")
        }
    }
    
    nonisolated private func loadDataFromBundle(resourceName: String) throws -> Data {
        let components = resourceName.split(separator: "/")
        
        let url: URL?
        if components.count == 2 {
            // Use subdirectory-aware lookup
            let resource = String(components[1]).replacingOccurrences(of: ".json", with: "")
            let subdir = String(components[0])
            url = Bundle.main.url(forResource: resource, withExtension: "json", subdirectory: subdir)
        } else {
            let resource = String(resourceName).replacingOccurrences(of: ".json", with: "")
            url = Bundle.main.url(forResource: resource, withExtension: "json")
        }
        
        guard let jsonUrl = url else {
            throw JSONDataLoadingError.fileNotFound("Resource not found: \(resourceName)")
        }
        
        guard let data = try? Data(contentsOf: jsonUrl) else {
            throw JSONDataLoadingError.fileNotFound("Could not load data from: \(resourceName)")
        }
        
        return data
    }
}

// MARK: - Data Models for JSON Decoding
// Note: CatalogItemData and WrappedGlassItemsData are defined in CatalogDataModels.swift
