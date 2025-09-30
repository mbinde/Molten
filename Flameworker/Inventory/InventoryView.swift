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
    @State private var selectedConsolidatedItem: ConsolidatedInventoryItem?
    @State private var selectedFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell] // All selected by default
    
    enum InventoryFilterType: CaseIterable, Hashable {
        case inventory, buy, sell
        
        var title: String {
            switch self {
            case .inventory: return "Inventory"
            case .buy: return "Buy"
            case .sell: return "Sell"
            }
        }
        
        var icon: String {
            switch self {
            case .inventory: return "archivebox.fill"
            case .buy: return "cart.fill"
            case .sell: return "dollarsign.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .inventory: return .blue
            case .buy: return .orange
            case .sell: return .green
            }
        }
    }
    
    // Fetch request for inventory items
    @FetchRequest(
        entity: InventoryItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \InventoryItem.id, ascending: true)]
    ) private var inventoryItems: FetchedResults<InventoryItem>
    
    // Consolidated items grouped by catalog item with filtering applied
    private var consolidatedItems: [ConsolidatedInventoryItem] {
        let filtered = filteredItems
        let grouped = Dictionary(grouping: filtered) { item in
            item.catalog_code ?? item.id ?? "unknown"
        }
        
        let consolidated = grouped.map { (key, items) in
            ConsolidatedInventoryItem.from(items: items, context: viewContext)
        }
        
        // Apply type filter to consolidated items
        let typeFiltered = consolidated.filter { consolidatedItem in
            // If no filters selected, show nothing
            if selectedFilters.isEmpty {
                return false
            }
            
            // Check if item matches any of the selected filter types
            var hasMatchingType = false
            
            if selectedFilters.contains(.inventory) && consolidatedItem.totalInventoryCount > 0 {
                hasMatchingType = true
            }
            
            if selectedFilters.contains(.buy) && consolidatedItem.totalBuyCount > 0 {
                hasMatchingType = true
            }
            
            if selectedFilters.contains(.sell) && consolidatedItem.totalSellCount > 0 {
                hasMatchingType = true
            }
            
            return hasMatchingType
        }
        
        return typeFiltered.sorted { item1, item2 in
            item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
        }
    }
    
    // Original filtered items based on search
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Inventory")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Filter tags in the navigation bar
                        HStack(spacing: 6) {
                            ForEach(InventoryFilterType.allCases, id: \.self) { filterType in
                                Button {
                                    toggleFilter(filterType)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: filterType.icon)
                                            .font(.caption2)
                                        Text(filterType.title)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(selectedFilters.contains(filterType) ? .white : filterType.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        selectedFilters.contains(filterType) ? filterType.color : Color.clear
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(filterType.color, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search inventory...")
            .sheet(isPresented: $showingAddItem) {
                AddInventoryItemView()
            }
            .sheet(item: $selectedItem) { item in
                InventoryItemDetailView(item: item)
            }
            .sheet(item: $selectedConsolidatedItem) { consolidatedItem in
                ConsolidatedInventoryDetailView(consolidatedItem: consolidatedItem)
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
            ForEach(consolidatedItems, id: \.id) { consolidatedItem in
                ConsolidatedInventoryRowView(consolidatedItem: consolidatedItem)
                    .onTapGesture {
                        selectedConsolidatedItem = consolidatedItem
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteConsolidatedItem(consolidatedItem)
                        } label: {
                            Label("Delete All", systemImage: "trash")
                        }
                    }
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleFilter(_ filterType: InventoryFilterType) {
        if selectedFilters.contains(filterType) {
            selectedFilters.remove(filterType)
        } else {
            selectedFilters.insert(filterType)
        }
    }
    
    private func deleteConsolidatedItem(_ consolidatedItem: ConsolidatedInventoryItem) {
        // Delete all items in the consolidated group
        for item in consolidatedItem.items {
            deleteItem(item)
        }
    }
    
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
