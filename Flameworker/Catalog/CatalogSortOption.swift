//
//  CatalogSortOption.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import Foundation
import CoreData

enum SortOption: String, CaseIterable {
    case name = "Name"
    case code = "Code"
    case manufacturer = "Manufacturer"
    
    var keyPath: KeyPath<CatalogItem, String?> {
        switch self {
        case .name: return \CatalogItem.name
        case .code: return \CatalogItem.code
        case .manufacturer: return \CatalogItem.manufacturer
        }
    }
    
    var nsSortDescriptor: NSSortDescriptor {
        switch self {
        case .name:
            return NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)
        case .code:
            return NSSortDescriptor(keyPath: \CatalogItem.code, ascending: true)
        case .manufacturer:
            return NSSortDescriptor(keyPath: \CatalogItem.manufacturer, ascending: true)
        }
    }
    
    var sortIcon: String {
        switch self {
        case .name:
            return "textformat.abc"
        case .code:
            return "number"
        case .manufacturer:
            return "building.2"
        }
    }
}
