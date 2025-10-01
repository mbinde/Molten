//
//  ConsolidatedInventoryDetailView.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI
import CoreData

struct ConsolidatedInventoryDetailView: View {
    let consolidatedItem: ConsolidatedInventoryItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteAlert = false
    @State private var selectedIndividualItem: InventoryItem?
    @State private var showingAddItem = false
    @State private var refreshTrigger = 0 // Used to trigger view refresh
    
    // Fetch fresh data when refresh is triggered
    @State private var freshItems: [InventoryItem] = []
    
    // Use fresh items if available, otherwise fall back to original
    private var currentItems: [InventoryItem] {
        freshItems.isEmpty ? consolidatedItem.items : freshItems
    }
    
    // Computed fresh consolidated item with current data
    private var currentConsolidatedItem: ConsolidatedInventoryItem {
        if freshItems.isEmpty {
            return consolidatedItem
        } else {
            return ConsolidatedInventoryItem.from(items: freshItems, context: viewContext)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with catalog item info
                    headerSection
                                        
                    // Individual items section
                    individualItemsSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(consolidatedItem.displayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete All Items", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedIndividualItem) { item in
                InventoryItemDetailView(item: item)
            }
            .sheet(isPresented: $showingAddItem, onDismiss: {
                refreshData()
            }) {
                AddInventoryItemView(prefilledCatalogCode: consolidatedItem.catalogCode)
            }
            .onAppear {
                refreshData()
            }
            .alert("Delete All Items", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    deleteAllItems()
                }
            } message: {
                Text("This will delete all \(currentItems.count) inventory items for this catalog item. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentConsolidatedItem.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let catalogCode = currentConsolidatedItem.catalogCode {
                        Text("Catalog Code: \(catalogCode)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack {
                    Image(systemName: "square.stack.3d.up")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("\(currentItems.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            // Product image if available
            if let catalogCode = currentConsolidatedItem.catalogCode, 
               ImageHelpers.productImageExists(for: catalogCode) {
                HStack {
                    ProductImageDetail(itemCode: catalogCode, maxSize: 150)
                    Spacer()
                }
            }
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var individualItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                
                Spacer()
                
                Text("Tap to view details, edit, or delete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(currentItems.sorted(by: { item1, item2 in
                    // Sort by type first, then by count
                    if item1.type != item2.type {
                        return item1.type < item2.type
                    }
                    return item1.count > item2.count
                }), id: \.objectID) { item in
                    IndividualInventoryItemRow(item: item) {
                        selectedIndividualItem = item
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func refreshData() {
        // Fetch fresh inventory items for this catalog code
        guard let catalogCode = consolidatedItem.catalogCode else {
            freshItems = []
            return
        }
        
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "catalog_code == %@", catalogCode)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.type, ascending: true)]
        
        do {
            freshItems = try viewContext.fetch(fetchRequest)
        } catch {
            print("❌ Failed to refresh inventory items: \(error)")
            freshItems = []
        }
    }
    
    private func deleteAllItems() {
        for item in currentItems {
            do {
                try InventoryService.shared.deleteInventoryItem(item, from: viewContext)
            } catch {
                print("❌ Failed to delete inventory item: \(error)")
            }
        }
        dismiss()
    }
    
    private func formatCount(_ count: Double, units: InventoryUnits?) -> String {
        let formattedCount: String
        if count.truncatingRemainder(dividingBy: 1) == 0 {
            formattedCount = String(format: "%.0f", count)
        } else {
            formattedCount = String(format: "%.1f", count)
        }
        
        let unitName = units?.displayName ?? "units"
        return "\(formattedCount) \(unitName)"
    }
}

// MARK: - Individual Item Row

struct IndividualInventoryItemRow: View {
    let item: InventoryItem
    let onTap: () -> Void
    
    private var itemType: InventoryItemType {
        InventoryItemType(rawValue: item.type) ?? .inventory
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Type icon
                Image(systemName: itemType.systemImageName)
                    .foregroundColor(itemType.color)
                    .font(.title3)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(itemType.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(item.formattedCountWithUnits)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ConsolidatedInventoryDetailView(consolidatedItem: ConsolidatedInventoryItem(
        id: "preview-id",
        catalogCode: "EF-GLR-001",
        catalogItemName: "Effetre Glass Rod - Blue",
        items: [],
        totalInventoryCount: 50.0,
        totalBuyCount: 25.0,
        totalSellCount: 10.0,
        inventoryUnits: InventoryUnits.rods,
        buyUnits: InventoryUnits.rods,
        sellUnits: InventoryUnits.rods,
        hasNotes: true,
        allNotes: "High quality glass rods"
    ))
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
