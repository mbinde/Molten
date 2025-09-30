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
                    .task {
                        await showLaunchScreen()
                    }
            } else {
                MainTabView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .task {
                        await performInitialDataLoad()
                    }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Shows launch screen for minimum duration with smooth animation
    @MainActor
    private func showLaunchScreen() async {
        // Show launch screen for at least 2 seconds
        try? await Task.sleep(for: .seconds(2))
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isLaunching = false
        }
    }
    
    /// Performs initial data loading with smart merge and fallback logic
    @MainActor
    private func performInitialDataLoad() async {
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


