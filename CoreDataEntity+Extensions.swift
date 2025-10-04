//
//  CoreDataEntity+Extensions.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Foundation
import CoreData

// MARK: - Core Data Entity Extensions
// Note: DisplayableEntity conformances temporarily removed due to compilation issues
// They can be added back once the protocol visibility issue is resolved

extension PurchaseRecord {
    /// Display title for the purchase record
    var displayTitle: String {
        if let catalogCode = catalog_code, !catalogCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return catalogCode
        } else if let id = id, !id.isEmpty {
            return "Item \(String(id.prefix(8)))"
        } else {
            return "Untitled Purchase"
        }
    }
}

extension CatalogItem {
    /// Display title for the catalog item  
    var displayTitle: String {
        if let code = code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return code
        } else if let id = id, !id.isEmpty {
            return "Item \(String(id.prefix(8)))"
        } else {
            return "Untitled Item"
        }
    }
}