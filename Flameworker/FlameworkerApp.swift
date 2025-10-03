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
                    .onAppear {
                        Task {
                            await performInitialDataLoad()
                        }
                    }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Shows launch screen for minimum duration with smooth animation
    @MainActor
    private func showLaunchScreen() async {
        // Show launch screen for at least 2 seconds, but with a maximum timeout
        do {
            try await Task.sleep(for: .seconds(2))
        } catch {
            // Handle cancellation gracefully
        }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isLaunching = false
        }
    }
    
    /// Performs initial data loading with smart merge and fallback logic
    /// This runs in the background and won't block app startup
    private func performInitialDataLoad() async {
        // Run data loading on a background context to avoid blocking the UI
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        do {
            try await DataLoadingService.shared.loadCatalogItemsFromJSONWithMerge(into: backgroundContext)
        } catch {
            // Fallback: try loading only if empty
            do {
                try await DataLoadingService.shared.loadCatalogItemsFromJSONIfEmpty(into: backgroundContext)
            } catch {
                // Don't crash the app - just log the error
            }
        }
    }
}


