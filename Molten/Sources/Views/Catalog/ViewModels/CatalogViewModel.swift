//
//  CatalogViewModel.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol-based ViewModel for CatalogView - enables testability
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
            if let coe = item.catalogItem.coe {
                return activeCOEFilter.contains(coe)
            }
            return false
        }
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
            // AND logic: item must have ALL selected tags
            viewModel.selectedTags.isSubset(of: Set(item.allTags))
        }
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

    // MARK: - Published State

    var items: [CompleteInventoryItemModel] = []
    var filteredItems: [CompleteInventoryItemModel] = []
    var sortedFilteredItems: [CompleteInventoryItemModel] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Search & Filter State

    /// Immediate search text (updates on every keystroke for UI responsiveness)
    var searchText = ""

    /// Debounced search text (updates after 300ms delay to avoid expensive filtering on every keystroke)
    var debouncedSearchText = ""

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    var searchTitlesOnly = true {
        didSet {
            if searchTitlesOnly != oldValue {
                applyFilters()
            }
        }
    }

    var selectedTags: Set<String> = [] {
        didSet {
            if selectedTags != oldValue {
                applyFilters()
            }
        }
    }

    var selectedCOEs: Set<Int32> = [] {
        didSet {
            if selectedCOEs != oldValue {
                applyFilters()
            }
        }
    }

    var selectedManufacturers: Set<String> = [] {
        didSet {
            if selectedManufacturers != oldValue {
                applyFilters()
            }
        }
    }

    var selectedManufacturer: String? = nil

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

    // MARK: - Initialization

    init(catalogService: CatalogService) {
        self.catalogService = catalogService

        // Load saved product type filter from UserDefaults, default to "all"
        if let savedData = UserDefaults.standard.data(forKey: Self.productTypeFilterKey),
           let savedTypes = try? JSONDecoder().decode(Set<String>.self, from: savedData) {
            self.selectedProductTypes = savedTypes
        } else {
            // Default to "all" (empty set) if no saved filter
            self.selectedProductTypes = []
        }

        // Set up debouncing for search text (300ms delay)
        // This prevents expensive filtering operations on every keystroke
        setupSearchDebouncing()

        // Set up observer for COE and manufacturer preference changes
        setupUserDefaultsObserver()
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
            // When UserDefaults changes, reapply filters
            // This catches changes made in Settings view for COE and manufacturer filters
            self?.applyFilters()
        }
    }

    // MARK: - Computed Properties

    var allAvailableTags: [String] {
        // Return only tags that have items in the current filtered view
        return Array(tagCounts.keys).sorted()
    }

    var allUserTags: Set<String> {
        return cachedUserTags
    }

    var allAvailableCOEs: [Int32] {
        // Return only COEs that have items in the current filtered view
        return Array(coeCounts.keys).sorted()
    }

    var availableManufacturers: [String] {
        // Return only manufacturers that have items in the current filtered view
        return Array(manufacturerCounts.keys).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var manufacturerCounts: [String: Int] {
        computeManufacturerCounts()
    }

    var coeCounts: [Int32: Int] {
        computeCOECounts()
    }

    var tagCounts: [String: Int] {
        computeTagCounts()
    }

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
        !selectedProductTypes.isEmpty ||
        selectedManufacturer != nil
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
        selectedManufacturer = nil
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

    func applyFilters() {
        var filtered = items

        // Apply product type filter
        if !selectedProductTypes.isEmpty {
            filtered = filtered.filter { item in
                selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        // Apply manufacturer filter (global preference from settings OR manual selection in catalog)
        // Global preference: UserDefaults "selectedManufacturerFilter" (set in Settings)
        // Manual selection: selectedManufacturers (set by checkboxes in Catalog filter UI)
        // Logic: If user manually selected manufacturers in catalog, use those. Otherwise, apply global preference.

        let activeManufacturerFilter: Set<String>?
        if !selectedManufacturers.isEmpty {
            // User manually selected specific manufacturers in catalog filter UI
            activeManufacturerFilter = selectedManufacturers
        } else if let data = UserDefaults.standard.data(forKey: "selectedManufacturerFilter"),
                  let globalPref = try? JSONDecoder().decode(Set<String>.self, from: data) {
            // Use global manufacturer preference from settings
            activeManufacturerFilter = globalPref
        } else {
            activeManufacturerFilter = nil
        }

        if let manufacturers = activeManufacturerFilter {
            filtered = filtered.filter { item in
                manufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // Apply legacy single manufacturer filter
        if let selectedManufacturer = selectedManufacturer {
            filtered = filtered.filter { item in
                item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines) == selectedManufacturer
            }
        }

        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { item in
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        // Apply COE filter (global COE preference from settings OR manual selection in catalog)
        // Global preference: COEGlassPreference.selectedCOETypes (set in Settings)
        // Manual selection: selectedCOEs (set by checkboxes in Catalog filter UI)
        // Logic: If user manually selected COEs in catalog, use those. Otherwise, apply global preference.

        let activeCOEFilter: Set<Int32>
        if !selectedCOEs.isEmpty {
            // User manually selected specific COEs in catalog filter UI
            activeCOEFilter = selectedCOEs
        } else {
            // Use global COE preference from settings
            activeCOEFilter = Set(COEGlassPreference.selectedCOETypes.map { Int32($0.rawValue) })
        }

        // Apply the active COE filter (only for glass items)
        if !activeCOEFilter.isEmpty {
            filtered = filtered.filter { item in
                if let coe = item.catalogItem.coe {
                    return activeCOEFilter.contains(coe)
                }
                return false  // Non-glass items don't match COE filter
            }
        }

        // Apply search filter (using debounced search text for performance)
        if !debouncedSearchText.isEmpty && SearchTextParser.isSearchTextMeaningful(debouncedSearchText) {
            let searchMode = SearchTextParser.parseSearchText(debouncedSearchText)
            filtered = filtered.filter { item in
                if searchTitlesOnly {
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

        filteredItems = filtered
        applySorting()
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
    }

    /// Save product type filter to UserDefaults for persistence across sessions
    private func saveProductTypeFilter() {
        if let encoded = try? JSONEncoder().encode(selectedProductTypes) {
            UserDefaults.standard.set(encoded, forKey: Self.productTypeFilterKey)
        }
    }

    // MARK: - Generic Filter Computation

    /// Generic method to compute available filter values and their counts
    /// Applies all filters EXCEPT the one being computed to show accurate counts
    private func computeAvailableValues<F: Filterable>(_ filter: F) -> [F.FilterKey: Int] {
        var filtered = items

        // Apply product type filter (always applied)
        if !selectedProductTypes.isEmpty {
            filtered = filtered.filter { item in
                selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        // Apply all OTHER filters (not the one we're computing)
        let allFilters: [any Filterable] = [
            ManufacturerFilter(),
            COEFilter(),
            TagFilter()
        ]

        for otherFilter in allFilters {
            // CRITICAL: Always apply filters with global preferences (COE, Manufacturer)
            // even when computing counts for that same filter type, because we want to
            // show only the values present in the currently filtered items.
            //
            // For tags, we also always apply the tag filter to show only tags in the current filtered set.
            //
            // Skip ONLY filters that are manually selected in the catalog UI when computing their own counts.

            let isSameFilterType = type(of: otherFilter) == type(of: filter)
            let shouldSkip: Bool

            if type(of: otherFilter) == ManufacturerFilter.self {
                // Skip only if computing manufacturer counts AND user has manual selection (no global pref active)
                shouldSkip = isSameFilterType && !selectedManufacturers.isEmpty
            } else if type(of: otherFilter) == COEFilter.self {
                // Skip only if computing COE counts AND user has manual selection (no global pref active)
                shouldSkip = isSameFilterType && !selectedCOEs.isEmpty
            } else if type(of: otherFilter) == TagFilter.self {
                // Never skip tags - always apply to show only tags in filtered results
                shouldSkip = false
            } else {
                // Default: skip if same filter type
                shouldSkip = isSameFilterType
            }

            if shouldSkip {
                continue
            }

            // Apply filters that are active
            if type(of: otherFilter) == ManufacturerFilter.self {
                let mfrFilter = ManufacturerFilter()
                if mfrFilter.isActive(in: self) {
                    filtered = mfrFilter.applyFilter(to: filtered, viewModel: self)
                }
            } else if type(of: otherFilter) == COEFilter.self {
                let coeFilter = COEFilter()
                if coeFilter.isActive(in: self) {
                    filtered = coeFilter.applyFilter(to: filtered, viewModel: self)
                }
            } else if type(of: otherFilter) == TagFilter.self {
                let tagFilter = TagFilter()
                if tagFilter.isActive(in: self) {
                    filtered = tagFilter.applyFilter(to: filtered, viewModel: self)
                }
            }
        }

        // Apply search filter (always applied when active, using debounced search text)
        if !debouncedSearchText.isEmpty && SearchTextParser.isSearchTextMeaningful(debouncedSearchText) {
            let searchMode = SearchTextParser.parseSearchText(debouncedSearchText)
            filtered = filtered.filter { item in
                if searchTitlesOnly {
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

        if let selectedManufacturer = selectedManufacturer {
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
}
