//
//  InventoryView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct InventoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var showingAddItem = false
    @State private var selectedItem: InventoryItem?
    
    // Fetch request for inventory items
    @FetchRequest(
        entity: InventoryItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \InventoryItem.id, ascending: true)]
    ) private var inventoryItems: FetchedResults<InventoryItem>
    
    // Filtered items based on search
    private var filteredItems: [InventoryItem] {
        if searchText.isEmpty {
            return Array(inventoryItems)
        } else {
            return inventoryItems.filter { item in
                let searchLower = searchText.lowercased()
                
                // Search in catalog_code if available
                if let catalogCode = item.catalog_code?.lowercased(), catalogCode.contains(searchLower) {
                    return true
                }
                
                // Search in notes if available
                if let notes = item.notes?.lowercased(), notes.contains(searchLower) {
                    return true
                }
                
                // Search in id
                if let id = item.id?.lowercased(), id.contains(searchLower) {
                    return true
                }
                
                return false
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if inventoryItems.isEmpty {
                    inventoryEmptyState
                } else if filteredItems.isEmpty && !searchText.isEmpty {
                    searchEmptyStateView
                } else {
                    inventoryListView
                }
            }
            .navigationTitle("Inventory")
            .searchable(text: $searchText, prompt: "Search inventory...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddInventoryItemView()
            }
            .sheet(item: $selectedItem) { item in
                InventoryItemDetailView(item: item)
            }
        }
    }
    
    // MARK: - Views
    
    private var inventoryEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Inventory Items")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start tracking your glass rod inventory by adding your first item.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingAddItem = true
            } label: {
                Label("Add First Item", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top)
            
            Spacer()
            
            // Feature preview
            VStack(alignment: .leading, spacing: 12) {
                Text("With inventory tracking you can:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Track rod quantities and units", systemImage: "archivebox")
                    Label("Create shopping lists", systemImage: "cart")
                    Label("Mark items for resale", systemImage: "dollarsign")
                    Label("Add notes and details", systemImage: "note.text")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
    }
    
    private var searchEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("No inventory items match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var inventoryListView: some View {
        List {
            ForEach(filteredItems, id: \.objectID) { item in
                InventoryItemRowView(item: item)
                    .onTapGesture {
                        selectedItem = item
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
    
    // MARK: - Actions
    
    private func deleteItem(_ item: InventoryItem) {
        do {
            try InventoryService.shared.deleteInventoryItem(item, from: viewContext)
        } catch {
            print("❌ Failed to delete inventory item: \(error)")
        }
    }
}

#Preview {
    InventoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
