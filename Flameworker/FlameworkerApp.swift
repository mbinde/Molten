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
        // Check if persistence controller is ready for data operations
        guard persistenceController.isReady else {
            if persistenceController.hasStoreLoadingError {
                let errorDescription = persistenceController.storeLoadingError?.localizedDescription ?? "Unknown error"
                print("⚠️ Persistent store failed to load: \(errorDescription)")
                
                // Check if this is a migration-related error
                if let nsError = persistenceController.storeLoadingError as NSError?,
                   nsError.domain == NSCocoaErrorDomain,
                   (nsError.code == NSPersistentStoreIncompatibleVersionHashError || 
                    nsError.code == NSMigrationMissingSourceModelError || 
                    nsError.code == NSMigrationError ||
                    errorDescription.contains("migration") || 
                    errorDescription.contains("mapping model")) {
                    
                    print("🔧 Migration error detected - attempting automatic recovery...")
                    await attemptMigrationRecovery()
                } else {
                    print("⚠️ Skipping data load - persistent store failed to load: \(errorDescription)")
                }
            } else {
                print("⚠️ Skipping data load - persistent stores not yet ready")
            }
            return
        }
        
        // Run data loading on a background context to avoid blocking the UI
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        // Perform necessary data migrations first
        do {
            try await CoreDataMigrationService.shared.performStartupMigrations(in: backgroundContext)
        } catch {
            print("⚠️ Migration failed: \(error.localizedDescription)")
            // Continue with data loading even if migration fails
        }
        
        do {
            try await DataLoadingService.shared.loadCatalogItemsFromJSONWithMerge(into: backgroundContext)
        } catch {
            // Fallback: try loading only if empty
            do {
                try await DataLoadingService.shared.loadCatalogItemsFromJSONIfEmpty(into: backgroundContext)
            } catch {
                // Don't crash the app - just log the error
                print("⚠️ Failed to load initial data: \(error.localizedDescription)")
            }
        }
    }
    
    /// Attempts to recover from Core Data migration failures by resetting the database
    /// This is typically only appropriate for development/testing scenarios
    private func attemptMigrationRecovery() async {
        print("🔧 Attempting Core Data migration recovery...")
        
        // Use the recovery methods from PersistenceController
        await PersistenceController.performStartupRecoveryIfNeeded()
        
        // After recovery, attempt to load data if the store is now ready
        if persistenceController.isReady {
            print("✅ Migration recovery successful - attempting to load data...")
            await performInitialDataLoad()
        } else {
            print("❌ Migration recovery failed - manual intervention may be required")
            // In a production app, you might want to show an alert to the user
        }
    }
}


