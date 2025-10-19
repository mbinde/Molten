//
//  CatalogItemHelpers.swift
//  Flameworker
//
//  Intelligently Combined and Enhanced Version
//  Created by Assistant on 10/01/25.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Comprehensive helper utilities for CatalogItemModel operations and display (Repository Pattern)
/// This is the authoritative source for all catalog item helper functionality using business models
struct CatalogItemHelpers {
    
    // MARK: - Tags Helper Functions
    
    /// Gets tags as a single string for a CatalogItemModel
    static func tagsForItem(_ item: CatalogItemModel) -> String {
        return item.tags.joined(separator: ",")
    }
    
    /// Extracts tags as an array from a CatalogItemModel
    static func tagsArrayForItem(_ item: CatalogItemModel) -> [String] {
        return item.tags
    }
    
    /// Creates a comma-separated tags string from an array
    static func createTagsString(from tags: [String]) -> String {
        return tags
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ",")
    }
    
    // MARK: - Synonyms Helper Functions
    
    /// Gets synonyms as a single string for a CatalogItemModel
    static func synonymsForItem(_ item: CatalogItemModel) -> String {
        // Business models don't have synonyms field yet, return empty for now
        return ""
    }
    
    /// Extracts synonyms as an array from a CatalogItemModel
    static func synonymsArrayForItem(_ item: CatalogItemModel) -> [String] {
        // Business models don't have synonyms field yet, return empty for now
        return []
    }
    
    // MARK: - COE Helper Functions
    
    /// Gets COE as a string for a CatalogItemModel
    static func coeForItem(_ item: CatalogItemModel) -> String {
        // Business models don't have COE field yet, return empty for now
        return ""
    }
    
    /// Gets the COE value as a display string for business models
    static func getCOEDisplayValue(from item: CatalogItemModel) -> String? {
        // Business models don't have COE field yet, return nil for now
        return nil
    }
    
    // MARK: - Color Helper Functions
    
    /// Returns a color for a given manufacturer for consistent UI theming
    /// This function provides backward compatibility while leveraging GlassManufacturers when available
    static func colorForManufacturer(_ manufacturer: String?) -> Color {
        // Prefer the unified GlassManufacturers system if available
        let unifiedColor = GlassManufacturers.colorForManufacturer(manufacturer)
        if unifiedColor != .secondary || manufacturer == nil {
            return unifiedColor
        }
        
        // Fallback to original logic if unified system returns secondary
        let cleanManufacturer = manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "unknown"
        
        switch cleanManufacturer {
        case "effetre", "moretti":
            return .blue
        case "vetrofond":
            return .green
        case "reichenbach":
            return .purple
        case "double helix":
            return .orange
        case "northstar":
            return .red
        case "glass alchemy":
            return .mint
        case "zimmermann":
            return .yellow
        case "kugler":
            return .pink
        case "unknown":
            return .secondary
        default:
            // Generate a consistent color based on manufacturer name
            let hash = cleanManufacturer.hash
            let colors: [Color] = [.cyan, .indigo, .teal, .brown, .gray]
            return colors[abs(hash) % colors.count]
        }
    }
    
    // MARK: - URL Utilities (Business Model Version)
    
    /// Validates if a manufacturer URL is valid and openable using business model
    static func isManufacturerURLValid(_ item: CatalogItemModel) -> Bool {
        guard let url = getManufacturerURL(from: item) else {
            return false
        }

        #if canImport(UIKit)
        return UIApplication.shared.canOpenURL(url)
        #else
        return true // On non-UIKit platforms, assume URL is valid
        #endif
    }
    
    // MARK: - Display Helpers (Business Model Version)
    
    /// Formats a date for display in catalog contexts
    static func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - Status Helper Functions
    
    /// Determines if a catalog item is not yet available (future release)
    /// Check if item is a future release (business model version)
    static func isFutureRelease(_ item: CatalogItemModel) -> Bool {
        // Business models don't have start_date field, always return false
        return false
    }
    
    // MARK: - Enhanced Data Access
    
    /// Get comprehensive item information for display using business models
    static func getItemDisplayInfo(_ item: CatalogItemModel) -> CatalogItemDisplayInfo {
        return CatalogItemDisplayInfo(
            name: item.name,
            code: item.code,
            manufacturer: item.manufacturer,
            manufacturerFullName: GlassManufacturers.fullName(for: item.manufacturer) ?? item.manufacturer,
            coe: getCOEDisplayValue(from: item),
            stockType: getStockType(from: item),
            tags: tagsArrayForItem(item),
            synonyms: synonymsArrayForItem(item),
            color: colorForManufacturer(item.manufacturer),
            manufacturerURL: getManufacturerURL(from: item),
            imagePath: nil, // Business models don't have image_path field yet
            description: nil // Business models don't have manufacturer_description field yet
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func getStockType(from item: CatalogItemModel) -> String? {
        // Business models don't have stock type field yet, return nil
        return nil
    }
    
    private static func getManufacturerURL(from item: CatalogItemModel) -> URL? {
        // Business models don't have manufacturer_url field yet
        // Return nil for now - can be enhanced when field is added to business model
        return nil
    }
}

// MARK: - Supporting Types

enum AvailabilityStatus {
    case available
    case discontinued
    case futureRelease // Added for compatibility - will not be used since start_date was removed
    
    var displayText: String {
        switch self {
        case .available:
            return "Available"
        case .discontinued:
            return "Discontinued"
        case .futureRelease:
            return "Future Release"
        }
    }
    
    var color: Color {
        switch self {
        case .available:
            return .green
        case .discontinued:
            return .orange
        case .futureRelease:
            return .blue
        }
    }
    
    var shortDisplayText: String {
        switch self {
        case .available:
            return "Avail."
        case .discontinued:
            return "Disc."
        case .futureRelease:
            return "Future"
        }
    }
}

/// Comprehensive display information for a catalog item
struct CatalogItemDisplayInfo {
    let name: String
    let code: String
    let manufacturer: String
    let manufacturerFullName: String
    let coe: String?
    let stockType: String?
    let tags: [String]
    let synonyms: [String]
    let color: Color
    let manufacturerURL: URL?
    let imagePath: String?
    let description: String?
    
    /// Formatted display name with code
    var nameWithCode: String {
        return "\(name) (\(code))"
    }
    
    /// Check if item has additional info to show
    var hasExtendedInfo: Bool {
        return !tags.isEmpty || !synonyms.isEmpty || stockType != nil || imagePath != nil
    }
    
    /// Check if item has a description to display
    var hasDescription: Bool {
        return description != nil && !(description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
    
    /// Check if item has a manufacturer URL to link to
    var hasManufacturerURL: Bool {
        return manufacturerURL != nil
    }
}
