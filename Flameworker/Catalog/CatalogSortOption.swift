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
    case startDate = "Start Date"
    
    var keyPath: KeyPath<CatalogItem, String?> {
        switch self {
        case .name: return \CatalogItem.name
        case .code: return \CatalogItem.code
        case .manufacturer: return \CatalogItem.manufacturer
        case .startDate: return \CatalogItem.name // We'll handle date sorting differently
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
        case .startDate:
            return NSSortDescriptor(keyPath: \CatalogItem.start_date, ascending: false)
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
        case .startDate:
            return "calendar"
        }
    }
}