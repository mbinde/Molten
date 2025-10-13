//
//  ConsolidatedInventoryDetailView.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//  Repository-based detail view for consolidated inventory items
//

import SwiftUI

/// Detail view for a consolidated inventory item using repository pattern
struct ConsolidatedInventoryDetailView: View {
    let consolidatedItem: ConsolidatedInventoryModel
    let inventoryService: InventoryService
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: InventoryItemModel?
    @State private var items: [InventoryItemModel]
    
    init(consolidatedItem: ConsolidatedInventoryModel, inventoryService: InventoryService) {
        self.consolidatedItem = consolidatedItem
        self.inventoryService = inventoryService
        self._items = State(initialValue: consolidatedItem.items)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Summary Section
                Section("Summary") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(consolidatedItem.displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        // Totals
                        HStack(spacing: 24) {
                            InventoryStatView(
                                title: "Inventory", 
                                count: consolidatedItem.totalInventoryCount,
                                color: .blue,
                                icon: "archivebox.fill"
                            )
                            
                            InventoryStatView(
                                title: "Buy", 
                                count: consolidatedItem.totalBuyCount,
                                color: .orange,
                                icon: "cart.fill"
                            )
                            
                            InventoryStatView(
                                title: "Sell", 
                                count: consolidatedItem.totalSellCount,
                                color: .green,
                                icon: "dollarsign.circle.fill"
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Individual Items Section
                Section("Individual Items (\(items.count))") {
                    ForEach(items) { item in
                        InventoryItemRow(item: item)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    itemToDelete = item
                                    showingDeleteConfirmation = true
                                }
                            }
                    }
                }
            }
            .navigationTitle("Inventory Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Item?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    deleteItem(item)
                }
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func deleteItem(_ item: InventoryItemModel) {
        Task {
            do {
                try await inventoryService.deleteItem(id: item.id)
                
                // Update local state
                await MainActor.run {
                    items.removeAll { $0.id == item.id }
                    itemToDelete = nil
                }
            } catch {
                print("Error deleting inventory item: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct InventoryStatView: View {
    let title: String
    let count: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Text("\(count, specifier: "%.1f")")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct InventoryItemRow: View {
    let item: InventoryItemModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.catalogCode)
                    .font(.headline)
                
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: item.type.systemImageName)
                        .foregroundColor(item.type.color)
                    Text("\(item.quantity, specifier: "%.1f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text(item.type.displayName)
                    .font(.caption)
                    .foregroundColor(item.type.color)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    let sampleItems = [
        InventoryItemModel(
            catalogCode: "BULLSEYE-RGR-001",
            quantity: 5.0,
            type: .inventory,
            notes: "Red glass rods from workshop"
        ),
        InventoryItemModel(
            catalogCode: "BULLSEYE-RGR-001",
            quantity: 2.0,
            type: .buy,
            notes: "Recent purchase"
        )
    ]
    
    let consolidatedItem = ConsolidatedInventoryModel(
        catalogCode: "BULLSEYE-RGR-001",
        items: sampleItems
    )
    
    let mockRepo = MockInventoryRepository()
    let inventoryService = InventoryService(repository: mockRepo)
    
    return ConsolidatedInventoryDetailView(
        consolidatedItem: consolidatedItem,
        inventoryService: inventoryService
    )
}