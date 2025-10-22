//
//  CatalogItemModel.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Child-level catalog item representing specific variants (rod, frit, sheet, etc.)
/// Contains variant-specific properties while linking to parent via parent_id
nonisolated struct CatalogItemModel: Identifiable, Equatable, Hashable, Sendable {
    // Backward compatibility: keep id as String, add id2 as UUID for new architecture
    let id: String        // Legacy primary key - keep for backward compatibility
    let id2: UUID         // New primary key - will replace id after migration
    let parent_id: UUID   // Foreign key to CatalogItemParentModel.id
    
    // Child-specific properties
    let item_type: String     // e.g., "rod", "frit", "sheet"
    let item_subtype: String? // e.g., "coarse", "10x10", or nil
    let stock_type: String?   // e.g., "discontinued", or nil
    let manufacturer_url: String? // URL to manufacturer's product page
    let image_path: String?   // Local image file path
    let image_url: String?    // Remote image URL
    
    // Legacy properties for backward compatibility during migration
    let name: String          // Computed from parent + item_type/subtype
    let code: String          // Computed from parent base_code + variant
    let manufacturer: String  // From parent
    let tags: [String]        // From parent
    let units: Int16         // Legacy field, maps to CatalogUnits enum
    
    nonisolated init(
        id: String = UUID().uuidString,
        id2: UUID = UUID(),
        parent_id: UUID,
        item_type: String,
        item_subtype: String? = nil,
        stock_type: String? = nil,
        manufacturer_url: String? = nil,
        image_path: String? = nil,
        image_url: String? = nil,

        // Legacy backward compatibility fields
        name: String,
        code: String,
        manufacturer: String,
        tags: [String] = [],
        units: Int16 = 1
    ) {
        self.id = id
        self.id2 = id2
        self.parent_id = parent_id
        self.item_type = item_type
        self.item_subtype = item_subtype
        self.stock_type = stock_type
        self.manufacturer_url = manufacturer_url
        self.image_path = image_path
        self.image_url = image_url
        
        // Legacy backward compatibility
        self.name = name
        self.code = code
        self.manufacturer = manufacturer
        self.tags = tags
        self.units = units
    }
    
    /// Legacy compatibility initializer - maintains old API during migration
    /// Creates a catalog item using the old single-entity structure
    @available(*, deprecated, message: "Use parent-child initializer instead")
    nonisolated init(id: String = UUID().uuidString, name: String, rawCode: String, manufacturer: String, tags: [String] = [], units: Int16 = 1) {
        // Create temporary parent ID for legacy items
        let tempParentId = UUID()
        
        self.id = id
        self.id2 = UUID()
        self.parent_id = tempParentId
        
        // Parse item type from name (simple heuristic)
        let itemType = Self.extractItemTypeFromName(name)
        self.item_type = itemType.type
        self.item_subtype = itemType.subtype
        self.stock_type = nil
        self.manufacturer_url = nil
        self.image_path = nil
        self.image_url = nil
        
        // Legacy backward compatibility
        self.name = name
        self.manufacturer = manufacturer
        self.tags = tags
        self.units = units
        self.code = Self.constructFullCode(manufacturer: manufacturer, code: rawCode)
    }
    
    /// Convenience initializer from parent and variant info
    nonisolated init(
        parent: CatalogItemParentModel,
        item_type: String,
        item_subtype: String? = nil,
        stock_type: String? = nil,
        manufacturer_url: String? = nil,
        image_path: String? = nil,
        image_url: String? = nil
    ) {
        self.id = UUID().uuidString // Legacy ID
        self.id2 = UUID()           // New ID
        self.parent_id = parent.id
        self.item_type = item_type
        self.item_subtype = item_subtype
        self.stock_type = stock_type
        self.manufacturer_url = manufacturer_url
        self.image_path = image_path
        self.image_url = image_url
        
        // Compute legacy fields from parent + variant
        self.name = Self.constructVariantName(parent: parent, itemType: item_type, itemSubtype: item_subtype)
        self.code = Self.constructVariantCode(parent: parent, itemType: item_type, itemSubtype: item_subtype)
        self.manufacturer = parent.manufacturer
        self.tags = parent.tags
        self.units = 1 // Default
    }
    
    /// Constructs the full code by combining manufacturer and code
    /// Always creates "MANUFACTURER-CODE" format, only skipping if already has correct prefix
    /// This contains the core business logic for catalog code formatting
    nonisolated static func constructFullCode(manufacturer: String, code: String) -> String {
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
    
    // MARK: - Name and Code Construction Logic

    /// Constructs variant name from parent and type info
    nonisolated static func constructVariantName(parent: CatalogItemParentModel, itemType: String, itemSubtype: String?) -> String {
        var name = parent.base_name
        
        // Add item type
        name += " \(itemType.capitalized)"
        
        // Add subtype if present
        if let subtype = itemSubtype, !subtype.isEmpty {
            name += " (\(subtype))"
        }
        
        return name
    }
    
    /// Constructs variant code from parent and type info
    nonisolated static func constructVariantCode(parent: CatalogItemParentModel, itemType: String, itemSubtype: String?) -> String {
        var code = parent.base_code
        
        // Add type suffix (e.g., "-R" for rod, "-F" for frit)
        let typeSuffix = Self.getTypeSuffix(for: itemType)
        if !typeSuffix.isEmpty {
            code += "-\(typeSuffix)"
        }
        
        // Add subtype suffix if present
        if let subtype = itemSubtype, !subtype.isEmpty {
            let subtypeSuffix = Self.getSubtypeSuffix(for: subtype)
            if !subtypeSuffix.isEmpty {
                code += "-\(subtypeSuffix)"
            }
        }
        
        return code
    }
    
    /// Gets type suffix for codes (R=Rod, F=Frit, S=Sheet, etc.)
    nonisolated private static func getTypeSuffix(for itemType: String) -> String {
        switch itemType.lowercased() {
        case "rod": return "R"
        case "frit": return "F"
        case "sheet": return "S"
        case "stringers": return "ST"
        case "powder": return "P"
        default: return itemType.prefix(2).uppercased()
        }
    }

    /// Gets subtype suffix for codes
    nonisolated private static func getSubtypeSuffix(for subtype: String) -> String {
        switch subtype.lowercased() {
        case "coarse": return "C"
        case "fine": return "F"
        case "medium": return "M"
        default: return subtype.prefix(2).uppercased()
        }
    }
    
    /// Extracts item type and subtype from legacy name field
    /// Used during migration from old single-entity structure
    nonisolated private static func extractItemTypeFromName(_ name: String) -> (type: String, subtype: String?) {
        let lowercaseName = name.lowercased()
        
        // Simple heuristic - look for common type keywords
        if lowercaseName.contains("rod") {
            return ("rod", nil)
        } else if lowercaseName.contains("frit") {
            // Check for frit subtypes
            if lowercaseName.contains("coarse") {
                return ("frit", "coarse")
            } else if lowercaseName.contains("fine") {
                return ("frit", "fine")
            } else if lowercaseName.contains("medium") {
                return ("frit", "medium")
            }
            return ("frit", nil)
        } else if lowercaseName.contains("sheet") {
            return ("sheet", nil)
        } else if lowercaseName.contains("stringer") {
            return ("stringers", nil)
        } else if lowercaseName.contains("powder") {
            return ("powder", nil)
        }
        
        // Default to generic type
        return ("misc", nil)
    }
    
    // MARK: - Validation Logic
    
    /// Validates child catalog item data integrity and business rules
    /// This contains the core validation logic for child catalog items
    nonisolated func validate() throws {
        // Validate legacy ID format (for backward compatibility)
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CatalogValidationError.invalidBaseCode("Legacy ID cannot be empty")
        }
        
        // Validate item type
        guard !item_type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CatalogValidationError.invalidItemType("Item type cannot be empty")
        }
        
        // Validate item type against allowed values
        let allowedItemTypes = ["rod", "frit", "sheet", "stringers", "powder", "misc"]
        guard allowedItemTypes.contains(item_type.lowercased()) else {
            throw CatalogValidationError.invalidItemType("Item type '\(item_type)' not allowed. Must be one of: \(allowedItemTypes.joined(separator: ", "))")
        }
        
        // Validate item subtype if present
        if let subtype = item_subtype, !subtype.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = ["coarse", "fine", "medium", "10x10", "20x20", "5x5"]  // Future: could restrict to these allowed subtypes
            // Allow any non-empty subtype for now
            if subtype.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw CatalogValidationError.invalidItemSubtype("Item subtype cannot be empty if specified")
            }
        }
        
        // Validate URLs if present
        if let urlString = manufacturer_url, !urlString.isEmpty {
            guard URL(string: urlString) != nil else {
                throw CatalogValidationError.invalidRelationship("Manufacturer URL is not valid: \(urlString)")
            }
        }
        
        if let urlString = image_url, !urlString.isEmpty {
            guard URL(string: urlString) != nil else {
                throw CatalogValidationError.invalidRelationship("Image URL is not valid: \(urlString)")
            }
        }
        
        // Validate computed legacy fields for backward compatibility
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CatalogValidationError.invalidBaseName("Computed name cannot be empty")
        }
        
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CatalogValidationError.invalidBaseCode("Computed code cannot be empty")
        }
        
        guard !manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CatalogValidationError.invalidManufacturer("Manufacturer cannot be empty")
        }
    }
    
    /// Validates that this child item correctly references its parent
    /// This ensures parent-child relationship integrity from the child side
    nonisolated func validateParentRelationship(with parent: CatalogItemParentModel) throws {
        // First validate this child item
        try validate()
        
        // Validate parent reference
        guard parent_id == parent.id else {
            throw CatalogValidationError.orphanedChildren("Child \(id2) references parent \(parent_id) but parent has ID \(parent.id)")
        }
        
        // Validate consistency between child and parent properties
        guard manufacturer == parent.manufacturer else {
            throw CatalogValidationError.inconsistentData("Child manufacturer '\(manufacturer)' doesn't match parent '\(parent.manufacturer)'")
        }
        
        // Validate that computed name includes parent base name (for consistency check)
        guard name.contains(parent.base_name) else {
            throw CatalogValidationError.inconsistentData("Child name '\(name)' should contain parent base name '\(parent.base_name)'")
        }
        
        // Validate that computed code includes parent base code
        guard code.contains(parent.base_code) || parent.base_code.contains(extractBaseCode()) else {
            throw CatalogValidationError.inconsistentData("Child code '\(code)' should be related to parent base code '\(parent.base_code)'")
        }
    }
    
    /// Extracts the base code portion from this item's full code
    /// Helper method for validation and relationship checking
    nonisolated private func extractBaseCode() -> String {
        // Remove manufacturer prefix first
        let manufacturerPrefix = manufacturer.uppercased() + "-"
        var baseCode = code
        
        if baseCode.hasPrefix(manufacturerPrefix) {
            baseCode = String(baseCode.dropFirst(manufacturerPrefix.count))
        }
        
        // Remove type/subtype suffixes (anything after the last hyphen that looks like a suffix)
        let components = baseCode.components(separatedBy: "-")
        if components.count > 1 {
            // Keep all but the last component if the last looks like a type suffix
            let lastComponent = components.last?.uppercased() ?? ""
            let knownSuffixes = ["R", "F", "S", "ST", "P", "C", "M"]
            
            if knownSuffixes.contains(lastComponent) || lastComponent.count <= 2 {
                return components.dropLast().joined(separator: "-")
            }
        }
        
        return baseCode
    }
    
    /// Determines if an existing item should be updated with new data
    /// This implements sophisticated change detection logic for catalog items
    nonisolated static func hasChanges(existing: CatalogItemModel, new: CatalogItemModel) -> Bool {
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
    nonisolated private static func extractRawCode(from formattedCode: String, manufacturer: String) -> String {
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
    nonisolated static func tagsToString(_ tags: [String]) -> String {
        // Filter out empty strings, trim whitespace, and join with commas
        let cleanTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleanTags.joined(separator: ",")
    }
    
    /// Converts comma-separated string to tag array from Core Data storage
    /// This extracts the parsing logic needed for CoreDataCatalogRepository
    nonisolated static func stringToTags(_ tagString: String) -> [String] {
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
    nonisolated var searchableText: [String] {
        var searchableFields = [name, code, manufacturer].filter { !$0.isEmpty }
        searchableFields.append(contentsOf: tags)
        return searchableFields
    }
}
