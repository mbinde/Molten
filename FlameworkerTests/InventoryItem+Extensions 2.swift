//
//  InventoryItem+Extensions.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Foundation
import SwiftUI
import CoreData

extension InventoryItem {
    
    // MARK: - Type Helper Properties
    
    /// Gets the InventoryItemType enum for this item
    var itemType: InventoryItemType {
        return InventoryItemType(from: self.type)
    }
    
    /// System image for the item type
    var typeSystemImage: String {
        return itemType.systemImage
    }
    
    /// Color for the item type
    var typeColor: Color {
        switch itemType {
        case .buy:
            return .blue
        case .sell:
            return .green
        case .unknown:
            return .gray
        }
    }
    
    // MARK: - Units and Display
    
    /// Gets the units for this inventory item through its catalog relationship
    var unitsKind: InventoryUnits {
        // Try to get units from catalog relationship first
        if let catalogCode = catalog_code,
           let catalogItem = getCatalogItem(),
           catalogItem.units > 0 {
            return InventoryUnits(from: catalogItem.units)
        }
        
        // Fallback to default
        return .rods
    }
    
    /// Formatted count with units
    var formattedCountWithUnits: String {
        let units = unitsKind
        return "\(Int(count)) \(units.displayName)"
    }
    
    // MARK: - Location Helpers
    
    /// Whether this item should show location field (when marked for inventory or sale)
    var shouldShowLocation: Bool {
        let type = InventoryItemType(from: self.type)
        return type == .buy || type == .sell
    }
    
    /// Safe access to location with empty string fallback
    var safeLocation: String {
        return location ?? ""
    }
    
    // MARK: - Private Helpers
    
    private func getCatalogItem() -> CatalogItem? {
        guard let catalogCode = catalog_code,
              let context = managedObjectContext else { return nil }
        
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ OR code == %@", catalogCode, catalogCode)
        fetchRequest.fetchLimit = 1
        
        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("❌ Failed to fetch catalog item: \(error)")
            return nil
        }
    }
}