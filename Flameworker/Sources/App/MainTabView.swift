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
}

/// Main tab view that provides navigation between the app's primary sections
struct MainTabView: View {
    @AppStorage("lastActiveTab") private var lastActiveTabRawValue = DefaultTab.catalog.rawValue
    @State private var selectedTab: DefaultTab = .catalog
    
    // MARK: - Dependency Injection
    private let catalogService: CatalogService
    private let purchaseService: PurchaseRecordService?

    // Create additional services needed for other views
    private let inventoryTrackingService: InventoryTrackingService
    private let shoppingListService: ShoppingListService

    /// Initialize MainTabView with dependency injection
    init(catalogService: CatalogService, purchaseService: PurchaseRecordService? = nil) {
        self.catalogService = catalogService
        self.purchaseService = purchaseService
        self.inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        self.shoppingListService = RepositoryFactory.createShoppingListService()
    }
    
    private var lastActiveTab: DefaultTab {
        let savedTab = DefaultTab(rawValue: lastActiveTabRawValue) ?? .catalog
        
        // Ensure the saved tab is still available with current feature flags
        return MainTabView.availableTabs().contains(savedTab) ? savedTab : .catalog
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
                    case .projectPlans:
                        if isProjectPlansEnabled {
                            ProjectPlansView()
                        } else {
                            featureDisabledPlaceholder(title: "Plans", icon: "pencil.and.list.clipboard")
                        }
                    case .projectLog:
                        if isProjectLogEnabled {
                            ProjectLogView()
                        } else {
                            featureDisabledPlaceholder(title: "Logs", icon: "book.pages")
                        }
                    case .settings:
                        SettingsView()
                    default:
                        EmptyView()
                    }
                }
            }

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab, onTabTap: handleTabTap)
        }
        .preferredColorScheme(UserSettings.shared.colorScheme)
        .onAppear {
            // Restore the last active tab on app launch
            selectedTab = lastActiveTab
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
    
    /// Returns tabs that are available based on current feature flags
    static func availableTabs() -> [DefaultTab] {
        return DefaultTab.allCases.filter { tab in
            switch tab {
            case .purchases:
                return isPurchaseRecordsEnabled
            case .projectPlans:
                return isProjectPlansEnabled
            case .projectLog:
                return isProjectLogEnabled
            default:
                return true // Always show catalog, inventory, shopping, settings
            }
        }
    }
    
    private func handleTabTap(_ tab: DefaultTab) {
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
    
    // Filter tabs based on feature flags
    private var availableTabs: [DefaultTab] {
        MainTabView.availableTabs()
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

#Preview {
    // Configure RepositoryFactory for preview
    RepositoryFactory.configureForTesting()
    
    // Create catalog service using new architecture
    let catalogService = RepositoryFactory.createCatalogService()
    
    return MainTabView(catalogService: catalogService)
}
