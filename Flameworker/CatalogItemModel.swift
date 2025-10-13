//
//  CatalogItemModel.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Simple data model for catalog items - no Core Data dependency
struct CatalogItemModel: Identifiable, Equatable {
    let id: String
    let name: String
    let code: String
    let manufacturer: String
    let tags: [String]
    
    init(id: String = UUID().uuidString, name: String, code: String, manufacturer: String, tags: [String] = []) {
        self.id = id
        self.name = name
        self.code = code
        self.manufacturer = manufacturer
        self.tags = tags
    }
    
    /// Creates a new CatalogItemModel with properly formatted code according to business rules
    /// This extracts the critical business logic from CatalogItemManager.constructFullCode()
    init(id: String = UUID().uuidString, name: String, rawCode: String, manufacturer: String, tags: [String] = []) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.tags = tags
        self.code = Self.constructFullCode(manufacturer: manufacturer, code: rawCode)
    }
    
    /// Constructs the full code by combining manufacturer and code
    /// Always creates "MANUFACTURER-CODE" format, only skipping if already has correct prefix
    /// This is the core business logic extracted from CatalogItemManager
    static func constructFullCode(manufacturer: String, code: String) -> String {
        let manufacturerPrefix = manufacturer.uppercased()
        
        // Only skip prefixing if the code already starts with the exact manufacturer prefix
        if code.hasPrefix("\(manufacturerPrefix)-") {
            return code
        }
        
        // Always construct the full code as "MANUFACTURER-CODE"
        // This handles cases like "TTL-8623" where the hyphen is part of the product code,
        // not a manufacturer separator
        let fullCode = "\(manufacturerPrefix)-\(code)"
        return fullCode
    }
    
    /// Determines if an existing item should be updated with new data
    /// This extracts the sophisticated change detection logic from CatalogItemManager.shouldUpdateExistingItem()
    static func hasChanges(existing: CatalogItemModel, new: CatalogItemModel) -> Bool {
        // Compare all fields systematically, similar to CatalogItemManager logic
        
        // Basic field comparisons
        if existing.name != new.name { return true }
        if existing.manufacturer != new.manufacturer { return true }
        
        // Code comparison (compare raw codes, not formatted ones)
        let existingRawCode = extractRawCode(from: existing.code, manufacturer: existing.manufacturer)
        let newRawCode = extractRawCode(from: new.code, manufacturer: new.manufacturer)
        if existingRawCode != newRawCode { return true }
        
        // Tag comparison - arrays must match exactly (including order and duplicates)
        if existing.tags != new.tags { return true }
        
        // No changes detected
        return false
    }
    
    /// Extracts the raw code by removing manufacturer prefix
    /// Helper method for change detection logic
    private static func extractRawCode(from formattedCode: String, manufacturer: String) -> String {
        let manufacturerPrefix = manufacturer.uppercased()
        let expectedPrefix = "\(manufacturerPrefix)-"
        
        if formattedCode.hasPrefix(expectedPrefix) {
            return String(formattedCode.dropFirst(expectedPrefix.count))
        }
        
        return formattedCode
    }
    
    // MARK: - Tag Conversion Utilities for Core Data Integration
    
    /// Converts tag array to comma-separated string for Core Data storage
    /// This extracts the conversion logic needed for CoreDataCatalogRepository
    static func tagsToString(_ tags: [String]) -> String {
        // Filter out empty strings and join with commas
        let cleanTags = tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return cleanTags.joined(separator: ",")
    }
    
    /// Converts comma-separated string to tag array from Core Data storage
    /// This extracts the parsing logic needed for CoreDataCatalogRepository  
    static func stringToTags(_ tagString: String) -> [String] {
        // Handle empty string
        guard !tagString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        // Split by comma and clean up whitespace
        return tagString.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Searchable Conformance

extension CatalogItemModel: Searchable {
    var searchableText: [String] {
        var searchableFields = [name, code, manufacturer].filter { !$0.isEmpty }
        searchableFields.append(contentsOf: tags)
        return searchableFields
    }
}