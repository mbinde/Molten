//
//  CatalogItemHelpers.swift
//  Flameworker
//
//  Intelligently Combined and Enhanced Version
//  Created by Assistant on 10/01/25.
//

import Foundation
import SwiftUI
import CoreData

/// Comprehensive helper utilities for CatalogItem operations and display
/// This is the authoritative source for all CatalogItem helper functionality
struct CatalogItemHelpers {
    
    // MARK: - Tags Helper Functions
    
    /// Gets tags as a single string for a CatalogItem
    static func tagsForItem(_ item: CatalogItem) -> String {
        return CoreDataHelpers.safeStringValue(from: item, key: "tags")
    }
    
    /// Extracts tags as an array from a CatalogItem
    static func tagsArrayForItem(_ item: CatalogItem) -> [String] {
        return CoreDataHelpers.safeStringArray(from: item, key: "tags")
    }
    
    /// Creates a comma-separated tags string from an array
    static func createTagsString(from tags: [String]) -> String {
        return tags
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ",")
    }
    
    // MARK: - Synonyms Helper Functions
    
    /// Gets synonyms as a single string for a CatalogItem
    static func synonymsForItem(_ item: CatalogItem) -> String {
        return CoreDataHelpers.safeStringValue(from: item, key: "synonyms")
    }
    
    /// Extracts synonyms as an array from a CatalogItem
    static func synonymsArrayForItem(_ item: CatalogItem) -> [String] {
        return CoreDataHelpers.safeStringArray(from: item, key: "synonyms")
    }
    
    // MARK: - COE Helper Functions
    
    /// Gets COE as a string for a CatalogItem
    static func coeForItem(_ item: CatalogItem) -> String {
        return CoreDataHelpers.safeStringValue(from: item, key: "coe")
    }
    
    /// Gets the COE value as a display string with enhanced formatting
    static func getCOEDisplayValue(from item: CatalogItem) -> String? {
        if let coe = item.value(forKey: "coe") as? Int {
            return String(coe)
        } else if let coe = item.value(forKey: "coe") as? String, !coe.isEmpty {
            return coe
        }
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
    
    // MARK: - URL Utilities
    
    /// Validates if a manufacturer URL is valid and openable
    static func isManufacturerURLValid(_ item: CatalogItem) -> Bool {
        guard let urlString = item.value(forKey: "manufacturer_url") as? String,
              !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: urlString) else {
            return false
        }
        
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// Gets the manufacturer URL from a CatalogItem if it exists and is valid
    static func getManufacturerURL(from item: CatalogItem) -> URL? {
        guard let urlString = item.value(forKey: "manufacturer_url") as? String,
              !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else {
            return nil
        }
        
        return url
    }
    
    // MARK: - Display Helpers
    
    /// Formats a date for display in catalog contexts
    static func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Gets the stock type for display
    static func getStockType(from item: CatalogItem) -> String? {
        guard let stockType = item.value(forKey: "stock_type") as? String,
              !stockType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return stockType
    }
    
    // MARK: - Status Helpers
    
    /// Determines if a catalog item is discontinued
    static func isDiscontinued(_ item: CatalogItem) -> Bool {
        return item.end_date != nil
    }
    
    /// Determines if a catalog item is not yet available (future release)
    static func isFutureRelease(_ item: CatalogItem) -> Bool {
        guard let startDate = item.start_date else { return false }
        return startDate > Date()
    }
    
    /// Gets the availability status of a catalog item
    static func getAvailabilityStatus(_ item: CatalogItem) -> AvailabilityStatus {
        if isDiscontinued(item) {
            return .discontinued
        } else if isFutureRelease(item) {
            return .futureRelease
        } else {
            return .available
        }
    }
    
    // MARK: - Enhanced Data Access
    
    /// Get comprehensive item information for display
    static func getItemDisplayInfo(_ item: CatalogItem) -> CatalogItemDisplayInfo {
        return CatalogItemDisplayInfo(
            name: item.name ?? "Unknown Item",
            code: item.code ?? "N/A",
            manufacturer: item.manufacturer ?? "Unknown",
            manufacturerFullName: GlassManufacturers.fullName(for: item.manufacturer ?? "") ?? item.manufacturer ?? "Unknown",
            coe: getCOEDisplayValue(from: item),
            stockType: getStockType(from: item),
            tags: tagsArrayForItem(item),
            synonyms: synonymsArrayForItem(item),
            color: colorForManufacturer(item.manufacturer),
            availabilityStatus: getAvailabilityStatus(item),
            manufacturerURL: getManufacturerURL(from: item),
            imagePath: item.value(forKey: "image_path") as? String
        )
    }
}

// MARK: - Supporting Types

enum AvailabilityStatus {
    case available
    case discontinued
    case futureRelease
    
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
    let availabilityStatus: AvailabilityStatus
    let manufacturerURL: URL?
    let imagePath: String?
    
    /// Formatted display name with code
    var nameWithCode: String {
        return "\(name) (\(code))"
    }
    
    /// Check if item has additional info to show
    var hasExtendedInfo: Bool {
        return !tags.isEmpty || !synonyms.isEmpty || stockType != nil || imagePath != nil
    }
}
