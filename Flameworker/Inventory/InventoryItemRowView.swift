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
                // Main identifier (use custom tags or ID)
                Text(displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // Favorite indicator
                if InventoryService.shared.isFavorite(item) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // Status indicators
                HStack(spacing: 4) {
                    if hasInventory {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    
                    if needsShopping {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                    }
                    
                    if isForSale {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            // Details grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                // Inventory info
                if hasInventory {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "archivebox.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Inventory")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        if let amount = item.inventory_amount, !amount.isEmpty {
                            Text("\(amount) \(item.inventory_units ?? "")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Shopping info
                if needsShopping {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "cart.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Shopping")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        if let amount = item.shopping_amount, !amount.isEmpty {
                            Text("\(amount) \(item.shopping_units ?? "")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // For Sale info
                if isForSale {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("For Sale")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        if let amount = item.forsale_amount, !amount.isEmpty {
                            Text("\(amount) \(item.forsale_units ?? "")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Notes preview (if any)
            if let notesPreview = notesPreview, !notesPreview.isEmpty {
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
    
    // MARK: - Computed Properties
    
    private var displayTitle: String {
        if let tags = item.custom_tags, !tags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return tags
        } else if let id = item.id, !id.isEmpty {
            return "Item \(String(id.prefix(8)))" // Show first 8 chars of ID
        } else {
            return "Untitled Item"
        }
    }
    
    private var hasInventory: Bool {
        (item.inventory_amount != nil && !item.inventory_amount!.isEmpty) ||
        (item.inventory_notes != nil && !item.inventory_notes!.isEmpty)
    }
    
    private var needsShopping: Bool {
        (item.shopping_amount != nil && !item.shopping_amount!.isEmpty) ||
        (item.shopping_notes != nil && !item.shopping_notes!.isEmpty)
    }
    
    private var isForSale: Bool {
        (item.forsale_amount != nil && !item.forsale_amount!.isEmpty) ||
        (item.forsale_notes != nil && !item.forsale_notes!.isEmpty)
    }
    
    private var notesPreview: String? {
        let allNotes = [item.inventory_notes, item.shopping_notes, item.forsale_notes]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " • ")
        
        return allNotes.isEmpty ? nil : allNotes
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