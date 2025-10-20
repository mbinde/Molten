//
//  MoltenApp.swift
//  Molten
//
//  Created by Melissa Binde on 9/27/25.
//

import SwiftUI
import CoreData

@main
struct MoltenApp: App {
    // DO NOT initialize PersistenceController here!
    // It will be initialized lazily during the loading screen
    @State private var isLaunching = true
    @State private var showFirstRunDataLoading = false
    @State private var firstRunDataLoadingComplete = false
    @State private var showTerminologyOnboarding = false
    @State private var userSettings = UserSettings.shared

    // Detect if we're running in test environment
    private var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        WindowGroup {
            // CRITICAL: Show LaunchScreenView IMMEDIATELY by avoiding complex conditionals
            // This prevents SwiftUI from evaluating the entire view tree on first launch
            Group {
                if isRunningTests {
                    // During tests, show a simple view without data loading
                    Text("Test Environment")
                        .onAppear {
                            isLaunching = false
                        }
                } else {
                    mainContentView
                }
            }
            .preferredColorScheme(userSettings.colorScheme)
        }
    }

    @ViewBuilder
    private var mainContentView: some View {
        ZStack {
            // Set black background only during launch to prevent white flash
            if isLaunching || showFirstRunDataLoading {
                Color.black
                    .ignoresSafeArea()
            }

            if isLaunching {
                LaunchScreenView()
                    .task {
                        await performQuickStartupChecks()
                    }
            } else if showFirstRunDataLoading && !firstRunDataLoadingComplete {
                // Show detailed progress for first-run data loading
                FirstRunDataLoadingView(isComplete: $firstRunDataLoadingComplete)
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
    
    /// Performs quick startup checks - transitions to first-run loading immediately
    /// CRITICAL: This function shows the loading screen FIRST, then initializes Core Data
    /// - Core Data initialization happens DURING the loading screen (user sees progress!)
    /// - NO blocking operations before showing UI
    @MainActor
    private func performQuickStartupChecks() async {
        // Show launch screen VERY briefly - just enough for smooth transition
        // Core Data initialization will happen DURING the loading screen!
        do {
            try await Task.sleep(for: .seconds(0.3))
        } catch {
            // Handle cancellation gracefully
        }

        // Transition to first-run loading view IMMEDIATELY
        // Core Data will be initialized while the loading screen is visible!
        print("🎯 Transitioning to first-run loading view")
        withAnimation(.easeInOut(duration: 0.3)) {
            isLaunching = false
            showFirstRunDataLoading = true
        }
    }
}


