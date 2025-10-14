//
//  CatalogItemParentModel.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//

import Foundation

/// Parent-level catalog item representing shared properties across variants
/// Contains the core business logic for catalog item parents
struct CatalogItemParentModel: Identifiable, Equatable, Hashable {
    let id: UUID
    let base_name: String
    let base_code: String  
    let manufacturer: String
    let coe: String
    let tags: [String]
    
    init(
        id: UUID = UUID(),
        base_name: String,
        base_code: String,
        manufacturer: String,
        coe: String,
        tags: [String] = []
    ) {
        self.id = id
        self.base_name = base_name
        self.base_code = base_code
        self.manufacturer = manufacturer
        self.coe = coe
        self.tags = tags
    }
    
    /// Creates a new parent with properly formatted code according to business rules
    /// This contains the core business logic for parent catalog item construction
    init(
        id: UUID = UUID(),
        base_name: String,
        raw_base_code: String,
        manufacturer: String,
        coe: String,
        tags: [String] = []
    ) {
        self.id = id
        self.base_name = base_name
        self.manufacturer = manufacturer
        self.coe = coe
        self.tags = tags
        self.base_code = Self.constructFullCode(manufacturer: manufacturer, code: raw_base_code)
    }
    
    /// Constructs the full code by combining manufacturer and code
    /// Always creates "MANUFACTURER-CODE" format, only skipping if already has correct prefix
    /// This contains the core business logic for catalog code formatting
    static func constructFullCode(manufacturer: String, code: String) -> String {
        let manufacturerPrefix = manufacturer.uppercased()
        
        // Only skip prefixing if the code already starts with the exact manufacturer prefix
        if code.hasPrefix("\(manufacturerPrefix)-") {
            return code
        }
        
        // Always construct the full code as "MANUFACTURER-CODE"
        return "\(manufacturerPrefix)-\(code)"
    }
    
    /// Determines if an existing parent should be updated with new data
    /// This implements sophisticated change detection logic for parent catalog items
    static func hasChanges(existing: CatalogItemParentModel, new: CatalogItemParentModel) -> Bool {
        // Compare all fields systematically
        if existing.base_name != new.base_name { return true }
        if existing.manufacturer != new.manufacturer { return true }
        if existing.coe != new.coe { return true }
        
        // Code comparison (compare raw codes, not formatted ones)
        let existingRawCode = extractRawCode(from: existing.base_code, manufacturer: existing.manufacturer)
        let newRawCode = extractRawCode(from: new.base_code, manufacturer: new.manufacturer)
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
    /// This extracts the conversion logic needed for Core Data repositories
    static func tagsToString(_ tags: [String]) -> String {
        // Filter out empty strings, trim whitespace, and join with commas
        let cleanTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleanTags.joined(separator: ",")
    }
    
    /// Converts comma-separated string to tag array from Core Data storage
    /// This extracts the parsing logic needed for Core Data repositories
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

extension CatalogItemParentModel: Searchable {
    var searchableText: [String] {
        var searchableFields = [base_name, base_code, manufacturer, coe].filter { !$0.isEmpty }
        searchableFields.append(contentsOf: tags)
        return searchableFields
    }
}