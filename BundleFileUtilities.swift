//  BundleFileUtilities.swift
//  Flameworker
//
//  Created by Assistant on 10/11/25.
//

import Foundation

/// Utility class for working with bundle file operations
class BundleFileUtilities {
    
    /// Filters an array of file names to return only JSON files
    /// - Parameter fileNames: Array of file names to filter
    /// - Returns: Array containing only files with .json extension
    static func filterJSONFiles(from fileNames: [String]) -> [String] {
        return fileNames.filter { $0.hasSuffix(".json") }
    }
    
    /// Identifies the target file (colors.json) from a list of file names
    /// - Parameter fileNames: Array of file names to search
    /// - Returns: "colors.json" if found, nil otherwise
    static func identifyTargetFile(from fileNames: [String]) -> String? {
        return fileNames.contains("colors.json") ? "colors.json" : nil
    }
}