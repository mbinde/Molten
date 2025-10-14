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
    
    // MARK: - Validation Logic
    
    /// Validates parent model data integrity and business rules
    /// This contains the core validation logic for parent catalog items
    func validate() throws {
        // Validate required fields
        guard !base_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CatalogValidationError.invalidBaseName("Base name cannot be empty")
        }
        
        guard !base_code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CatalogValidationError.invalidBaseCode("Base code cannot be empty")
        }
        
        guard !manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CatalogValidationError.invalidManufacturer("Manufacturer cannot be empty")
        }
        
        // Validate COE format (should be numeric)
        guard !coe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CatalogValidationError.invalidCOE("COE cannot be empty")
        }
        
        // COE should be parseable as an integer (common range 80-120)
        guard let coeInt = Int(coe), coeInt >= 50, coeInt <= 200 else {
            throw CatalogValidationError.invalidCOE("COE must be a number between 50 and 200, got: \(coe)")
        }
        
        // Validate base_code format (should not contain invalid characters)
        let invalidCodeCharacters = CharacterSet(charactersIn: "!@#$%^&*()+=[]{}|\\:;\"'<>?/`~")
        if base_code.rangeOfCharacter(from: invalidCodeCharacters) != nil {
            throw CatalogValidationError.invalidBaseCode("Base code contains invalid characters: \(base_code)")
        }
        
        // Validate tags (should not be empty strings)
        let invalidTags = tags.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !invalidTags.isEmpty {
            throw CatalogValidationError.invalidTags("Tags cannot contain empty strings")
        }
    }
    
    /// Validates parent-child relationship integrity
    /// This ensures the parent has valid properties for child relationships
    static func validateParentChildRelationship(parent: CatalogItemParentModel, children: [CatalogItemModel]) throws {
        // Validate parent first
        try parent.validate()
        
        // Validate all children reference this parent
        let orphanedChildren = children.filter { $0.parent_id != parent.id }
        if !orphanedChildren.isEmpty {
            throw CatalogValidationError.orphanedChildren("Found \(orphanedChildren.count) children not referencing parent \(parent.id)")
        }
        
        // Validate children have consistent properties with parent
        for child in children {
            // Child's computed properties should match parent where applicable
            if child.manufacturer != parent.manufacturer {
                throw CatalogValidationError.inconsistentData("Child \(child.id2) manufacturer '\(child.manufacturer)' doesn't match parent '\(parent.manufacturer)'")
            }
        }
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

// MARK: - Validation Errors

/// Validation errors for catalog item relationships
enum CatalogValidationError: Error, LocalizedError {
    case invalidBaseName(String)
    case invalidBaseCode(String)
    case invalidManufacturer(String)
    case invalidCOE(String)
    case invalidTags(String)
    case invalidItemType(String)
    case invalidItemSubtype(String)
    case orphanedChildren(String)
    case inconsistentData(String)
    case invalidRelationship(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidBaseName(let message),
             .invalidBaseCode(let message),
             .invalidManufacturer(let message),
             .invalidCOE(let message),
             .invalidTags(let message),
             .invalidItemType(let message),
             .invalidItemSubtype(let message),
             .orphanedChildren(let message),
             .inconsistentData(let message),
             .invalidRelationship(let message):
            return message
        }
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