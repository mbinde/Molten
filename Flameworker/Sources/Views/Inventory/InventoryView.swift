//
//
//  InventoryView.swift
//  Flameworker
//
//  Migrated to Repository Pattern on 10/12/25 by Assistant
//  Updated for GlassItem architecture on 10/14/25
//

import SwiftUI
import Foundation

/// Repository-based InventoryView that uses the new GlassItem architecture
struct InventoryView: View {
    @State private var searchText = ""
    @State private var searchTitlesOnly = false  // Inventory doesn't need title-only search
    @State private var showingAddItem = false
    @State private var selectedGlassItem: CompleteInventoryItemModel?
    @State private var prefilledNaturalKey: String = ""
    @State private var showingAddFromCatalog = false
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var sortOption: InventorySortOption = .name
    @State private var showingSortMenu = false
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    @State private var searchClearedFeedback = false
    @State private var glassItems: [CompleteInventoryItemModel] = []
    @State private var isLoading = false

    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService
    
    enum InventorySortOption: String, CaseIterable {
        case name = "Name"
        case totalQuantity = "Total Quantity"
        case manufacturer = "Manufacturer"
        case naturalKey = "Natural Key"
        
        var title: String { rawValue }
        
        var icon: String {
            switch self {
            case .name: return "textformat.abc"
            case .totalQuantity: return "archivebox.fill"
            case .manufacturer: return "building.2"
            case .naturalKey: return "number"
            }
        }
    }
    
    // Initialize with repository-based services
    init(catalogService: CatalogService? = nil, inventoryTrackingService: InventoryTrackingService? = nil) {
        self.catalogService = catalogService ?? RepositoryFactory.createCatalogService()
        self.inventoryTrackingService = inventoryTrackingService ?? RepositoryFactory.createInventoryTrackingService()
    }
    
    // Computed properties
    private var filteredItems: [CompleteInventoryItemModel] {
        var items = glassItems

        // Only show items with inventory (totalQuantity > 0)
        items = items.filter { $0.totalQuantity > 0 }

        // Apply tag filter
        if !selectedTags.isEmpty {
            items = items.filter { item in
                !selectedTags.isDisjoint(with: Set(item.tags))
            }
        }

        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.glassItem.name.localizedCaseInsensitiveContains(searchText) ||
                item.glassItem.natural_key.localizedCaseInsensitiveContains(searchText) ||
                item.glassItem.manufacturer.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }
    
    private var sortedFilteredItems: [CompleteInventoryItemModel] {
        return filteredItems.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
            switch sortOption {
            case .name:
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            case .totalQuantity:
                return item1.totalQuantity != item2.totalQuantity ? 
                    item1.totalQuantity > item2.totalQuantity :
                    item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            case .manufacturer:
                return item1.glassItem.manufacturer.localizedCaseInsensitiveCompare(item2.glassItem.manufacturer) == .orderedAscending
            case .naturalKey:
                return item1.glassItem.natural_key.localizedCaseInsensitiveCompare(item2.glassItem.natural_key) == .orderedAscending
            }
        }
    }
    
    private var isEmpty: Bool {
        filteredItems.isEmpty
    }

    private var allAvailableTags: [String] {
        // Get all tags from items with inventory
        let itemsWithInventory = glassItems.filter { $0.totalQuantity > 0 }
        let allTags = itemsWithInventory.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter controls using shared component
                SearchAndFilterHeader(
                    searchText: $searchText,
                    searchTitlesOnly: $searchTitlesOnly,
                    selectedTags: $selectedTags,
                    showingAllTags: $showingAllTags,
                    allAvailableTags: allAvailableTags,
                    showingSortMenu: $showingSortMenu,
                    searchClearedFeedback: $searchClearedFeedback,
                    searchPlaceholder: "Search inventory by name, code, manufacturer...",
                    showSearchTitlesToggle: false  // Not needed for inventory
                )

                // Main content
                Group {
                    if isEmpty {
                        inventoryEmptyState
                    } else {
                        inventoryListView
                    }
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAllTags) {
                TagSelectionSheet(
                    availableTags: allAvailableTags,
                    selectedTags: $selectedTags
                )
            }
            .confirmationDialog("Sort Options", isPresented: $showingSortMenu) {
                sortMenuContent
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }
    
    // MARK: - Views
    
    private var inventoryEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Inventory Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start tracking your glass inventory by adding your first item")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Add Item") {
                showingAddItem = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var inventoryListView: some View {
        List {
            ForEach(sortedFilteredItems, id: \.id) { item in
                Button(action: {
                    selectedGlassItem = item
                }) {
                    InventoryItemRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $selectedGlassItem) { item in
            // Repository-based detail view
            ConsolidatedInventoryDetailView(
                glassItem: item.glassItem,
                inventoryTrackingService: inventoryTrackingService
            )
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationStack {
                AddInventoryItemView(
                    prefilledNaturalKey: prefilledNaturalKey.isEmpty ? nil : prefilledNaturalKey,
                    inventoryTrackingService: inventoryTrackingService,
                    catalogService: catalogService
                )
            }
        }
    }
    
    private var searchAndFilterControls: some View {
        VStack(spacing: 12) {
            // Search bar
            InventorySearchBar(text: $searchText)
            
            // Filter controls
            if !selectedFilters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedFilters), id: \.self) { filter in
                            InventoryFilterChip(
                                title: filter.capitalized,
                                isSelected: true,
                                systemImage: "square.stack.3d.up",
                                color: .blue
                            ) {
                                selectedFilters.remove(filter)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Available filter buttons
            if !availableInventoryTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableInventoryTypes, id: \.self) { type in
                            if !selectedFilters.contains(type) {
                                Button(type.capitalized) {
                                    selectedFilters.insert(type)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddItem = true
            } label: {
                Label("Add Item", systemImage: "plus")
            }
        }
        
        ToolbarItem(placement: .secondaryAction) {
            Button {
                showingSortMenu = true
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
    }
    
    private var sortMenuContent: some View {
        ForEach(InventorySortOption.allCases, id: \.self) { option in
            Button {
                sortOption = option
            } label: {
                Label(option.title, systemImage: option.icon)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadData() async {
        isLoading = true
        do {
            let items = try await catalogService.getAllGlassItems()
            await MainActor.run {
                glassItems = items
                isLoading = false
            }
        } catch {
            await MainActor.run {
                glassItems = []
                isLoading = false
            }
            print("Error loading inventory items: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct InventoryItemRow: View {
    let item: CompleteInventoryItemModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.glassItem.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(item.glassItem.natural_key)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.glassItem.manufacturer.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if item.totalQuantity > 0 {
                        Text("\(item.totalQuantity, specifier: "%.1f")")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No inventory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !item.inventoryByType.isEmpty {
                        Text("\(item.inventoryByType.count) type\(item.inventoryByType.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Show inventory types
            if !item.inventoryByType.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(item.inventoryByType.sorted(by: { $0.key < $1.key }), id: \.key) { type, quantity in
                            Text("\(type): \(quantity, specifier: "%.1f")")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            
            // Show tags if available
            if !item.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(item.tags.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .foregroundColor(.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        if item.tags.count > 5 {
                            Text("+\(item.tags.count - 5)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct InventorySearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search inventory...", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

struct InventoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let systemImage: String
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                Image(systemName: "xmark")
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1), in: Capsule())
            .foregroundColor(color)
        }
    }
}

#Preview {
    InventoryView()
}
