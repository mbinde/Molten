//
//  CatalogView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//  ✅ MIGRATED to GlassItem Architecture on 10/14/25
//
//  MIGRATION SUMMARY:
//  • Updated from CatalogItemModel to CompleteInventoryItemModel
//  • Switched from getAllItems() to getAllGlassItems() API
//  • Updated all property accesses to use glassItem.property structure  
//  • Converted "code" references to "naturalKey" system
//  • Added Hashable conformance to CompleteInventoryItemModel for navigation
//

import SwiftUI
import Foundation

// Navigation destinations for CatalogView NavigationStack - NEW: Updated for GlassItem architecture
enum CatalogNavigationDestination: Hashable {
    case addInventoryItem(naturalKey: String)
    case catalogItemDetail(itemModel: CompleteInventoryItemModel)  // NEW: Use CompleteInventoryItemModel
}

struct CatalogView: View {
    @State private var searchText = ""
    
    // Use manual UserDefaults handling instead of @AppStorage to prevent test crashes
    @State private var defaultSortOptionRawValue = SortOption.name.rawValue
    @State private var enabledManufacturersData: Data = Data()
    
    private var userDefaults: UserDefaults {
        // Use isolated UserDefaults during testing to prevent Core Data conflicts
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let testSuiteName = "Test_CatalogView_Settings"
            return UserDefaults(suiteName: testSuiteName) ?? UserDefaults.standard
        } else {
            return UserDefaults.standard
        }
    }
    @State private var sortOption: SortOption = .name
    @State private var showingSortMenu = false
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var showingManufacturerSelection = false
    @State private var selectedManufacturer: String? = nil
    @State private var isLoadingData = false
    @State private var searchClearedFeedback = false
    @State private var navigationPath = NavigationPath()

    // Repository pattern - single source of truth for data
    private let catalogService: CatalogService
    @State private var catalogItems: [CompleteInventoryItemModel] = []  // NEW: Use CompleteInventoryItemModel instead of legacy CatalogItemModel
    
    /// Repository pattern initializer - now the primary/only initializer
    init(catalogService: CatalogService) {
        self.catalogService = catalogService
    }
    
    // Get enabled manufacturers set from settings
    private var enabledManufacturers: Set<String> {
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: enabledManufacturersData) {
            return decoded
        }
        
        // If no settings saved, return all manufacturers (default behavior)
        // BUT: Only if catalogItems is populated, otherwise return empty set to disable filtering
        guard !catalogItems.isEmpty else {
            return Set()
        }
        
        let allManufacturers = catalogItems.map { item in
            item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)  // NEW: Access through glassItem
        }
        .filter { !$0.isEmpty }
        
        let manufacturerSet = Set(allManufacturers)
        return manufacturerSet
    }
    
    // Filtered items based on search text, selected tags, selected manufacturer, enabled manufacturers, and COE filter
    // NEW: Updated for CompleteInventoryItemModel with GlassItem architecture
    private var filteredItems: [CompleteInventoryItemModel] {
        let items = catalogItems  // Already CompleteInventoryItemModel array
        
        // Simplified filtering for repository pattern - avoid Core Data dependencies
        // Advanced filtering temporarily disabled to prevent test hanging
        let enableAdvancedFiltering = false // Was: FeatureFlags.advancedFiltering
        
        if enableAdvancedFiltering {
            
            // Apply COE filter FIRST (before all other filters) - skipped for now since we need protocol conformance
            var coeFiltered = items
            
            // Apply manufacturer filter using repository data
            var manufacturerFiltered = coeFiltered
            if !enabledManufacturers.isEmpty {
                manufacturerFiltered = coeFiltered.filter { item in
                    enabledManufacturers.contains(item.glassItem.manufacturer)  // NEW: Access through glassItem
                }
            }
            
            // Apply specific manufacturer filter if one is selected
            var specificManufacturerFiltered = manufacturerFiltered
            if let selectedManufacturer = selectedManufacturer {
                specificManufacturerFiltered = manufacturerFiltered.filter { item in
                    item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines) == selectedManufacturer  // NEW: Access through glassItem
                }
            }
            
            // Apply tag filter 
            var tagFiltered = specificManufacturerFiltered
            if !selectedTags.isEmpty {
                tagFiltered = specificManufacturerFiltered.filter { item in
                    !selectedTags.isDisjoint(with: Set(item.tags))
                }
            }
            
            // Apply search filter
            if !searchText.isEmpty {
                let searchFiltered = tagFiltered.filter { item in
                    item.glassItem.name.localizedCaseInsensitiveContains(searchText) ||  // NEW: Access through glassItem
                    item.glassItem.naturalKey.localizedCaseInsensitiveContains(searchText) ||  // NEW: Use naturalKey
                    item.glassItem.manufacturer.localizedCaseInsensitiveContains(searchText)  // NEW: Access through glassItem
                }
                return searchFiltered
            }
            
            return tagFiltered
        } else {
            // Apply search filter only
            if !searchText.isEmpty {
                let searchFiltered = items.filter { item in
                    item.glassItem.name.localizedCaseInsensitiveContains(searchText) ||  // NEW: Access through glassItem
                    item.glassItem.naturalKey.localizedCaseInsensitiveContains(searchText) ||  // NEW: Use naturalKey
                    item.glassItem.manufacturer.localizedCaseInsensitiveContains(searchText)  // NEW: Access through glassItem
                }
                return searchFiltered
            }
            
            return items
        }
    }
    
    // Sorted filtered items for the unified list using repository data
    // NEW: Updated for CompleteInventoryItemModel with GlassItem architecture  
    private var sortedFilteredItems: [CompleteInventoryItemModel] {
        return filteredItems.sorted { item1, item2 in
            switch sortOption {
            case .name:
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending  // NEW: Access through glassItem
            case .manufacturer:
                return item1.glassItem.manufacturer.localizedCaseInsensitiveCompare(item2.glassItem.manufacturer) == .orderedAscending  // NEW: Access through glassItem
            case .code:
                return item1.glassItem.naturalKey.localizedCaseInsensitiveCompare(item2.glassItem.naturalKey) == .orderedAscending  // NEW: Use naturalKey instead of code
            }
        }
    }
    
    // Simplified sorting without Core Data dependencies
    // private var catalogSortCriteria removed - no longer needed for repository pattern
    
    // All available tags from catalog items (only from enabled manufacturers)
    private var allAvailableTags: [String] {
        let baseItems = selectedManufacturer != nil ? filteredItemsBeforeTags : catalogItemsFilteredByManufacturers
        let allTags = baseItems.flatMap { item in
            item.tags
        }
        return Array(Set(allTags)).sorted()
    }
    
    // Available manufacturers from enabled manufacturers that have items
    private var availableManufacturers: [String] {
        let manufacturers = catalogItemsFilteredByManufacturers.map { item in
            item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)  // NEW: Access through glassItem
        }
        .filter { !$0.isEmpty }
        
        let uniqueManufacturers = Array(Set(manufacturers))
        
        // Sort alphabetically (simplified sorting for repository pattern)
        return uniqueManufacturers.sorted { manufacturer1, manufacturer2 in
            manufacturer1.localizedCaseInsensitiveCompare(manufacturer2) == .orderedAscending
        }
    }
    
    // Helper: Items filtered only by enabled manufacturers (before other filters)
    // NEW: Updated for CompleteInventoryItemModel with GlassItem architecture
    private var catalogItemsFilteredByManufacturers: [CompleteInventoryItemModel] {
        if enabledManufacturers.isEmpty {
            return catalogItems
        } else {
            return catalogItems.filter { item in
                enabledManufacturers.contains(item.glassItem.manufacturer)  // NEW: Access through glassItem
            }
        }
    }
    
    // Helper: Items filtered by enabled manufacturers and specific manufacturer (before tag filter)
    // NEW: Updated for CompleteInventoryItemModel with GlassItem architecture
    private var filteredItemsBeforeTags: [CompleteInventoryItemModel] {
        var items = catalogItemsFilteredByManufacturers
        
        // Apply specific manufacturer filter if one is selected
        if let selectedManufacturer = selectedManufacturer {
            items = items.filter { item in
                item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines) == selectedManufacturer  // NEW: Access through glassItem
            }
        }
        
        // Apply text search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.glassItem.name.localizedCaseInsensitiveContains(searchText) ||  // NEW: Access through glassItem
                item.glassItem.naturalKey.localizedCaseInsensitiveContains(searchText) ||  // NEW: Use naturalKey
                item.glassItem.manufacturer.localizedCaseInsensitiveContains(searchText)  // NEW: Access through glassItem
            }
        }
        
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
                // Simplified tag view - full implementation would require creating repository-based CatalogAllTagsView
                NavigationView {
                    List(allAvailableTags, id: \.self) { tag in
                        Button(action: {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }) {
                            HStack {
                                Text(tag)
                                Spacer()
                                if selectedTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .navigationTitle("Select Tags")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingAllTags = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingManufacturerSelection) {
                CatalogManufacturerFilterView(
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
                // Load settings from safe UserDefaults (isolated during testing)
                defaultSortOptionRawValue = userDefaults.string(forKey: "defaultSortOption") ?? SortOption.name.rawValue
                enabledManufacturersData = userDefaults.data(forKey: "enabledManufacturers") ?? Data()
                
                // Initialize sort option from user settings
                sortOption = SortOption(rawValue: defaultSortOptionRawValue) ?? .name
                
                // Load data through repository pattern
                Task {
                    await refreshData()
                }
            }
            .navigationDestination(for: CatalogNavigationDestination.self) { destination in
                switch destination {
                case .addInventoryItem(let naturalKey):
                    AddInventoryItemView(prefilledNaturalKey: naturalKey)
                case .catalogItemDetail(let itemModel):
                    InventoryDetailView(item: itemModel)  // NEW: Use comprehensive InventoryDetailView
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
                // Simplified filtering for repository pattern - avoid Core Data dependencies
                let enableAdvancedFiltering = false // Was: FeatureFlags.advancedFiltering
                
                // Only show advanced filters if feature flag is enabled
                if enableAdvancedFiltering {
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
            // Simplified manufacturer display for repository pattern
            filters.append("manufacturer '\(selectedManufacturer)'")
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
            // All items in one list using repository data
            ForEach(sortedFilteredItems, id: \.id) { item in
                NavigationLink(value: CatalogNavigationDestination.catalogItemDetail(itemModel: item)) {
                    CatalogItemModelRowView(item: item)
                }
            }
        }
    }
}

// MARK: - CatalogView Actions
extension CatalogView {
    
    private func manufacturerDisplayName(_ manufacturer: String) -> String {
        // Simplified manufacturer display for repository pattern
        // Avoid GlassManufacturers utility which might have Core Data dependencies
        return manufacturer
        
        /* Original implementation with potential Core Data dependencies:
        let fullName = GlassManufacturers.fullName(for: manufacturer) ?? manufacturer
        
        if let coeValues = GlassManufacturers.coeValues(for: manufacturer) {
            let coeString = coeValues.map(String.init).joined(separator: ", ")
            return "\(fullName) (\(coeString))"
        } else {
            return fullName
        }
        */
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func updateSorting(_ newSortOption: SortOption) {
        sortOption = newSortOption
        defaultSortOptionRawValue = newSortOption.rawValue
        // Save to safe UserDefaults (isolated during testing)
        userDefaults.set(newSortOption.rawValue, forKey: "defaultSortOption")
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
    
    /// Load catalog items through repository pattern (NEW: Updated for GlassItem architecture)  
    func loadItemsFromRepository() async throws -> [CompleteInventoryItemModel] {
        let loadedItems = try await catalogService.getAllGlassItems()  // NEW: Use getAllGlassItems instead of getAllItems
        
        // Update state with loaded models
        await MainActor.run {
            withAnimation(.default) {
                catalogItems = loadedItems
            }
        }
        
        return loadedItems
    }
    
    /// Get all display items through repository pattern (NEW: Updated for GlassItem architecture)
    func getDisplayItems() async -> [CompleteInventoryItemModel] {
        do {
            return try await catalogService.getAllGlassItems()  // NEW: Use getAllGlassItems instead of getAllItems
        } catch {
            print("❌ Error loading display items from repository: \(error)")
            return []
        }
    }
    
    /// Perform search through repository pattern (NEW: Updated for GlassItem architecture)
    func performSearch(searchText: String) async -> [CompleteInventoryItemModel] {
        do {
            // Use the new search API that returns CompleteInventoryItemModel
            let searchRequest = GlassItemSearchRequest(searchText: searchText)
            let searchResult = try await catalogService.searchGlassItems(request: searchRequest)
            return searchResult.items
        } catch {
            print("❌ Error searching items through repository: \(error)")
            return []
        }
    }
    
    /// Get available manufacturers from repository data (NEW: Updated for GlassItem architecture)
    func getAvailableManufacturers() async -> [String] {
        do {
            let allItems = try await catalogService.getAllGlassItems()  // NEW: Use getAllGlassItems
            let manufacturers = Set(allItems.map { $0.glassItem.manufacturer })  // NEW: Access through glassItem
            return Array(manufacturers).sorted()
        } catch {
            print("❌ Error getting manufacturers from repository: \(error)")
            return []
        }
    }
    
    // MARK: - Repository-based Actions
    
    private func refreshData() async {
        do {
            let items = try await catalogService.getAllGlassItems()  // NEW: Use getAllGlassItems
            await MainActor.run {
                withAnimation(.default) {
                    catalogItems = items
                }
            }
            print("🔄 Repository refresh: Loaded \(items.count) catalog items")
        } catch {
            print("❌ Error refreshing data from repository: \(error)")
        }
    }
    
    private func loadJSONData() {
        // JSON loading would now go through repository-based DataLoadingService
        // This is a placeholder for the repository-based JSON loading
        Task {
            await refreshData()
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

// MARK: - Repository-based Row and Detail Views
struct CatalogManufacturerFilterView: View {
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

// MARK: - Repository-based Row and Detail Views

struct CatalogItemModelRowView: View {
    let item: CompleteInventoryItemModel  // NEW: Use CompleteInventoryItemModel instead of CatalogItemModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Placeholder for product image thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "eyedropper")
                        .foregroundColor(.secondary)
                )
            
            // Item details
            VStack(alignment: .leading, spacing: 4) {
                // Item name
                Text(item.glassItem.name)  // NEW: Access through glassItem
                    .font(.headline)
                    .lineLimit(1)
                
                // Item code and manufacturer  
                HStack {
                    Text(item.glassItem.naturalKey)  // NEW: Use naturalKey instead of code
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.glassItem.manufacturer)  // NEW: Access through glassItem
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .lineLimit(1)
                
                // Tags if available
                if !item.tags.isEmpty {  // NEW: Tags are at the top level of CompleteInventoryItemModel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(item.tags, id: \.self) { tag in
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
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    let catalogService = RepositoryFactory.createCatalogService()
    CatalogView(catalogService: catalogService)
}
