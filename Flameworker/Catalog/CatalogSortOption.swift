//
//  CatalogSortOption.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//  Migrated to Repository Pattern on 10/13/25.
//

import Foundation

enum SortOption: String, CaseIterable {
    case name = "Name"
    case code = "Code"
    case manufacturer = "Manufacturer"
    
    /// KeyPath for CatalogItemModel (business model) instead of Core Data entity
    var keyPath: KeyPath<CatalogItemModel, String> {
        switch self {
        case .name: return \CatalogItemModel.name
        case .code: return \CatalogItemModel.code
        case .manufacturer: return \CatalogItemModel.manufacturer
        }
    }
    
    /// Sort function for business models (replaces NSSortDescriptor)
    func sort<T: CatalogSortable>(_ items: [T]) -> [T] {
        switch self {
        case .name:
            return items.sorted { (item1: T, item2: T) -> Bool in
                item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            }
        case .code:
            return items.sorted { (item1: T, item2: T) -> Bool in
                item1.code.localizedCaseInsensitiveCompare(item2.code) == .orderedAscending
            }
        case .manufacturer:
            return items.sorted { (item1: T, item2: T) -> Bool in
                item1.manufacturer.localizedCaseInsensitiveCompare(item2.manufacturer) == .orderedAscending
            }
        }
    }
    
    /// Sort function specifically for CatalogItemModel arrays
    func sortCatalogItems(_ items: [CatalogItemModel]) -> [CatalogItemModel] {
        return sort(items)
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
