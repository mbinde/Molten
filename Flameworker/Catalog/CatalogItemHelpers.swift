//
//  CatalogItemHelpers.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import Foundation
import SwiftUI
import CoreData

struct CatalogItemHelpers {
    
    // MARK: - Tags Helper Functions
    
    static func tagsForItem(_ item: CatalogItem) -> String {
        return CoreDataHelpers.safeStringValue(from: item, key: "tags")
    }
    
    static func tagsArrayForItem(_ item: CatalogItem) -> [String] {
        return CoreDataHelpers.safeStringArray(from: item, key: "tags")
    }
    
    // MARK: - Synonyms Helper Functions
    
    static func synonymsForItem(_ item: CatalogItem) -> String {
        return CoreDataHelpers.safeStringValue(from: item, key: "synonyms")
    }
    
    static func synonymsArrayForItem(_ item: CatalogItem) -> [String] {
        return CoreDataHelpers.safeStringArray(from: item, key: "synonyms")
    }
    
    // MARK: - COE Helper Functions
    
    static func coeForItem(_ item: CatalogItem) -> String {
        return CoreDataHelpers.safeStringValue(from: item, key: "coe")
    }
    
    // MARK: - Color Helper Functions
    
    static func colorForManufacturer(_ manufacturer: String?) -> Color {
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
}