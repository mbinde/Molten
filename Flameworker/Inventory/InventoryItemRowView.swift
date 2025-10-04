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
    @State private var catalogItemName: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Main identifier - use catalog item name or fallback to catalog_code/id
                Text(catalogItemName ?? item.catalog_code ?? item.id ?? "Unknown Item")
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
                    HStack(spacing: 4) {
                        Image(systemName: item.typeSystemImage)
                            .foregroundColor(item.typeColor)
                            .font(.caption)
                                                
                        Text(item.formattedCountWithUnits)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
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
        .onAppear {
            loadCatalogItemName()
        }
        .onChange(of: item.catalog_code) { _, _ in
            loadCatalogItemName()
        }
    }
    
    private func loadCatalogItemName() {
        guard let catalogCode = item.catalog_code, !catalogCode.isEmpty else {
            catalogItemName = nil
            return
        }
        
        // Create fetch request to find catalog item by ID or code
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ OR code == %@", catalogCode, catalogCode)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let catalogItem = results.first {
                catalogItemName = catalogItem.name
            } else {
                catalogItemName = nil
            }
        } catch {
            print("❌ Failed to load catalog item name: \(error)")
            catalogItemName = nil
        }
    }
}


#Preview {
    List {
        // Preview with some sample data
        InventoryItemRowView(item: {
            let context = PersistenceController.preview.container.viewContext
            
            // Create catalog item first
            let catalogItem = CatalogItem(context: context)
            catalogItem.id = "BR-GLR-001"
            catalogItem.code = "BR-GLR-001"
            catalogItem.name = "Borosilicate Glass Rod"
            catalogItem.units = InventoryUnits.rods.rawValue
            
            let item = InventoryItem(context: context)
            item.id = "preview-1"
            item.catalog_code = "BR-GLR-001"
            item.count = 50.0
            item.type = InventoryItemType.sell.rawValue
            item.notes = "High quality borosilicate glass rods for flameworking"
            return item
        }())
        
        InventoryItemRowView(item: {
            let context = PersistenceController.preview.container.viewContext
            
            // Create catalog item first
            let catalogItem = CatalogItem(context: context)
            catalogItem.id = "FR-COL-002"
            catalogItem.code = "FR-COL-002"
            catalogItem.name = "Colored Frit"
            catalogItem.units = InventoryUnits.ounces.rawValue
            
            let item = InventoryItem(context: context)
            item.id = "preview-2"
            item.catalog_code = "FR-COL-002"
            item.count = 200.0
            item.type = InventoryItemType.buy.rawValue
            item.notes = "Assorted colored frit for decoration"
            return item
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
