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
                // Main identifier - use catalog_code or id as fallback
                Text(item.catalog_code ?? item.id ?? "Unknown Item")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // Status indicators
                HStack(spacing: 8) {
                    if item.count > 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    if item.count > 0 && item.count <= 10 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
            }
            
            // Item details
            HStack {
                if item.count > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: "archivebox.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Count")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Text(item.formattedCountWithUnits)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack {
                        Image(systemName: item.typeSystemImage)
                            .foregroundColor(item.typeColor)
                            .font(.caption)
                        Text("Type")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    Text(item.typeDisplayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Notes preview
            if let notes = item.notes, !notes.isEmpty {
                Text(notes)
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
            item.catalog_code = "BR-GLR-001"
            item.count = 50.0
            item.units = 1
            item.type = InventoryItemType.sell.rawValue
            item.notes = "High quality borosilicate glass rods for flameworking"
            return item
        }())
        
        InventoryItemRowView(item: {
            let item = InventoryItem(context: PersistenceController.preview.container.viewContext)
            item.id = "preview-2"
            item.catalog_code = "FR-COL-002"
            item.count = 200.0
            item.units = 2
            item.type = InventoryItemType.buy.rawValue
            item.notes = "Assorted colored frit for decoration"
            return item
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
