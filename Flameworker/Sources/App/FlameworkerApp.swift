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
    @State private var showTerminologyOnboarding = false
    @State private var userSettings = UserSettings.shared

    // Detect if we're running in test environment
    private var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Set black background only during launch to prevent white flash
                if isLaunching {
                    Color.black
                        .ignoresSafeArea()
                }
                if isRunningTests {
                    // During tests, show a simple view without data loading
                    Text("Test Environment")
                        .onAppear {
                            isLaunching = false
                        }
                } else if isLaunching {
                    LaunchScreenView()
                        .task {
                            await showLaunchScreen()
                        }
                } else {
                    #if os(iOS)
                    createMainTabView()
                        .fullScreenCover(isPresented: $showTerminologyOnboarding) {
                            FirstRunTerminologyView()
                        }
                        .onAppear {
                            // Check if user needs to complete terminology onboarding
                            if !GlassTerminologySettings.shared.hasCompletedOnboarding {
                                showTerminologyOnboarding = true
                            }
                        }
                    #else
                    createMainTabView()
                        .sheet(isPresented: $showTerminologyOnboarding) {
                            FirstRunTerminologyView()
                        }
                        .onAppear {
                            // Check if user needs to complete terminology onboarding
                            if !GlassTerminologySettings.shared.hasCompletedOnboarding {
                                showTerminologyOnboarding = true
                            }
                        }
                    #endif
                }
            }
            .preferredColorScheme(userSettings.colorScheme)
        }
    }
    
    // MARK: - Private Methods
    
    /// Create MainTabView with properly configured services
    private func createMainTabView() -> MainTabView {
        // NOTE: RepositoryFactory is already configured in performInitialDataLoad()
        // Do NOT reconfigure it here as that would reset the container and lose loaded data

        // Create catalog service using the new architecture
        let catalogService = RepositoryFactory.createCatalogService()

        // Create purchase service using the factory (will use Core Data in production)
        let purchaseService = RepositoryFactory.createPurchaseRecordService()

        return MainTabView(catalogService: catalogService, purchaseService: purchaseService)
    }
    
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
        
        // Perform necessary startup checks (quick for first run)
        do {
            // Configure repository factory for the app environment
            // IMPORTANT: Set mode to .hybrid for development/production
            RepositoryFactory.configureForDevelopment()
            // Then set the persistent container to ensure we use the correct instance
            RepositoryFactory.configure(persistentContainer: persistenceController.container)
            print("✅ Repository factory configured successfully (mode: hybrid, container: shared)")
        } catch {
            print("⚠️ Repository configuration issue: \(error.localizedDescription)")
            // Continue with data loading even if configuration has issues
        }
        
        // Prioritize loading data if empty (first run experience)
        do {
            let catalogService = RepositoryFactory.createCatalogService()
            let glassItemLoadingService = GlassItemDataLoadingService(catalogService: catalogService)

            // Check if JSON file has changed using checksum
            let jsonHasChanged = try glassItemLoadingService.hasJSONFileChanged()

            let existingItems = try await catalogService.getAllGlassItems()

            if existingItems.isEmpty {
                print("🎯 First run detected - loading catalog data immediately...")
                let result = try await glassItemLoadingService.loadGlassItemsFromJSONIfEmpty()
                if let loadingResult = result {
                    print("✅ First-run data loading completed successfully! Created \(loadingResult.itemsCreated) items.")
                } else {
                    print("ℹ️ No data loading needed - items already exist.")
                }
            } else if jsonHasChanged {
                print("🔄 Detected new glass data, merging with existing catalog...")
                let result = try await glassItemLoadingService.loadGlassItemsAndUpdateExisting()
                print("✅ Data merge completed! Created: \(result.itemsCreated), Updated: \(result.itemsUpdated), Skipped: \(result.itemsSkipped)")
            } else {
                print("✅ Catalog data is up to date, skipping JSON load")
            }

            // Pre-load catalog cache during launch screen so it's ready when user opens Catalog tab
            print("📦 Pre-loading catalog cache...")
            await CatalogDataCache.shared.loadIfNeeded(catalogService: catalogService)
            print("✅ Catalog cache ready")
        } catch {
            print("⚠️ Primary data loading failed: \(error.localizedDescription)")
            // Continue without data loading - app can still function
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


