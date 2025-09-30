//
//  ConsolidatedInventoryItem.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import Foundation
import CoreData

/// Structure to hold consolidated inventory data for a catalog item
struct ConsolidatedInventoryItem: Identifiable {
    let id: String
    let catalogCode: String?
    let catalogItemName: String?
    let items: [InventoryItem]
    let totalInventoryCount: Double
    let totalBuyCount: Double
    let totalSellCount: Double
    let inventoryUnits: InventoryUnits?
    let buyUnits: InventoryUnits?
    let sellUnits: InventoryUnits?
    let hasNotes: Bool
    let allNotes: String
    
    // Computed properties for display
    var displayName: String {
        catalogItemName ?? catalogCode ?? items.first?.id ?? "Unknown Item"
    }
    
    var hasInventory: Bool {
        totalInventoryCount > 0 || totalBuyCount > 0 || totalSellCount > 0
    }
    
    var isLowStock: Bool {
        hasInventory && (totalInventoryCount + totalBuyCount + totalSellCount) <= 10
    }
}

// MARK: - ConsolidatedInventoryItem Extension

extension ConsolidatedInventoryItem {
    static func from(items: [InventoryItem], context: NSManagedObjectContext) -> ConsolidatedInventoryItem {
        let catalogCode = items.first?.catalog_code
        var catalogItemName: String? = nil
        
        // Try to load catalog item name
        if let catalogCode = catalogCode, !catalogCode.isEmpty {
            let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@ OR code == %@", catalogCode, catalogCode)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                catalogItemName = results.first?.name
            } catch {
                print("❌ Failed to load catalog item name: \(error)")
            }
        }
        
        // Calculate totals by type
        var totalInventoryCount = 0.0
        var totalBuyCount = 0.0
        var totalSellCount = 0.0
        var inventoryUnits: InventoryUnits? = nil
        var buyUnits: InventoryUnits? = nil
        var sellUnits: InventoryUnits? = nil
        
        for item in items {
            let itemType = InventoryItemType(rawValue: item.type) ?? .inventory
            let units = item.unitsKind
            
            switch itemType {
            case .inventory:
                totalInventoryCount += item.count
                inventoryUnits = units
            case .buy:
                totalBuyCount += item.count
                buyUnits = units
            case .sell:
                totalSellCount += item.count
                sellUnits = units
            }
        }
        
        // Collect notes
        let allNotes = items.compactMap { $0.notes }.filter { !$0.isEmpty }.joined(separator: " • ")
        
        return ConsolidatedInventoryItem(
            id: catalogCode ?? "unknown-\(UUID().uuidString)",
            catalogCode: catalogCode,
            catalogItemName: catalogItemName,
            items: items,
            totalInventoryCount: totalInventoryCount,
            totalBuyCount: totalBuyCount,
            totalSellCount: totalSellCount,
            inventoryUnits: inventoryUnits,
            buyUnits: buyUnits,
            sellUnits: sellUnits,
            hasNotes: !allNotes.isEmpty,
            allNotes: allNotes
        )
    }
}