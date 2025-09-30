//
//  MainTabView.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI
import CoreData

/// Notification names for tab interactions
extension Notification.Name {
    static let clearCatalogSearch = Notification.Name("clearCatalogSearch")
    static let clearInventorySearch = Notification.Name("clearInventorySearch")
    static let clearPurchasesSearch = Notification.Name("clearPurchasesSearch")
}

/// Main tab view that provides navigation between the app's primary sections
struct MainTabView: View {
    @AppStorage("lastActiveTab") private var lastActiveTabRawValue = DefaultTab.catalog.rawValue
    @State private var selectedTab: DefaultTab = .catalog
    
    private var lastActiveTab: DefaultTab {
        DefaultTab(rawValue: lastActiveTabRawValue) ?? .catalog
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            Group {
                switch selectedTab {
                case .catalog:
                    CatalogView()
                case .inventory:
                    InventoryView()
                case .purchases:
                    PurchasesView()
                case .projectLog:
                    ProjectLogView()
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
    
    private func handleTabTap(_ tab: DefaultTab) {
        if selectedTab == tab {
            // Same tab tapped, clear search
            switch tab {
            case .catalog:
                NotificationCenter.default.post(name: .clearCatalogSearch, object: nil)
            case .inventory:
                NotificationCenter.default.post(name: .clearInventorySearch, object: nil)
            case .purchases:
                NotificationCenter.default.post(name: .clearPurchasesSearch, object: nil)
            default:
                break
            }
        } else {
            selectedTab = tab
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: DefaultTab
    let onTabTap: (DefaultTab) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(DefaultTab.allCases, id: \.self) { tab in
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
