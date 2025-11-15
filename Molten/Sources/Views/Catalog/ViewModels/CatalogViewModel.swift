//
//  CatalogViewModel.swift
//  Molten
//
//  Created by Assistant on 10/27/25.
//  Protocol-based ViewModel for CatalogView - enables testability
//

import Foundation
import SwiftUI

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

    private let catalogService: CatalogService

    // MARK: - Constants

    private static let productTypeFilterKey = "catalog.selectedProductTypes"

    // MARK: - Published State

    var items: [CompleteInventoryItemModel] = []
    var filteredItems: [CompleteInventoryItemModel] = []
    var sortedFilteredItems: [CompleteInventoryItemModel] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Search & Filter State

    var searchText = "" {
        didSet {
            if searchText != oldValue {
                applyFilters()
            }
        }
    }

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

    // MARK: - Initialization

    init(catalogService: CatalogService) {
        self.catalogService = catalogService

        // Load saved product type filter from UserDefaults, default to "glass"
        if let savedData = UserDefaults.standard.data(forKey: Self.productTypeFilterKey),
           let savedTypes = try? JSONDecoder().decode(Set<String>.self, from: savedData),
           !savedTypes.isEmpty {
            self.selectedProductTypes = savedTypes
        } else {
            // Default to "glass" if no saved filter
            self.selectedProductTypes = ["glass"]
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
        !searchText.isEmpty ||
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
            // Load all glass items from catalog service
            items = try await catalogService.getAllGlassItems()

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

        // Apply manufacturer filter
        if !selectedManufacturers.isEmpty {
            filtered = filtered.filter { item in
                selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
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

        // Apply COE filter (only for glass items)
        if !selectedCOEs.isEmpty {
            filtered = filtered.filter { item in
                if let coe = item.catalogItem.coe {
                    return selectedCOEs.contains(coe)
                }
                return false  // Non-glass items don't match COE filter
            }
        }

        // Apply search filter
        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
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

    private func computeManufacturerCounts() -> [String: Int] {
        var filtered = items

        // Apply all filters EXCEPT manufacturer
        // Apply product type filter
        if !selectedProductTypes.isEmpty {
            filtered = filtered.filter { item in
                selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        if !selectedTags.isEmpty {
            filtered = filtered.filter { item in
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        if !selectedCOEs.isEmpty {
            filtered = filtered.filter { item in
                if let coe = item.catalogItem.coe {
                    return selectedCOEs.contains(coe)
                }
                return false
            }
        }

        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
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

        var counts: [String: Int] = [:]
        for item in filtered {
            let mfr = item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            counts[mfr, default: 0] += 1
        }
        return counts
    }

    private func computeCOECounts() -> [Int32: Int] {
        var filtered = items

        // Apply all filters EXCEPT COE
        // Apply product type filter
        if !selectedProductTypes.isEmpty {
            filtered = filtered.filter { item in
                selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        if !selectedManufacturers.isEmpty {
            filtered = filtered.filter { item in
                selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        if !selectedTags.isEmpty {
            filtered = filtered.filter { item in
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
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

        var counts: [Int32: Int] = [:]
        for item in filtered {
            // Only count COE for glass items
            if let coe = item.catalogItem.coe {
                counts[coe, default: 0] += 1
            }
        }
        return counts
    }

    private func computeTagCounts() -> [String: Int] {
        var filtered = items

        // Apply all filters EXCEPT tags
        // Apply product type filter
        if !selectedProductTypes.isEmpty {
            filtered = filtered.filter { item in
                selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        if !selectedManufacturers.isEmpty {
            filtered = filtered.filter { item in
                selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        if !selectedCOEs.isEmpty {
            filtered = filtered.filter { item in
                if let coe = item.catalogItem.coe {
                    return selectedCOEs.contains(coe)
                }
                return false
            }
        }

        if !searchText.isEmpty && SearchTextParser.isSearchTextMeaningful(searchText) {
            let searchMode = SearchTextParser.parseSearchText(searchText)
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

        var counts: [String: Int] = [:]
        for item in filtered {
            for tag in item.allTags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }

    private func generateEmptyStateMessage() -> String {
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
