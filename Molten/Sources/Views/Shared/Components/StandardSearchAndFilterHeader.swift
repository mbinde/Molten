//
//  StandardSearchAndFilterHeader.swift
//  Molten
//
//  Wrapper around SearchAndFilterHeader with sensible defaults
//  to reduce boilerplate in views
//

import SwiftUI

/// Standard search and filter header with common defaults
struct StandardSearchAndFilterHeader: View {

    // MARK: - Search and Filter State

    @Binding var searchText: String
    @Binding var searchTitlesOnly: Bool
    @Binding var selectedTags: Set<String>
    @Binding var selectedCOEs: Set<Int32>
    @Binding var selectedManufacturers: Set<String>
    @Binding var selectedProductTypes: Set<String>

    // MARK: - Sheet Presentation State

    @Binding var showingAllTags: Bool
    @Binding var showingCOESelection: Bool
    @Binding var showingManufacturerSelection: Bool
    @Binding var showingProductTypeSelection: Bool

    // MARK: - Available Options

    let allAvailableTags: [String]
    let allAvailableCOEs: [Int32]
    let allAvailableManufacturers: [String]
    let allAvailableProductTypes: [String]

    // MARK: - Optional Customization

    let manufacturerCounts: [String: Int]?
    let coeCounts: [Int32: Int]?
    let tagCounts: [String: Int]?
    let sortMenuContent: () -> AnyView
    let searchPlaceholder: String
    let searchClearedFeedback: Binding<Bool>

    init(
        searchText: Binding<String>,
        searchTitlesOnly: Binding<Bool>,
        selectedTags: Binding<Set<String>>,
        selectedCOEs: Binding<Set<Int32>>,
        selectedManufacturers: Binding<Set<String>>,
        selectedProductTypes: Binding<Set<String>> = .constant([]),
        showingAllTags: Binding<Bool>,
        showingCOESelection: Binding<Bool>,
        showingManufacturerSelection: Binding<Bool>,
        showingProductTypeSelection: Binding<Bool> = .constant(false),
        allAvailableTags: [String],
        allAvailableCOEs: [Int32],
        allAvailableManufacturers: [String],
        allAvailableProductTypes: [String] = [],
        manufacturerCounts: [String: Int]? = nil,
        coeCounts: [Int32: Int]? = nil,
        tagCounts: [String: Int]? = nil,
        sortMenuContent: @escaping () -> AnyView = { AnyView(EmptyView()) },
        searchPlaceholder: String = "Search...",
        searchClearedFeedback: Binding<Bool> = .constant(false)
    ) {
        self._searchText = searchText
        self._searchTitlesOnly = searchTitlesOnly
        self._selectedTags = selectedTags
        self._selectedCOEs = selectedCOEs
        self._selectedManufacturers = selectedManufacturers
        self._selectedProductTypes = selectedProductTypes
        self._showingAllTags = showingAllTags
        self._showingCOESelection = showingCOESelection
        self._showingManufacturerSelection = showingManufacturerSelection
        self._showingProductTypeSelection = showingProductTypeSelection
        self.allAvailableTags = allAvailableTags
        self.allAvailableCOEs = allAvailableCOEs
        self.allAvailableManufacturers = allAvailableManufacturers
        self.allAvailableProductTypes = allAvailableProductTypes
        self.manufacturerCounts = manufacturerCounts
        self.coeCounts = coeCounts
        self.tagCounts = tagCounts
        self.sortMenuContent = sortMenuContent
        self.searchPlaceholder = searchPlaceholder
        self.searchClearedFeedback = searchClearedFeedback
    }

    var body: some View {
        SearchAndFilterHeader(
            searchText: $searchText,
            searchTitlesOnly: $searchTitlesOnly,
            selectedTags: $selectedTags,
            showingAllTags: $showingAllTags,
            allAvailableTags: allAvailableTags,
            selectedCOEs: $selectedCOEs,
            showingCOESelection: $showingCOESelection,
            allAvailableCOEs: allAvailableCOEs,
            selectedProductTypes: $selectedProductTypes,
            showingProductTypeSelection: $showingProductTypeSelection,
            allAvailableProductTypes: allAvailableProductTypes,
            selectedManufacturers: $selectedManufacturers,
            showingManufacturerSelection: $showingManufacturerSelection,
            allAvailableManufacturers: allAvailableManufacturers,
            manufacturerDisplayName: { code in
                GlassManufacturers.fullName(for: code) ?? code
            },
            manufacturerCounts: manufacturerCounts,
            coeCounts: coeCounts,
            tagCounts: tagCounts,
            sortMenuContent: sortMenuContent,
            searchClearedFeedback: searchClearedFeedback,
            searchPlaceholder: searchPlaceholder
        )
    }
}
