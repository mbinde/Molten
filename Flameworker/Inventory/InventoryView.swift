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
        sortDescriptors: [NSSortDescriptor(keyPath: \InventoryItem.custom_tags, ascending: true)]
    ) private var inventoryItems: FetchedResults<InventoryItem>
    
    // Filtered items based on search using centralized search utilities
    private var filteredItems: [InventoryItem] {
        return SearchUtilities.searchInventoryItems(Array(inventoryItems), query: searchText)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if inventoryItems.isEmpty {
                    inventoryEmptyState
                } else if filteredItems.isEmpty && !searchText.isEmpty {
                    SearchEmptyStateView(searchText: searchText)
                } else {
                    inventoryListView
                }
            }
            .standardListNavigation(
                title: "Inventory",
                searchText: $searchText,
                searchPrompt: "Search inventory...",
                primaryAction: { showingAddItem = true }
            )
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
        EmptyStateView(
            icon: "archivebox",
            title: "No Inventory Items",
            subtitle: "Start tracking your glass rod inventory by adding your first item.",
            buttonTitle: "Add First Item",
            buttonAction: { showingAddItem = true },
            features: [
                FeatureDescription(title: "Track rod quantities and units", icon: "archivebox"),
                FeatureDescription(title: "Create shopping lists", icon: "cart"),
                FeatureDescription(title: "Mark items for resale", icon: "dollarsign"),
                FeatureDescription(title: "Add notes and custom tags", icon: "tag"),
                FeatureDescription(title: "Mark favorites", icon: "heart")
            ]
        )
    }
    
    private var inventoryListView: some View {
        List {
            ForEach(filteredItems, id: \.objectID) { item in
                InventoryItemRowView(item: item)
                    .onTapGesture {
                        selectedItem = item
                    }
                    .swipeActions(edge: .trailing) {
                        SwipeActionsBuilder.inventoryItemActions(
                            item: item,
                            onDelete: { deleteItem(item) },
                            onToggleFavorite: { toggleFavorite(item) }
                        )
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
    
    private func toggleFavorite(_ item: InventoryItem) {
        do {
            try InventoryService.shared.toggleFavorite(item, in: viewContext)
        } catch {
            print("❌ Failed to toggle favorite: \(error)")
        }
    }
}

#Preview {
    InventoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
