//
//  MainTabView.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI
import CoreData

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isPurchaseRecordsEnabled = false
private let isProjectLogEnabled = false

/// Notification names for tab interactions
extension Notification.Name {
    static let clearCatalogSearch = Notification.Name("clearCatalogSearch")
    static let clearInventorySearch = Notification.Name("clearInventorySearch")
    static let clearPurchasesSearch = Notification.Name("clearPurchasesSearch")
    static let resetCatalogNavigation = Notification.Name("resetCatalogNavigation")
    static let resetInventoryNavigation = Notification.Name("resetInventoryNavigation")
    static let resetPurchasesNavigation = Notification.Name("resetPurchasesNavigation")
    static let inventoryItemAdded = Notification.Name("inventoryItemAdded")
}

/// Main tab view that provides navigation between the app's primary sections
struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("lastActiveTab") private var lastActiveTabRawValue = DefaultTab.catalog.rawValue
    @State private var selectedTab: DefaultTab = .catalog
    
    private var lastActiveTab: DefaultTab {
        let savedTab = DefaultTab(rawValue: lastActiveTabRawValue) ?? .catalog
        
        // Ensure the saved tab is still available with current feature flags
        return MainTabView.availableTabs().contains(savedTab) ? savedTab : .catalog
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            Group {
                switch selectedTab {
                case .catalog:
                    CatalogView(catalogService: createCatalogService())
                case .inventory:
                    InventoryView()
                case .purchases:
                    if isPurchaseRecordsEnabled {
                        PurchasesView()
                    } else {
                        featureDisabledPlaceholder(title: "Purchase Records", icon: "cart.badge.plus")
                    }
                case .projectLog:
                    if isProjectLogEnabled {
                        ProjectLogView()
                    } else {
                        featureDisabledPlaceholder(title: "Project Log", icon: "book.pages")
                    }
                case .settings:
                    SettingsView()
                }
            }
            
            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab, onTabTap: handleTabTap)
        }
        .onAppear {
            // Restore the last active tab on app launch
            selectedTab = lastActiveTab
        }
        .onChange(of: selectedTab) { _, newTab in
            // Save the selected tab whenever it changes
            lastActiveTabRawValue = newTab.rawValue
        }
    }
    
    /// Create the production catalog service with Core Data repository
    private func createCatalogService() -> CatalogService {
        let coreDataRepository = CoreDataCatalogRepository(context: viewContext)
        return CatalogService(repository: coreDataRepository)
    }
    
    // MARK: - Helper Functions
    
    /// Returns tabs that are available based on current feature flags
    static func availableTabs() -> [DefaultTab] {
        return DefaultTab.allCases.filter { tab in
            switch tab {
            case .purchases:
                return isPurchaseRecordsEnabled
            case .projectLog:
                return isProjectLogEnabled
            default:
                return true // Always show catalog, inventory, settings
            }
        }
    }
    
    private func handleTabTap(_ tab: DefaultTab) {
        // Only handle tabs that are currently available
        guard MainTabView.availableTabs().contains(tab) else { return }
        
        if selectedTab == tab {
            // Same tab tapped, clear search and reset navigation
            switch tab {
            case .catalog:
                NotificationCenter.default.post(name: .clearCatalogSearch, object: nil)
                NotificationCenter.default.post(name: .resetCatalogNavigation, object: nil)
            case .inventory:
                NotificationCenter.default.post(name: .clearInventorySearch, object: nil)
                NotificationCenter.default.post(name: .resetInventoryNavigation, object: nil)
            case .purchases:
                NotificationCenter.default.post(name: .clearPurchasesSearch, object: nil)
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
            .navigationBarTitleDisplayMode(.inline)
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
                    .fill(Color(.systemGray4))
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
            .foregroundColor(Color(.separator))
            .opacity(0.6)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
