//
//  MainTabView-Utilities.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/29/25.
//

import SwiftUI
import CoreData

struct MainTabView: View {
    @AppStorage("defaultTab") private var defaultTabRawValue = DefaultTab.catalog.rawValue
    @State private var selectedTab: DefaultTab = .catalog
    
    private var defaultTab: DefaultTab {
        DefaultTab(rawValue: defaultTabRawValue) ?? .catalog
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CatalogView()
                .tabItem {
                    Label(DefaultTab.catalog.displayName, systemImage: DefaultTab.catalog.systemImage)
                }
                .tag(DefaultTab.catalog)
            
            InventoryView()
                .tabItem {
                    Label(DefaultTab.inventory.displayName, systemImage: DefaultTab.inventory.systemImage)
                }
                .tag(DefaultTab.inventory)
            
            ProjectLogView()
                .tabItem {
                    Label(DefaultTab.projectLog.displayName, systemImage: DefaultTab.projectLog.systemImage)
                }
                .tag(DefaultTab.projectLog)
            
            SettingsView()
                .tabItem {
                    Label(DefaultTab.settings.displayName, systemImage: DefaultTab.settings.systemImage)
                }
                .tag(DefaultTab.settings)
        }
        .onAppear {
            selectedTab = defaultTab
        }
    }
}

#Preview {
    MainTabView()
}