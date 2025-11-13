//
//  CatalogDataValidator.swift
//  Molten
//
//  Created by Assistant on 2025-11-12.
//  Validates catalog JSON data before importing
//

import Foundation
import OSLog

/// Validates catalog data to detect errors before importing
final class CatalogDataValidator: Sendable {

    // MARK: - Properties

    nonisolated private let jsonLoader: any JSONDataLoading
    nonisolated private let catalogService: CatalogService

    // MARK: - Initialization

    /// Initialize validator with dependencies
    /// - Parameters:
    ///   - jsonLoader: Loader for accessing catalog JSON data
    ///   - catalogService: Service for checking existing items
    nonisolated init(jsonLoader: any JSONDataLoading, catalogService: CatalogService) {
        self.jsonLoader = jsonLoader
        self.catalogService = catalogService
    }

    // MARK: - Public API

    /// Validate all items in the JSON data
    /// - Returns: Validation result with errors and warnings
    /// - Throws: If JSON cannot be loaded or parsed
    func validateJSONData() async throws -> JSONValidationResult {
        let data = try jsonLoader.findCatalogJSONData()
        let catalogItems = try jsonLoader.decodeCatalogItems(from: data)

        var result = JSONValidationResult(
            totalItemsFound: 0,
            itemsWithErrors: 0,
            itemsWithWarnings: 0,
            validationDetails: []
        )
        result.totalItemsFound = catalogItems.count

        // Validate each item
        for (index, item) in catalogItems.enumerated() {
            let validation = await validateCatalogItem(item, index: index)
            result.merge(validation)
        }

        return result
    }

    // MARK: - Private Validation

    /// Validate a single catalog item
    /// - Parameters:
    ///   - catalogItem: Item to validate
    ///   - index: Index in the catalog array
    /// - Returns: Validation result for this item
    private func validateCatalogItem(_ catalogItem: CatalogItemData, index: Int) async -> ItemValidationResult {
        var result = ItemValidationResult(
            itemIndex: 0,
            itemCode: "",
            itemName: "",
            errors: [],
            warnings: []
        )
        result.itemIndex = index
        result.itemCode = catalogItem.code ?? "NO_CODE"
        result.itemName = catalogItem.name

        // Check required fields
        if catalogItem.name.isEmpty {
            result.errors.append("Name is empty")
        }

        // Code is now optional - only validate if present
        if let code = catalogItem.code, code.isEmpty {
            result.errors.append("Code is empty (present but blank)")
        }

        // Validate COE
        let coe = extractCOE(from: catalogItem)
        if coe < 80 || coe > 120 {
            result.warnings.append("COE value \(coe) is outside typical range (80-120)")
        }

        // Validate manufacturer
        let manufacturer = extractManufacturer(from: catalogItem)
        if manufacturer == "unknown" {
            result.warnings.append("Could not determine manufacturer")
        }

        // Validate natural key
        let naturalKey = generateNaturalKey(from: catalogItem)
        if let isAvailable = try? await catalogService.isNaturalKeyAvailable(naturalKey),
           !isAvailable {
            result.warnings.append("Natural key \(naturalKey) already exists")
        }

        return result
    }

    // MARK: - Extraction Helpers

    /// Extract manufacturer abbreviation from catalog item
    private func extractManufacturer(from catalogItem: CatalogItemData) -> String {
        // Manufacturers in the database are stored as abbreviations (e.g., "BE", "CiM", "EF", "GAF")
        // NOT as full names like "Bullseye Glass Co"

        // ALWAYS use the manufacturer field if provided (this is the proper manufacturer code from JSON)
        if let manufacturer = catalogItem.manufacturer, !manufacturer.isEmpty {
            return manufacturer  // Keep original case to match GlassManufacturers mapping
        }

        // Fallback: extract from code (format like "CIM-123" -> "CIM")
        // This is a legacy fallback for old data that might not have the manufacturer field
        if let code = catalogItem.code {
            let codeParts = code.components(separatedBy: "-")
            if codeParts.count >= 2 {
                return codeParts[0]  // Keep original case
            }
        }

        return "unknown"
    }

    /// Extract SKU from CatalogItemData (returns nil if code is missing)
    private func extractSKU(from catalogItem: CatalogItemData) -> String? {
        // Return the full code as the SKU if it exists
        // This ensures image loading works correctly since image files are named with the full code
        // For example: "OC-6023-83CC-F" stays as "OC-6023-83CC-F", not truncated to "6023"
        // Returns nil for manufacturers that don't use SKUs
        return catalogItem.code
    }

    /// Extract COE from CatalogItemData
    private func extractCOE(from catalogItem: CatalogItemData) -> Int32 {
        guard let coeString = catalogItem.coe else { return 96 } // Default to 96

        // Try to parse as integer
        if let coeInt = Int32(coeString) {
            return coeInt
        }

        // Try to parse as double and convert
        if let coeDouble = Double(coeString) {
            return Int32(coeDouble)
        }

        return 96 // Default fallback
    }

    /// Generate natural key from CatalogItemData
    /// CRITICAL: This always prefers stable_id from JSON when available.
    /// The stable_id is the primary identifier (6-char hash from the scraper database).
    /// natural_key is now a legacy field that mirrors stable_id.
    /// DO NOT use item_stable_id, manufacturer_url, or other fields for identification.
    private func generateNaturalKey(from catalogItem: CatalogItemData) -> String {
        // Use stable_id from JSON if available (preferred - this is the standard case)
        if let stableId = catalogItem.stable_id, !stableId.isEmpty {
            return stableId
        }

        // Fallback: generate a stable_id for very old data without one
        // stable_id is a 6-char hash, not a sequential key
        let manufacturer = extractManufacturer(from: catalogItem)
        let sku = extractSKU(from: catalogItem) ?? "NO_SKU"
        return String(format: "%06d", abs("\(manufacturer)-\(sku)".hashValue % 1000000))
    }
}
