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
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
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
