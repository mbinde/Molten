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
    case addInventoryItem(stableId: String)
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
    @State private var selectedManufacturers: Set<String> = []
    @State private var showingManufacturerFilterSelection = false
    @State private var showingManufacturerSelection = false  // Keep for legacy CatalogManufacturerFilterView
    @State private var selectedManufacturer: String? = nil
    @State private var isLoadingData = false
    @State private var hasCompletedInitialLoad = false
    @State private var searchClearedFeedback = false
    @State private var navigationPath = NavigationPath()
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date = Date.distantPast

    // Repository pattern - single source of truth for data
    private let catalogService: CatalogService

    // PERFORMANCE: Use app-level cache to avoid reloading data on every tab switch
    @StateObject private var dataCache = CatalogDataCache.shared

    // Performance optimization: Cache computed values to avoid recomputation on every view refresh
    @State private var cachedAllTags: [String] = []
    @State private var cachedUserTags: Set<String> = []
    @State private var cachedAllCOEs: [Int32] = []
    @State private var cachedManufacturers: [String] = []
    @State private var cacheInvalidationTrigger: Int = 0

    // CRITICAL PERFORMANCE FIX: Cache filtered and sorted results
    // These are expensive operations (O(n) filter + O(n log n) sort on 1719 items)
    // Without caching, they run on EVERY view refresh (keyboard appearance, focus changes, etc.)
    @State private var cachedFilteredItems: [CompleteInventoryItemModel] = []
    @State private var cachedSortedFilteredItems: [CompleteInventoryItemModel] = []
    @State private var lastSearchText: String = ""
    @State private var lastSelectedTags: Set<String> = []
    @State private var lastSelectedCOEs: Set<Int32> = []
    @State private var lastSelectedManufacturers: Set<String> = []
    @State private var lastSortOption: SortOption = .name

    // Computed property to get items from cache
    private var catalogItems: [CompleteInventoryItemModel] {
        dataCache.items
    }

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
    // PERFORMANCE: Returns cached results, cache is updated via .onChange() modifiers
    private var filteredItems: [CompleteInventoryItemModel] {
        return cachedFilteredItems
    }

    // Sorted filtered items for the unified list using repository data
    // NEW: Updated for CompleteInventoryItemModel with GlassItem architecture
    // PERFORMANCE: Returns cached results, cache is updated via .onChange() modifiers
    private var sortedFilteredItems: [CompleteInventoryItemModel] {
        return cachedSortedFilteredItems
    }

    /// Recompute filtered items cache (expensive operation - only call when filters change!)
    private func updateFilteredItemsCache() {
        print("🔍 CatalogView: updateFilteredItemsCache() called")
        print("  selectedManufacturers: \(selectedManufacturers)")
        var items = catalogItems  // Already CompleteInventoryItemModel array
        print("  catalogItems count: \(items.count)")

        // Apply manufacturer filter
        if !selectedManufacturers.isEmpty {
            items = items.filter { item in
                selectedManufacturers.contains(item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            print("  After manufacturer filter: \(items.count) items")
        }

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

        // Update cache
        cachedFilteredItems = items

        // Update tracking variables
        lastSearchText = searchText
        lastSelectedTags = selectedTags
        lastSelectedCOEs = selectedCOEs
        lastSelectedManufacturers = selectedManufacturers
    }

    /// Recompute sorted filtered items cache (expensive operation - only call when sort changes!)
    private func updateSortedFilteredItemsCache() {
        cachedSortedFilteredItems = cachedFilteredItems.sorted { (item1: CompleteInventoryItemModel, item2: CompleteInventoryItemModel) -> Bool in
            switch sortOption {
            case .name:
                return item1.glassItem.name.localizedCaseInsensitiveCompare(item2.glassItem.name) == .orderedAscending
            case .manufacturer:
                return item1.glassItem.manufacturer.localizedCaseInsensitiveCompare(item2.glassItem.manufacturer) == .orderedAscending
            case .code:
                return item1.glassItem.natural_key.localizedCaseInsensitiveCompare(item2.glassItem.natural_key) == .orderedAscending
            }
        }

        lastSortOption = sortOption
    }
    
    // Simplified sorting without Core Data dependencies
    // private var catalogSortCriteria removed - no longer needed for repository pattern
    
    // All available tags from catalog items (only from enabled manufacturers)
    // Includes both manufacturer tags and user-created tags
    // PERFORMANCE OPTIMIZED: Returns cached value, recomputed only when data changes
    private var allAvailableTags: [String] {
        return cachedAllTags
    }

    // Set of all user-created tags for visual distinction
    // PERFORMANCE OPTIMIZED: Returns cached value, recomputed only when data changes
    private var allUserTags: Set<String> {
        return cachedUserTags
    }

    /// Recompute all caches when catalog data changes
    /// This is expensive (O(n)) so only call when data actually changes
    private func updateTagCaches() {
        print("🔄 CatalogView: Updating caches (processing \(catalogItems.count) items)...")
        let startTime = CFAbsoluteTimeGetCurrent()

        // PERFORMANCE: Work directly with catalogItems array, don't call expensive computed properties
        // The filters/search are applied during display, not during cache computation
        var allTagsSet = Set<String>()
        var userTagsSet = Set<String>()
        var allCOEsSet = Set<Int32>()
        var manufacturersSet = Set<String>()

        for item in catalogItems {
            allTagsSet.formUnion(item.allTags)  // Pre-computed, no repeated computation
            userTagsSet.formUnion(item.userTags)
            allCOEsSet.insert(item.glassItem.coe)

            let mfr = item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mfr.isEmpty {
                manufacturersSet.insert(mfr)
            }
        }

        cachedAllTags = allTagsSet.sorted()
        cachedUserTags = userTagsSet
        cachedAllCOEs = allCOEsSet.sorted()
        cachedManufacturers = manufacturersSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("✅ CatalogView: Caches updated in \(String(format: "%.1f", elapsed))ms - Tags: \(cachedAllTags.count), Manufacturers: \(cachedManufacturers.count), COEs: \(cachedAllCOEs.count)")
        print("  Available manufacturers: \(cachedManufacturers.prefix(5).joined(separator: ", "))\(cachedManufacturers.count > 5 ? "..." : "")")
    }

    // All available COE values from catalog items (only from enabled manufacturers)
    // PERFORMANCE OPTIMIZED: Returns cached value, recomputed only when data changes
    private var allAvailableCOEs: [Int32] {
        return cachedAllCOEs
    }

    // Available manufacturers from enabled manufacturers that have items
    // PERFORMANCE OPTIMIZED: Returns cached value, recomputed only when data changes
    private var availableManufacturers: [String] {
        return cachedManufacturers
    }

    // MARK: - Filter Counts (for display in filter selection sheets)

    /// Count items per manufacturer based on current filters (excluding manufacturer filter itself)
    private var manufacturerCounts: [String: Int] {
        var items = catalogItems

        // Apply all filters EXCEPT manufacturer
        if !selectedTags.isEmpty {
            items = items.filter { item in
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                selectedCOEs.contains(item.glassItem.coe)
            }
        }

        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            items = items.filter { item in
                if searchTitlesOnly {
                    return SearchTextParser.matchesName(name: item.glassItem.name, mode: searchMode)
                } else {
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

        // Count items per manufacturer
        var counts: [String: Int] = [:]
        for item in items {
            let mfr = item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            counts[mfr, default: 0] += 1
        }
        return counts
    }

    /// Count items per COE based on current filters (excluding COE filter itself)
    private var coeCounts: [Int32: Int] {
        var items = catalogItems

        // Apply all filters EXCEPT COE
        if !selectedManufacturers.isEmpty {
            items = items.filter { item in
                selectedManufacturers.contains(item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        if !selectedTags.isEmpty {
            items = items.filter { item in
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            items = items.filter { item in
                if searchTitlesOnly {
                    return SearchTextParser.matchesName(name: item.glassItem.name, mode: searchMode)
                } else {
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

        // Count items per COE
        var counts: [Int32: Int] = [:]
        for item in items {
            counts[item.glassItem.coe, default: 0] += 1
        }
        return counts
    }

    /// Count items per tag based on current filters (excluding tag filter itself)
    private var tagCounts: [String: Int] {
        var items = catalogItems

        // Apply all filters EXCEPT tags
        if !selectedManufacturers.isEmpty {
            items = items.filter { item in
                selectedManufacturers.contains(item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                selectedCOEs.contains(item.glassItem.coe)
            }
        }

        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
            items = items.filter { item in
                if searchTitlesOnly {
                    return SearchTextParser.matchesName(name: item.glassItem.name, mode: searchMode)
                } else {
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

        // Count items per tag
        var counts: [String: Int] = [:]
        for item in items {
            for tag in item.allTags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
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
                    selectedManufacturers: $selectedManufacturers,
                    showingManufacturerSelection: $showingManufacturerFilterSelection,
                    allAvailableManufacturers: availableManufacturers,
                    manufacturerDisplayName: { code in
                        GlassManufacturers.fullName(for: code) ?? code
                    },
                    manufacturerCounts: manufacturerCounts,
                    coeCounts: coeCounts,
                    tagCounts: tagCounts,
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
                    if dataCache.isLoading && catalogItems.isEmpty {
                        catalogLoadingState
                    } else if catalogItems.isEmpty {
                        catalogEmptyState
                    } else if filteredItems.isEmpty && (!searchText.isEmpty || !selectedTags.isEmpty || !selectedCOEs.isEmpty || !selectedManufacturers.isEmpty || selectedManufacturer != nil) {
                        searchEmptyStateView
                    } else {
                        catalogListView
                    }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                FilterSelectionSheet.tags(
                    availableTags: allAvailableTags,
                    selectedTags: $selectedTags,
                    itemCounts: tagCounts
                )
            }
            .sheet(isPresented: $showingCOESelection) {
                FilterSelectionSheet.coes(
                    availableCOEs: allAvailableCOEs,
                    selectedCOEs: $selectedCOEs,
                    itemCounts: coeCounts
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
                // Load settings from safe UserDefaults (isolated during testing)
                defaultSortOptionRawValue = userDefaults.string(forKey: "defaultSortOption") ?? SortOption.name.rawValue
                enabledManufacturersData = userDefaults.data(forKey: "enabledManufacturers") ?? Data()

                // Load search titles only setting (default: true)
                searchTitlesOnly = userDefaults.bool(forKey: "searchTitlesOnly") != false  // Default to true if not set

                // Initialize sort option from user settings
                sortOption = SortOption(rawValue: defaultSortOptionRawValue) ?? .name
            }
            .task {
                // PERFORMANCE: Load data from cache (loads only once, reuses on tab switches)
                print("📱 CatalogView: .task starting")
                let taskStart = CFAbsoluteTimeGetCurrent()

                await dataCache.loadIfNeeded(catalogService: catalogService)

                let cacheLoadTime = (CFAbsoluteTimeGetCurrent() - taskStart) * 1000
                print("⏱️  CatalogView: Cache load completed in \(String(format: "%.1f", cacheLoadTime))ms")

                // Update all caches after data is available (only once, not on every change)
                updateTagCaches()

                // CRITICAL: Initialize filtered/sorted caches so first interaction is instant
                print("🚀 CatalogView: Initializing filter/sort caches...")
                updateFilteredItemsCache()
                updateSortedFilteredItemsCache()
                print("✅ CatalogView: Filter/sort caches initialized with \(cachedSortedFilteredItems.count) items")

                let totalTime = (CFAbsoluteTimeGetCurrent() - taskStart) * 1000
                print("✅ CatalogView: .task completed in \(String(format: "%.1f", totalTime))ms")
            }
            .onChange(of: searchText) { _, _ in
                updateFilteredItemsCache()
                updateSortedFilteredItemsCache()
            }
            .onChange(of: selectedTags) { _, _ in
                updateFilteredItemsCache()
                updateSortedFilteredItemsCache()
            }
            .onChange(of: selectedCOEs) { _, _ in
                updateFilteredItemsCache()
                updateSortedFilteredItemsCache()
            }
            .onChange(of: selectedManufacturers) { _, _ in
                updateFilteredItemsCache()
                updateSortedFilteredItemsCache()
            }
            .onChange(of: sortOption) { _, _ in
                updateSortedFilteredItemsCache()
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
            .background(selectedManufacturer != nil ? Color.blue : DesignSystem.Colors.backgroundInput)
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
                .background(selectedTags.isEmpty ? DesignSystem.Colors.backgroundInput : Color.blue)
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
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "text.justify")
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
            .padding(.top, 60)
        }
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

        if !selectedManufacturers.isEmpty {
            let mfrText = selectedManufacturers.count == 1 ? "manufacturer" : "manufacturers"
            let mfrList = selectedManufacturers.sorted().compactMap { GlassManufacturers.fullName(for: $0) ?? $0 }.joined(separator: ", ")
            filters.append("\(mfrText) \(mfrList)")
        }

        if let selectedManufacturer = selectedManufacturer {
            // Legacy single manufacturer filter
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
            ForEach(sortedFilteredItems, id: \.id) { item in
                NavigationLink(value: CatalogNavigationDestination.catalogItemDetail(itemModel: item)) {
                    GlassItemRowView.catalog(item: item)
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
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
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
            selectedManufacturers.removeAll()
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
    
    // MARK: - Repository-based Actions

    private func refreshData() async {
        // PERFORMANCE: Use cache reload instead of direct query
        print("📊 CatalogView: Refresh requested - reloading cache")
        await dataCache.reload(catalogService: catalogService)
        updateTagCaches()
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
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    // Note: CatalogView constructor will configure for production automatically
    let catalogService = RepositoryFactory.createCatalogService()
    return CatalogView(catalogService: catalogService)
}
