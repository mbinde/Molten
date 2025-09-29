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
        // Get tags from Core Data - they're stored as comma-separated string
        if let tagsString = item.value(forKey: "tags") as? String {
            return tagsString
        }
        return ""
    }
    
    static func tagsArrayForItem(_ item: CatalogItem) -> [String] {
        let tagsString = tagsForItem(item)
        if tagsString.isEmpty {
            return []
        }
        return tagsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    // MARK: - Synonyms Helper Functions
    
    static func synonymsForItem(_ item: CatalogItem) -> String {
        // Get synonyms from Core Data - they're stored as comma-separated string
        // Handle case where synonyms attribute might not exist in the model
        do {
            if let synonymsString = item.value(forKey: "synonyms") as? String {
                return synonymsString
            }
        } catch {
            // Synonyms attribute doesn't exist in Core Data model
            return ""
        }
        return ""
    }
    
    static func synonymsArrayForItem(_ item: CatalogItem) -> [String] {
        let synonymsString = synonymsForItem(item)
        if synonymsString.isEmpty {
            return []
        }
        return synonymsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    // MARK: - COE Helper Functions
    
    static func coeForItem(_ item: CatalogItem) -> String {
        // Get COE from Core Data
        // Handle case where coe attribute might not exist in the model
        do {
            if let coeString = item.value(forKey: "coe") as? String {
                return coeString
            }
        } catch {
            // COE attribute doesn't exist in Core Data model
            return ""
        }
        return ""
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