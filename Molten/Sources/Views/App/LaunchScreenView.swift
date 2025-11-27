//
//  LaunchScreenView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Simple launch screen that shows the Molten logo while the app initializes.
/// All initialization (Core Data, catalog, caches) happens during this screen.
struct LaunchScreenView: View {
    @Binding var isComplete: Bool

    var body: some View {
        ZStack {
            // Background color
            Color.black
                .ignoresSafeArea()

            // Main content - Molten logo image
            Image("Molten")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            // Subtle loading indicator at bottom
            VStack {
                Spacer()

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(0.8)
                    .padding(.bottom, 80)
            }
        }
        .task {
            await performInitialization()
        }
    }

    // MARK: - Initialization

    @MainActor
    private func performInitialization() async {
        print("⏱️ [STARTUP] LaunchScreenView initialization started at \(Date())")

        // Initialize Core Data stores
        print("⏱️ [STARTUP] Starting PersistenceController.initialize()")
        await PersistenceController.shared.initialize()
        print("⏱️ [STARTUP] PersistenceController.initialize() completed")

        // Check if Core Data loaded successfully
        guard PersistenceController.shared.isReady else {
            print("⚠️ Core Data failed to load - continuing to main UI")
            isComplete = true
            return
        }

        // Check for screenshot mode reset flag
        let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("-ResetForScreenshots")

        if isScreenshotMode {
            print("🎬 [SCREENSHOTS] Screenshot mode detected - resetting all data")
            await PersistenceController.shared.deleteAllData()
            print("✅ [SCREENSHOTS] All data deleted")
        }

        do {
            // Initialize catalog database (bundled SQLite)
            print("📦 Initializing catalog database from bundle...")
            try await CatalogDatabaseManager.shared.initialize()
            print("✅ Catalog database initialized")

            let catalogService = AppDependencies().catalogService

            // Build search cache for instant search
            print("🔍 Building search cache...")
            await CatalogSearchCache.shared.loadIfNeeded(catalogService: catalogService)
            print("✅ Search cache ready")

            // Build catalog cache (skip if debug flag set)
            if !DebugConfig.disableImageLoading {
                print("📦 Building catalog cache...")
                await CatalogDataCache.shared.loadIfNeeded(catalogService: catalogService)
                print("✅ Catalog cache ready")
            }

            // Load location data (hybrid: bundle + web)
            let locationService = AppDependencies().unifiedLocationService
            do {
                let result = try await locationService.loadLocationsHybrid()
                print("✅ Loaded \(result.total) locations")
            } catch {
                print("⚠️ Failed to load locations: \(error.localizedDescription)")
                // Continue - locations are optional
            }

            // Generate demo data if in screenshot mode
            if isScreenshotMode {
                print("🎬 [SCREENSHOTS] Generating demo data...")
                let deps = AppDependencies()
                let demoDataGenerator = DemoDataGenerator(
                    catalogService: catalogService,
                    inventoryService: deps.inventoryTrackingService,
                    shoppingListService: deps.shoppingListService,
                    purchaseRecordService: deps.purchaseRecordService
                )
                try await demoDataGenerator.generateDemoData()
                print("✅ [SCREENSHOTS] Demo data generated")
            }

            print("🎉 All initialization complete!")

        } catch {
            print("⚠️ Initialization error: \(error.localizedDescription)")
            // Continue to main UI even on error
        }

        // Signal completion
        withAnimation(.easeInOut(duration: 0.3)) {
            isComplete = true
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isComplete = false

        var body: some View {
            if isComplete {
                Text("Loading Complete!")
                    .font(.largeTitle)
            } else {
                LaunchScreenView(isComplete: $isComplete)
            }
        }
    }

    return PreviewWrapper()
}