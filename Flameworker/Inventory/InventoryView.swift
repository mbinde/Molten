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
    @State private var selectedCatalogItemForAdding: CatalogItem?
    @State private var prefilledCatalogCodeForAdding: String = ""
    @State private var showingAddFromCatalog = false
    @AppStorage("defaultInventorySortOption") private var defaultInventorySortOptionRawValue = InventorySortOption.name.rawValue
    @State private var sortOption: InventorySortOption = .name
    @State private var showingSortMenu = false
    
    enum InventorySortOption: String, CaseIterable {
        case name = "Name"
        case inventoryCount = "Inventory Count"
        case buyCount = "Buy Count"
        case sellCount = "Sell Count"
        
        var title: String {
            return self.rawValue
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
    
    // Success toast state
    @State private var showingSuccessToast = false
    @State private var successMessage = ""
    
    // Fetch request for inventory items
    @FetchRequest(
        entity: InventoryItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \InventoryItem.id, ascending: true)]
    ) private var inventoryItems: FetchedResults<InventoryItem>
    
    // Manual catalog items state to avoid @FetchRequest entity resolution issues
    @State private var catalogItems: [CatalogItem] = []
    
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
                
                // Search in catalog item name by looking up the catalog item
                if let catalogCode = item.catalog_code, !catalogCode.isEmpty {
                    // Create a fetch request to find the catalog item
                    let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@ OR code == %@", catalogCode, catalogCode)
                    fetchRequest.fetchLimit = 1
                    
                    do {
                        let results = try viewContext.fetch(fetchRequest)
                        if let catalogItem = results.first,
                           let catalogName = catalogItem.name?.lowercased(),
                           catalogName.contains(searchLower) {
                            return true
                        }
                    } catch {
                        // If lookup fails, continue with other search criteria
                    }
                }
                
                return false
            }
        }
    }
    
    // Catalog items that match search but aren't in our inventory
    private var suggestedCatalogItems: [CatalogItem] {
        guard !searchText.isEmpty else { return [] }
        return InventorySearchSuggestions.suggestedCatalogItems(
            query: searchText,
            inventoryItems: Array(inventoryItems),
            catalogItems: Array(catalogItems)
        )
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if inventoryItems.isEmpty {
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
            .sheet(isPresented: $showingAddItem) {
                NavigationStack {
                    AddInventoryItemView()
                }
            }
            .sheet(isPresented: $showingAddFromCatalog) {
                addFromCatalogSheet
            }
            .onAppear {
                // Initialize sort option from user settings
                sortOption = InventorySortOption(rawValue: defaultInventorySortOptionRawValue) ?? .name
            }
            .sheet(item: $selectedItem) { item in
                NavigationStack {
                    InventoryItemDetailView(item: item) // Uses default startInEditMode: false
                }
            }
            .sheet(item: $selectedConsolidatedItem) { consolidatedItem in
                ConsolidatedInventoryDetailView(consolidatedItem: consolidatedItem)
            }
            .onAppear {
                loadSelectedFilters()
                loadCatalogItems()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
                // Refresh catalog data when Core Data saves occur (e.g., after initial data loading)
                loadCatalogItems()
            }
            .onChange(of: selectedFilters) { _, newValue in
                saveSelectedFilters(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearInventorySearch)) { _ in
                searchText = ""
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryItemAdded)) { notification in
                handleInventoryItemAdded(notification)
            }
        }
        .overlay(alignment: .top) {
            if showingSuccessToast {
                successToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // MARK: - Success Toast View
    
    private var successToast: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
            
            Text(successMessage)
                .font(.subheadline)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Helper Functions
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func handleInventoryItemAdded(_ notification: Notification) {
        if let message = notification.userInfo?["message"] as? String {
            successMessage = message
            withAnimation(.easeInOut(duration: 0.3)) {
                showingSuccessToast = true
            }
            // Auto-hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingSuccessToast = false
                }
            }
        }
    }
    
    // MARK: - Extracted View Components
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Inventory")
                .font(.headline)
                .fontWeight(.bold)
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddItem = true
            } label: {
                Label("Add Item", systemImage: "plus")
            }
        }
    }
    
    @ViewBuilder
    private var searchAndFilterControls: some View {
        VStack(spacing: 12) {
            searchBarSection
            filterButtonsSection
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var searchBarSection: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search inventory...", text: $searchText)
                
                Button {
                    searchText = ""
                    hideKeyboard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(searchText.isEmpty ? .secondary.opacity(0.3) : .secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)
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
    }
    
    @ViewBuilder
    private var filterButtonsSection: some View {
        HStack(spacing: 12) {
            Text("Show:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                allFilterButton
                
                ForEach(InventoryFilterType.allCases, id: \.self) { filterType in
                    individualFilterButton(filterType)
                }
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var allFilterButton: some View {
        Button {
            selectedFilters = [.inventory, .buy, .sell]
        } label: {
            Text("all")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(selectedFilters == [.inventory, .buy, .sell] ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedFilters == [.inventory, .buy, .sell] ? Color.blue : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func individualFilterButton(_ filterType: InventoryFilterType) -> some View {
        Button {
            selectedFilters = [filterType]
        } label: {
            HStack(spacing: 4) {
                Image(systemName: filterType.icon)
                    .font(.caption2)
                Text(filterType.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(selectedFilters == [filterType] ? .white : filterType.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selectedFilters == [filterType] ? filterType.color : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(filterType.color, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var sortMenuContent: some View {
        ForEach(InventorySortOption.allCases, id: \.self) { option in
            Button(option.title) {
                sortOption = option
                defaultInventorySortOptionRawValue = option.rawValue
            }
        }
        Button("Cancel", role: .cancel) { }
    }
    
    @ViewBuilder
    private var addFromCatalogSheet: some View {
        NavigationStack {
            AddInventoryItemView(prefilledCatalogCode: prefilledCatalogCodeForAdding)
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
    
    private var inventoryListView: some View {
        List {
            // Show inventory items first
            if !consolidatedItems.isEmpty {
                Section {
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
                } header: {
                    if !searchText.isEmpty {
                        Text("Your Inventory")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // Show catalog suggestions when searching
            if !searchText.isEmpty && !suggestedCatalogItems.isEmpty {
                Section {
                    ForEach(suggestedCatalogItems.prefix(10), id: \.objectID) { catalogItem in
                        CatalogItemSuggestionRow(catalogItem: catalogItem) {
                            // Open add inventory screen with this catalog item pre-filled
                            openAddInventoryFor(catalogItem: catalogItem)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.green)
                        Text("Add from Catalog")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                } footer: {
                    if suggestedCatalogItems.count > 10 {
                        Text("Showing first 10 results. Refine your search for more specific results.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Show empty state only if no inventory items AND no catalog suggestions
            if consolidatedItems.isEmpty && suggestedCatalogItems.isEmpty && !searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No Results")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("No inventory items or catalog items match '\(searchText)'")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }
    
    // MARK: - Actions
    
    private func openAddInventoryFor(catalogItem: CatalogItem) {
        // Create a special state to track that we're adding from catalog search
        // Use the catalog item's code or id as the prefilled code
        let prefilledCode = catalogItem.code ?? catalogItem.id ?? ""
        prefilledCatalogCodeForAdding = prefilledCode
        
        print("🎯 Opening add inventory for catalog item:")
        print("   - Name: \(catalogItem.name ?? "nil")")
        print("   - Code: \(catalogItem.code ?? "nil")")  
        print("   - ID: \(catalogItem.id ?? "nil")")
        print("   - Prefilled code will be: '\(prefilledCode)'")
        
        // Navigate to add inventory with prefilled catalog code
        selectedCatalogItemForAdding = catalogItem
        showingAddFromCatalog = true
    }
    
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
    
    /// Manually load catalog items to avoid @FetchRequest entity resolution issues on iPhone 17
    private func loadCatalogItems() {
        guard let fetchRequest = PersistenceController.createCatalogItemFetchRequest(in: viewContext) else {
            print("❌ Failed to create CatalogItem fetch request in InventoryView")
            catalogItems = []
            return
        }
        
        // Apply the same sort descriptors as the original @FetchRequest
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)]
        
        do {
            catalogItems = try viewContext.fetch(fetchRequest)
            print("✅ Manually loaded \(catalogItems.count) catalog items in InventoryView")
        } catch {
            print("❌ Error loading catalog items in InventoryView: \(error)")
            catalogItems = []
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

// MARK: - Catalog Item Suggestion Row

struct CatalogItemSuggestionRow: View {
    let catalogItem: CatalogItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            print("🔗 Tapped catalog suggestion: \(catalogItem.name ?? "Unknown")")
            onTap()
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Product image if available
                if let itemCode = catalogItem.code ?? catalogItem.id {
                    let manufacturer = catalogItem.manufacturer
                    if ImageHelpers.productImageExists(for: itemCode, manufacturer: manufacturer) {
                        ProductImageDetail(itemCode: itemCode, manufacturer: manufacturer, maxSize: 50)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        // Placeholder for consistent alignment
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray6))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            )
                    }
                } else {
                    // Placeholder for consistent alignment when no code/ID is available
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray6))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                                .font(.title3)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(catalogItem.name ?? "Unknown Item")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                    
                    if let code = catalogItem.code ?? catalogItem.id {
                        Text(code)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .contentShape(Rectangle()) // Makes entire row tappable
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InventoryView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

