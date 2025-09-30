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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with catalog item info
                    headerSection
                    
                    // Summary section
                    summarySection
                    
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
                    Menu {
                        Button {
                            showingAddItem = true
                        } label: {
                            Label("Add More Inventory", systemImage: "plus")
                        }
                        
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
            .sheet(isPresented: $showingAddItem) {
                AddInventoryItemView()
            }
            .alert("Delete All Items", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    deleteAllItems()
                }
            } message: {
                Text("This will delete all \(consolidatedItem.items.count) inventory items for this catalog item. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(consolidatedItem.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let catalogCode = consolidatedItem.catalogCode {
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
                Text("\(consolidatedItem.items.count)")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                if consolidatedItem.totalInventoryCount > 0 {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Inventory")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(formatCount(consolidatedItem.totalInventoryCount, units: consolidatedItem.inventoryUnits))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if consolidatedItem.totalBuyCount > 0 {
                    HStack {
                        Image(systemName: "cart.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Buy List")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(formatCount(consolidatedItem.totalBuyCount, units: consolidatedItem.buyUnits))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if consolidatedItem.totalSellCount > 0 {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sell List")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(formatCount(consolidatedItem.totalSellCount, units: consolidatedItem.sellUnits))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    @ViewBuilder
    private var individualItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Individual Items")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Tap to edit")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(consolidatedItem.items.sorted(by: { item1, item2 in
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
    
    private func deleteAllItems() {
        for item in consolidatedItem.items {
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
                    
                    if let id = item.id {
                        Text("ID: \(id)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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