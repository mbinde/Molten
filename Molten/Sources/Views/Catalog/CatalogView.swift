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
    // MIGRATION COMPLETE: ViewModel manages search, filters, sorting, loading, and data ✓
    @State private var viewModel: CatalogViewModel

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
    @State private var showingManufacturerSelection = false  // Keep for legacy CatalogManufacturerFilterView
    @State private var navigationPath = NavigationPath()
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date = Date.distantPast
    @State private var catalogUpdateMessage = ""
    @State private var showCatalogUpdateToast = false

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
    init(deps: AppDependencies = AppDependencies()) {
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

    /// Filter header - uses SearchAndFilterHeader component but without the search field (now using native .searchable())
    private var filterHeader: some View {
        VStack(spacing: DesignSystem.Spacing.none) {
            // Top row: Search titles only toggle
            HStack {
                // Compact search titles only toggle
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Toggle("", isOn: $viewModel.searchTitlesOnly)
                        .labelsHidden()
                    Text("Search titles only")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xs)

            // Bottom row: Product type (left) and filter chips (right)
            HStack(spacing: DesignSystem.Spacing.md) {
                // Left: Product type filter (radio button style, single select)
                compactProductTypeFilterButton

                Spacer()

                // Right: Filter chips (COE, Tags, Mfr from left to right)
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // COE filter chip
                    compactCOEFilterButton

                    // Tag filter chip
                    compactTagFilterButton

                    // Manufacturer filter chip (far right)
                    compactManufacturerFilterButton
                }
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }

    // MARK: - Compact Filter Buttons

    private var compactManufacturerFilterButton: some View {
        Button {
            showingManufacturerFilterSelection = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if viewModel.selectedManufacturers.isEmpty {
                    Image(systemName: "building.2")
                        .font(DesignSystem.Typography.captionSmall)
                    Text("Mfr")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show first 2 manufacturers inline (abbreviated)
                    let sortedMfrs = viewModel.selectedManufacturers.sorted()
                    ForEach(Array(sortedMfrs.prefix(2)), id: \.self) { mfr in
                        Text(mfr.uppercased())
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.bold)
                    }
                    if viewModel.selectedManufacturers.count > 2 {
                        Text("+\(viewModel.selectedManufacturers.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            viewModel.selectedManufacturers.removeAll()
                        }
                }
                if viewModel.selectedManufacturers.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(Font.system(size: 10))
                }
            }
            .foregroundColor(viewModel.selectedManufacturers.isEmpty ? .secondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(viewModel.selectedManufacturers.isEmpty ? Color(.systemGray6) : .accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
        .sheet(isPresented: $showingManufacturerFilterSelection) {
            manufacturerMultiSelectSheet
        }
    }

    private var compactCOEFilterButton: some View {
        Button {
            showingCOESelection = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if viewModel.selectedCOEs.isEmpty {
                    Text("COE")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show selected COEs inline
                    let sortedCOEs = viewModel.selectedCOEs.sorted()
                    ForEach(Array(sortedCOEs.prefix(2)), id: \.self) { coe in
                        Text(String(coe))
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.bold)
                    }
                    if viewModel.selectedCOEs.count > 2 {
                        Text("+\(viewModel.selectedCOEs.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            viewModel.selectedCOEs.removeAll()
                        }
                }
                if viewModel.selectedCOEs.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(Font.system(size: 10))
                }
            }
            .foregroundColor(viewModel.selectedCOEs.isEmpty ? .secondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(viewModel.selectedCOEs.isEmpty ? Color(.systemGray6) : .accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }

    private var compactTagFilterButton: some View {
        Button {
            showingAllTags = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if viewModel.selectedTags.isEmpty {
                    Image(systemName: "tag")
                        .font(DesignSystem.Typography.captionSmall)
                    Text("Tags")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(DesignSystem.FontWeight.medium)
                } else {
                    // Show first 2 tags inline
                    let sortedTags = viewModel.selectedTags.sorted()
                    ForEach(Array(sortedTags.prefix(2)), id: \.self) { tag in
                        Text(tag)
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.bold)
                            .lineLimit(1)
                    }
                    if viewModel.selectedTags.count > 2 {
                        Text("+\(viewModel.selectedTags.count - 2)")
                            .font(DesignSystem.Typography.captionSmall)
                            .fontWeight(DesignSystem.FontWeight.medium)
                    }
                    // X button to clear
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignSystem.Typography.captionSmall)
                        .onTapGesture {
                            viewModel.selectedTags.removeAll()
                        }
                }
                if viewModel.selectedTags.isEmpty {
                    Image(systemName: "chevron.down")
                        .font(Font.system(size: 10))
                }
            }
            .foregroundColor(viewModel.selectedTags.isEmpty ? .secondary : .white)
            .padding(.horizontal, DesignSystem.Padding.chip)
            .padding(.vertical, DesignSystem.Padding.chipVertical)
            .background(viewModel.selectedTags.isEmpty ? Color(.systemGray6) : .accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        }
    }

    private var compactProductTypeFilterButton: some View {
        // Radio button style segmented control for product type (single select)
        Picker("Product Type", selection: Binding(
            get: { viewModel.selectedProductTypes.first ?? "glass" },
            set: { newValue in
                withAnimation {
                    viewModel.selectedProductTypes = [newValue]
                }
            }
        )) {
            Text("Glass").tag("glass")
            Text("Coating").tag("coating")
            Text("Tool").tag("tool")
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 250) // Constrain width so it doesn't stretch too much
    }

    private func displayNameForProductType(_ type: String) -> String {
        switch type {
        case "glass": return "Glass"
        case "coating": return "Coating"
        case "tool": return "Tool"
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
                                    .foregroundColor(.accentColor)
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
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        viewModel.selectedManufacturers.removeAll()
                    }
                    .disabled(viewModel.selectedManufacturers.isEmpty)
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
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search colors, codes, manufacturers..."
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onChange(of: viewModel.searchText) { oldValue, newValue in
                // Debounce search text updates (300ms delay)
                // This prevents expensive filtering on every keystroke
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    // Only update if the value hasn't changed (user stopped typing)
                    if viewModel.searchText == newValue {
                        viewModel.debouncedSearchText = newValue
                        viewModel.applyFilters()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                viewModel.sortOption = option
                                updateSorting(option)
                            } label: {
                                Label(option.rawValue, systemImage: option.sortIcon)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .accessibilityLabel("Sort")
                    }
                }
            }
            .modifier(SheetModifiers(
                showingAllTags: $showingAllTags,
                showingCOESelection: $showingCOESelection,
                showingManufacturerSelection: $showingManufacturerSelection,
                allAvailableTags: allAvailableTags,
                selectedTags: $viewModel.selectedTags,
                tagCounts: tagCounts,
                allAvailableCOEs: allAvailableCOEs,
                selectedCOEs: $viewModel.selectedCOEs,
                coeCounts: coeCounts,
                availableManufacturers: availableManufacturers,
                selectedManufacturer: $viewModel.selectedManufacturer,
                manufacturerDisplayName: manufacturerDisplayName
            ))
            .modifier(LifecycleModifiers(
                userDefaults: userDefaults,
                defaultSortOptionRawValue: $defaultSortOptionRawValue,
                enabledManufacturersData: $enabledManufacturersData,
                searchTitlesOnly: $viewModel.searchTitlesOnly,
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
                        deps: AppDependencies()
                    )
                case .catalogItemDetail(let itemModel):
                    InventoryDetailView(
                        item: itemModel,
                        deps: AppDependencies()
                    )
                }
            }
    }
    
    // MARK: - Filter Buttons

    private var manufacturerFilterButton: some View {
        Button {
            showingManufacturerSelection = true
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.selectedManufacturer != nil ? manufacturerDisplayName(viewModel.selectedManufacturer!) : "All Manufacturers")
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
            }
            .foregroundColor(viewModel.selectedManufacturer != nil ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(viewModel.selectedManufacturer != nil ? Color.blue : DesignSystem.Colors.backgroundInput)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var tagFilterButton: some View {
        Button {
            showingAllTags = true
        } label: {
            Text(viewModel.selectedTags.isEmpty ? "All Tags" : "\(viewModel.selectedTags.count) Tag\(viewModel.selectedTags.count == 1 ? "" : "s")")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.selectedTags.isEmpty ? .primary : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(viewModel.selectedTags.isEmpty ? DesignSystem.Colors.backgroundInput : Color.blue)
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
    
    // MIGRATION: Get empty state message from ViewModel
    private var emptyStateMessage: String {
        return viewModel.emptyStateMessage
    }
    
    private var catalogListView: some View {
        List {
            ForEach(sortedFilteredItems, id: \.id) { item in
                NavigationLink(value: CatalogNavigationDestination.catalogItemDetail(itemModel: item)) {
                    GlassItemRowView.catalog(item: item)
                }
                .accessibilityIdentifier("catalog.item.\(item.glassItem.stable_id)")
            }
        }
        .accessibilityIdentifier("catalog.list")
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
        // MIGRATION: ViewModel handles sorting, just save to UserDefaults
        viewModel.updateSorting(newSortOption)
        defaultSortOptionRawValue = newSortOption.rawValue
        // Save to safe UserDefaults (isolated during testing)
        userDefaults.set(newSortOption.rawValue, forKey: "defaultSortOption")
    }
    
    private func clearSearch() {
        // MIGRATION: Use ViewModel clearSearch
        hideKeyboard()
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
        print("📊 CatalogView: Refresh requested - reloading via ViewModel")
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

// MARK: - View Modifiers (to reduce body complexity)

struct SheetModifiers: ViewModifier {
    @Binding var showingAllTags: Bool
    @Binding var showingCOESelection: Bool
    @Binding var showingManufacturerSelection: Bool
    let allAvailableTags: [String]
    @Binding var selectedTags: Set<String>
    let tagCounts: [String: Int]
    let allAvailableCOEs: [Int32]
    @Binding var selectedCOEs: Set<Int32>
    let coeCounts: [Int32: Int]
    let availableManufacturers: [String]
    @Binding var selectedManufacturer: String?
    let manufacturerDisplayName: (String) -> String

    func body(content: Content) -> some View {
        content
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
    }
}

struct LifecycleModifiers: ViewModifier {
    let userDefaults: UserDefaults
    @Binding var defaultSortOptionRawValue: String
    @Binding var enabledManufacturersData: Data
    @Binding var searchTitlesOnly: Bool
    @Binding var selectedProductTypes: Set<String>
    @Binding var sortOption: SortOption
    let viewModel: CatalogViewModel
    let clearSearch: () -> Void
    let resetNavigation: () -> Void
    @Binding var catalogUpdateMessage: String
    @Binding var showCatalogUpdateToast: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .clearCatalogSearch)) { _ in
                clearSearch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetCatalogNavigation)) { _ in
                resetNavigation()
            }
            .onReceive(NotificationCenter.default.publisher(for: .catalogUpdateCompleted)) { notification in
                // Reload catalog data when update completes
                Task {
                    await viewModel.loadData()

                    // Show toast notification
                    if let result = notification.object as? CatalogUpdateResult {
                        catalogUpdateMessage = "Catalog updated to v\(result.version)"
                        withAnimation {
                            showCatalogUpdateToast = true
                        }
                    }
                }
            }
            .onAppear {
                // Load settings from safe UserDefaults (isolated during testing)
                defaultSortOptionRawValue = userDefaults.string(forKey: "defaultSortOption") ?? SortOption.name.rawValue
                enabledManufacturersData = userDefaults.data(forKey: "enabledManufacturers") ?? Data()

                // Load search titles only setting (default: true)
                searchTitlesOnly = userDefaults.bool(forKey: "searchTitlesOnly") != false  // Default to true if not set

                // Product types: empty set = show all (new behavior, no need to persist)

                // Initialize sort option from user settings
                sortOption = SortOption(rawValue: defaultSortOptionRawValue) ?? .name
            }
            .task {
                // MIGRATION: Load data from ViewModel
                let taskStart = CFAbsoluteTimeGetCurrent()

                await viewModel.loadData()

                let dataLoadTime = (CFAbsoluteTimeGetCurrent() - taskStart) * 1000
                let totalTime = (CFAbsoluteTimeGetCurrent() - taskStart) * 1000
            }
    }
}

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
    let deps = AppDependencies(persistenceController: .createTestController())
    return CatalogView(deps: deps)
}
