//
//  CatalogView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData
import Foundation

// Navigation destinations for CatalogView NavigationStack
enum CatalogNavigationDestination: Hashable {
    case addInventoryItem(catalogCode: String)
    case inventoryItemDetail(objectID: NSManagedObjectID)
    case catalogItemDetail(objectID: NSManagedObjectID)
}

struct CatalogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @AppStorage("defaultSortOption") private var defaultSortOptionRawValue = SortOption.name.rawValue
    @State private var sortOption: SortOption = .name
    @State private var showingSortMenu = false
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var showingManufacturerSelection = false
    @State private var selectedManufacturer: String? = nil
    @State private var isLoadingData = false
    @State private var searchClearedFeedback = false
    @State private var navigationPath = NavigationPath()

    
    // Read enabled manufacturers from settings
    @AppStorage("enabledManufacturers") private var enabledManufacturersData: Data = Data()

    @FetchRequest(
        entity: CatalogItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CatalogItem.name, ascending: true)],
        animation: .default
    )
    private var catalogItems: FetchedResults<CatalogItem>
    
    // Get enabled manufacturers set from settings
    private var enabledManufacturers: Set<String> {
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: enabledManufacturersData) {
            return decoded
        }
        // If no settings saved, return all manufacturers (default behavior)
        let allManufacturers = catalogItems.compactMap { item in
            item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        return Set(allManufacturers)
    }
    
    // Filtered items based on search text, selected tags, selected manufacturer, enabled manufacturers, and COE filter
    private var filteredItems: [CatalogItem] {
        var items = Array(catalogItems)
        
        if FeatureFlags.advancedFiltering {
            // Apply COE filter FIRST (before all other filters)
            items = CatalogViewHelpers.applyCOEFilter(items)
            
            // Apply manufacturer filter using centralized utility
            items = FilterUtilities.filterCatalogByManufacturers(items, enabledManufacturers: enabledManufacturers)
            
            // Apply specific manufacturer filter if one is selected
            if let selectedManufacturer = selectedManufacturer {
                items = items.filter { item in
                    item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines) == selectedManufacturer
                }
            }
            
            // Apply tag filter using centralized utility
            items = FilterUtilities.filterCatalogByTags(items, selectedTags: selectedTags)
        }
        
        // Always apply centralized search utility for consistent behavior with Inventory search
        if !searchText.isEmpty {
            items = SearchUtilities.searchCatalogItems(items, query: searchText)
        }
        
        return items
    }
    
    // Sorted filtered items for the unified list using centralized utility
    private var sortedFilteredItems: [CatalogItem] {
        return SortUtilities.sortCatalogEntities(filteredItems, by: catalogSortCriteria)
    }
    
    // Convert our SortOption to the new CatalogSortCriteria
    private var catalogSortCriteria: CatalogSortCriteria {
        switch sortOption {
        case .name:
            return .name
        case .manufacturer:
            return .manufacturer
        case .code:
            return .code
        }
    }
    
    // All available tags from catalog items (only from enabled manufacturers)
    private var allAvailableTags: [String] {
        let baseItems = selectedManufacturer != nil ? filteredItemsBeforeTags : catalogItemsFilteredByManufacturers
        let allTags = baseItems.flatMap { item in
            CatalogItemHelpers.tagsArrayForItem(item)
        }
        return Array(Set(allTags)).sorted()
    }
    
    // Available manufacturers from enabled manufacturers that have items
    private var availableManufacturers: [String] {
        let manufacturers = catalogItemsFilteredByManufacturers.compactMap { item in
            item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        
        let uniqueManufacturers = Array(Set(manufacturers))
        
        // Sort by COE first, then alphabetically within each COE group (same as settings)
        return uniqueManufacturers.sorted { manufacturer1, manufacturer2 in
            let coe1 = GlassManufacturers.primaryCOE(for: manufacturer1) ?? Int.max
            let coe2 = GlassManufacturers.primaryCOE(for: manufacturer2) ?? Int.max
            
            if coe1 != coe2 {
                return coe1 < coe2
            }
            
            // If COEs are the same, sort alphabetically by full name
            let name1 = GlassManufacturers.fullName(for: manufacturer1) ?? manufacturer1
            let name2 = GlassManufacturers.fullName(for: manufacturer2) ?? manufacturer2
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    // Helper: Items filtered only by enabled manufacturers (before other filters)
    private var catalogItemsFilteredByManufacturers: [CatalogItem] {
        return FilterUtilities.filterCatalogByManufacturers(Array(catalogItems), enabledManufacturers: enabledManufacturers)
    }
    
    // Helper: Items filtered by enabled manufacturers and specific manufacturer (before tag filter)
    private var filteredItemsBeforeTags: [CatalogItem] {
        var items = catalogItemsFilteredByManufacturers
        
        // Apply specific manufacturer filter if one is selected
        if let selectedManufacturer = selectedManufacturer {
            items = items.filter { item in
                item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines) == selectedManufacturer
            }
        }
        
        // Apply text search filter
        items = SearchUtilities.searchCatalogItems(items, query: searchText)
        
        return items
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search and filter controls
                searchAndFilterHeader
                
                // Main content
                Group {
                    if catalogItems.isEmpty {
                        catalogEmptyState
                    } else if filteredItems.isEmpty && (!searchText.isEmpty || !selectedTags.isEmpty || selectedManufacturer != nil) {
                        searchEmptyStateView
                    } else {
                        catalogListView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Catalog")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                    }
                }
            }
            .confirmationDialog("Sort Options", isPresented: $showingSortMenu) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        sortOption = option
                        updateSorting(option)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingAllTags) {
                CatalogAllTagsView(
                    allAvailableTags: allAvailableTags,
                    catalogItems: catalogItems,
                    selectedTags: $selectedTags,
                    isPresented: $showingAllTags
                )
            }
            .sheet(isPresented: $showingManufacturerSelection) {
                ManufacturerFilterView(
                    availableManufacturers: availableManufacturers,
                    selectedManufacturer: $selectedManufacturer,
                    manufacturerDisplayName: manufacturerDisplayName
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearCatalogSearch)) { _ in
                clearSearch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetCatalogNavigation)) { _ in
                resetNavigation()
            }
            .onAppear {
                // Initialize sort option from user settings
                sortOption = SortOption(rawValue: defaultSortOptionRawValue) ?? .name
            }
            .navigationDestination(for: CatalogNavigationDestination.self) { destination in
                switch destination {
                case .addInventoryItem(let catalogCode):
                    AddInventoryItemView(prefilledCatalogCode: catalogCode)
                case .inventoryItemDetail(let objectID):
                    if let inventoryItem = viewContext.object(with: objectID) as? InventoryItem {
                        InventoryItemDetailView(item: inventoryItem) // Uses default startInEditMode: false
                    } else {
                        Text("Item not found")
                            .foregroundColor(.secondary)
                    }
                case .catalogItemDetail(let objectID):
                    if let catalogItem = viewContext.object(with: objectID) as? CatalogItem {
                        CatalogItemSimpleView(item: catalogItem)
                    } else {
                        Text("Item not found")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Search and Filter Header
    
    private var searchAndFilterHeader: some View {
        VStack(spacing: 8) {
            // Custom search bar with inline sort button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search colors, codes, manufacturers...", text: $searchText)
                    
                    // Clear button (X) - always visible
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
            
            // Filter dropdowns row
            HStack(spacing: 12) {
                // Only show advanced filters if feature flag is enabled
                if FeatureFlags.advancedFiltering {
                    // Manufacturer dropdown - Simplified approach
                    if !availableManufacturers.isEmpty {
                        manufacturerFilterButton
                    }
                    
                    // Tag dropdown
                    if !allAvailableTags.isEmpty {
                        tagFilterButton
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            // Search cleared feedback
            Group {
                if searchClearedFeedback {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Search cleared")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale))
                }
            }
            , alignment: .center
        )
    }
    
    // MARK: - Filter Buttons
    
    private var manufacturerFilterButton: some View {
        Button {
            showingManufacturerSelection = true
        } label: {
            HStack(spacing: 4) {
                Text(selectedManufacturer != nil ? manufacturerDisplayName(selectedManufacturer!) : "All Manufacturers")
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
            }
            .foregroundColor(selectedManufacturer != nil ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedManufacturer != nil ? Color.blue : Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var tagFilterButton: some View {
        Button {
            showingAllTags = true
        } label: {
            Text(selectedTags.isEmpty ? "All Tags" : "\(selectedTags.count) Tag\(selectedTags.count == 1 ? "" : "s")")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedTags.isEmpty ? .primary : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedTags.isEmpty ? Color(.systemGray5) : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Views
    
    private var catalogEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "eyedropper.halffull")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Catalog Items")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start building your glass color catalog by loading catalog data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var searchEmptyStateView: some View {
        List {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("No Results")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
    
    private var emptyStateMessage: String {
        var filters: [String] = []
        
        if !searchText.isEmpty {
            filters.append("'\(searchText)'")
        }
        
        if let selectedManufacturer = selectedManufacturer {
            let manufacturerName = GlassManufacturers.fullName(for: selectedManufacturer) ?? selectedManufacturer
            filters.append("manufacturer '\(manufacturerName)'")
        }
        
        if !selectedTags.isEmpty {
            let tagText = selectedTags.count == 1 ? "tag" : "tags"
            filters.append("\(tagText) '\(selectedTags.sorted().joined(separator: "', '"))'")
        }
        
        if filters.isEmpty {
            return "No catalog items found"
        } else {
            return "No catalog items match " + filters.joined(separator: " and ")
        }
    }
    
    private var catalogListView: some View {
        List {
            // All items in one list
            ForEach(sortedFilteredItems) { item in
                NavigationLink(value: CatalogNavigationDestination.catalogItemDetail(objectID: item.objectID)) {
                    CatalogItemRowView(item: item)
                }
            }
            .onDelete(perform: deleteItems)
        }
    }
}

// MARK: - CatalogView Actions
extension CatalogView {
    
    private func manufacturerDisplayName(_ manufacturer: String) -> String {
        let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer
        
        if let coeValues = GlassManufacturers.coeValues(for: manufacturer) {
            let coeString = coeValues.map(String.init).joined(separator: ", ")
            return "\(fullName) (\(coeString))"
        } else {
            return fullName
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func deleteItems(offsets: IndexSet) {
        CoreDataOperations.deleteItems(sortedFilteredItems, at: offsets, in: viewContext)
    }
    
    private func deleteItemsFromSection(items: [CatalogItem], offsets: IndexSet) {
        CoreDataOperations.deleteItems(items, at: offsets, in: viewContext)
    }
    
    private func updateSorting(_ newSortOption: SortOption) {
        sortOption = newSortOption
        defaultSortOptionRawValue = newSortOption.rawValue // Save to settings
    }
    
    private func clearSearch() {
        // Clear search state with animation for visual feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            searchText = ""
            selectedTags.removeAll()
            selectedManufacturer = nil
        }
        
        // Hide keyboard
        hideKeyboard()
        
        // Provide brief visual feedback
        searchClearedFeedback = true
        
        // Reset feedback after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                searchClearedFeedback = false
            }
        }
    }
    
    private func resetNavigation() {
        // Reset navigation state to show the catalog list
        withAnimation(.easeInOut(duration: 0.3)) {
            navigationPath = NavigationPath()
        }
    }
    
    private func refreshData() {
        let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        do {
            let items = try viewContext.fetch(request)
            print("🔄 Manual refresh: Found \(items.count) catalog items in Core Data")
            for (index, item) in items.enumerated() {
                if index < 5 { // Show first 5 items
                    print("   Item \(index + 1): \(item.name ?? "No name") (\(item.code ?? "No code"))")
                }
            }
            if items.count > 5 {
                print("   ... and \(items.count - 5) more items")
            }
        } catch {
            print("❌ Error fetching catalog items: \(error)")
        }
    }

    private func addItem() {
        withAnimation {
            let newCatalogItem = CatalogItem(context: viewContext)
            newCatalogItem.code = "NEW-\(Int(Date().timeIntervalSince1970))"
            newCatalogItem.name = "New Item"
            newCatalogItem.manufacturer = "Unknown"
            
            // Set default image_path if the attribute exists
            let entityDescription = newCatalogItem.entity
            if entityDescription.attributesByName["image_path"] != nil {
                newCatalogItem.setValue("", forKey: "image_path") // Empty string as default
            }

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error saving new item: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func deleteAllItems() {
        withAnimation {
            // Delete all catalog items
            catalogItems.forEach { item in
                viewContext.delete(item)
            }
            
            do {
                try viewContext.save()
                print("🗑️ All catalog items deleted successfully")
            } catch {
                let nsError = error as NSError
                print("❌ Error deleting all items: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    

    
    // MARK: - Data Loading Helpers
    
    private func loadJSONData() {
        AsyncOperationHandler.perform(
            operation: {
                try await DataLoadingService.shared.loadCatalogItemsFromJSON(into: viewContext)
            },
            operationName: "JSON loading",
            loadingState: $isLoadingData
        )
    }
    
    private func smartMergeJSONData() {
        AsyncOperationHandler.perform(
            operation: {
                try await DataLoadingService.shared.loadCatalogItemsFromJSONWithMerge(into: viewContext)
            },
            operationName: "Smart merge",
            loadingState: $isLoadingData
        )
    }
    
    private func loadJSONIfEmpty() {
        AsyncOperationHandler.perform(
            operation: {
                try await DataLoadingService.shared.loadCatalogItemsFromJSONIfEmpty(into: viewContext)
            },
            operationName: "Conditional JSON loading",
            loadingState: $isLoadingData
        )
    }
    
    private func inspectJSONStructure() {
        print("🔍 Inspecting JSON structure...")
        
        guard let url = Bundle.main.url(forResource: "colors", withExtension: "json") else {
            print("❌ Could not find colors.json")
            return
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Could not load colors.json")
            return
        }
        
        // Try standard JSON inspection
        do {
            // Try to parse as generic JSON to see the structure
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📄 Standard JSON is a Dictionary with keys:")
                for (key, value) in jsonObject.prefix(3) { // Show first 3 items
                    print("   Key: \(key)")
                    if let itemDict = value as? [String: Any] {
                        print("     Item fields:")
                        for (field, fieldValue) in itemDict {
                            let valueType = type(of: fieldValue)
                            print("       \(field): \(fieldValue) (Type: \(valueType))")
                        }
                    }
                    print()
                }
            } else if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("📄 Standard JSON is an Array with \(jsonArray.count) items")
                if let firstItem = jsonArray.first {
                    print("   First item fields:")
                    for (field, fieldValue) in firstItem {
                        let valueType = type(of: fieldValue)
                        print("     \(field): \(fieldValue) (Type: \(valueType))")
                    }
                }
            } else {
                print("❌ JSON structure is neither dictionary nor array")
                
                // Show raw content for debugging
                if let rawString = String(data: data, encoding: .utf8) {
                    print("📄 First 500 characters of raw file:")
                    print(String(rawString.prefix(500)))
                }
            }
        } catch {
            print("❌ Error parsing standard JSON: \(error)")
        }
    }
}

// MARK: - Tag Filter View
/*
struct TagFilterView: View {
    let availableTags: [String]
    @Binding var selectedTags: Set<String>
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    // Filtered tags based on search text
    private var filteredTags: [String] {
        if searchText.isEmpty {
            return availableTags
        } else {
            return availableTags.filter { tag in
                tag.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Tags list
                List {
                    if filteredTags.isEmpty {
                        if searchText.isEmpty {
                            Text("No tags available")
                                .foregroundColor(.secondary)
                        } else {
                            Text("No tags match '\(searchText)'")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(filteredTags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedTags.contains(tag) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleTag(tag)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter by Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        selectedTags.removeAll()
                    }
                    .disabled(selectedTags.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Focus search field when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFieldFocused = true
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField("Search tags...", text: $searchText)
                .focused($isSearchFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    isSearchFieldFocused = false
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFieldFocused = true
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
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Actions
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}
 */

// MARK: - Manufacturer Filter View
struct ManufacturerFilterView: View {
    let availableManufacturers: [String]
    @Binding var selectedManufacturer: String?
    let manufacturerDisplayName: (String) -> String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Button("All Manufacturers") {
                    selectedManufacturer = nil
                    dismiss()
                }
                .foregroundColor(.primary)
                
                ForEach(availableManufacturers, id: \.self) { manufacturer in
                    Button(action: {
                        selectedManufacturer = manufacturer
                        dismiss()
                    }) {
                        HStack {
                            Text(manufacturerDisplayName(manufacturer))
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedManufacturer == manufacturer {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Manufacturer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Simple Catalog Item Detail View

struct CatalogItemSimpleView: View {
    let item: CatalogItem
    @Environment(\.dismiss) private var dismiss
    
    private var displayInfo: CatalogItemDisplayInfo {
        CatalogItemHelpers.getItemDisplayInfo(item)
    }
    
    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Main content with image and details side by side
                    HStack(alignment: .top, spacing: 16) {
                        // Product image if available
                        if ImageHelpers.productImageExists(for: displayInfo.code, manufacturer: displayInfo.manufacturer) {
                            ProductImageDetail(itemCode: displayInfo.code, manufacturer: displayInfo.manufacturer, maxSize: 200)
                                .frame(maxWidth: 200)
                        } else {
                            // Placeholder for when no image exists
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 200, height: 200)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .foregroundColor(.secondary)
                                            .font(.largeTitle)
                                        Text("No Image")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                        
                        // Item details inline with image
                        VStack(alignment: .leading, spacing: 12) {
                            // COE (without thermometer icon)
                            if let coe = displayInfo.coe {
                                inlineDetailRow(title: "COE", value: coe)
                            }
                            
                            // Manufacturer
                            inlineDetailRow(title: "Manufacturer", value: displayInfo.manufacturerFullName)
                            
                            // Item code
                            inlineDetailRow(title: "Item Code", value: displayInfo.code)
                            
                            // Stock Type
                            if let stockType = displayInfo.stockType {
                                inlineDetailRow(title: "Stock Type", value: stockType.capitalized)
                            }
                            
                            // Tags inline
                            if !displayInfo.tags.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Tags")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    LazyVGrid(columns: [
                                        GridItem(.adaptive(minimum: 60), spacing: 6)
                                    ], spacing: 6) {
                                        ForEach(displayInfo.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Description below the image (full width)
                    if displayInfo.hasDescription {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            
                            Text(displayInfo.description!)
                                .font(.body)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Synonyms section if available
                    if !displayInfo.synonyms.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Also Known As")
                                .font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 100), spacing: 8)
                            ], spacing: 8) {
                                ForEach(displayInfo.synonyms, id: \.self) { synonym in
                                    Text(synonym)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.1))
                                        .foregroundColor(.green)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    // Related inventory items section
                    RelatedInventoryItemsView(catalogCode: displayInfo.code, manufacturer: displayInfo.manufacturer)
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(displayInfo.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: CatalogNavigationDestination.addInventoryItem(catalogCode: displayInfo.code)) {
                        Label("Add to Inventory", systemImage: "plus.circle.fill")
                    }
                }
            }
    }
    
    // MARK: - Helper Views
    
    private func inlineDetailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Related Inventory Items View

struct RelatedInventoryItemsView: View {
    let catalogCode: String
    let manufacturer: String?
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest private var inventoryItems: FetchedResults<InventoryItem>
    
    init(catalogCode: String, manufacturer: String? = nil) {
        self.catalogCode = catalogCode
        self.manufacturer = manufacturer
        
        // Create a more flexible predicate to match different formats
        var predicates: [NSPredicate] = []
        
        // Search for exact match
        predicates.append(NSPredicate(format: "catalog_code == %@", catalogCode))
        
        // If we have manufacturer, also search for manufacturer-code format
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            let prefixedCode = "\(manufacturer)-\(catalogCode)"
            predicates.append(NSPredicate(format: "catalog_code == %@", prefixedCode))
        }
        
        // Also search for any code ending with this catalog code (in case there are other prefixes)
        predicates.append(NSPredicate(format: "catalog_code ENDSWITH %@", "-\(catalogCode)"))
        
        // Combine all predicates with OR
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        // Fix: Use sortDescriptors and predicate initializer
        self._inventoryItems = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \InventoryItem.type, ascending: true)],
            predicate: compoundPredicate
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventory")
                .font(.headline)
            
            if inventoryItems.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "cube.transparent")
                            .foregroundColor(.secondary)
                        Text("No inventory items yet")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    NavigationLink(value: CatalogNavigationDestination.addInventoryItem(catalogCode: CatalogCodeLookup.preferredCatalogCode(from: catalogCode, manufacturer: manufacturer))) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to Inventory")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(inventoryItems, id: \.objectID) { item in
                        NavigationLink(value: CatalogNavigationDestination.inventoryItemDetail(objectID: item.objectID)) {
                            HStack {
                                Image(systemName: InventoryItemType(rawValue: item.type)?.systemImageName ?? "cube")
                                    .foregroundColor(InventoryItemType(rawValue: item.type)?.color ?? .gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(InventoryItemType(rawValue: item.type)?.displayName ?? "Unknown")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(item.formattedCountWithUnits)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    NavigationLink(value: CatalogNavigationDestination.addInventoryItem(catalogCode: CatalogCodeLookup.preferredCatalogCode(from: catalogCode, manufacturer: manufacturer))) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Another Item")
                                .font(.subheadline)
                        }
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}


// MARK: - CatalogItemRowView
struct CatalogItemRowView: View {
    let item: CatalogItem
    
    private var displayInfo: CatalogItemDisplayInfo {
        CatalogItemHelpers.getItemDisplayInfo(item)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Product image thumbnail
            ProductImageThumbnail(
                itemCode: displayInfo.code,
                manufacturer: displayInfo.manufacturer,
                size: 60
            )
            
            // Item details
            VStack(alignment: .leading, spacing: 4) {
                // Item name
                Text(displayInfo.name)
                    .font(.headline)
                    .lineLimit(1)
                
                // Item code and manufacturer
                HStack {
                    Text(displayInfo.code)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !displayInfo.manufacturerFullName.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(displayInfo.manufacturerFullName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .lineLimit(1)
                
                // Tags if available
                if !displayInfo.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(displayInfo.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.15))
                                    .foregroundColor(.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                // COE if available
                if let coe = displayInfo.coe {
                    Text("COE \(coe)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Preview
#Preview {
    CatalogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
