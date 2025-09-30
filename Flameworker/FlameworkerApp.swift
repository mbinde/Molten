//
//  FlameworkerApp.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/27/25.
//

import SwiftUI
import CoreData

@main
struct FlameworkerApp: App {
    let persistenceController = PersistenceController.shared
    @State private var isLaunching = true
    
    var body: some Scene {
        WindowGroup {
            if isLaunching {
                LaunchScreenView()
                    .onAppear {
                        // Show launch screen for at least 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isLaunching = false
                            }
                        }
                    }
            } else {
                // Main Tab View - inline implementation to avoid file conflicts
                AppMainTabView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .task {
                        // Automatically load/merge JSON data when the app starts
                        let context = persistenceController.container.viewContext
                        do {
                            print("🚀 App startup: Performing smart merge of JSON data...")
                            try await DataLoadingService.shared.loadCatalogItemsFromJSONWithMerge(into: context)
                            print("✅ App startup: Smart merge completed successfully")
                        } catch {
                            print("❌ App startup: Smart merge failed: \(error)")
                            // Fallback: try loading only if empty
                            do {
                                print("🔄 App startup: Trying fallback load if empty...")
                                try await DataLoadingService.shared.loadCatalogItemsFromJSONIfEmpty(into: context)
                                print("✅ App startup: Fallback load completed")
                            } catch {
                                print("❌ App startup: All loading methods failed: \(error)")
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Tab View Implementation
struct AppMainTabView: View {
    @AppStorage("defaultTab") private var defaultTabRawValue = DefaultTab.catalog.rawValue
    @State private var selectedTab: DefaultTab = .catalog
    
    private var defaultTab: DefaultTab {
        DefaultTab(rawValue: defaultTabRawValue) ?? .catalog
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CatalogView()
                .tabItem {
                    Label("Catalog", systemImage: "eyedropper.halffull")
                }
                .tag(DefaultTab.catalog)
            
            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "archivebox")
                }
                .tag(DefaultTab.inventory)
            
            ProjectLogView()
                .tabItem {
                    Label("Project Log", systemImage: "book.pages")
                }
                .tag(DefaultTab.projectLog)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(DefaultTab.settings)
        }
        .onAppear {
            selectedTab = defaultTab
        }
    }
}
