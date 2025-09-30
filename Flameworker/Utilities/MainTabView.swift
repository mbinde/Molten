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
}

/// Main tab view that provides navigation between the app's primary sections
struct MainTabView: View {
    @AppStorage("defaultTab") private var defaultTabRawValue = DefaultTab.catalog.rawValue
    @State private var selectedTab: DefaultTab = .catalog
    
    private var defaultTab: DefaultTab {
        DefaultTab(rawValue: defaultTabRawValue) ?? .catalog
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
            selectedTab = defaultTab
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
        HStack {
            ForEach(DefaultTab.allCases, id: \.self) { tab in
                Button {
                    onTabTap(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20))
                        Text(tab.displayName)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
