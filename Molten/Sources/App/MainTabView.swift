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
    static let shoppingListItemAdded = Notification.Name("shoppingListItemAdded")
    static let showSettings = Notification.Name("showSettings")
    static let navigateToShoppingListForStore = Notification.Name("navigateToShoppingListForStore")
    static let filterShoppingListByStore = Notification.Name("filterShoppingListByStore")
    static let navigateToInventorySharingWithCode = Notification.Name("navigateToInventorySharingWithCode")
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
    
    var body: some View {
        return VStack(spacing: 0) {
            // Main content area - use ZStack with opacity to preserve view state
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
                    if isPurchaseRecordsEnabled {
                        if let purchaseService = purchaseService {
                            PurchasesView(purchaseService: purchaseService)
                                .opacity(selectedTab == .purchases ? 1 : 0)
                                .id("purchases-view")
                        } else {
                            featureDisabledPlaceholder(title: "Purchase Records", icon: "cart.badge.plus")
                                .opacity(selectedTab == .purchases ? 1 : 0)
                        }
                    } else {
                        featureDisabledPlaceholder(title: "Purchase Records", icon: "cart.badge.plus")
                            .opacity(selectedTab == .purchases ? 1 : 0)
                    }
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
            .frame(maxHeight: .infinity)

            // Custom tab bar
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
                }
                )
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
        VStack(spacing: 0) {
            // Sync status indicator (shown at top of tab bar)
            if let syncMonitor = syncMonitor {
                CloudKitSyncStatusView(monitor: syncMonitor)
                    .padding(.horizontal, DesignSystem.Padding.standard)
                    .padding(.top, DesignSystem.Padding.compact)
            }

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
            .frame(height: 60)
        }
        .background(tabBarBackground)
        .overlay(topSeparator, alignment: .top)
    }
    
    private func tabButton(for tab: DefaultTab) -> some View {
        Button {
            onTabTap(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 22, weight: .medium))
                Text(tab.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(selectedTab == tab ? .primary : .secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selectionBackground(for: tab))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
            VStack(spacing: 4) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .medium))
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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
