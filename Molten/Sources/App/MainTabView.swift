//
//  MainTabView.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isPurchaseRecordsEnabled = true
private let isProjectPlansEnabled = true
private let isLogbookEnabled = true
private let isRecipesEnabled = true

/// Notification names for tab interactions
extension Notification.Name {
    static let clearCatalogSearch = Notification.Name("clearCatalogSearch")
    static let clearInventorySearch = Notification.Name("clearInventorySearch")
    static let clearPurchasesSearch = Notification.Name("clearPurchasesSearch")
    static let resetCatalogNavigation = Notification.Name("resetCatalogNavigation")
    static let resetInventoryNavigation = Notification.Name("resetInventoryNavigation")
    static let resetPurchasesNavigation = Notification.Name("resetPurchasesNavigation")
    static let inventoryItemAdded = Notification.Name("inventoryItemAdded")
    static let inventoryChanged = Notification.Name("inventoryChanged")  // Posted when QR scan modifies inventory
    static let shoppingListItemAdded = Notification.Name("shoppingListItemAdded")
    static let showSettings = Notification.Name("showSettings")
    static let navigateToShoppingListForStore = Notification.Name("navigateToShoppingListForStore")
    static let filterShoppingListByStore = Notification.Name("filterShoppingListByStore")
    static let navigateToInventorySharingWithCode = Notification.Name("navigateToInventorySharingWithCode")
    static let openMoltenDeepLink = Notification.Name("openMoltenDeepLink")
    static let applyGlobalSearch = Notification.Name("applyGlobalSearch")
    static let navigateToItemDetail = Notification.Name("navigateToItemDetail")
    static let catalogDetailDismissed = Notification.Name("catalogDetailDismissed")
    static let showCatalogFilters = Notification.Name("showCatalogFilters")
    static let catalogFilterCountChanged = Notification.Name("catalogFilterCountChanged")
    static let showInventoryFilters = Notification.Name("showInventoryFilters")
    static let inventoryFilterCountChanged = Notification.Name("inventoryFilterCountChanged")
    static let showShoppingFilters = Notification.Name("showShoppingFilters")
    static let shoppingFilterCountChanged = Notification.Name("shoppingFilterCountChanged")
    static let applyInventorySearch = Notification.Name("applyInventorySearch")
    static let applyShoppingSearch = Notification.Name("applyShoppingSearch")
}

/// Main tab view that provides navigation between the app's primary sections
struct MainTabView: View {
    @AppStorage("lastActiveTab") private var lastActiveTabRawValue = DefaultTab.catalog.rawValue
    @State private var selectedTab: DefaultTab = .catalog
    @State private var showingMoreMenu = false
    @State private var showingTabCustomization = false
    @State private var showingSearch = false
    @State private var globalSearchText = ""
    @State private var searchBarExpanded = false  // Stage 1: bar visible but not focused
    @State private var selectedItemForDetail: CompleteInventoryItemModel?
    @State private var returnToSearchAfterDetail = false  // Track if we should reopen search after back
    @State private var catalogActiveFilterCount = 0  // Track active filter count for badge
    @State private var inventoryActiveFilterCount = 0  // Track active filter count for badge
    @State private var shoppingActiveFilterCount = 0  // Track active filter count for badge
    @State private var tabConfig: TabConfiguration? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appDependencies) private var dependencies

    // MARK: - Dependency Injection
    private let deps: AppDependencies
    private let catalogService: CatalogService
    private let purchaseService: PurchaseRecordService?
    private let syncMonitor: CloudKitSyncMonitor?

    // Create additional services needed for other views
    private let inventoryTrackingService: InventoryTrackingService
    private let shoppingListService: ShoppingListService
    private let kilnScheduleService: KilnScheduleService

    /// Initialize MainTabView with dependency injection
    init(
        deps: AppDependencies,
        catalogService: CatalogService,
        purchaseService: PurchaseRecordService? = nil,
        inventoryService: InventoryTrackingService,
        shoppingListService: ShoppingListService,
        kilnScheduleService: KilnScheduleService,
        syncMonitor: CloudKitSyncMonitor? = nil
    ) {
        self.deps = deps
        self.catalogService = catalogService
        self.purchaseService = purchaseService
        self.inventoryTrackingService = inventoryService
        self.shoppingListService = shoppingListService
        self.kilnScheduleService = kilnScheduleService
        self.syncMonitor = syncMonitor
    }
    
    private var lastActiveTab: DefaultTab {
        let savedTab = DefaultTab(rawValue: lastActiveTabRawValue) ?? .catalog

        // Ensure the saved tab is still available with current feature flags
        return MainTabView.availableTabs().contains(savedTab) ? savedTab : .catalog
    }

    /// Determine search scope based on current tab
    private var searchScopeForCurrentTab: GlobalSearchScope {
        switch selectedTab {
        case .inventory:
            return .inventory
        case .shopping:
            return .shopping
        default:
            return .catalog
        }
    }

    /// Returns the active filter count for the currently selected tab
    private var activeFilterCountForCurrentTab: Int {
        switch selectedTab {
        case .catalog: return catalogActiveFilterCount
        case .inventory: return inventoryActiveFilterCount
        case .shopping: return shoppingActiveFilterCount
        default: return 0
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content area - extends under tab bar
            Group {
                switch selectedTab {
                case .catalog:
                    CatalogView(deps: deps)
                case .inventory:
                    InventoryView(deps: deps)
                case .shopping:
                    ShoppingListView(deps: deps)
                case .purchases:
                    PurchasesView()
                case .settings:
                    SettingsView()
                case .locations:
                    LocationsView(viewModel: LocationsViewModel(
                        locationService: dependencies.unifiedLocationService
                    ))
                case .projects, .projectPlans:
                    ProjectsView()
                case .logbook:
                    LogbookView(logbookRepository: dependencies.logbookRepository)
                case .recipes:
                    RecipesView()
                case .kilnSchedules:
                    KilnSchedulesView(kilnScheduleService: kilnScheduleService)
                }
            }

            // Tab bar with glass effect overlaying content
            if searchBarExpanded {
                // State 2: Search bar expanded (collapsed tabs)
                ExpandedSearchBar(
                    searchText: globalSearchText,
                    onTap: {
                        // Go to state 3: open search sheet
                        showingSearch = true
                    },
                    onCollapse: {
                        // Go back to state 1: full tabs
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchBarExpanded = false
                        }
                    },
                    onClear: {
                        // Clear search and collapse the bar
                        globalSearchText = ""
                        NotificationCenter.default.post(
                            name: .applyGlobalSearch,
                            object: nil,
                            userInfo: ["searchText": ""]
                        )
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchBarExpanded = false
                        }
                    }
                )
            } else {
                // State 1: Full tab bar with floating filter and search buttons
                ZStack(alignment: .bottom) {
                    // Floating buttons anchored to screen edges
                    HStack {
                        // Floating filter button (left side) - show on Catalog, Inventory, Shopping tabs
                        if selectedTab == .catalog || selectedTab == .inventory || selectedTab == .shopping {
                            Button {
                                switch selectedTab {
                                case .catalog:
                                    NotificationCenter.default.post(name: .showCatalogFilters, object: nil)
                                case .inventory:
                                    NotificationCenter.default.post(name: .showInventoryFilters, object: nil)
                                case .shopping:
                                    NotificationCenter.default.post(name: .showShoppingFilters, object: nil)
                                default:
                                    break
                                }
                            } label: {
                                ZStack(alignment: .topLeading) {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 52, height: 52)
                                        .background(
                                            Circle()
                                                .fill(DesignSystem.Colors.accentSecondary)
                                        )
                                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                                    // Badge showing active filter count
                                    if activeFilterCountForCurrentTab > 0 {
                                        Text("\(activeFilterCountForCurrentTab)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(minWidth: 18, minHeight: 18)
                                            .background(
                                                Circle()
                                                    .fill(DesignSystem.Colors.accentPrimary)
                                            )
                                            .offset(x: -4, y: -4)
                                    }
                                }
                            }
                        }

                        Spacer()

                        // Floating search button (right side) - on Catalog, Inventory, Shopping tabs
                        if selectedTab == .catalog || selectedTab == .inventory || selectedTab == .shopping {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    searchBarExpanded = true
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 52)
                                    .background(
                                        Circle()
                                            .fill(DesignSystem.Colors.accentPrimary)
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 76)  // Position above tab bar
                    .allowsHitTesting(true)

                    // Dynamic tab bar based on TabConfiguration
                    HStack(spacing: 4) {
                        if let config = tabConfig {
                            ForEach(config.tabBarTabs, id: \.self) { tab in
                                tabBarButton(for: tab)
                            }
                        }
                        moreTabButton
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 61)  // 49 * 1.25 = ~61
                    .background(
                        RoundedRectangle(cornerRadius: 31)
                            .fill(Color(.systemBackground).opacity(0.95))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 31))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                    .padding(.bottom, 8)
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            GlobalSearchOverlay(
                isPresented: $showingSearch,
                deps: deps,
                initialSearchText: globalSearchText,
                searchScope: searchScopeForCurrentTab,
                onSearchSubmit: { searchText in
                    globalSearchText = searchText
                    // Post notification to apply search filter to current tab
                    let notificationName: Notification.Name
                    switch selectedTab {
                    case .inventory:
                        notificationName = .applyInventorySearch
                    case .shopping:
                        notificationName = .applyShoppingSearch
                    default:
                        selectedTab = .catalog
                        notificationName = .applyGlobalSearch
                    }
                    NotificationCenter.default.post(
                        name: notificationName,
                        object: nil,
                        userInfo: ["searchText": searchText]
                    )
                },
                onItemSelected: { item in
                    // Navigate to catalog tab and show detail for this item
                    selectedTab = .catalog
                    selectedItemForDetail = item
                    returnToSearchAfterDetail = true  // Remember to reopen search when back is pressed
                    // Post notification to navigate to item detail
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(
                            name: .navigateToItemDetail,
                            object: nil,
                            userInfo: ["item": item]
                        )
                    }
                }
            )
        }
        .sheet(isPresented: $showingTabCustomization) {
            NavigationStack {
                TabCustomizationView()
            }
        }
        .background(DesignSystem.Colors.background)
        .preferredColorScheme(UserSettings.shared.colorScheme)
        .onAppear {
            // Initialize tab configuration (only once, on MainActor)
            if tabConfig == nil {
                tabConfig = TabConfiguration.shared
            }

            // Restore the last active tab on app launch (only once)
            if !hasRestoredTab {
                hasRestoredTab = true
                selectedTab = lastActiveTab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            selectedTab = .settings
            markTabAsViewed(.settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .catalogDetailDismissed)) { _ in
            // When back is pressed from detail view, reopen search if we came from search
            if returnToSearchAfterDetail {
                returnToSearchAfterDetail = false
                showingSearch = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToShoppingListForStore)) { notification in
            // Switch to shopping tab and filter by store
            if let storeName = notification.userInfo?["storeName"] as? String {
                selectedTab = .shopping
                markTabAsViewed(.shopping)

                // Post notification to filter shopping list by store
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(
                        name: .filterShoppingListByStore,
                        object: nil,
                        userInfo: ["storeName": storeName]
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToInventorySharingWithCode)) { notification in
            // Switch to inventory tab and trigger sharing view with pre-filled code
            selectedTab = .inventory
            markTabAsViewed(.inventory)

            // Forward notification to InventoryView to show sharing sheet
            // The notification is already posted, InventoryView will receive it
        }
        .onReceive(NotificationCenter.default.publisher(for: .catalogFilterCountChanged)) { notification in
            // Update the badge count when filters change
            if let count = notification.userInfo?["count"] as? Int {
                catalogActiveFilterCount = count
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryFilterCountChanged)) { notification in
            if let count = notification.userInfo?["count"] as? Int {
                inventoryActiveFilterCount = count
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shoppingFilterCountChanged)) { notification in
            if let count = notification.userInfo?["count"] as? Int {
                shoppingActiveFilterCount = count
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            // Save the selected tab whenever it changes (but only if it actually changed)
            if oldTab != newTab {
                lastActiveTabRawValue = newTab.rawValue
            }

            // Mark tabs as viewed so they stay alive
            switch newTab {
            case .catalog: catalogHasBeenViewed = true
            case .inventory: inventoryHasBeenViewed = true
            case .shopping: shoppingHasBeenViewed = true
            case .purchases: purchasesHasBeenViewed = true
            case .locations: locationsHasBeenViewed = true
            case .kilnSchedules: kilnSchedulesHasBeenViewed = true
            case .recipes: recipesHasBeenViewed = true
            default: break
            }
        }
    }

    // Track which tabs have been viewed to keep them alive
    @State private var catalogHasBeenViewed = false
    @State private var inventoryHasBeenViewed = false
    @State private var shoppingHasBeenViewed = false
    @State private var purchasesHasBeenViewed = false
    @State private var locationsHasBeenViewed = false
    @State private var kilnSchedulesHasBeenViewed = false
    @State private var recipesHasBeenViewed = false
    @State private var hasRestoredTab = false
    
    // MARK: - Helper Functions

    /// Returns tabs that are available based on current feature flags
    static func availableTabs() -> [DefaultTab] {
        return DefaultTab.allCases.filter { tab in
            switch tab {
            case .projects:
                // Legacy combined Projects tab - check feature flag
                return FeatureFlags.ENABLE_PROJECTS
            case .projectPlans:
                return isProjectPlansEnabled && FeatureFlags.ENABLE_PROJECTS
            case .logbook:
                return isLogbookEnabled && FeatureFlags.ENABLE_PROJECTS
            case .recipes:
                return isRecipesEnabled && FeatureFlags.ENABLE_RECIPES
            case .purchases:
                return isPurchaseRecordsEnabled && FeatureFlags.ENABLE_PURCHASES
            case .kilnSchedules:
                return FeatureFlags.ENABLE_KILN_SCHEDULES
            case .settings:
                return true // Allow Settings in tab bar if user customizes
            default:
                return true // Always show catalog, inventory, shopping
            }
        }
    }
    
    private func handleTabTap(_ tab: DefaultTab) {
        // Ensure tabConfig is loaded
        guard let config = tabConfig else {
            print("⚠️ MainTabView: handleTabTap called but tabConfig not yet loaded")
            return
        }

        // Special handling for More tab - show the More menu
        if !config.tabBarTabs.contains(tab) && config.moreTabs.contains(tab) {
            showingMoreMenu = true
            return
        }

        // Only handle tabs that are currently available
        guard MainTabView.availableTabs().contains(tab) else { return }

        if selectedTab == tab {
            // Same tab tapped, reset navigation only (preserve search state)
            switch tab {
            case .catalog:
                NotificationCenter.default.post(name: .resetCatalogNavigation, object: nil)
            case .inventory:
                NotificationCenter.default.post(name: .resetInventoryNavigation, object: nil)
            case .purchases:
                NotificationCenter.default.post(name: .resetPurchasesNavigation, object: nil)
            default:
                break
            }
        } else {
            selectedTab = tab
            markTabAsViewed(tab)
        }
    }

    private func markTabAsViewed(_ tab: DefaultTab) {
        // Mark tabs as viewed so they stay alive
        switch tab {
        case .catalog: catalogHasBeenViewed = true
        case .inventory: inventoryHasBeenViewed = true
        case .shopping: shoppingHasBeenViewed = true
        case .purchases: purchasesHasBeenViewed = true
        case .locations: locationsHasBeenViewed = true
        case .kilnSchedules: kilnSchedulesHasBeenViewed = true
        case .recipes: recipesHasBeenViewed = true
        default: break
        }
    }

    // MARK: - Tab Bar Button

    private func tabBarButton(for tab: DefaultTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            handleTabTap(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 25))  // 20 * 1.25 = 25
                Text(tab.displayName)
                    .font(.caption)  // Slightly larger than caption2
            }
            .foregroundColor(isSelected ? DesignSystem.Colors.accentPrimary : .primary)
            .frame(width: 76, height: 53)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? DesignSystem.Colors.accentPrimary.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - More Tab Button

    private var moreTabButton: some View {
        Menu {
            // Show all tabs that are in the More menu according to config
            if let config = tabConfig {
                ForEach(config.moreTabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        markTabAsViewed(tab)
                    } label: {
                        Label(tab.displayName, systemImage: tab.systemImage)
                            .font(.title3)
                    }
                }
            }

            Divider()

            Button {
                showingTabCustomization = true
            } label: {
                Label("Customize Tabs", systemImage: "square.grid.2x2")
                    .font(.title3)
            }
        } label: {
            let isSelected = tabConfig?.moreTabs.contains(selectedTab) == true
            VStack(spacing: 3) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 25))  // 20 * 1.25 = 25
                Text("More")
                    .font(.caption)  // Slightly larger than caption2
            }
            .foregroundColor(isSelected ? DesignSystem.Colors.accentPrimary : .primary)
            .frame(width: 76, height: 53)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? DesignSystem.Colors.accentPrimary.opacity(0.15) : Color.clear)
            )
        }
    }

    // MARK: - Feature Disabled Placeholder
    
    private func featureDisabledPlaceholder(title: String, icon: String) -> some View {
        NavigationStack {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 80))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text("Available in future update")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Text("This feature is temporarily disabled in the current release. It will be available in a future version of the app.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: DefaultTab
    let onTabTap: (DefaultTab) -> Void
    let syncMonitor: CloudKitSyncMonitor?
    var tabConfig: TabConfiguration
    @Binding var showingMoreMenu: Bool
    let onMoreTabSelect: (DefaultTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Show tabs from configuration
            ForEach(tabConfig.tabBarTabs, id: \.self) { tab in
                tabButton(for: tab)
            }

            // Show More button if needed
            if tabConfig.needsMoreTab {
                moreButton
            }
        }
        .frame(height: 49)
        .background(
            tabBarBackground
                .ignoresSafeArea()
        )
        .overlay(topSeparator, alignment: .top)
    }
    
    private func tabButton(for tab: DefaultTab) -> some View {
        Button {
            onTabTap(tab)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 20, weight: .medium))
                Text(tab.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(selectedTab == tab ? .primary : .secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selectionBackground(for: tab))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
    
    private func selectionBackground(for tab: DefaultTab) -> some View {
        Group {
            if selectedTab == tab {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.3))
                    .opacity(0.8)
            } else {
                Color.clear
            }
        }
    }

    private var moreButton: some View {
        Button {
            showingMoreMenu = true
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .medium))
                Text("More")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(tabConfig.moreTabs.contains(selectedTab) ? .primary : .secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if tabConfig.moreTabs.contains(selectedTab) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.3))
                        .opacity(0.8)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingMoreMenu, arrowEdge: .bottom) {
            MoreTabView(
                selectedTab: $selectedTab,
                config: tabConfig,
                onTabSelect: onMoreTabSelect
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private var tabBarBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.1), radius: 0.5, x: 0, y: -0.5)
    }
    
    private var topSeparator: some View {
        Rectangle()
            .frame(height: 0.33)
            .foregroundColor(Color.gray.opacity(0.3))
            .opacity(0.6)
    }
}

// MARK: - Expanded Search Bar (State 2)

/// Search bar that replaces the tab bar when expanded
/// Tapping it opens the full search sheet (State 3)
struct ExpandedSearchBar: View {
    let searchText: String
    let onTap: () -> Void
    let onCollapse: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App icon - tap to expand tabs
            Button(action: onCollapse) {
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Search bar - tap to open search sheet
            Button(action: onTap) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    if searchText.isEmpty {
                        Text("Search catalog...")
                            .foregroundColor(.secondary)
                    } else {
                        Text(searchText)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // Always show X button to dismiss/clear
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    // Use test dependencies for preview
    let deps = AppDependencies(persistenceController: .createTestController())

    MainTabView(
        deps: deps,
        catalogService: deps.catalogService,
        inventoryService: deps.inventoryTrackingService,
        shoppingListService: deps.shoppingListService,
        kilnScheduleService: deps.kilnScheduleService
    )
}
