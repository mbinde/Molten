//
//  CatalogViewModel.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol-based ViewModel for CatalogView - enables testability
//
//  ⚠️ DEPRECATED: This ViewModel is superseded by UnifiedGlassViewModel.swift
//  When ENABLE_UNIFIED_GLASS_VIEW is true, this ViewModel is not used.
//  TODO: Delete this file once UnifiedGlassView is stable in production.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Filterable Protocol

/// Protocol for filters that can compute available values and counts
protocol Filterable {
    associatedtype FilterKey: Hashable

    /// Extract the filter key(s) from an item
    func extractFilterKeys(_ item: CompleteInventoryItemModel) -> [FilterKey]

    /// Whether this filter is currently active (should be excluded from count computation)
    func isActive(in viewModel: CatalogViewModel) -> Bool

    /// Apply this specific filter to items
    func applyFilter(to items: [CompleteInventoryItemModel], viewModel: CatalogViewModel) -> [CompleteInventoryItemModel]

    /// Whether to skip this filter when computing available values for the same filter type
    /// - Parameter sameType: true if we're computing counts for this filter type
    /// - Parameter viewModel: the view model with current filter state
    func shouldSkipWhenComputing(sameType: Bool, viewModel: CatalogViewModel) -> Bool
}

// MARK: - Concrete Filters

struct ManufacturerFilter: Filterable {
    func extractFilterKeys(_ item: CompleteInventoryItemModel) -> [String] {
        let mfr = item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        return mfr.isEmpty ? [] : [mfr]
    }

    func isActive(in viewModel: CatalogViewModel) -> Bool {
        // Active if either manual selection OR global preference is set
        if !viewModel.selectedManufacturers.isEmpty {
            return true
        }
        // Check if global preference is set
        return getGlobalManufacturerPreference() != nil
    }

    func applyFilter(to items: [CompleteInventoryItemModel], viewModel: CatalogViewModel) -> [CompleteInventoryItemModel] {
        // Determine active manufacturer filter (manual selection OR global preference)
        let activeManufacturers: Set<String>
        if !viewModel.selectedManufacturers.isEmpty {
            // User manually selected specific manufacturers in catalog filter UI
            activeManufacturers = viewModel.selectedManufacturers
        } else if let globalPref = getGlobalManufacturerPreference() {
            // Use global manufacturer preference from settings
            activeManufacturers = globalPref
        } else {
            // No filter active
            return items
        }

        return items.filter { item in
            activeManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Read global manufacturer preference from UserDefaults
    private func getGlobalManufacturerPreference() -> Set<String>? {
        guard let data = UserDefaults.standard.data(forKey: "selectedManufacturerFilter"),
              let manufacturers = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return nil
        }
        return manufacturers
    }

    func shouldSkipWhenComputing(sameType: Bool, viewModel: CatalogViewModel) -> Bool {
        // Skip only if computing manufacturer counts AND user has manual selection
        sameType && !viewModel.selectedManufacturers.isEmpty
    }
}

struct COEFilter: Filterable {
    func extractFilterKeys(_ item: CompleteInventoryItemModel) -> [Int32] {
        guard let coe = item.catalogItem.coe else { return [] }
        return [coe]
    }

    func isActive(in viewModel: CatalogViewModel) -> Bool {
        // Active if either manual selection OR global preference is set
        if !viewModel.selectedCOEs.isEmpty {
            return true
        }
        // Check if global preference differs from "all COEs"
        let globalCOEs = COEGlassPreference.selectedCOETypes
        return !globalCOEs.isEmpty && globalCOEs.count < COEGlassType.allCases.count
    }

    func applyFilter(to items: [CompleteInventoryItemModel], viewModel: CatalogViewModel) -> [CompleteInventoryItemModel] {
        // Determine active COE filter (manual selection OR global preference)
        let activeCOEFilter: Set<Int32>
        if !viewModel.selectedCOEs.isEmpty {
            // User manually selected specific COEs in catalog filter UI
            activeCOEFilter = viewModel.selectedCOEs
        } else {
            // Use global COE preference from settings
            activeCOEFilter = Set(COEGlassPreference.selectedCOETypes.map { Int32($0.rawValue) })
        }

        // If all COEs are selected, don't filter
        guard !activeCOEFilter.isEmpty else { return items }

        return items.filter { item in
            // Non-glass items (coatings, tools) don't have COE - don't filter them out
            if item.catalogItem.itemType != .glass {
                return true
            }
            if let coe = item.catalogItem.coe {
                // Item has COE - check if it matches filter
                return activeCOEFilter.contains(coe)
            }
            // Item has no COE (tools, coatings) - pass through unchanged
            return true
        }
    }

    func shouldSkipWhenComputing(sameType: Bool, viewModel: CatalogViewModel) -> Bool {
        // Skip only if computing COE counts AND user has manual selection
        sameType && !viewModel.selectedCOEs.isEmpty
    }
}

struct TagFilter: Filterable {
    func extractFilterKeys(_ item: CompleteInventoryItemModel) -> [String] {
        return item.allTags
    }

    func isActive(in viewModel: CatalogViewModel) -> Bool {
        return !viewModel.selectedTags.isEmpty
    }

    func applyFilter(to items: [CompleteInventoryItemModel], viewModel: CatalogViewModel) -> [CompleteInventoryItemModel] {
        guard !viewModel.selectedTags.isEmpty else { return items }
        return items.filter { item in
            // OR logic: item must have ANY of the selected tags
            !viewModel.selectedTags.isDisjoint(with: Set(item.allTags))
        }
    }

    func shouldSkipWhenComputing(sameType: Bool, viewModel: CatalogViewModel) -> Bool {
        // Never skip tags - always apply to show only tags in filtered results
        false
    }
}

struct ProductTypeFilter: Filterable {
    func extractFilterKeys(_ item: CompleteInventoryItemModel) -> [String] {
        return [item.catalogItem.itemType.rawValue]
    }

    func isActive(in viewModel: CatalogViewModel) -> Bool {
        return !viewModel.selectedProductTypes.isEmpty
    }

    func applyFilter(to items: [CompleteInventoryItemModel], viewModel: CatalogViewModel) -> [CompleteInventoryItemModel] {
        guard !viewModel.selectedProductTypes.isEmpty else { return items }
        return items.filter { item in
            viewModel.selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
        }
    }

    func shouldSkipWhenComputing(sameType: Bool, viewModel: CatalogViewModel) -> Bool {
        // Skip when computing product type counts AND filter is active
        sameType && !viewModel.selectedProductTypes.isEmpty
    }
}

struct SearchFilter: Filterable {
    func extractFilterKeys(_ item: CompleteInventoryItemModel) -> [String] {
        // Search doesn't use key extraction for counts
        return []
    }

    func isActive(in viewModel: CatalogViewModel) -> Bool {
        return !viewModel.debouncedSearchText.isEmpty &&
               SearchTextParser.isSearchTextMeaningful(viewModel.debouncedSearchText)
    }

    func applyFilter(to items: [CompleteInventoryItemModel], viewModel: CatalogViewModel) -> [CompleteInventoryItemModel] {
        guard isActive(in: viewModel) else { return items }

        let searchMode = SearchTextParser.parseSearchText(viewModel.debouncedSearchText)
        return items.filter { item in
            if viewModel.searchTitlesOnly {
                return SearchTextParser.matchesName(name: item.catalogItem.name, mode: searchMode)
            } else {
                let allFields = [
                    item.catalogItem.name,
                    item.catalogItem.stable_id,
                    item.catalogItem.manufacturer,
                    item.catalogItem.sku,
                    item.catalogItem.mfr_notes
                ].compactMap { $0 }
                return SearchTextParser.matchesAnyField(fields: allFields, mode: searchMode)
            }
        }
    }

    func shouldSkipWhenComputing(sameType: Bool, viewModel: CatalogViewModel) -> Bool {
        // Never skip search - always apply when active
        false
    }
}

/// ViewModel for the Catalog view
///
/// Manages presentation logic for:
/// - Loading catalog data
/// - Filtering by search, tags, COE, manufacturers
/// - Sorting items
/// - Computing available filter options
/// - Providing UI state and computed properties
@MainActor
@Observable
class CatalogViewModel: CatalogViewModelProtocol {

    // MARK: - Dependencies

    let catalogService: CatalogService  // Internal for cache refresh on rating changes

    // MARK: - Constants

    private static let productTypeFilterKey = "catalog.selectedProductTypes"
    private static let coeFilterKey = "catalog.selectedCOEs"
    private static let manufacturerFilterKey = "catalog.selectedManufacturers"
    private static let tagsFilterKey = "catalog.selectedTags"
    private static let searchTitlesOnlyKey = "catalog.searchTitlesOnly"
    private static let sortOptionKey = "catalog.sortOption"

    // MARK: - Published State

    var items: [CompleteInventoryItemModel] = []
    var filteredItems: [CompleteInventoryItemModel] = []
    var sortedFilteredItems: [CompleteInventoryItemModel] = []
    var isLoading = true  // Start true to show loading state until first load completes
    var errorMessage: String?

    // MARK: - Search & Filter State

    /// Debounce task for search input
    /// @ObservationIgnored to prevent triggering observation on every keystroke
    @ObservationIgnored private var searchDebounceTask: Task<Void, Never>?
    private static let searchDebounceDelay: UInt64 = 300_000_000 // 300ms in nanoseconds

    /// Immediate search text (updates on every keystroke for UI responsiveness)
    /// @ObservationIgnored to prevent triggering observation - only debouncedSearchText should trigger updates
    @ObservationIgnored private var _searchText = ""
    var searchText: String {
        get { _searchText }
        set {
            _searchText = newValue
            debounceSearch(newValue)
        }
    }

    /// Debounced search text (updates after 300ms delay to avoid expensive filtering on every keystroke)
    var debouncedSearchText = ""

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    var searchTitlesOnly = true {
        didSet {
            if searchTitlesOnly != oldValue {
                saveSearchTitlesOnly()
                applyFilters()
            }
        }
    }

    var selectedTags: Set<String> = [] {
        didSet {
            if selectedTags != oldValue {
                saveTagsFilter()
                applyFilters()
            }
        }
    }

    var selectedCOEs: Set<Int32> = [] {
        didSet {
            if selectedCOEs != oldValue {
                saveCOEFilter()
                applyFilters()
            }
        }
    }

    var selectedManufacturers: Set<String> = [] {
        didSet {
            if selectedManufacturers != oldValue {
                saveManufacturerFilter()
                applyFilters()
            }
        }
    }

    var selectedProductTypes: Set<String> = [] {
        didSet {
            if selectedProductTypes != oldValue {
                // Save to UserDefaults
                saveProductTypeFilter()
                applyFilters()
            }
        }
    }

    // MARK: - Sort State

    var sortOption: SortOption = .name {
        didSet {
            if sortOption != oldValue {
                saveSortOption()
                // Ratings are always loaded, so just re-sort
                applySorting()
            }
        }
    }

    // MARK: - UI State

    var searchClearedFeedback = false

    // MARK: - Cached Computed Values (for performance)

    private var cachedAllTags: [String] = []
    private var cachedUserTags: Set<String> = []
    private var cachedAllCOEs: [Int32] = []
    private var cachedManufacturers: [String] = []

    // Observer for UserDefaults changes
    nonisolated(unsafe) private var userDefaultsObserver: NSObjectProtocol?

    // Flag to prevent cascading updates during initialization
    private var isInitializing = true

    // MARK: - Initialization

    init(catalogService: CatalogService) {
        self.catalogService = catalogService

        // Load saved filters from UserDefaults
        // Note: We set the backing storage directly to avoid triggering didSet during init

        // Product type filter
        if let savedData = UserDefaults.standard.data(forKey: Self.productTypeFilterKey),
           let savedTypes = try? JSONDecoder().decode(Set<String>.self, from: savedData) {
            self._selectedProductTypes = savedTypes
        } else {
            self._selectedProductTypes = []
        }

        // COE filter
        if let savedData = UserDefaults.standard.data(forKey: Self.coeFilterKey),
           let savedCOEs = try? JSONDecoder().decode([Int32].self, from: savedData) {
            self._selectedCOEs = Set(savedCOEs)
        } else {
            self._selectedCOEs = []
        }

        // Manufacturer filter
        if let savedData = UserDefaults.standard.data(forKey: Self.manufacturerFilterKey),
           let savedManufacturers = try? JSONDecoder().decode([String].self, from: savedData) {
            self._selectedManufacturers = Set(savedManufacturers)
        } else {
            self._selectedManufacturers = []
        }

        // Tags filter
        if let savedData = UserDefaults.standard.data(forKey: Self.tagsFilterKey),
           let savedTags = try? JSONDecoder().decode([String].self, from: savedData) {
            self._selectedTags = Set(savedTags)
        } else {
            self._selectedTags = []
        }

        // Search titles only preference
        if UserDefaults.standard.object(forKey: Self.searchTitlesOnlyKey) != nil {
            self._searchTitlesOnly = UserDefaults.standard.bool(forKey: Self.searchTitlesOnlyKey)
        } else {
            self._searchTitlesOnly = true  // default
        }

        // Sort option
        if let savedSortRaw = UserDefaults.standard.string(forKey: Self.sortOptionKey),
           let savedSort = SortOption(rawValue: savedSortRaw) {
            self._sortOption = savedSort
        } else {
            self._sortOption = .name  // default
        }

        // Set up debouncing for search text (300ms delay)
        // This prevents expensive filtering operations on every keystroke
        setupSearchDebouncing()

        // Set up observer for COE and manufacturer preference changes
        setupUserDefaultsObserver()

        // Mark initialization complete
        isInitializing = false
    }

    nonisolated deinit {
        if let observer = userDefaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Configure Combine publisher to debounce search text updates
    private func setupSearchDebouncing() {
        // Monitor searchText changes and debounce them
        // Note: We use a NotificationCenter-based approach since @Observable doesn't provide Publishers
        // Alternative: If this becomes problematic, convert to @Published properties with ObservableObject

        // For now, we'll rely on the view to handle debouncing via onChange
        // The debouncedSearchText will be set by the view after 300ms delay
    }

    /// Set up observer for UserDefaults changes to COE and manufacturer preferences
    private func setupUserDefaultsObserver() {
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.isInitializing else { return }
            // When UserDefaults changes, reapply filters
            // This catches changes made in Settings view for COE and manufacturer filters
            self.applyFilters()
        }
    }

    // MARK: - Computed Properties

    var allAvailableTags: [String] {
        // Return ALL tags from the catalog (not just filtered ones)
        // The filter sheet will grey out ones with 0 count
        return cachedAllTags
    }

    var allUserTags: Set<String> {
        return cachedUserTags
    }

    var allAvailableCOEs: [Int32] {
        // Return ALL COEs from the catalog (not just filtered ones)
        // The filter sheet will grey out ones with 0 count
        return cachedAllCOEs
    }

    var availableManufacturers: [String] {
        // Return ALL manufacturers from the catalog (not just filtered ones)
        // The filter sheet will grey out ones with 0 count
        return cachedManufacturers
    }

    // PERFORMANCE: Cached counts - recomputed only in applyFilters(), not on every view render
    private(set) var manufacturerCounts: [String: Int] = [:]
    private(set) var coeCounts: [Int32: Int] = [:]
    private(set) var tagCounts: [String: Int] = [:]
    private(set) var productTypeCounts: [String: Int] = [:]

    var emptyStateMessage: String {
        generateEmptyStateMessage()
    }

    var hasData: Bool {
        !items.isEmpty
    }

    var hasActiveFilters: Bool {
        !debouncedSearchText.isEmpty ||
        !selectedTags.isEmpty ||
        !selectedCOEs.isEmpty ||
        !selectedManufacturers.isEmpty ||
        !selectedProductTypes.isEmpty
    }

    /// Count of active filters (excluding search) for badge display
    var activeFilterCount: Int {
        var count = 0
        if !selectedTags.isEmpty { count += 1 }
        if !selectedCOEs.isEmpty { count += 1 }
        if !selectedManufacturers.isEmpty { count += 1 }
        if !selectedProductTypes.isEmpty { count += 1 }
        return count
    }

    // MARK: - Actions

    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            // Load all glass items from catalog service with current sort option
            // This ensures ratings are loaded if sorting by rating
            items = try await catalogService.getAllGlassItems(sortBy: sortOption.asGlassItemSortOption)

            // Update caches
            updateCaches()

            // Apply initial filters and sorting
            applyFilters()
            applySorting()

        } catch {
            errorMessage = "Failed to load catalog: \(error.localizedDescription)"
            items = []
            filteredItems = []
            sortedFilteredItems = []
        }

        isLoading = false
    }

    func refreshData() async {
        await loadData()
    }

    func clearSearch() {
        searchText = ""
        selectedTags.removeAll()
        selectedCOEs.removeAll()
        selectedManufacturers.removeAll()
        selectedProductTypes.removeAll()
        searchClearedFeedback = true

        // Reset feedback after delay (will be handled by view)
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            searchClearedFeedback = false
        }
    }

    func updateSorting(_ newSortOption: SortOption) {
        sortOption = newSortOption
        applySorting()
    }

    // MARK: - Search Debouncing

    /// Debounce search input to avoid filtering on every keystroke
    private func debounceSearch(_ text: String) {
        // Cancel any pending debounce task
        searchDebounceTask?.cancel()

        // If text is empty, update immediately (user cleared the search)
        if text.isEmpty {
            debouncedSearchText = ""
            applyFilters()
            return
        }

        // Schedule debounced update
        searchDebounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: Self.searchDebounceDelay)
                // Only update if not cancelled and text hasn't changed
                if !Task.isCancelled && _searchText == text {
                    debouncedSearchText = text
                    applyFilters()
                }
            } catch {
                // Task was cancelled - this is expected when typing continues
            }
        }
    }

    func applyFilters() {
        var filtered = items

        // IMPORTANT: When adding a new filter type:
        // 1. Create a new struct conforming to Filterable (see ManufacturerFilter, etc.)
        // 2. Add it to this allFilters array
        // 3. Add it to the allFilters array in computeAvailableValues() as well
        let filtersWithoutSearch: [any Filterable] = [
            ProductTypeFilter(),
            ManufacturerFilter(),
            COEFilter(),
            TagFilter()
        ]

        // Apply all filters EXCEPT search first
        for filter in filtersWithoutSearch {
            filtered = filter.applyFilter(to: filtered, viewModel: self)
        }

        // Update cache with filtered items (before search) so GlobalSearchOverlay can use them
        // Only update if we have items - prevents empty ViewModels from clobbering valid data
        if !items.isEmpty {
            CatalogDataCache.shared.filteredItemsWithoutSearch = filtered
        }

        // Now apply search filter
        filtered = SearchFilter().applyFilter(to: filtered, viewModel: self)

        filteredItems = filtered
        applySorting()

        // PERFORMANCE: Update cached counts after filtering
        // Only recompute counts for filter types that CAN be affected by other filters
        // COE counts affected by: manufacturer, product type (not by COE selection itself)
        // Manufacturer counts affected by: COE, product type (not by manufacturer selection itself)
        // Tag counts affected by: all other filters (not by tag selection itself)
        // Product type counts: always show total counts (not affected by filters)
        // This prevents infinite loops where selecting a filter triggers its own count recomputation
        manufacturerCounts = computeManufacturerCounts()
        coeCounts = computeCOECounts()
        tagCounts = computeTagCounts()
        // productTypeCounts always shows totals, computed once when items load

        // Notify MainTabView of filter count change for badge display
        NotificationCenter.default.post(
            name: .catalogFilterCountChanged,
            object: nil,
            userInfo: ["count": activeFilterCount]
        )
    }

    // MARK: - Private Helpers

    private func applySorting() {
        sortedFilteredItems = filteredItems.sorted { (item1, item2) in
            switch sortOption {
            case .name:
                return item1.catalogItem.name.localizedCaseInsensitiveCompare(item2.catalogItem.name) == .orderedAscending
            case .manufacturer:
                return item1.catalogItem.manufacturer.localizedCaseInsensitiveCompare(item2.catalogItem.manufacturer) == .orderedAscending
            case .code:
                return item1.catalogItem.stable_id.localizedCaseInsensitiveCompare(item2.catalogItem.stable_id) == .orderedAscending
            case .rating:
                // Sort by rating (highest first), items without ratings at the end
                switch (item1.rating, item2.rating) {
                case (.some(let r1), .some(let r2)):
                    // Both have ratings - sort by average rating (descending)
                    if r1.averageRating != r2.averageRating {
                        return r1.averageRating > r2.averageRating
                    }
                    // Same rating - sort by total number of ratings (descending)
                    if r1.totalRatings != r2.totalRatings {
                        return r1.totalRatings > r2.totalRatings
                    }
                    // Same rating and count - sort by name
                    return item1.catalogItem.name.localizedCaseInsensitiveCompare(item2.catalogItem.name) == .orderedAscending
                case (.some, .none):
                    // item1 has rating, item2 doesn't - item1 comes first
                    return true
                case (.none, .some):
                    // item2 has rating, item1 doesn't - item2 comes first
                    return false
                case (.none, .none):
                    // Neither has rating - sort by name
                    return item1.catalogItem.name.localizedCaseInsensitiveCompare(item2.catalogItem.name) == .orderedAscending
                }
            }
        }
    }

    private func updateCaches() {
        var allTagsSet = Set<String>()
        var userTagsSet = Set<String>()
        var allCOEsSet = Set<Int32>()
        var manufacturersSet = Set<String>()

        for item in items {
            allTagsSet.formUnion(item.allTags)
            userTagsSet.formUnion(item.userTags)

            // Only add COE if it exists (glass items only)
            if let coe = item.catalogItem.coe {
                allCOEsSet.insert(coe)
            }

            let mfr = item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mfr.isEmpty {
                manufacturersSet.insert(mfr)
            }
        }

        cachedAllTags = allTagsSet.sorted()
        cachedUserTags = userTagsSet
        cachedAllCOEs = allCOEsSet.sorted()
        cachedManufacturers = manufacturersSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        // Compute product type counts once from all items (not affected by filters)
        productTypeCounts = computeProductTypeCounts()
    }

    /// Save product type filter to UserDefaults for persistence across sessions
    private func saveProductTypeFilter() {
        if let encoded = try? JSONEncoder().encode(selectedProductTypes) {
            UserDefaults.standard.set(encoded, forKey: Self.productTypeFilterKey)
        }
    }

    /// Save COE filter to UserDefaults for persistence across sessions
    private func saveCOEFilter() {
        if let encoded = try? JSONEncoder().encode(Array(selectedCOEs)) {
            UserDefaults.standard.set(encoded, forKey: Self.coeFilterKey)
        }
    }

    /// Save manufacturer filter to UserDefaults for persistence across sessions
    private func saveManufacturerFilter() {
        if let encoded = try? JSONEncoder().encode(Array(selectedManufacturers)) {
            UserDefaults.standard.set(encoded, forKey: Self.manufacturerFilterKey)
        }
    }

    /// Save tags filter to UserDefaults for persistence across sessions
    private func saveTagsFilter() {
        if let encoded = try? JSONEncoder().encode(Array(selectedTags)) {
            UserDefaults.standard.set(encoded, forKey: Self.tagsFilterKey)
        }
    }

    /// Save search titles only preference to UserDefaults
    private func saveSearchTitlesOnly() {
        UserDefaults.standard.set(searchTitlesOnly, forKey: Self.searchTitlesOnlyKey)
    }

    /// Save sort option to UserDefaults for persistence across sessions
    private func saveSortOption() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: Self.sortOptionKey)
    }

    // MARK: - Generic Filter Computation

    /// Generic method to compute available filter values and their counts
    /// Applies all filters EXCEPT the one being computed to show accurate counts
    private func computeAvailableValues<F: Filterable>(_ filter: F) -> [F.FilterKey: Int] {
        var filtered = items

        // IMPORTANT: When adding a new filter type:
        // 1. Create a new struct conforming to Filterable (see ManufacturerFilter, etc.)
        // 2. Add it to this allFilters array
        // 3. Add it to the allFilters array in applyFilters() as well
        let allFilters: [any Filterable] = [
            ProductTypeFilter(),
            ManufacturerFilter(),
            COEFilter(),
            TagFilter(),
            SearchFilter()
        ]

        // Apply all OTHER filters (not the one we're computing counts for)
        for otherFilter in allFilters {
            let isSameFilterType = type(of: otherFilter) == type(of: filter)
            if otherFilter.shouldSkipWhenComputing(sameType: isSameFilterType, viewModel: self) {
                continue
            }
            filtered = otherFilter.applyFilter(to: filtered, viewModel: self)
        }

        // Count occurrences of each filter key
        var counts: [F.FilterKey: Int] = [:]
        for item in filtered {
            for key in filter.extractFilterKeys(item) {
                counts[key, default: 0] += 1
            }
        }
        return counts
    }

    private func computeManufacturerCounts() -> [String: Int] {
        return computeAvailableValues(ManufacturerFilter())
    }

    private func computeCOECounts() -> [Int32: Int] {
        return computeAvailableValues(COEFilter())
    }

    private func computeTagCounts() -> [String: Int] {
        return computeAvailableValues(TagFilter())
    }

    private func computeProductTypeCounts() -> [String: Int] {
        // Count all items by product type (glass, coating, tool)
        // No filter exclusion needed - we always want the full count
        var counts: [String: Int] = [:]
        for item in items {
            let productType = item.catalogItem.itemType.rawValue
            counts[productType, default: 0] += 1
        }
        return counts
    }

    private func generateEmptyStateMessage() -> String {
        var filters: [String] = []

        if !debouncedSearchText.isEmpty {
            filters.append("'\(debouncedSearchText)'")
        }

        if !selectedManufacturers.isEmpty {
            let mfrText = selectedManufacturers.count == 1 ? "manufacturer" : "manufacturers"
            let mfrList = selectedManufacturers.sorted().compactMap { GlassManufacturers.fullName(for: $0) ?? $0 }.joined(separator: ", ")
            filters.append("\(mfrText) \(mfrList)")
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
}
