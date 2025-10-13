//
//  InventoryView.swift  
//  Flameworker
//
//  Migrated to Repository Pattern on 10/12/25 by Assistant
//  Original Core Data version preserved as InventoryViewLegacy.swift
//

import SwiftUI

/// Repository-based InventoryView that uses InventoryViewModel instead of direct Core Data
struct InventoryView: View {
    @State private var viewModel: InventoryViewModel
    @State private var showingAddItem = false
    @State private var selectedConsolidatedItem: ConsolidatedInventoryModel?
    @State private var prefilledCatalogCodeForAdding: String = ""
    @State private var showingAddFromCatalog = false
    @State private var selectedFilters: Set<InventoryItemType> = []
    @State private var sortOption: InventorySortOption = .name
    @State private var showingSortMenu = false
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    
    enum InventorySortOption: String, CaseIterable {
        case name = "Name"
        case inventoryCount = "Inventory Count"
        case buyCount = "Buy Count"
        case sellCount = "Sell Count"
        
        var title: String { rawValue }
        
        var icon: String {
            switch self {
            case .name: return "textformat.abc"
            case .inventoryCount: return "archivebox.fill"
            case .buyCount: return "cart.fill"
            case .sellCount: return "dollarsign.circle.fill"
            }
        }
    }
    
    // Initialize with repository-based services
    init(inventoryService: InventoryService, catalogService: CatalogService? = nil) {
        let vm = InventoryViewModel(inventoryService: inventoryService, catalogService: catalogService)
        self._viewModel = State(initialValue: vm)
    }
    
    // Legacy initializer for backward compatibility during migration
    init() {
        // TODO: This should be removed once the app is fully migrated
        // For now, create with default Core Data repositories
        let coreDataInventoryRepo = CoreDataInventoryRepository()
        let inventoryService = InventoryService(repository: coreDataInventoryRepo)
        
        let vm = InventoryViewModel(inventoryService: inventoryService)
        self._viewModel = State(initialValue: vm)
    }
    
    // Computed properties that work with InventoryViewModel
    private var consolidatedItems: [ConsolidatedInventoryModel] {
        let filtered = applyFilters(viewModel.consolidatedItems)
        return sortConsolidatedItems(filtered)
    }
    
    private var isEmpty: Bool {
        viewModel.consolidatedItems.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    inventoryEmptyState
                } else {
                    inventoryListView
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .safeAreaInset(edge: .top) {
                searchAndFilterControls
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
    
    @ViewBuilder
    private var inventoryEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Inventory Items")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add items to track your glass inventory")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add First Item") {
                showingAddItem = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    @ViewBuilder
    private var inventoryListView: some View {
        List {
            ForEach(consolidatedItems, id: \.id) { consolidatedItem in
                ConsolidatedInventoryRow(item: consolidatedItem) {
                    selectedConsolidatedItem = consolidatedItem
                }
            }
            .onDelete(perform: deleteConsolidatedItems)
        }
        .sheet(item: $selectedConsolidatedItem) { item in
            // TODO: Update ConsolidatedInventoryDetailView to use repository pattern
            ConsolidatedInventoryDetailView(consolidatedItem: convertToLegacyFormat(item))
        }
        .sheet(isPresented: $showingAddItem) {
            // TODO: Update add item view to use repository pattern
            Text("Add Item - TODO: Implement with repository pattern")
        }
    }
    
    @ViewBuilder
    private var searchAndFilterControls: some View {
        VStack(spacing: 12) {
            // Search bar
            SearchBar(text: $viewModel.searchText)
                .onChange(of: viewModel.searchText) { _, newValue in
                    Task {
                        await viewModel.searchItems(searchText: newValue)
                    }
                }
            
            // Filter controls
            if !selectedFilters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedFilters), id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                isSelected: true,
                                systemImage: filter.systemImageName,
                                color: filter.color
                            ) {
                                selectedFilters.remove(filter)
                                Task {
                                    await applyCurrentFilters()
                                }
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
    
    @ViewBuilder
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
        await viewModel.loadInventoryItems()
    }
    
    private func applyFilters(_ items: [ConsolidatedInventoryModel]) -> [ConsolidatedInventoryModel] {
        if selectedFilters.isEmpty {
            return items
        }
        
        return items.filter { consolidatedItem in
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
    }
    
    private func sortConsolidatedItems(_ items: [ConsolidatedInventoryModel]) -> [ConsolidatedInventoryModel] {
        return items.sorted { item1, item2 in
            switch sortOption {
            case .name:
                return item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
            case .inventoryCount:
                return item1.totalInventoryCount != item2.totalInventoryCount ? 
                    item1.totalInventoryCount > item2.totalInventoryCount :
                    item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
            case .buyCount:
                return item1.totalBuyCount != item2.totalBuyCount ?
                    item1.totalBuyCount > item2.totalBuyCount :
                    item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
            case .sellCount:
                return item1.totalSellCount != item2.totalSellCount ?
                    item1.totalSellCount > item2.totalSellCount :
                    item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
            }
        }
    }
    
    private func applyCurrentFilters() async {
        viewModel.selectedFilters = selectedFilters
        await viewModel.applyFilters()
    }
    
    private func deleteConsolidatedItems(offsets: IndexSet) {
        // TODO: Implement deletion through repository pattern
        for index in offsets {
            let item = consolidatedItems[index]
            Task {
                // Delete all individual items in this consolidated group
                for inventoryItem in item.items {
                    await viewModel.deleteInventoryItem(id: inventoryItem.id)
                }
            }
        }
    }
    
    // Temporary converter for legacy components
    private func convertToLegacyFormat(_ item: ConsolidatedInventoryModel) -> ConsolidatedInventoryItem {
        // TODO: Remove this once ConsolidatedInventoryDetailView is migrated
        return ConsolidatedInventoryItem(
            id: item.id,
            catalogCode: item.catalogCode,
            catalogItemName: item.displayName,
            items: [], // TODO: Convert InventoryItemModel to InventoryItem
            totalInventoryCount: Double(item.totalInventoryCount),
            totalBuyCount: Double(item.totalBuyCount),
            totalSellCount: Double(item.totalSellCount),
            inventoryUnits: nil, // TODO: Map from model
            buyUnits: nil,
            sellUnits: nil,
            hasNotes: !item.items.allSatisfy { $0.notes?.isEmpty ?? true },
            allNotes: item.items.compactMap { $0.notes }.joined(separator: "; ")
        )
    }
}

// MARK: - Supporting Views

struct ConsolidatedInventoryRow: View {
    let item: ConsolidatedInventoryModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(item.catalogCode)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if item.totalInventoryCount > 0 {
                            Label("\(item.totalInventoryCount)", systemImage: "archivebox.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        if item.totalBuyCount > 0 {
                            Label("\(item.totalBuyCount)", systemImage: "cart.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if item.totalSellCount > 0 {
                            Label("\(item.totalSellCount)", systemImage: "dollarsign.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct SearchBar: View {
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

struct FilterChip: View {
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