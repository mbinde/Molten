//
//  MainTabView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
import CoreData

struct MainTabView: View {
    @AppStorage("defaultTab") private var defaultTabRawValue = DefaultTab.inventory.rawValue
    @State private var selectedTab: Int = 1 // Will be set from UserDefaults in onAppear
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CatalogView()
                .tabItem {
                    Label("Catalog", systemImage: "books.vertical")
                }
                .tag(0)
            
            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "archivebox")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .onAppear {
            // Set the initial tab based on user preference
            if let defaultTab = DefaultTab(rawValue: defaultTabRawValue) {
                selectedTab = defaultTab.rawValue
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}