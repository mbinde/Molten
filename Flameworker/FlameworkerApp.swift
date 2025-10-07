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
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Shows launch screen while loading initial data for a great first-run experience
    @MainActor
    private func showLaunchScreen() async {
        // Start loading initial data immediately
        let dataLoadingTask = Task {
            await performInitialDataLoad()
        }
        
        // Show launch screen for at least 1 second, but not more than 4 seconds
        let minimumLaunchTime = Task {
            do {
                try await Task.sleep(for: .seconds(1.0))
            } catch {
                // Handle cancellation gracefully
            }
        }
        
        let maximumWaitTime = Task {
            do {
                try await Task.sleep(for: .seconds(4.0))
            } catch {
                // Handle cancellation gracefully
            }
        }
        
        // Wait for minimum launch time
        await minimumLaunchTime.value
        
        // Then wait for data loading OR maximum wait time, whichever comes first
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await dataLoadingTask.value }
            group.addTask { await maximumWaitTime.value }
            
            // Wait for the first task to complete
            await group.next()
            group.cancelAll() // Cancel the remaining task
        }
        
        // Smooth transition to main UI
        withAnimation(.easeInOut(duration: 0.5)) {
            isLaunching = false
        }
    }
    
    /// Performs initial data loading optimized for first-run experience
    /// This runs during the launch screen to ensure users see populated data immediately
    private func performInitialDataLoad() async {
        print("🚀 Starting initial data load for optimal first-run experience...")
        
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
        
        // Perform necessary data migrations first (but quickly for first run)
        do {
            try await CoreDataMigrationService.shared.performStartupMigrations(in: backgroundContext)
        } catch {
            print("⚠️ Migration failed: \(error.localizedDescription)")
            // Continue with data loading even if migration fails
        }
        
        // Prioritize loading data if empty (first run experience)
        do {
            let existingCount = try await backgroundContext.perform {
                let request = NSFetchRequest<CatalogItem>(entityName: "CatalogItem")
                request.includesPropertyValues = false
                return try backgroundContext.count(for: request)
            }
            
            if existingCount == 0 {
                print("🎯 First run detected - loading catalog data immediately...")
                try await DataLoadingService.shared.loadCatalogItemsFromJSONIfEmpty(into: backgroundContext)
                print("✅ First-run data loading completed successfully!")
            } else {
                print("📊 Found \(existingCount) existing items - performing smart merge...")
                try await DataLoadingService.shared.loadCatalogItemsFromJSONWithMerge(into: backgroundContext)
                print("✅ Smart merge completed successfully!")
            }
        } catch {
            print("⚠️ Primary data loading failed, trying fallback: \(error.localizedDescription)")
            // Fallback: try basic loading if empty
            do {
                try await DataLoadingService.shared.loadCatalogItemsFromJSONIfEmpty(into: backgroundContext)
                print("✅ Fallback data loading successful!")
            } catch {
                print("❌ All data loading attempts failed: \(error.localizedDescription)")
            }
        }
        
        print("🏁 Initial data load complete - UI ready to display!")
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


