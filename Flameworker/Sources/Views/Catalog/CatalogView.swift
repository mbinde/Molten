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
    @State private var searchTitlesOnly = true  // Toggle for title-only search (default: ON)

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
    @State private var selectedTags: Set<String> = []
    @State private var showingAllTags = false
    @State private var selectedCOEs: Set<Int32> = []
    @State private var showingCOESelection = false
    @State private var showingManufacturerSelection = false
    @State private var selectedManufacturer: String? = nil
    @State private var isLoadingData = false
    @State private var hasCompletedInitialLoad = false
    @State private var searchClearedFeedback = false
    @State private var navigationPath = NavigationPath()
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date = Date.distantPast

    // Repository pattern - single source of truth for data
    private let catalogService: CatalogService
    @State private var catalogItems: [CompleteInventoryItemModel] = []  // NEW: Use CompleteInventoryItemModel instead of legacy CatalogItemModel
    
    /// Repository pattern initializer - now the primary/only initializer
    init(catalogService: CatalogService) {
        self.catalogService = catalogService

        // NOTE: RepositoryFactory configuration happens in FlameworkerApp, NOT here
        // Do NOT call configureForProduction() here as it resets the container
        // and loses any data loaded during app startup
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
        var items = catalogItems  // Already CompleteInventoryItemModel array

        // Apply tag filter first (always enabled)
        // Now includes both manufacturer tags and user tags
        if !selectedTags.isEmpty {
            items = items.filter { item in
                // Item must have at least one of the selected tags (manufacturer or user tags)
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        // Apply COE filter
        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                selectedCOEs.contains(item.glassItem.coe)
            }
        }

        // Apply search filter using SearchTextParser for advanced search
        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            items = items.filter { item in
                if searchTitlesOnly {
                    // When "Search titles only" is ON, only search the name field
                    return SearchTextParser.matchesName(name: item.glassItem.name, mode: searchMode)
                } else {
                    // When OFF, search all fields
                    let allFields = [
                        item.glassItem.name,
                        item.glassItem.natural_key,
                        item.glassItem.manufacturer,
                        item.glassItem.sku,
                        item.glassItem.mfr_notes
                    ]
                    return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
                }
            }
        }

        return items
    }
    
    // Sorted filtered items for the unified list using repository data
    // NEW: Updated for CompleteInventoryItemModel with GlassItem architecture  
    private var sortedFilteredItems: [CompleteInventoryItemModel] {
        return filteredItems.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
            switch sortOption {
            case .name:
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending  // NEW: Access through glassItem
            case .manufacturer:
                return item1.glassItem.manufacturer.localizedCaseInsensitiveCompare(item2.glassItem.manufacturer) == .orderedAscending  // NEW: Access through glassItem
            case .code:
                return item1.glassItem.natural_key.localizedCaseInsensitiveCompare(item2.glassItem.natural_key) == .orderedAscending  // NEW: Use natural_key instead of naturalKey
            }
        }
    }
    
    // Simplified sorting without Core Data dependencies
    // private var catalogSortCriteria removed - no longer needed for repository pattern
    
    // All available tags from catalog items (only from enabled manufacturers)
    // Includes both manufacturer tags and user-created tags
    private var allAvailableTags: [String] {
        let baseItems = selectedManufacturer != nil ? filteredItemsBeforeTags : catalogItemsFilteredByManufacturers
        let allTags = baseItems.flatMap { item in
            item.allTags  // Use allTags to include both manufacturer and user tags
        }
        return Array(Set(allTags)).sorted()
    }

    // Set of all user-created tags for visual distinction
    private var allUserTags: Set<String> {
        let baseItems = selectedManufacturer != nil ? filteredItemsBeforeTags : catalogItemsFilteredByManufacturers
        let userTags = baseItems.flatMap { item in
            item.userTags
        }
        return Set(userTags)
    }

    // All available COE values from catalog items (only from enabled manufacturers)
    private var allAvailableCOEs: [Int32] {
        let baseItems = selectedManufacturer != nil ? filteredItemsBeforeTags : catalogItemsFilteredByManufacturers
        let allCOEs = baseItems.map { $0.glassItem.coe }
        return Array(Set(allCOEs)).sorted()
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

        // Apply text search filter using SearchTextParser for advanced search
        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            items = items.filter { item in
                if searchTitlesOnly {
                    // When "Search titles only" is ON, only search the name field
                    return SearchTextParser.matchesName(name: item.glassItem.name, mode: searchMode)
                } else {
                    // When OFF, search all fields
                    let allFields = [
                        item.glassItem.name,
                        item.glassItem.natural_key,
                        item.glassItem.manufacturer,
                        item.glassItem.sku,
                        item.glassItem.mfr_notes
                    ]
                    return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
                }
            }
        }

        return items
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search and filter controls using shared component
                SearchAndFilterHeader(
                    searchText: $searchText,
                    searchTitlesOnly: $searchTitlesOnly,
                    selectedTags: $selectedTags,
                    showingAllTags: $showingAllTags,
                    allAvailableTags: allAvailableTags,
                    selectedCOEs: $selectedCOEs,
                    showingCOESelection: $showingCOESelection,
                    allAvailableCOEs: allAvailableCOEs,
                    sortMenuContent: {
                        AnyView(
                            Group {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Button {
                                        sortOption = option
                                        updateSorting(option)
                                    } label: {
                                        Label(option.rawValue, systemImage: option.sortIcon)
                                    }
                                }
                            }
                        )
                    },
                    searchClearedFeedback: $searchClearedFeedback,
                    searchPlaceholder: "Search colors, codes, manufacturers...",
                    userDefaults: userDefaults
                )

                // Main content
                Group {
                    if catalogItems.isEmpty {
                        if isLoadingData && !hasCompletedInitialLoad {
                            catalogLoadingState
                        } else {
                            catalogEmptyState
                        }
                    } else if filteredItems.isEmpty && (!searchText.isEmpty || !selectedTags.isEmpty || !selectedCOEs.isEmpty || selectedManufacturer != nil) {
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
            .sheet(isPresented: $showingAllTags) {
                TagSelectionSheet(
                    availableTags: allAvailableTags,
                    selectedTags: $selectedTags,
                    userTags: allUserTags
                )
            }
            .sheet(isPresented: $showingCOESelection) {
                COESelectionSheet(
                    availableCOEs: allAvailableCOEs,
                    selectedCOEs: $selectedCOEs
                )
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
                // Only load data once on appear
                guard catalogItems.isEmpty else {
                    return
                }

                // Load settings from safe UserDefaults (isolated during testing)
                defaultSortOptionRawValue = userDefaults.string(forKey: "defaultSortOption") ?? SortOption.name.rawValue
                enabledManufacturersData = userDefaults.data(forKey: "enabledManufacturers") ?? Data()

                // Load search titles only setting (default: true)
                searchTitlesOnly = userDefaults.bool(forKey: "searchTitlesOnly") != false  // Default to true if not set

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
                    InventoryDetailView(
                        item: itemModel,
                        inventoryTrackingService: RepositoryFactory.createInventoryTrackingService()
                    )
                }
            }
        }
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

    private var catalogLoadingState: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.bottom, 8)

                Text("Loading Catalog")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Please wait while we load your glass catalog...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var catalogEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "eyedropper.halffull")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Catalog Items")
                .font(.title2)
                .fontWeight(.bold)

            Text("Something is very wrong, we should always be able to load some catalog data. Please contact the developer.")
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

        if !selectedCOEs.isEmpty {
            let coeText = selectedCOEs.count == 1 ? "COE" : "COEs"
            let coeList = selectedCOEs.sorted().map { String($0) }.joined(separator: ", ")
            filters.append("\(coeText) \(coeList)")
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
            selectedCOEs.removeAll()
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
        // Prevent multiple simultaneous refreshes
        guard !isRefreshing else { return }

        // Throttle refreshes to prevent infinite loops (minimum 1 second between calls)
        let now = Date()
        if now.timeIntervalSince(lastRefreshTime) < 1.0 { return }

        // Set loading state
        await MainActor.run {
            isLoadingData = true
        }

        isRefreshing = true
        lastRefreshTime = now

        do {
            // Simply load items from the database
            // JSON syncing and updates happen at app startup in FlameworkerApp.performInitialDataLoad()
            // CatalogView should only read from the database, not trigger JSON syncs
            let items = try await catalogService.getAllGlassItems()

            await MainActor.run {
                withAnimation(.default) {
                    catalogItems = items
                }
            }
        } catch {
            print("❌ Error loading data from repository: \(error)")
            await MainActor.run {
                catalogItems = []
            }
        }

        // Clear loading state and mark initial load as complete
        await MainActor.run {
            isLoadingData = false
            hasCompletedInitialLoad = true
        }

        isRefreshing = false
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
            // Product image thumbnail using SKU
            ProductImageThumbnail(
                itemCode: item.glassItem.sku,
                manufacturer: item.glassItem.manufacturer,
                naturalKey: item.glassItem.natural_key,
                size: 60
            )
            
            // Item details
            VStack(alignment: .leading, spacing: 4) {
                // Item name
                Text(item.glassItem.name)  // NEW: Access through glassItem
                    .font(.headline)
                    .lineLimit(1)
                
                // Item code and manufacturer  
                HStack {
                    Text(item.glassItem.natural_key)  // NEW: Use naturalKey instead of code
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
                
                // Tags if available (includes both manufacturer and user tags)
                if !item.allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(item.allTags, id: \.self) { tag in
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
    // Note: CatalogView constructor will configure for production automatically
    let catalogService = RepositoryFactory.createCatalogService()
    return CatalogView(catalogService: catalogService)
}
