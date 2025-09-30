//
//  JSONDataLoader.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import Foundation
import OSLog

/// Handles finding, loading, and decoding JSON data from the app bundle
struct JSONDataLoader {
    private let log = Logger.dataLoading
    
    /// Finds and loads JSON data for the catalog from common bundle locations
    func findCatalogJSONData() throws -> Data {
        // Debug bundle contents
        debugBundleContents()
        
        // Candidate resource paths to try in order
        let candidateNames = [
            "colors.json",
            "Data/colors.json", 
            "effetre.json",
            "Data/effetre.json"
        ]
        
        for name in candidateNames {
            if let data = try? loadDataFromBundle(resourceName: name) {
                log.info("Successfully loaded \(name), size: \(data.count) bytes")
                return data
            }
        }
        
        throw DataLoadingError.fileNotFound("Could not find colors.json or effetre.json in bundle")
    }
    
    /// Decodes catalog items from data, supporting multiple JSON shapes and date formats
    func decodeCatalogItems(from data: Data) throws -> [CatalogItemData] {
        let decoder = JSONDecoder()
        
        // Try nested structure first
        if let wrapped = try? decoder.decode(WrappedColorsData.self, from: data) {
            log.info("Decoded nested JSON structure with \(wrapped.colors.count) items")
            return wrapped.colors
        }
        
        // Try dictionary/array with multiple date formats
        let possibleDateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"]
        
        for format in possibleDateFormats {
            let df = DateFormatter()
            df.dateFormat = format
            decoder.dateDecodingStrategy = .formatted(df)
            
            if let dict = try? decoder.decode([String: CatalogItemData].self, from: data) {
                log.info("Decoded dictionary with \(dict.count) items using date format: \(format)")
                return Array(dict.values)
            }
            if let array = try? decoder.decode([CatalogItemData].self, from: data) {
                log.info("Decoded array with \(array.count) items using date format: \(format)")
                return array
            }
        }
        
        // Try without date formatting
        decoder.dateDecodingStrategy = .deferredToDate
        if let dict = try? decoder.decode([String: CatalogItemData].self, from: data) {
            log.info("Decoded dictionary without date formatting: \(dict.count) items")
            return Array(dict.values)
        }
        if let array = try? decoder.decode([CatalogItemData].self, from: data) {
            log.info("Decoded array without date formatting: \(array.count) items")
            return array
        }
        
        // Log a preview of the JSON to help debug
        if let jsonString = String(data: data, encoding: .utf8) {
            log.debug("First 500 characters of JSON: \(String(jsonString.prefix(500)))")
        }
        
        throw DataLoadingError.decodingFailed("Could not decode JSON in any supported format")
    }
    
    // MARK: - Private Helpers
    
    private func debugBundleContents() {
        guard let bundlePath = Bundle.main.resourcePath else { return }
        
        log.debug("Bundle path: \(bundlePath)")
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            let jsonFiles = contents.filter { $0.hasSuffix(".json") }
            log.debug("JSON files in bundle root: \(jsonFiles)")
            
            // Also check Data subdirectory
            let dataPath = (bundlePath as NSString).appendingPathComponent("Data")
            if FileManager.default.fileExists(atPath: dataPath) {
                let dataContents = try FileManager.default.contentsOfDirectory(atPath: dataPath)
                let dataJsonFiles = dataContents.filter { $0.hasSuffix(".json") }
                log.debug("JSON files in Data folder: \(dataJsonFiles)")
            }
        } catch {
            log.error("Error reading bundle contents: \(String(describing: error))")
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
            throw DataLoadingError.fileNotFound("Resource not found: \(resourceName)")
        }
        
        guard let data = try? Data(contentsOf: jsonUrl) else {
            throw DataLoadingError.fileNotFound("Could not load data from: \(resourceName)")
        }
        
        return data
    }
}