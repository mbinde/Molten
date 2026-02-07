//
//  UnifiedGlassView.swift
//  Molten
//
//  Created by Assistant on 2/5/26.
//  Unified view combining Catalog, Inventory, and Shopping list functionality
//

import SwiftUI
import Foundation

/// Navigation destinations for UnifiedGlassView
enum GlassNavigationDestination: Hashable {
    case itemDetail(itemModel: CompleteInventoryItemModel)
    case addInventoryItem(stableId: String)
}

struct UnifiedGlassView: View {
    @State private var viewModel: UnifiedGlassViewModel

    // UI State
    @State private var navigationPath = NavigationPath()
    @State private var showingFilterSheet = false
    @State private var showingHelp = false
    @State private var showingSettings = false
    @State private var localSearchText = ""  // Local copy to avoid TextField re-renders
    @FocusState private var isSearchFocused: Bool

    // Shopping mode state
    @State private var isShoppingMode = false
    @State private var basketItems: Set<String> = []
    @State private var shoppingQuantities: [String: Double] = [:]
    @State private var showingCheckoutSheet = false

    // Inventory feature states (from old InventoryView)
    @State private var showingAddInventory = false
    @State private var showingQRScanner = false
    @State private var showingInventorySharing = false
    @State private var showingLabelDesigner = false
    @State private var showingManageLocations = false
    @State private var showingUpgradePrompt = false
    @State private var pendingShareCode: String? = nil

    // Shopping feature states
    @State private var showingAddShoppingItem = false

    // Filter sheet states
    @State private var showingCOESelection = false
    @State private var showingManufacturerSelection = false
    @State private var showingProductTypeSelection = false
    @State private var showingLocationSelection = false
    @State private var showingStoreSelection = false

    #if DEBUG
    // Processed items tracking (for row highlighting during review)
    @State private var processedItemIds: Set<String> = []
    #endif

    // Services and environment
    private let deps: AppDependencies
    @Environment(EntitlementService.self) private var entitlementService

    // MARK: - Initialization

    init(deps: AppDependencies = .shared) {
        self.deps = deps
        let vm = UnifiedGlassViewModel(
            catalogService: deps.catalogService,
            shoppingListService: deps.shoppingListService,
            inventoryTrackingService: deps.inventoryTrackingService
        )
        self._viewModel = State(initialValue: vm)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Quick filter tabs
                quickFilterTabs
                    .padding(.horizontal)
                    .padding(.top, DesignSystem.Spacing.sm)

                // Search bar
                searchBar
                    .padding(.horizontal)
                    .padding(.top, DesignSystem.Spacing.sm)

                // Context-specific filter bar (location or store)
                contextFilterBar

                // Main content
                mainContent
            }
            .navigationTitle("Supplies")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    sortMenu
                }
                ToolbarItem(placement: .confirmationAction) {
                    contextMenu
                }
            }
            .navigationDestination(for: GlassNavigationDestination.self) { destination in
                switch destination {
                case .itemDetail(let itemModel):
                    InventoryDetailView(item: itemModel, deps: deps)
                case .addInventoryItem(let stableId):
                    AddInventoryItemView(prefilledNaturalKey: stableId, deps: deps)
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                filterSheet
            }
            .sheet(isPresented: $showingHelp) {
                CatalogHelpView()
            }
            .sheet(isPresented: $showingSettings) {
                SuppliesSettingsView()
            }
            .sheet(isPresented: $showingCheckoutSheet) {
                checkoutSheet
            }
            // Inventory feature sheets
            .sheet(isPresented: $showingAddInventory, onDismiss: {
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await viewModel.refreshData()
                }
            }) {
                AddInventoryItemView(prefilledNaturalKey: nil, deps: deps)
            }
            .sheet(isPresented: $showingQRScanner) {
                QRCodeScannerView { scannedURL in
                    if let url = URL(string: scannedURL) {
                        NotificationCenter.default.post(
                            name: .openMoltenDeepLink,
                            object: nil,
                            userInfo: ["url": url]
                        )
                    }
                }
            }
            .sheet(isPresented: $showingLabelDesigner) {
                LabelDesignerView(items: viewModel.filteredItems)
            }
            .sheet(isPresented: $showingManageLocations) {
                ManageLocationsView(
                    storageLocationDefinitionRepository: deps.storageLocationDefinitionRepository,
                    storageLocationRepository: deps.storageLocationRepository,
                    inventoryTrackingService: deps.inventoryTrackingService,
                    onLocationsChanged: {
                        Task { await viewModel.refreshData() }
                    }
                )
            }
            .sheet(isPresented: $showingUpgradePrompt) {
                UpgradePromptView(
                    feature: "inventory",
                    currentCount: viewModel.inventoryItemIds.count,
                    limit: entitlementService.getInventoryLimit() ?? 0
                )
            }
            .fullScreenCover(isPresented: $showingInventorySharing) {
                NavigationStack {
                    InventorySharingView(pendingShareCode: pendingShareCode)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showingInventorySharing = false
                                    pendingShareCode = nil
                                }
                            }
                        }
                }
            }
            // Shopping feature sheets
            .sheet(isPresented: $showingAddShoppingItem, onDismiss: {
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await viewModel.refreshData()
                }
            }) {
                NavigationStack {
                    AddShoppingListItemView(deps: deps)
                }
            }
            .task {
                await viewModel.loadData()
                #if DEBUG
                await loadProcessedItems()
                #endif
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showCatalogFilters)) { _ in
                showingFilterSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryItemAdded)) { _ in
                Task { await viewModel.refreshData() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .shoppingListItemAdded)) { _ in
                Task { await viewModel.refreshData() }
            }
            #if DEBUG
            .onReceive(NotificationCenter.default.publisher(for: .catalogFlagChanged)) { _ in
                Task { await loadProcessedItems() }
            }
            #endif
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                TextField("Search supplies...", text: $localSearchText)
                    .focused($isSearchFocused)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .onChange(of: localSearchText) { _, newValue in
                        viewModel.searchText = newValue
                    }

                if !localSearchText.isEmpty {
                    Button {
                        localSearchText = ""
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(DesignSystem.Colors.backgroundSecondary)
            )

            // Filter button with badge
            Button {
                showingFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.hasActiveFilters ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textSecondary)

                    if viewModel.activeFilterCount > 0 {
                        Text("\(viewModel.activeFilterCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Circle().fill(DesignSystem.Colors.accentDanger))
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filters")
            .accessibilityHint(viewModel.activeFilterCount > 0 ? "\(viewModel.activeFilterCount) filters active" : "No filters active")
        }
    }

    // MARK: - Quick Filter Tabs

    private var quickFilterTabs: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(GlassQuickFilter.allCases) { filter in
                quickFilterButton(for: filter)
            }
        }
    }

    private func quickFilterButton(for filter: GlassQuickFilter) -> some View {
        let isSelected = viewModel.quickFilter == filter
        let count = countForQuickFilter(filter)

        // Use .fill variant when selected
        let iconName = isSelected ? "\(filter.systemImage).fill" : filter.systemImage

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.quickFilter = filter
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))

                // Selected tab: icon + text + count
                // Unselected tabs: icon + count only (more compact)
                if isSelected {
                    Text(filter.displayName)
                        .font(.system(size: 14, weight: .medium))
                }

                if count > 0 {
                    Text(isSelected ? "(\(count))" : "\(count)")
                        .font(.system(size: 12, weight: isSelected ? .regular : .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.horizontal, isSelected ? DesignSystem.Spacing.md : DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(isSelected ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.backgroundSecondary)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quick_filter_\(filter.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }

    private func countForQuickFilter(_ filter: GlassQuickFilter) -> Int {
        switch filter {
        case .all:
            return viewModel.allItems.count
        case .myGlass:
            return viewModel.inventoryItemIds.count
        case .wishList:
            return viewModel.shoppingListItemIds.count
        }
    }

    // MARK: - Context Filter Bar

    @ViewBuilder
    private var contextFilterBar: some View {
        switch viewModel.quickFilter {
        case .all:
            EmptyView()
        case .myGlass:
            if !viewModel.availableLocations.isEmpty {
                locationFilterBar
            }
        case .wishList:
            if !viewModel.availableStores.isEmpty {
                storeFilterBar
            }
        }
    }

    private var locationFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // "All Locations" chip
                filterChip(
                    label: "All Locations",
                    isSelected: viewModel.selectedLocations.isEmpty,
                    action: { viewModel.selectedLocations.removeAll() }
                )

                ForEach(viewModel.availableLocations, id: \.self) { location in
                    filterChip(
                        label: location.isEmpty ? "(none)" : location,
                        isSelected: viewModel.selectedLocations.contains(location),
                        action: {
                            if viewModel.selectedLocations.contains(location) {
                                viewModel.selectedLocations.remove(location)
                            } else {
                                viewModel.selectedLocations.insert(location)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
    }

    private var storeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // "All Stores" chip
                filterChip(
                    label: "All Stores",
                    isSelected: viewModel.selectedStore == nil,
                    action: { viewModel.selectedStore = nil }
                )

                ForEach(viewModel.availableStores, id: \.self) { store in
                    filterChip(
                        label: store,
                        isSelected: viewModel.selectedStore == store,
                        action: { viewModel.selectedStore = store }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                        .fill(isSelected ? DesignSystem.Colors.accentSecondary : DesignSystem.Colors.backgroundSecondary)
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.allItems.isEmpty {
            loadingState
        } else if viewModel.allItems.isEmpty && viewModel.shoppingLists.isEmpty {
            emptyState
        } else if viewModel.quickFilter == .wishList {
            wishListContent
        } else {
            catalogContent
        }
    }

    private var loadingState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading glass catalog...")
                .font(DesignSystem.Typography.listItemSubtitle)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text("No glass items")
                .font(DesignSystem.Typography.sectionTitle)
            Text("Your catalog is empty")
                .font(DesignSystem.Typography.listItemSubtitle)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var catalogContent: some View {
        Group {
            if viewModel.filteredItems.isEmpty && viewModel.hasActiveFilters {
                noResultsState
            } else {
                catalogList
            }
        }
    }

    private var wishListContent: some View {
        VStack(spacing: 0) {
            // Shopping mode header (when active)
            if isShoppingMode {
                shoppingModeHeader
            }

            // List content
            Group {
                if viewModel.filteredShoppingItems.isEmpty {
                    if viewModel.hasActiveFilters {
                        noResultsState
                    } else {
                        wishListEmptyState
                    }
                } else {
                    wishListList
                }
            }

            // Shopping mode button (when not in shopping mode and there are items)
            if !isShoppingMode && !viewModel.filteredShoppingItems.isEmpty {
                startShoppingButton
            }
        }
    }

    private var shoppingModeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("Shopping Mode")
                    .font(DesignSystem.Typography.listItemTitle)
                Text("\(basketItems.count) of \(viewModel.filteredShoppingItems.count) in basket")
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            Button("Cancel") {
                withAnimation {
                    isShoppingMode = false
                    basketItems.removeAll()
                    shoppingQuantities.removeAll()
                }
            }
            .foregroundColor(DesignSystem.Colors.accentDanger)

            Button("Checkout") {
                showingCheckoutSheet = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(basketItems.isEmpty)
        }
        .padding()
        .background(DesignSystem.Colors.backgroundSecondary)
    }

    private var startShoppingButton: some View {
        Button {
            withAnimation {
                isShoppingMode = true
                // Initialize quantities from shopping list items
                for item in viewModel.filteredShoppingItems {
                    shoppingQuantities[item.catalogItem.stable_id] = item.shoppingListItem.neededQuantity
                }
            }
        } label: {
            HStack {
                Image(systemName: "cart.fill")
                Text("Start Shopping")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.accentPrimary)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .padding()
    }

    private var noResultsState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text("No results")
                .font(DesignSystem.Typography.sectionTitle)
            Text(viewModel.emptyStateMessage)
                .font(DesignSystem.Typography.listItemSubtitle)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Clear Filters") {
                viewModel.clearAllFilters()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wishListEmptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "heart")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text("Your wish list is empty")
                .font(DesignSystem.Typography.sectionTitle)
            Text("Browse the catalog and add items you want to buy")
                .font(DesignSystem.Typography.listItemSubtitle)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Browse All Glass") {
                viewModel.quickFilter = .all
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Lists

    private var catalogList: some View {
        List {
            ForEach(viewModel.filteredItems, id: \.catalogItem.stable_id) { item in
                NavigationLink(value: GlassNavigationDestination.itemDetail(itemModel: item)) {
                    catalogRow(for: item)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                #if DEBUG
                .listRowBackground(
                    processedItemIds.contains(item.catalogItem.stable_id)
                        ? DesignSystem.Colors.accentSuccess.opacity(0.15)
                        : nil
                )
                #endif
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 80, for: .scrollContent)  // Space for tab bar
    }

    private var wishListList: some View {
        List {
            ForEach(viewModel.filteredShoppingItems, id: \.catalogItem.stable_id) { item in
                // Find the corresponding CompleteInventoryItemModel for navigation
                if let completeItem = viewModel.allItems.first(where: { $0.catalogItem.stable_id == item.catalogItem.stable_id }) {
                    NavigationLink(value: GlassNavigationDestination.itemDetail(itemModel: completeItem)) {
                        wishListRow(for: item)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } else {
                    wishListRow(for: item)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 80, for: .scrollContent)  // Space for tab bar
    }

    // MARK: - Row Views

    @ViewBuilder
    private func catalogRow(for item: CompleteInventoryItemModel) -> some View {
        // Use existing row view based on mode
        switch viewModel.quickFilter {
        case .all:
            // In "All" mode, show catalog row with status indicators
            let hasInventory = viewModel.inventoryItemIds.contains(item.catalogItem.stable_id)
            let onWishList = viewModel.shoppingListItemIds.contains(item.catalogItem.stable_id)
            GlassItemRowView.unified(item: item, hasInventory: hasInventory, onWishList: onWishList)
        case .myGlass:
            // In "My Glass" mode, show inventory row with quantities
            GlassItemRowView.inventory(item: item, selectedLocations: viewModel.selectedLocations)
        case .wishList:
            // This shouldn't happen in catalogRow
            GlassItemRowView.catalog(item: item)
        }
    }

    private func wishListRow(for item: DetailedShoppingListItemModel) -> some View {
        let stableId = item.catalogItem.stable_id
        let isInBasket = basketItems.contains(stableId)

        return GlassItemRowView.shoppingList(
            item: item,
            showStore: viewModel.selectedStore == nil,
            isShoppingMode: isShoppingMode,
            isInBasket: isInBasket,
            quantity: isShoppingMode ? Binding(
                get: { shoppingQuantities[stableId] ?? item.shoppingListItem.neededQuantity },
                set: { shoppingQuantities[stableId] = $0 }
            ) : nil,
            onBasketToggle: isShoppingMode ? {
                withAnimation {
                    if basketItems.contains(stableId) {
                        basketItems.remove(stableId)
                    } else {
                        basketItems.insert(stableId)
                    }
                }
            } : nil
        )
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(UnifiedGlassSortOption.allCases) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("glass_sort_button")
    }

    // MARK: - Context Menu (ellipsis)

    private var contextMenu: some View {
        Menu {
            // Context-specific actions based on current mode
            switch viewModel.quickFilter {
            case .myGlass:
                // Inventory actions
                Button {
                    showingAddInventory = true
                } label: {
                    Label("Add Inventory", systemImage: "plus")
                }

                Button {
                    showingQRScanner = true
                } label: {
                    Label("Scan QR Code", systemImage: "camera")
                }

                Divider()

                Button {
                    showingInventorySharing = true
                } label: {
                    Label("Inventory Sharing", systemImage: "person.2")
                }

                Button {
                    showingLabelDesigner = true
                } label: {
                    Label("Print Labels", systemImage: "qrcode")
                }
                .disabled(viewModel.filteredItems.isEmpty)

                Button {
                    showingManageLocations = true
                } label: {
                    Label("Manage Locations", systemImage: "archivebox")
                }

            case .wishList:
                // Shopping list actions
                Button {
                    showingAddShoppingItem = true
                } label: {
                    Label("Add to Shopping List", systemImage: "plus")
                }

                if !isShoppingMode {
                    Button {
                        isShoppingMode = true
                    } label: {
                        Label("Start Shopping", systemImage: "cart")
                    }
                }

            case .all:
                // All mode - show quick add options
                Button {
                    showingAddInventory = true
                } label: {
                    Label("Add Inventory", systemImage: "plus.circle")
                }

                Button {
                    showingAddShoppingItem = true
                } label: {
                    Label("Add to Shopping List", systemImage: "heart")
                }
            }

            Divider()

            // Always available
            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gear")
            }

            Button {
                showingHelp = true
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityIdentifier("supplies_menu")
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            List {
                // Sort section
                Section("Sort") {
                    ForEach(UnifiedGlassSortOption.allCases) { option in
                        Button {
                            viewModel.sortOption = option
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                Spacer()
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignSystem.Colors.accentPrimary)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                // Product type section
                Section("Product Type") {
                    ForEach(["glass", "coating", "tool"], id: \.self) { type in
                        filterToggleRow(
                            label: displayNameForProductType(type),
                            count: viewModel.productTypeCounts[type] ?? 0,
                            isSelected: viewModel.selectedProductTypes.contains(type),
                            action: {
                                if viewModel.selectedProductTypes.contains(type) {
                                    viewModel.selectedProductTypes.remove(type)
                                } else {
                                    viewModel.selectedProductTypes.insert(type)
                                }
                            }
                        )
                    }
                }

                // Manufacturer section
                Section("Manufacturer") {
                    NavigationLink {
                        manufacturerSelectionList
                    } label: {
                        HStack {
                            Text("Select Manufacturers")
                            Spacer()
                            if !viewModel.selectedManufacturers.isEmpty {
                                Text("\(viewModel.selectedManufacturers.count) selected")
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }

                // COE section
                Section("COE") {
                    NavigationLink {
                        coeSelectionList
                    } label: {
                        HStack {
                            Text("Select COEs")
                            Spacer()
                            if !viewModel.selectedCOEs.isEmpty {
                                Text("\(viewModel.selectedCOEs.count) selected")
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }

                // Clear all button
                Section {
                    Button("Clear All Filters") {
                        viewModel.clearAllFilters()
                    }
                    .foregroundColor(DesignSystem.Colors.accentDanger)
                    .disabled(!viewModel.hasActiveFilters)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingFilterSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func filterToggleRow(label: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                Spacer()
                Text("(\(count))")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textSecondary)
            }
        }
        .foregroundColor(.primary)
    }

    private var manufacturerSelectionList: some View {
        List {
            ForEach(viewModel.availableManufacturers, id: \.self) { mfr in
                Button {
                    if viewModel.selectedManufacturers.contains(mfr) {
                        viewModel.selectedManufacturers.remove(mfr)
                    } else {
                        viewModel.selectedManufacturers.insert(mfr)
                    }
                } label: {
                    HStack {
                        Text(GlassManufacturers.fullName(for: mfr) ?? mfr)
                        Spacer()
                        Text("(\(viewModel.manufacturerCounts[mfr] ?? 0))")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Image(systemName: viewModel.selectedManufacturers.contains(mfr) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.selectedManufacturers.contains(mfr) ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textSecondary)
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Manufacturers")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Clear") {
                    viewModel.selectedManufacturers.removeAll()
                }
                .disabled(viewModel.selectedManufacturers.isEmpty)
            }
        }
    }

    private var coeSelectionList: some View {
        List {
            ForEach(viewModel.allAvailableCOEs, id: \.self) { coe in
                Button {
                    if viewModel.selectedCOEs.contains(coe) {
                        viewModel.selectedCOEs.remove(coe)
                    } else {
                        viewModel.selectedCOEs.insert(coe)
                    }
                } label: {
                    HStack {
                        Text("COE \(coe)")
                        Spacer()
                        Text("(\(viewModel.coeCounts[coe] ?? 0))")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Image(systemName: viewModel.selectedCOEs.contains(coe) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.selectedCOEs.contains(coe) ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textSecondary)
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("COE")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Clear") {
                    viewModel.selectedCOEs.removeAll()
                }
                .disabled(viewModel.selectedCOEs.isEmpty)
            }
        }
    }

    // MARK: - Checkout Sheet

    private var checkoutSheet: some View {
        let basketItemsList = viewModel.filteredShoppingItems.filter { basketItems.contains($0.catalogItem.stable_id) }

        return UnifiedCheckoutSheet(
            basketItems: basketItemsList,
            quantities: shoppingQuantities,
            inventoryTrackingService: deps.inventoryTrackingService,
            shoppingListService: deps.shoppingListService,
            onComplete: {
                // Reset shopping mode
                isShoppingMode = false
                basketItems.removeAll()
                shoppingQuantities.removeAll()
                // Refresh data
                Task { await viewModel.refreshData() }
            },
            onCancel: {
                showingCheckoutSheet = false
            }
        )
    }

    // MARK: - Helpers

    private func displayNameForProductType(_ type: String) -> String {
        switch type.lowercased() {
        case "glass": return "Glass"
        case "coating": return "Coatings"
        case "tool": return "Tools"
        default: return type.capitalized
        }
    }

    #if DEBUG
    // MARK: - Processed Items (DEBUG)

    @MainActor
    private func loadProcessedItems() async {
        do {
            var allProcessedIds = Set<String>()

            // Check admin repository (CloudKit - manually set in app)
            let adminRepo = deps.catalogFlagAdminRepository
            let adminFlags = try await adminRepo.fetchAllFlags()
            let adminProcessed = adminFlags
                .filter { $0.flag_key == kProcessedKey && $0.flag_value }
                .map { $0.item_stable_id }
            allProcessedIds.formUnion(adminProcessed)

            // Check bundled repository (SQLite - imported from export)
            let bundledRepo = deps.catalogFlagBundledRepository
            let bundledFlags = try await bundledRepo.fetchAllFlags()
            let bundledProcessed = bundledFlags
                .filter { $0.flag_key == kProcessedKey && $0.flag_value }
                .map { $0.item_stable_id }
            allProcessedIds.formUnion(bundledProcessed)

            processedItemIds = allProcessedIds
        } catch {
            print("Error loading processed items: \(error)")
        }
    }
    #endif
}

// MARK: - Unified Checkout Sheet

/// Simplified checkout sheet for the unified glass view
private struct UnifiedCheckoutSheet: View {
    let basketItems: [DetailedShoppingListItemModel]
    let quantities: [String: Double]
    let inventoryTrackingService: InventoryTrackingService
    let shoppingListService: ShoppingListService
    let onComplete: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var addToInventory = true
    @State private var removeFromList = true
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Options
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Checkout Options")
                        .font(DesignSystem.Typography.listItemTitle)

                    Toggle("Add to inventory", isOn: $addToInventory)
                        .tint(.accentColor)

                    Toggle("Remove from wish list", isOn: $removeFromList)
                        .tint(.accentColor)
                }
                .padding()
                .background(DesignSystem.Colors.backgroundSecondary)

                // Items list
                List {
                    Section("Items (\(basketItems.count))") {
                        ForEach(basketItems, id: \.catalogItem.stable_id) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.catalogItem.name)
                                        .font(DesignSystem.Typography.listItemTitle)
                                    Text(item.catalogItem.manufacturer)
                                        .font(DesignSystem.Typography.listItemCaption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }

                                Spacer()

                                Text("\(Int(quantities[item.catalogItem.stable_id] ?? item.shoppingListItem.neededQuantity))")
                                    .font(DesignSystem.Typography.prominentNumber)
                                    .foregroundColor(DesignSystem.Colors.moltenOrange)
                            }
                        }
                    }
                }

                // Action buttons
                HStack(spacing: DesignSystem.Spacing.md) {
                    Button("Cancel") {
                        dismiss()
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .foregroundColor(.primary)
                    .cornerRadius(DesignSystem.CornerRadius.medium)

                    Button {
                        Task { await performCheckout() }
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Checkout")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignSystem.Colors.accentPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                    .disabled(isProcessing)
                }
                .padding()
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func performCheckout() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Add to inventory
            if addToInventory {
                for item in basketItems {
                    let quantity = quantities[item.catalogItem.stable_id] ?? item.shoppingListItem.neededQuantity
                    _ = try await inventoryTrackingService.addInventory(
                        quantity: quantity,
                        type: item.shoppingListItem.type ?? "rod",
                        toItem: item.catalogItem.stable_id
                    )
                }
            }

            // Remove from shopping list
            if removeFromList {
                for item in basketItems {
                    try await shoppingListService.shoppingListRepository.deleteItem(
                        forItem: item.catalogItem.stable_id
                    )
                }
            }

            await MainActor.run {
                dismiss()
                onComplete()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return UnifiedGlassView(deps: deps)
}
