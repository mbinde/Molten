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
}

/// Main tab view that provides navigation between the app's primary sections
struct MainTabView: View {
    @AppStorage("lastActiveTab") private var lastActiveTabRawValue = DefaultTab.catalog.rawValue
    @State private var selectedTab: DefaultTab = .catalog
    @State private var showingSettings = false
    @State private var showingProjectsMenu = false
    @State private var showingMoreMenu = false
    @State private var activeProjectType: ProjectViewType? = nil
    @State private var tabConfig = TabConfiguration.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Dependency Injection
    private let catalogService: CatalogService
    private let purchaseService: PurchaseRecordService?
    private let syncMonitor: CloudKitSyncMonitor?

    // Create additional services needed for other views
    private let inventoryTrackingService: InventoryTrackingService
    private let shoppingListService: ShoppingListService

    // MARK: - Computed Properties

    /// Determines if we should use compact layout (single Projects tab with menu)
    /// or expanded layout (separate Plans and Logs tabs)
    /// Uses device idiom to decide - iPhones use compact, iPads use expanded
    private var shouldUseCompactLayout: Bool {
        #if os(iOS)
        // Note: UIScreen.main deprecated in iOS 26.0
        // Use device idiom for layout decision instead
        // - iPhones: Use compact layout (single Projects tab with menu)
        // - iPads: Use expanded layout (separate Plans and Logs tabs)
        return UIDevice.current.userInterfaceIdiom != .pad
        #else
        // macOS always uses expanded layout
        return false
        #endif
    }

    /// Initialize MainTabView with dependency injection
    init(catalogService: CatalogService, purchaseService: PurchaseRecordService? = nil, syncMonitor: CloudKitSyncMonitor? = nil) {
        self.catalogService = catalogService
        self.purchaseService = purchaseService
        self.syncMonitor = syncMonitor
        self.inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        self.shoppingListService = RepositoryFactory.createShoppingListService()
    }
    
    private var lastActiveTab: DefaultTab {
        let savedTab = DefaultTab(rawValue: lastActiveTabRawValue) ?? .catalog

        // Ensure the saved tab is still available with current feature flags and layout mode
        return MainTabView.availableTabs(isCompact: shouldUseCompactLayout).contains(savedTab) ? savedTab : .catalog
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area - use ZStack with opacity to preserve view state
            ZStack {
                if selectedTab == .catalog || catalogHasBeenViewed {
                    CatalogView(catalogService: catalogService)
                        .opacity(selectedTab == .catalog ? 1 : 0)
                        .id("catalog-view")
                }

                if selectedTab == .inventory || inventoryHasBeenViewed {
                    InventoryView(
                        catalogService: catalogService,
                        inventoryTrackingService: inventoryTrackingService
                    )
                    .opacity(selectedTab == .inventory ? 1 : 0)
                    .id("inventory-view")
                }

                if selectedTab == .shopping || shoppingHasBeenViewed {
                    ShoppingListView(shoppingListService: shoppingListService)
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

                // Projects tab content - shown when in compact mode
                if shouldUseCompactLayout && selectedTab == .projects {
                    if let projectType = activeProjectType {
                        switch projectType {
                        case .plans:
                            if isProjectPlansEnabled {
                                ProjectsView()
                            } else {
                                featureDisabledPlaceholder(title: "Plans", icon: "pencil.and.list.clipboard")
                            }
                        case .logs:
                            if isLogbookEnabled {
                                LogbookView()
                            } else {
                                featureDisabledPlaceholder(title: "Logs", icon: "book.pages")
                            }
                        }
                    } else {
                        // Show placeholder when projects tab is selected but no project type chosen
                        EmptyView()
                    }
                }

                // Expanded mode: Show separate project tabs
                if !shouldUseCompactLayout {
                    if selectedTab == .projectPlans {
                        if isProjectPlansEnabled {
                            ProjectsView()
                        } else {
                            featureDisabledPlaceholder(title: "Plans", icon: "pencil.and.list.clipboard")
                        }
                    }

                    if selectedTab == .logbook {
                        if isLogbookEnabled {
                            LogbookView()
                        } else {
                            featureDisabledPlaceholder(title: "Logs", icon: "book.pages")
                        }
                    }
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
            CustomTabBar(
                selectedTab: $selectedTab,
                onTabTap: handleTabTap,
                isCompact: shouldUseCompactLayout,
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

                    // Special handling for Plans and Logbook in compact mode
                    if shouldUseCompactLayout && (tab == .projectPlans || tab == .logbook) {
                        // Switch to Projects tab and set the appropriate project type
                        selectedTab = .projects
                        activeProjectType = tab == .projectPlans ? .plans : .logs
                        return
                    }

                    // Mark tab as viewed
                    markTabAsViewed(tab)
                }
            )
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
        .sheet(isPresented: $showingProjectsMenu) {
            ProjectsMenuView(
                selectedProjectType: $activeProjectType,
                onDismiss: {
                    showingProjectsMenu = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            // Restore the last active tab on app launch (only once)
            if !hasRestoredTab {
                hasRestoredTab = true
                selectedTab = lastActiveTab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            showingSettings = true
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
            default: break
            }
        }
    }

    // Track which tabs have been viewed to keep them alive
    @State private var catalogHasBeenViewed = false
    @State private var inventoryHasBeenViewed = false
    @State private var shoppingHasBeenViewed = false
    @State private var purchasesHasBeenViewed = false
    @State private var hasRestoredTab = false
    
    // MARK: - Helper Functions

    /// Returns tabs that are available based on current feature flags and layout mode
    /// - Parameter isCompact: If true, returns compact layout tabs (with Projects menu).
    ///                        If false, returns expanded layout tabs (separate Plans/Logs tabs).
    static func availableTabs(isCompact: Bool = true) -> [DefaultTab] {
        return DefaultTab.allCases.filter { tab in
            switch tab {
            case .projects:
                // Only show combined Projects tab in compact mode
                return isCompact && (isProjectPlansEnabled || isLogbookEnabled)
            case .projectPlans:
                // Only show separate Plans tab in expanded mode
                return !isCompact && isProjectPlansEnabled
            case .logbook:
                // Only show separate Logs tab in expanded mode
                return !isCompact && isLogbookEnabled
            case .purchases:
                return isPurchaseRecordsEnabled // Show if enabled
            case .settings:
                return true // Allow Settings in tab bar if user customizes
            default:
                return true // Always show catalog, inventory, shopping
            }
        }
    }
    
    private func handleTabTap(_ tab: DefaultTab) {
        // Special handling for More tab - show the More menu
        if !tabConfig.tabBarTabs.contains(tab) && tabConfig.moreTabs.contains(tab) {
            showingMoreMenu = true
            return
        }

        // Only handle tabs that are currently available for current layout mode
        guard MainTabView.availableTabs(isCompact: shouldUseCompactLayout).contains(tab) else { return }

        // Special handling for Settings - show as sheet
        if tab == .settings {
            // Don't change selectedTab - just show Settings sheet over current tab
            // This prevents blank screen when sheet is dismissed
            showingSettings = true
            return
        }

        // Special handling for projects tab in compact mode - show menu
        if shouldUseCompactLayout && tab == .projects {
            if selectedTab == .projects && activeProjectType != nil {
                // Already on projects tab with a type selected - show menu to switch
                showingProjectsMenu = true
            } else {
                // First time tapping projects or switching to projects - show menu
                selectedTab = tab
                showingProjectsMenu = true
            }
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
    let isCompact: Bool
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

/// Projects menu shown when tapping the Projects tab
struct ProjectsMenuView: View {
    @Binding var selectedProjectType: ProjectViewType?
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach([ProjectViewType.plans, ProjectViewType.logs], id: \.displayName) { projectType in
                        Button {
                            selectedProjectType = projectType
                            dismiss()
                            onDismiss()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: projectType.systemImage)
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(projectType.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(projectType.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedProjectType == projectType {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("Choose Project Type")
                }
            }
            .navigationTitle("Projects")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    // Configure RepositoryFactory for preview
    RepositoryFactory.configureForTesting()

    // Create catalog service using new architecture
    let catalogService = RepositoryFactory.createCatalogService()

    return MainTabView(catalogService: catalogService)
}
