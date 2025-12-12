//
//  MainTabView.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI

// MARK: - Release Configuration
// Set to false for simplified release builds
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
    static let globalSearchTextChanged = Notification.Name("globalSearchTextChanged")
}

/// Main tab view that provides navigation between the app's primary sections
struct MainTabView: View {
    @AppStorage("lastActiveTab") private var lastActiveTabRawValue = DefaultTab.catalog.rawValue
    @State private var selectedTab: DefaultTab = .catalog
    @State private var showingSettings = false
    @State private var showingMoreMenu = false
    @State private var tabConfig: TabConfiguration? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appDependencies) private var dependencies

    // Search state (managed at MainTabView level so it can affect content)
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var showSearchOverlay = false
    @FocusState private var isSearchFocused: Bool

    // MARK: - Dependency Injection
    private let deps: AppDependencies
    private let catalogService: CatalogService
    private let syncMonitor: CloudKitSyncMonitor?

    // Create additional services needed for other views
    private let inventoryTrackingService: InventoryTrackingService
    private let shoppingListService: ShoppingListService
    private let kilnScheduleService: KilnScheduleService

    /// Initialize MainTabView with dependency injection
    init(
        deps: AppDependencies,
        catalogService: CatalogService,
        inventoryService: InventoryTrackingService,
        shoppingListService: ShoppingListService,
        kilnScheduleService: KilnScheduleService,
        syncMonitor: CloudKitSyncMonitor? = nil
    ) {
        self.deps = deps
        self.catalogService = catalogService
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
    
    var body: some View {
        ZStack {
            // Main content area - use ZStack with opacity to preserve view state
            VStack(spacing: 0) {
                ZStack {
                if selectedTab == .catalog || catalogHasBeenViewed {
                    CatalogView(deps: deps)
                        .opacity(selectedTab == .catalog ? 1 : 0)
                        .id("catalog-view")
                }

                if selectedTab == .inventory || inventoryHasBeenViewed {
                    InventoryView(deps: deps)
                    .opacity(selectedTab == .inventory ? 1 : 0)
                    .id("inventory-view")
                }

                if selectedTab == .shopping || shoppingHasBeenViewed {
                    ShoppingListView(deps: deps)
                        .opacity(selectedTab == .shopping ? 1 : 0)
                        .id("shopping-view")
                }

                if selectedTab == .purchases || purchasesHasBeenViewed {
                    PurchasesView()
                        .opacity(selectedTab == .purchases ? 1 : 0)
                        .id("purchases-view")
                }

                // Project Plans tab
                if selectedTab == .projectPlans {
                    if isProjectPlansEnabled {
                        ProjectsView()
                    } else {
                        featureDisabledPlaceholder(title: "Plans", icon: "pencil.and.list.clipboard")
                    }
                }

                // Logbook tab
                if selectedTab == .logbook {
                    if isLogbookEnabled {
                        LogbookView(logbookRepository: dependencies.logbookRepository)
                    } else {
                        featureDisabledPlaceholder(title: "Logs", icon: "book.pages")
                    }
                }

                // Recipes tab
                if selectedTab == .recipes || recipesHasBeenViewed {
                    if isRecipesEnabled {
                        RecipesView()
                            .opacity(selectedTab == .recipes ? 1 : 0)
                            .id("recipes-view")
                    } else {
                        featureDisabledPlaceholder(title: "Recipes", icon: "book.closed")
                            .opacity(selectedTab == .recipes ? 1 : 0)
                    }
                }

                // Locations tab (stores, classes, workshops)
                if selectedTab == .locations || locationsHasBeenViewed {
                    LocationsView(viewModel: LocationsViewModel(
                        locationService: dependencies.unifiedLocationService
                    ))
                    .opacity(selectedTab == .locations ? 1 : 0)
                    .id("locations-view")
                }

                // Kiln Schedules tab
                if selectedTab == .kilnSchedules || kilnSchedulesHasBeenViewed {
                    KilnSchedulesView(kilnScheduleService: kilnScheduleService)
                        .opacity(selectedTab == .kilnSchedules ? 1 : 0)
                        .id("kiln-schedules-view")
                }

                // Legacy tabs (kept for backwards compatibility but not shown in tab bar)
                Group {
                    switch selectedTab {
                    case .settings:
                        // Settings moved to top nav
                        EmptyView()
                    default:
                        EmptyView()
                    }
                }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Custom tab bar overlaid at bottom
            VStack {
                Spacer()
                if let tabConfig = tabConfig {
                    CustomTabBar(
                        selectedTab: $selectedTab,
                        onTabTap: handleTabTap,
                        syncMonitor: syncMonitor,
                        tabConfig: tabConfig,
                        showingMoreMenu: $showingMoreMenu,
                        onMoreTabSelect: { tab in
                            showingMoreMenu = false

                            // Special handling for Settings - show as sheet
                            if tab == .settings {
                                showingSettings = true
                                return
                            }

                            // Select the tab directly
                            selectedTab = tab
                            markTabAsViewed(tab)
                        },
                        isSearchActive: $isSearchActive,
                        searchText: $searchText,
                        showSearchOverlay: $showSearchOverlay,
                        onSearchSubmit: {
                            // Dismiss keyboard and close overlay when search is submitted
                            isSearchFocused = false
                            showSearchOverlay = false
                        }
                    )
                }
            }

            // Full-screen search overlay (shown when user taps on the search field)
            if showSearchOverlay {
                SearchOverlayView(
                    searchText: $searchText,
                    isSearchFocused: $isSearchFocused,
                    onDismiss: {
                        showSearchOverlay = false
                    },
                    onSubmit: {
                        isSearchFocused = false
                        showSearchOverlay = false
                    }
                )
                .transition(.opacity)
            }
        }
        .background(DesignSystem.Colors.background)
        .preferredColorScheme(UserSettings.shared.colorScheme)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingSettings = false
                            }
                        }
                    }
            }
        }
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
            showingSettings = true
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
        .onChange(of: searchText) { _, newValue in
            // Broadcast search text changes to the active tab
            NotificationCenter.default.post(
                name: .globalSearchTextChanged,
                object: nil,
                userInfo: ["searchText": newValue, "isActive": isSearchActive]
            )
        }
        .onChange(of: isSearchActive) { _, newValue in
            // Notify child views when search state changes
            NotificationCenter.default.post(
                name: .globalSearchTextChanged,
                object: nil,
                userInfo: ["searchText": newValue ? searchText : "", "isActive": newValue]
            )
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
                return FeatureFlags.ENABLE_PURCHASES
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

        // Special handling for Settings - show as sheet
        if tab == .settings {
            // Don't change selectedTab - just show Settings sheet over current tab
            // This prevents blank screen when sheet is dismissed
            showingSettings = true
            return
        }

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
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text("Available in future update")
                        .font(.title3)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Text("This feature is temporarily disabled in the current release. It will be available in a future version of the app.")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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

    // Search state
    @Binding var isSearchActive: Bool
    @Binding var searchText: String
    @Binding var showSearchOverlay: Bool
    let onSearchSubmit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if isSearchActive {
                // Collapsed state: show only first tab icon + expanded search bar
                collapsedTabButton
                expandedSearchBar
            } else {
                // Normal state: show all tabs + search FAB
                ForEach(tabConfig.tabBarTabs, id: \.self) { tab in
                    tabButton(for: tab)
                }

                if tabConfig.needsMoreTab {
                    moreButton
                }

                searchFAB
            }
        }
        .frame(height: 49)
        .background(
            tabBarBackground
                .ignoresSafeArea()
        )
        .overlay(topSeparator, alignment: .top)
        .animation(.easeInOut(duration: 0.25), value: isSearchActive)
    }

    // MARK: - Collapsed Tab Button (when search is active)

    private var collapsedTabButton: some View {
        Button {
            // When tapped in search mode, collapse search and return to tab
            withAnimation(.easeInOut(duration: 0.25)) {
                isSearchActive = false
                searchText = ""
            }
        } label: {
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 50, height: 49)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Search Bar (when search is active but not typing)

    private var expandedSearchBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Tappable search field that opens full search overlay
            Button {
                showSearchOverlay = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .font(.system(size: 16))

                    Text(searchText.isEmpty ? "Search catalog..." : searchText)
                        .foregroundColor(searchText.isEmpty ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !searchText.isEmpty {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.system(size: 16))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            }
            .buttonStyle(.plain)

            // Close button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearchActive = false
                    searchText = ""
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.trailing, DesignSystem.Spacing.sm)
    }

    // MARK: - Search FAB (when search is NOT active)

    private var searchFAB: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isSearchActive = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accentPrimary)
                    .frame(width: 44, height: 44)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .accessibilityLabel("Search")
        .accessibilityIdentifier("tab_bar_search_button")
    }
    
    private func tabButton(for tab: DefaultTab) -> some View {
        Button {
            onTabTap(tab)
        } label: {
            VStack(spacing: tabConfig.showTabLabels ? 2 : 0) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: tabConfig.showTabLabels ? 20 : 24, weight: .medium))
                if tabConfig.showTabLabels {
                    Text(tab.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
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
            VStack(spacing: tabConfig.showTabLabels ? 2 : 0) {
                Image(systemName: "ellipsis")
                    .font(.system(size: tabConfig.showTabLabels ? 20 : 24, weight: .medium))
                if tabConfig.showTabLabels {
                    Text("More")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
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

// MARK: - Search Overlay View

/// Full-screen search overlay that appears when user taps on the search field
/// Similar to App Store search experience
struct SearchOverlayView: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let onDismiss: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search bar at top
            HStack(spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .font(.system(size: 16))

                    TextField("Search catalog...", text: $searchText)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            onSubmit()
                        }
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm + 2)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))

                Button("Cancel") {
                    onDismiss()
                }
                .foregroundColor(DesignSystem.Colors.accentPrimary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.sm)

            Divider()

            // Search suggestions / results area
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Show search suggestions when typing
                    if !searchText.isEmpty {
                        // This area will show filtered results from the catalog
                        // The actual results are shown in the CatalogView below
                        Text("Searching for \"\(searchText)\"...")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.lg)
                    } else {
                        // Empty state - prompt to search
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))

                            Text("Search colors, codes, manufacturers...")
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
            }

            Spacer()
        }
        .background(DesignSystem.Colors.background)
        .onAppear {
            // Auto-focus the search field when overlay appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
}
