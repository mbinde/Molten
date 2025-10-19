//
//  MainTabView.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isPurchaseRecordsEnabled = false
private let isProjectPlansEnabled = true
private let isProjectLogEnabled = true

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
    @State private var activeProjectType: ProjectViewType? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Dependency Injection
    private let catalogService: CatalogService
    private let purchaseService: PurchaseRecordService?

    // Create additional services needed for other views
    private let inventoryTrackingService: InventoryTrackingService
    private let shoppingListService: ShoppingListService

    // MARK: - Computed Properties

    /// Determines if we should use compact layout (single Projects tab with menu)
    /// or expanded layout (separate Plans and Logs tabs)
    /// Uses screen width to decide - even large iPhones can show separate tabs
    private var shouldUseCompactLayout: Bool {
        #if os(iOS)
        // Get screen width in points
        let screenWidth = UIScreen.main.bounds.width

        // Use expanded layout (separate tabs) if we have enough space
        // Standard iPhone widths:
        // - iPhone SE, 8, etc: 375pt
        // - iPhone 12, 13, 14: 390pt
        // - iPhone 14 Plus, 15 Plus: 430pt
        // - iPhone 14 Pro Max, 15 Pro Max: 430pt
        // - iPad Mini portrait: 744pt
        // - iPad portrait: 820pt+
        //
        // Threshold: 390pt (includes iPhone 12+ and larger)
        // This means even iPhone 14/15/16 in portrait will get separate tabs
        return screenWidth < 390
        #else
        // macOS always uses expanded layout
        return false
        #endif
    }

    /// Initialize MainTabView with dependency injection
    init(catalogService: CatalogService, purchaseService: PurchaseRecordService? = nil) {
        self.catalogService = catalogService
        self.purchaseService = purchaseService
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

                // Projects tab content - shown when in compact mode
                if shouldUseCompactLayout && selectedTab == .projects {
                    if let projectType = activeProjectType {
                        switch projectType {
                        case .plans:
                            if isProjectPlansEnabled {
                                ProjectPlansView()
                            } else {
                                featureDisabledPlaceholder(title: "Plans", icon: "pencil.and.list.clipboard")
                            }
                        case .logs:
                            if isProjectLogEnabled {
                                ProjectLogView()
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
                            ProjectPlansView()
                        } else {
                            featureDisabledPlaceholder(title: "Plans", icon: "pencil.and.list.clipboard")
                        }
                    }

                    if selectedTab == .projectLog {
                        if isProjectLogEnabled {
                            ProjectLogView()
                        } else {
                            featureDisabledPlaceholder(title: "Logs", icon: "book.pages")
                        }
                    }
                }

                // Legacy tabs (kept for backwards compatibility but not shown in tab bar)
                Group {
                    switch selectedTab {
                    case .purchases:
                        if isPurchaseRecordsEnabled {
                            if let purchaseService = purchaseService {
                                PurchasesView(purchaseService: purchaseService)
                            } else {
                                featureDisabledPlaceholder(title: "Purchase Records", icon: "cart.badge.plus")
                            }
                        } else {
                            featureDisabledPlaceholder(title: "Purchase Records", icon: "cart.badge.plus")
                        }
                    case .settings:
                        // Settings moved to top nav
                        EmptyView()
                    default:
                        EmptyView()
                    }
                }
            }

            // Custom tab bar
            CustomTabBar(
                selectedTab: $selectedTab,
                onTabTap: handleTabTap,
                isCompact: shouldUseCompactLayout
            )
        }
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
            // Restore the last active tab on app launch
            selectedTab = lastActiveTab
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            showingSettings = true
        }
        .onChange(of: selectedTab) { _, newTab in
            // Save the selected tab whenever it changes
            lastActiveTabRawValue = newTab.rawValue

            // Mark tabs as viewed so they stay alive
            switch newTab {
            case .catalog: catalogHasBeenViewed = true
            case .inventory: inventoryHasBeenViewed = true
            case .shopping: shoppingHasBeenViewed = true
            default: break
            }
        }
    }

    // Track which tabs have been viewed to keep them alive
    @State private var catalogHasBeenViewed = false
    @State private var inventoryHasBeenViewed = false
    @State private var shoppingHasBeenViewed = false
    
    // MARK: - Helper Functions

    /// Returns tabs that are available based on current feature flags and layout mode
    /// - Parameter isCompact: If true, returns compact layout tabs (with Projects menu).
    ///                        If false, returns expanded layout tabs (separate Plans/Logs tabs).
    static func availableTabs(isCompact: Bool = true) -> [DefaultTab] {
        return DefaultTab.allCases.filter { tab in
            switch tab {
            case .projects:
                // Only show combined Projects tab in compact mode
                return isCompact && (isProjectPlansEnabled || isProjectLogEnabled)
            case .projectPlans:
                // Only show separate Plans tab in expanded mode
                return !isCompact && isProjectPlansEnabled
            case .projectLog:
                // Only show separate Logs tab in expanded mode
                return !isCompact && isProjectLogEnabled
            case .purchases:
                return false // Disabled - purchases moved to inventory/shopping
            case .settings:
                return false // Settings moved to top nav, not in tab bar
            default:
                return true // Always show catalog, inventory, shopping
            }
        }
    }
    
    private func handleTabTap(_ tab: DefaultTab) {
        // Only handle tabs that are currently available for current layout mode
        guard MainTabView.availableTabs(isCompact: shouldUseCompactLayout).contains(tab) else { return }

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

    // Filter tabs based on feature flags and layout mode
    private var availableTabs: [DefaultTab] {
        MainTabView.availableTabs(isCompact: isCompact)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(availableTabs, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .frame(height: 60)
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
