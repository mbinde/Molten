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

enum CatalogSearchScope: String, CaseIterable {
    case allFields = "All fields"
    case titlesOnly = "Only titles"
}

// Navigation destinations for CatalogView NavigationStack - NEW: Updated for GlassItem architecture
enum CatalogNavigationDestination: Hashable {
    case addInventoryItem(stableId: String)
    case catalogItemDetail(itemModel: CompleteInventoryItemModel)  // NEW: Use CompleteInventoryItemModel
}

struct CatalogView: View {
    // MIGRATION COMPLETE: ViewModel manages search, filters, sorting, loading, and data ✓
    @State private var viewModel: CatalogViewModel

    // Search scope state - persisted via viewModel.searchTitlesOnly and UserDefaults
    @State private var searchScope: CatalogSearchScope = .titlesOnly


    // Use manual UserDefaults handling instead of @AppStorage to prevent test crashes
    @State private var defaultSortOptionRawValue = SortOption.name.rawValue
    @State private var enabledManufacturersData: Data = Data()
    @State private var selectedProductTypes: Set<String> = []  // Product type filter: empty = show all, non-empty = filter
    @State private var showingProductTypeSelection = false

    private var userDefaults: UserDefaults {
        // Use isolated UserDefaults during testing to prevent Core Data conflicts
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let testSuiteName = "Test_CatalogView_Settings"
            return UserDefaults(suiteName: testSuiteName) ?? UserDefaults.standard
        } else {
            return UserDefaults.standard
        }
    }

    // UI-only state (not managed by ViewModel)
    @State private var showingAllTags = false
    @State private var showingCOESelection = false
    @State private var showingManufacturerFilterSelection = false
    @State private var navigationPath = NavigationPath()
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date = Date.distantPast
    @State private var catalogUpdateMessage = ""
    @State private var showCatalogUpdateToast = false

    // Local search text state - isolates TextField from ViewModel to prevent full view re-renders
    // The ViewModel's searchText setter handles debouncing and triggers filtering
    @State private var localSearchText = ""

    // Repository pattern - single source of truth for data
    private let catalogService: CatalogService
    private let inventoryTrackingService: InventoryTrackingService
    private let userNotesRepository: UserNotesRepository
    private let userTagsRepository: UserTagsRepository
    private let shoppingListRepository: ShoppingListRepository
    private let userImageRepository: UserImageRepository
    private let kilnScheduleService: KilnScheduleService
    private let glassItemRepository: GlassItemRepository

    // MIGRATION: Get items from ViewModel instead of cache
    private var catalogItems: [CompleteInventoryItemModel] {
        viewModel.items
    }

    /// Protocol-based initializer - accepts ViewModel directly (for testing)
    init(viewModel: CatalogViewModel,
         catalogService: CatalogService,
         inventoryTrackingService: InventoryTrackingService,
         userNotesRepository: UserNotesRepository,
         userTagsRepository: UserTagsRepository,
         shoppingListRepository: ShoppingListRepository,
         userImageRepository: UserImageRepository,
         kilnScheduleService: KilnScheduleService,
         glassItemRepository: GlassItemRepository) {
        self._viewModel = State(initialValue: viewModel)
        self.catalogService = catalogService
        self.inventoryTrackingService = inventoryTrackingService
        self.userNotesRepository = userNotesRepository
        self.userTagsRepository = userTagsRepository
        self.shoppingListRepository = shoppingListRepository
        self.userImageRepository = userImageRepository
        self.kilnScheduleService = kilnScheduleService
        self.glassItemRepository = glassItemRepository
    }

    /// Convenience initializer - creates ViewModel with services from AppDependencies
    init(deps: AppDependencies = .shared) {
        let viewModel = CatalogViewModel(catalogService: deps.catalogService)
        self.init(
            viewModel: viewModel,
            catalogService: deps.catalogService,
            inventoryTrackingService: deps.inventoryTrackingService,
            userNotesRepository: deps.userNotesRepository,
            userTagsRepository: deps.userTagsRepository,
            shoppingListRepository: deps.shoppingListRepository,
            userImageRepository: deps.userImageRepository,
            kilnScheduleService: deps.kilnScheduleService,
            glassItemRepository: deps.glassItemRepository
        )
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
    
    // MIGRATION: Get filtered items from ViewModel instead of manual cache
    private var filteredItems: [CompleteInventoryItemModel] {
        return viewModel.filteredItems
    }

    // MIGRATION: Get sorted filtered items from ViewModel instead of manual cache
    private var sortedFilteredItems: [CompleteInventoryItemModel] {
        return viewModel.sortedFilteredItems
    }

    // Simplified sorting without Core Data dependencies
    // private var catalogSortCriteria removed - no longer needed for repository pattern

    // MIGRATION: Get available tags from ViewModel
    private var allAvailableTags: [String] {
        return viewModel.allAvailableTags
    }

    // MIGRATION: Get user tags from ViewModel
    private var allUserTags: Set<String> {
        return viewModel.allUserTags
    }


    // MIGRATION: Get available COEs from ViewModel
    private var allAvailableCOEs: [Int32] {
        return viewModel.allAvailableCOEs
    }

    // MIGRATION: Get available manufacturers from ViewModel
    private var availableManufacturers: [String] {
        return viewModel.availableManufacturers
    }

    // MARK: - Filter Counts (for display in filter selection sheets)

    // MIGRATION: Get filter counts from ViewModel
    private var manufacturerCounts: [String: Int] {
        return viewModel.manufacturerCounts
    }

    private var coeCounts: [Int32: Int] {
        return viewModel.coeCounts
    }

    private var tagCounts: [String: Int] {
        return viewModel.tagCounts
    }


    // MARK: - View Components

    private var searchAndFilterHeader: some View {
        StandardSearchAndFilterHeader(
            searchText: $viewModel.searchText,
            searchTitlesOnly: $viewModel.searchTitlesOnly,
            selectedTags: $viewModel.selectedTags,
            selectedCOEs: $viewModel.selectedCOEs,
            selectedManufacturers: $viewModel.selectedManufacturers,
            selectedProductTypes: $viewModel.selectedProductTypes,
            showingAllTags: $showingAllTags,
            showingCOESelection: $showingCOESelection,
            showingManufacturerSelection: $showingManufacturerFilterSelection,
            showingProductTypeSelection: $showingProductTypeSelection,
            allAvailableTags: allAvailableTags,
            allAvailableCOEs: allAvailableCOEs,
            allAvailableManufacturers: availableManufacturers,
            allAvailableProductTypes: ["glass", "coating", "tool"],
            manufacturerCounts: manufacturerCounts,
            coeCounts: coeCounts,
            tagCounts: tagCounts,
            sortMenuContent: {
                AnyView(
                    Group {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                viewModel.sortOption = option
                                updateSorting(option)
                            } label: {
                                Label(option.rawValue, systemImage: option.sortIcon)
                            }
                        }
                    }
                )
            },
            searchPlaceholder: "Search colors, codes, manufacturers...",
            searchClearedFeedback: $viewModel.searchClearedFeedback
        )
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Filter controls (using SearchAndFilterHeader but without built-in search)
            filterHeader

            // Main content
            Group {
                if viewModel.isLoading && catalogItems.isEmpty {
                    catalogLoadingState
                } else if catalogItems.isEmpty {
                    catalogEmptyState
                } else if filteredItems.isEmpty && viewModel.hasActiveFilters {
                    searchEmptyStateView
                } else {
                    catalogListView
                }
            }
        }
    }

    /// Filter header - uses reusable ModernFilterHeader component
    private var filterHeader: some View {
        ModernFilterHeader(
            searchTitlesOnly: $viewModel.searchTitlesOnly,
            sortOption: $viewModel.sortOption,
            sortOptions: Array(SortOption.allCases),
            sortOptionIcon: { $0.sortIcon },
            onSortChange: { updateSorting($0) },
            selectedTags: $viewModel.selectedTags,
            selectedCOEs: $viewModel.selectedCOEs,
            selectedManufacturers: $viewModel.selectedManufacturers,
            showingTagsSheet: $showingAllTags,
            showingCOESheet: $showingCOESelection,
            showingManufacturerSheet: $showingManufacturerFilterSelection,
            productTypeFilter: .init(
                selectedProductTypes: $viewModel.selectedProductTypes,
                availableTypes: FeatureFlags.availableProductTypes,
                displayName: displayNameForProductType,
                typeCounts: viewModel.productTypeCounts
            ),
            coeFilter: .init(
                selectedCOEs: $viewModel.selectedCOEs,
                availableCOEs: allAvailableCOEs
            )
        )
    }

    // MARK: - Helper Methods

    private func displayNameForProductType(_ type: String) -> String {
        switch type.lowercased() {
        case "glass": return "Glass"
        case "coating": return "Coatings"
        case "tool": return "Tools"
        default: return type.capitalized
        }
    }

    // Manufacturer multi-select sheet
    private var manufacturerMultiSelectSheet: some View {
        NavigationStack {
            List {
                ForEach(availableManufacturers, id: \.self) { mfr in
                    Button {
                        withAnimation {
                            if viewModel.selectedManufacturers.contains(mfr) {
                                viewModel.selectedManufacturers.remove(mfr)
                            } else {
                                viewModel.selectedManufacturers.insert(mfr)
                            }
                        }
                    } label: {
                        HStack {
                            Text(manufacturerDisplayName(mfr))
                            Spacer()
                            if viewModel.selectedManufacturers.contains(mfr) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.accentColor)
                            }
                            if let count = manufacturerCounts[mfr] {
                                Text("(\(count))")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Filter by Manufacturer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingManufacturerFilterSelection = false
                    }
                    .accessibilityIdentifier("catalog_manufacturer_filter_done")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        viewModel.selectedManufacturers.removeAll()
                    }
                    .disabled(viewModel.selectedManufacturers.isEmpty)
                    .accessibilityIdentifier("catalog_manufacturer_filter_clear")
                }
            }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            contentWithModifiers
        }
    }

    // Extract modifiers to reduce body complexity
    private var contentWithModifiers: some View {
        mainContentView
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("Catalog")
            .searchable(
                text: $localSearchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search colors, codes, manufacturers..."
            )
            .searchScopes($searchScope, activation: .onSearchPresentation) {
                ForEach(CatalogSearchScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue)
                }
            }
            .onChange(of: searchScope) { oldValue, newValue in
                viewModel.searchTitlesOnly = (newValue == .titlesOnly)
                // Persist to UserDefaults
                userDefaults.set(newValue == .titlesOnly, forKey: "searchTitlesOnly")
            }
            .onChange(of: localSearchText) { oldValue, newValue in
                // Sync local state to ViewModel - debouncing happens in ViewModel
                viewModel.searchText = newValue
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .modifier(CatalogSheetModifiers(
                showingAllTags: $showingAllTags,
                showingCOESelection: $showingCOESelection,
                showingManufacturerSelection: $showingManufacturerFilterSelection,
                allAvailableTags: allAvailableTags,
                allUserTags: allUserTags,
                selectedTags: $viewModel.selectedTags,
                tagCounts: tagCounts,
                allAvailableCOEs: allAvailableCOEs,
                selectedCOEs: $viewModel.selectedCOEs,
                coeCounts: coeCounts,
                availableManufacturers: availableManufacturers,
                selectedManufacturers: $viewModel.selectedManufacturers,
                manufacturerDisplayName: manufacturerDisplayName,
                manufacturerCounts: manufacturerCounts
            ))
            .modifier(CatalogLifecycleModifiers(
                userDefaults: userDefaults,
                defaultSortOptionRawValue: $defaultSortOptionRawValue,
                enabledManufacturersData: $enabledManufacturersData,
                searchTitlesOnly: $viewModel.searchTitlesOnly,
                searchScope: $searchScope,
                selectedProductTypes: $selectedProductTypes,
                sortOption: $viewModel.sortOption,
                viewModel: viewModel,
                clearSearch: clearSearch,
                resetNavigation: resetNavigation,
                catalogUpdateMessage: $catalogUpdateMessage,
                showCatalogUpdateToast: $showCatalogUpdateToast
            ))
            .toast(
                message: catalogUpdateMessage,
                style: .info,
                isShowing: $showCatalogUpdateToast
            )
            .navigationDestination(for: CatalogNavigationDestination.self) { destination in
                switch destination {
                case .addInventoryItem(let naturalKey):
                    AddInventoryItemView(
                        prefilledNaturalKey: naturalKey,
                        deps: .shared
                    )
                case .catalogItemDetail(let itemModel):
                    InventoryDetailView(
                        item: itemModel,
                        deps: .shared
                    )
                }
            }
    }
    
    // MARK: - Filter Buttons

    private var tagFilterButton: some View {
        Button {
            showingAllTags = true
        } label: {
            Text(viewModel.selectedTags.isEmpty ? "All Tags" : "\(viewModel.selectedTags.count) Tag\(viewModel.selectedTags.count == 1 ? "" : "s")")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.selectedTags.isEmpty ? .primary : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(viewModel.selectedTags.isEmpty ? DesignSystem.Colors.backgroundInput : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Views

    private var catalogLoadingState: some View {
        CatalogLoadingState()
    }

    private var catalogEmptyState: some View {
        CatalogEmptyState()
    }
    
    private var searchEmptyStateView: some View {
        CatalogSearchEmptyState(
            message: viewModel.emptyStateMessage,
            onClearSearch: clearSearch
        )
    }
    
    private var catalogListView: some View {
        CatalogListView(items: sortedFilteredItems)
    }
}

// MARK: - CatalogView Actions
extension CatalogView {
    
    private func manufacturerDisplayName(_ manufacturer: String) -> String {
        // Use GlassManufacturers utility to get full name (no Core Data dependencies)
        return GlassManufacturers.fullName(for: manufacturer) ?? manufacturer
    }
    
    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    private func updateSorting(_ newSortOption: SortOption) {
        // MIGRATION: ViewModel handles sorting, just save to UserDefaults
        viewModel.updateSorting(newSortOption)
        defaultSortOptionRawValue = newSortOption.rawValue
        // Save to safe UserDefaults (isolated during testing)
        userDefaults.set(newSortOption.rawValue, forKey: "defaultSortOption")
    }
    
    private func clearSearch() {
        // MIGRATION: Use ViewModel clearSearch
        hideKeyboard()
        localSearchText = ""  // Sync local state with ViewModel
        viewModel.clearSearch()
    }
    
    private func resetNavigation() {
        // Reset navigation state to show the catalog list
        withAnimation(.easeInOut(duration: 0.3)) {
            navigationPath = NavigationPath()
        }
    }
    
    // MARK: - Repository-based Actions

    private func refreshData() async {
        // MIGRATION: Use ViewModel refresh instead of cache
        await viewModel.refreshData()
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
                                        .foregroundColor(Color.accentColor)
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
                    .accessibilityIdentifier("catalog_tag_filter_clear")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("catalog_tag_filter_done")
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
                .font(.body)
            
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
                        .font(.body)
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


// MARK: - Preview
#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return CatalogView(deps: deps)
}
