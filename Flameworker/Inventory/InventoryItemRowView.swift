//
//  InventoryItemRowView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct InventoryItemRowView: View {
    let item: InventoryItem
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Main identifier (use the protocol method)
                Text(item.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // Favorite indicator
                if InventoryService.shared.isFavorite(item) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // Status indicators using reusable component
                InventoryStatusIndicators(
                    hasInventory: item.hasInventory,
                    needsShopping: item.needsShopping,
                    isForSale: item.isForSale
                )
            }
            
            // Details grid using reusable components
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                // Inventory info
                if item.hasInventory {
                    InventoryGridItemView(
                        title: "Inventory",
                        icon: "archivebox.fill",
                        color: .green,
                        amount: item.inventory_amount,
                        units: item.inventory_units
                    )
                }
                
                // Shopping info
                if item.needsShopping {
                    InventoryGridItemView(
                        title: "Shopping",
                        icon: "cart.fill",
                        color: .orange,
                        amount: item.shopping_amount,
                        units: item.shopping_units
                    )
                }
                
                // For Sale info
                if item.isForSale {
                    InventoryGridItemView(
                        title: "For Sale",
                        icon: "dollarsign.circle.fill",
                        color: .blue,
                        amount: item.forsale_amount,
                        units: item.forsale_units
                    )
                }
            }
            
            // Notes preview using helper
            if let notesPreview = InventoryDataValidator.createNotesPreview(
                inventory: item.inventory_notes,
                shopping: item.shopping_notes,
                forsale: item.forsale_notes
            ) {
                Text(notesPreview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Makes the entire row tappable
    }
}


#Preview {
    List {
        // Preview with some sample data
        InventoryItemRowView(item: {
            let item = InventoryItem(context: PersistenceController.preview.container.viewContext)
            item.id = "preview-1"
            item.custom_tags = "Clear Glass Rods"
            item.favorite = Data([1])
            item.inventory_amount = "50"
            item.inventory_units = "pieces"
            item.inventory_notes = "High quality borosilicate"
            item.shopping_amount = "25"
            item.shopping_units = "pieces"
            item.forsale_amount = "10"
            item.forsale_units = "pieces"
            return item
        }())
        
        InventoryItemRowView(item: {
            let item = InventoryItem(context: PersistenceController.preview.container.viewContext)
            item.id = "preview-2"
            item.custom_tags = "Colored Frit"
            item.inventory_amount = "200"
            item.inventory_units = "grams"
            return item
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
