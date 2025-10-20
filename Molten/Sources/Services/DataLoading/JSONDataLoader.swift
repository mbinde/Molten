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
private let enableJSONParsingDebugLogs = true

/// Handles finding, loading, and decoding JSON data from the app bundle
struct JSONDataLoader {
    private let logger = Logger(subsystem: "com.flameworker.jsonDataLoader", category: "JSONDataLoader")
    
    // MARK: - Private Logging Helper
    
    private func debugLog(_ message: String) {
        if enableJSONParsingDebugLogs {
            logger.info("\(message)")
        }
    }
    
    /// Finds and loads JSON data for the catalog from common bundle locations
    func findCatalogJSONData() throws -> Data {
        // Debug bundle contents
        debugBundleContents()

        // Candidate resource paths to try in order (new format first)
        let candidateNames = [
            "glassitems.json",
            "Sources/Resources/glassitems.json",
            "glassitems.json",
            "Sources/Resources/glassitems.json"
        ]

        for name in candidateNames {
            if let data = try? loadDataFromBundle(resourceName: name) {
                debugLog("Successfully loaded \(name), size: \(data.count) bytes")
                return data
            }
        }

        throw JSONDataLoadingError.fileNotFound("Could not find glassitems.json or glassitems.json in bundle")
    }
    
    /// Decodes catalog items from the new glassitems JSON format
    /// Also extracts and stores metadata (version, generated timestamp) for bug reports
    func decodeCatalogItems(from data: Data) throws -> [CatalogItemData] {
        let decoder = JSONDecoder()

        // Decode the new format: { "version": "1.0", "generated": "...", "glassitems": [...] }
        do {
            let wrapped = try decoder.decode(WrappedGlassItemsData.self, from: data)
            debugLog("Decoded glass items JSON structure with \(wrapped.glassitems.count) items")
            debugLog("Version: \(wrapped.metadata.version), Generated: \(wrapped.metadata.generated)")

            // Store metadata for debugging/bug reports
            storeMetadata(wrapped.metadata)

            return wrapped.glassitems
        } catch {
            // Log a preview of the JSON to help debug
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.error("Failed to decode JSON. First 500 characters: \(String(jsonString.prefix(500)))")
            }

            throw JSONDataLoadingError.decodingFailed("Expected JSON format: { \"version\": \"1.0\", \"generated\": \"...\", \"glassitems\": [...] }. Error: \(error.localizedDescription)")
        }
    }

    /// Store catalog metadata in UserDefaults for bug reports
    private func storeMetadata(_ metadata: CatalogMetadata) {
        let defaults = UserDefaults.standard
        defaults.set(metadata.version, forKey: "CatalogDataVersion")
        defaults.set(metadata.generated, forKey: "CatalogDataGenerated")
        if let itemCount = metadata.itemCount {
            defaults.set(itemCount, forKey: "CatalogDataItemCount")
        }
        debugLog("Stored catalog metadata: version=\(metadata.version), generated=\(metadata.generated)")
    }
    
    // MARK: - Private Helpers
    
    private func debugBundleContents() {
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
    
    private func loadDataFromBundle(resourceName: String) throws -> Data {
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
