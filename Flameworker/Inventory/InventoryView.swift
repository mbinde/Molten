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
    @State private var selectedFilters: Set<InventoryFilterType> = []
    @State private var cachedFilteredItems: [InventoryItem] = [] // Renamed to avoid conflict
    @State private var sortOption: InventorySortOption = .name
    @State private var showingSortMenu = false
    
    enum InventorySortOption: CaseIterable {
        case name, inventoryCount, buyCount, sellCount
        
        var title: String {
            switch self {
            case .name: return "Name"
            case .inventoryCount: return "Inventory Count"
            case .buyCount: return "Buy Count"
            case .sellCount: return "Sell Count"
            }
        }
        
        var icon: String {
            switch self {
            case .name: return "textformat.abc"
            case .inventoryCount: return "archivebox.fill"
            case .buyCount: return "cart.fill"
            case .sellCount: return "dollarsign.circle.fill"
            }
        }
    }
    
    // Persist filter state using AppStorage
    @AppStorage("selectedInventoryFilters") private var selectedFiltersData: Data = Data()
    
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
            switch sortOption {
            case .name:
                return item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
            case .inventoryCount:
                if item1.totalInventoryCount != item2.totalInventoryCount {
                    return item1.totalInventoryCount > item2.totalInventoryCount // Descending (highest first)
                } else {
                    return item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
                }
            case .buyCount:
                if item1.totalBuyCount != item2.totalBuyCount {
                    return item1.totalBuyCount > item2.totalBuyCount // Descending (highest first)
                } else {
                    return item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
                }
            case .sellCount:
                if item1.totalSellCount != item2.totalSellCount {
                    return item1.totalSellCount > item2.totalSellCount // Descending (highest first)
                } else {
                    return item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
                }
            }
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
            .safeAreaInset(edge: .top) {
                // Custom search bar with inline sort button
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search inventory...", text: $searchText)
                        
                        // Clear button (X)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    Button {
                        showingSortMenu = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .confirmationDialog("Sort Options", isPresented: $showingSortMenu) {
                ForEach(InventorySortOption.allCases, id: \.self) { option in
                    Button(option.title) {
                        sortOption = option
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingAddItem) {
                AddInventoryItemView()
            }
            .sheet(item: $selectedItem) { item in
                InventoryItemDetailView(item: item)
            }
            .sheet(item: $selectedConsolidatedItem) { consolidatedItem in
                ConsolidatedInventoryDetailView(consolidatedItem: consolidatedItem)
            }
            .onAppear {
                loadSelectedFilters()
            }
            .onChange(of: selectedFilters) { newValue in
                saveSelectedFilters(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearInventorySearch)) { _ in
                searchText = ""
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
                ConsolidatedInventoryRowView(consolidatedItem: consolidatedItem, selectedFilters: selectedFilters)
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
    
    private func loadSelectedFilters() {
        if selectedFiltersData.isEmpty {
            // Default to all filters selected on first launch
            selectedFilters = [.inventory, .buy, .sell]
        } else {
            if let decoded = try? JSONDecoder().decode([InventoryFilterType].self, from: selectedFiltersData) {
                selectedFilters = Set(decoded)
            } else {
                // Fallback to all selected if decoding fails
                selectedFilters = [.inventory, .buy, .sell]
            }
        }
    }
    
    private func saveSelectedFilters(_ filters: Set<InventoryFilterType>) {
        if let encoded = try? JSONEncoder().encode(Array(filters)) {
            selectedFiltersData = encoded
        }
    }
    
    private func toggleFilter(_ filterType: InventoryFilterType) {
        var currentFilters = selectedFilters
        if currentFilters.contains(filterType) {
            currentFilters.remove(filterType)
        } else {
            currentFilters.insert(filterType)
        }
        selectedFilters = currentFilters
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
