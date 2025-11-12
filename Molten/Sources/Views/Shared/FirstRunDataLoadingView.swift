//
//  FirstRunDataLoadingView.swift
//  Molten
//
//  Created by Assistant on 10/19/25.
//  First-run data loading experience with progress indicators
//
//  PERFORMANCE NOTE: During development, we observed first-run keyboard delays
//  (7-8 seconds before text fields responded). Investigation proved this was
//  Xcode debugging overhead, NOT an app issue:
//  - With Xcode: 7-8 second delays
//  - After force-quit (disconnects debugger): Instant response
//  The app itself loads and initializes correctly.
//

import SwiftUI

/// Progress view shown during first-run data loading
/// Shows users what steps are happening so they know the app isn't frozen
struct FirstRunDataLoadingView: View {
    @Binding var isComplete: Bool
    @State private var currentStep: LoadingStep = .initializing
    @State private var progress: Double = 0.0
    @State private var itemsLoaded: Int = 0

    private let deps: AppDependencies

    init(isComplete: Binding<Bool>, deps: AppDependencies = AppDependencies()) {
        self._isComplete = isComplete
        self.deps = deps
    }

    enum LoadingStep: String, CaseIterable {
        case initializing = "Initializing app..."
        case loadingCatalog = "Loading glass catalog..."
        case buildingSearchIndex = "Building search index..."
        case loadingImages = "Preparing product images..."
        case loadingLocations = "Loading store locations..."
        case finalizing = "Finalizing setup..."
        case complete = "Ready to go!"

        var emoji: String {
            switch self {
            case .initializing: return "🚀"
            case .loadingCatalog: return "📦"
            case .buildingSearchIndex: return "🔍"
            case .loadingImages: return "🖼️"
            case .loadingLocations: return "📍"
            case .finalizing: return "⚡"
            case .complete: return "✅"
            }
        }

        var stepNumber: Int {
            LoadingStep.allCases.firstIndex(of: self) ?? 0
        }

        var totalSteps: Int {
            LoadingStep.allCases.count - 1 // Don't count "complete"
        }
    }

    var body: some View {
        ZStack {
            // Background matching launch screen
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App logo
                VStack(spacing: 12) {
                    Image("Molten")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)

                    Text("Molten")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Spacer()

                // Loading progress section
                VStack(spacing: 24) {
                    // Current step indicator
                    HStack(spacing: 12) {
                        Text(currentStep.emoji)
                            .font(.title)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentStep.rawValue)
                                .font(.headline)
                                .foregroundColor(.white)

                            if itemsLoaded > 0 && currentStep == .loadingCatalog {
                                Text("\(itemsLoaded) items loaded")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 32)

                    // Progress bar
                    VStack(spacing: 8) {
                        ProgressView(value: progress, total: 1.0)
                            .tint(.orange)
                            .frame(height: 8)

                        Text("Step \(currentStep.stepNumber + 1) of \(currentStep.totalSteps)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // Helpful tip
                Text("This one-time setup prepares your glass catalog")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
        .task {
            await performDataLoading()
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func performDataLoading() async {
        print("⏱️ [STARTUP] FirstRunDataLoadingView.performDataLoading() started at \(Date())")

        // Step 1: Initializing - Load Core Data stores
        currentStep = .initializing
        progress = 0.05

        // Initialize Core Data stores asynchronously (this is where the heavy work happens!)
        print("⏱️ [STARTUP] Starting PersistenceController.initialize() at \(Date())")
        await PersistenceController.shared.initialize()
        print("⏱️ [STARTUP] PersistenceController.initialize() completed at \(Date())")

        // Check if Core Data loaded successfully
        guard PersistenceController.shared.isReady else {
            print("⚠️ Core Data failed to load - skipping to main UI")
            withAnimation(.easeInOut(duration: 0.3)) {
                isComplete = true
            }
            return
        }

        // Check for screenshot mode reset flag
        let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("-ResetForScreenshots")

        if isScreenshotMode {
            print("🎬 [SCREENSHOTS] Screenshot mode detected - resetting all data")
            // Delete all Core Data
            await PersistenceController.shared.deleteAllData()
            print("✅ [SCREENSHOTS] All data deleted")
        }

        // Configure repository factory (only set container, preserve mode from MoltenApp)
        RepositoryFactory.configure(persistentContainer: PersistenceController.shared.container)
        print("✅ Repository factory container configured (mode: \(RepositoryFactory.mode))")

        progress = 0.1

        do {
            let catalogService = deps.catalogService
            let glassItemLoadingService = GlassItemDataLoadingService(catalogService: catalogService)

            // Check if we need to wipe and reload due to catalog data version change
            let needsDataWipe = (try? glassItemLoadingService.needsCatalogDataWipe()) ?? false

            if needsDataWipe {
                print("🔄 Catalog data version increased - wiping all catalog data")
                try await glassItemLoadingService.wipeCatalogData()
            }

            // Check if we need to load or update data from JSON
            let existingItems = try await catalogService.getAllGlassItems()
            let isFirstRun = existingItems.isEmpty || needsDataWipe

            // Check if JSON file has changed (for existing installations)
            let jsonHasChanged = (try? glassItemLoadingService.hasJSONFileChanged()) ?? false

            let needsDataLoad = isFirstRun || isScreenshotMode  // Always reload in screenshot mode
            let needsDataUpdate = !isFirstRun && jsonHasChanged && !isScreenshotMode

            // Step 2: Load catalog data (if needed)
            currentStep = .loadingCatalog
            progress = 0.25

            if needsDataLoad {
                print("🎯 First run detected - loading catalog from JSON")

                // Load glass items
                let glassResult = try await glassItemLoadingService.loadGlassItemsFromJSONIfEmpty()
                if let loadingResult = glassResult {
                    itemsLoaded = loadingResult.itemsCreated
                    print("✅ Loaded \(itemsLoaded) glass items from JSON")
                }

                // Load coatings
                let coatingRepository = deps.coatingItemRepository
                let coatingLoadingService = CoatingItemDataLoadingService(coatingRepository: coatingRepository)
                let coatingResult = try await coatingLoadingService.loadCoatingsFromJSON()
                itemsLoaded += coatingResult.itemsCreated
                print("✅ Loaded \(coatingResult.itemsCreated) coatings from JSON")

                // Load tools
                let toolRepository = deps.toolItemRepository
                let toolLoadingService = ToolItemDataLoadingService(toolRepository: toolRepository)
                let toolResult = try await toolLoadingService.loadAllToolsFromJSON()
                itemsLoaded += toolResult.itemsCreated
                print("✅ Loaded \(toolResult.itemsCreated) tools from JSON")

                print("✅ Total items loaded: \(itemsLoaded) (glass + coatings + tools)")

                // DO NOT purge persistent history when using CloudKit!
                // Purging causes CloudKit to lose sync state and re-import everything, creating duplicates.
                // See: https://stackoverflow.com/questions/72557060/
                print("🐛✅ Loaded \(itemsLoaded) items - letting CloudKit manage persistent history")
            } else if needsDataUpdate {
                print("🔄 JSON file changed - updating existing catalog data")

                // Update glass items
                let glassResult = try await glassItemLoadingService.loadGlassItemsAndUpdateExisting(options: .appUpdate)
                itemsLoaded = glassResult.itemsUpdated + glassResult.itemsCreated
                print("✅ Updated glass catalog: \(glassResult.itemsUpdated) updated, \(glassResult.itemsCreated) new, \(glassResult.itemsSkipped) unchanged")

                // Check and update coatings if needed
                let coatingRepository = deps.coatingItemRepository
                let coatingLoadingService = CoatingItemDataLoadingService(coatingRepository: coatingRepository)
                if (try? coatingLoadingService.hasJSONFileChanged()) == true {
                    let coatingResult = try await coatingLoadingService.loadCoatingsFromJSON(options: .appUpdate)
                    itemsLoaded += coatingResult.itemsUpdated + coatingResult.itemsCreated
                    print("✅ Updated coatings: \(coatingResult.itemsUpdated) updated, \(coatingResult.itemsCreated) new")
                }

                // Check and update tools if needed (check each manufacturer)
                let toolRepository = deps.toolItemRepository
                let toolLoadingService = ToolItemDataLoadingService(toolRepository: toolRepository)
                let toolResult = try await toolLoadingService.loadAllToolsFromJSON(options: .appUpdate)
                itemsLoaded += toolResult.itemsUpdated + toolResult.itemsCreated
                print("✅ Updated tools: \(toolResult.itemsUpdated) updated, \(toolResult.itemsCreated) new")
            } else {
                print("✅ Catalog data already exists and up-to-date (\(existingItems.count) items)")
                itemsLoaded = existingItems.count
            }

            progress = 0.5

            // Step 3: Build search index
            // CRITICAL: Always build caches during startup so first search is instant!
            currentStep = .buildingSearchIndex
            progress = 0.6

            await CatalogSearchCache.shared.loadIfNeeded(catalogService: catalogService)
            progress = 0.75

            // Step 4: Load catalog cache
            // CRITICAL: Always build catalog cache during startup!
            currentStep = .loadingImages
            progress = 0.85

            // Skip image loading if disabled via debug flag
            if DebugConfig.disableImageLoading {
                print("🚫 Skipping catalog cache (image loading disabled via DebugConfig)")
            } else {
                print("📦 Building catalog cache...")
                await CatalogDataCache.shared.loadIfNeeded(catalogService: catalogService)
                print("✅ Catalog cache ready")
            }
            progress = 0.85

            // Step 4.5: Load location data (hybrid: bundle + web)
            currentStep = .loadingLocations
            progress = 0.90

            let locationService = deps.unifiedLocationService
            do {
                let result = try await locationService.loadLocationsHybrid()
                print("✅ Loaded \(result.total) locations total (\(result.bundled) from bundle, \(result.web) from web)")
            } catch {
                print("⚠️  Failed to load locations: \(error.localizedDescription)")
                // Continue - locations are optional
            }

            // Step 5: Generate demo data if in screenshot mode
            if isScreenshotMode {
                print("🎬 [SCREENSHOTS] Generating demo data for screenshots...")
                let inventoryService = deps.inventoryTrackingService
                let shoppingListService = deps.shoppingListService
                let purchaseRecordService = deps.purchaseRecordService

                let demoDataGenerator = DemoDataGenerator(
                    catalogService: catalogService,
                    inventoryService: inventoryService,
                    shoppingListService: shoppingListService,
                    purchaseRecordService: purchaseRecordService
                )

                try await demoDataGenerator.generateDemoData()
                print("✅ [SCREENSHOTS] Demo data generation complete")
            }

            // Step 5: Finalizing
            currentStep = .finalizing
            progress = 0.9

            // NOTE: During development, we observed 7-8 second keyboard delays on first run
            // when connected to Xcode. Testing revealed this is Xcode debugging overhead:
            // - With Xcode attached: 7-8 second delay before keyboard responds
            // - After force-quit (disconnects from Xcode): Instant keyboard response
            // - Adding artificial delays here did NOT solve the issue
            //
            // CONCLUSION: The delay is caused by Xcode profiling/debugging, not the app.
            // No additional waiting needed here - the app is ready after Core Data loads.

            progress = 0.95

            // Complete - app is now FULLY ready!
            currentStep = .complete
            progress = 1.0

            print("🎉 All initialization complete - app is fully ready!")

            // Brief pause to show completion message
            try? await Task.sleep(for: .milliseconds(500))

            // Signal completion
            withAnimation(.easeInOut(duration: 0.3)) {
                isComplete = true
            }

        } catch {
            print("⚠️ First-run data loading failed: \(error.localizedDescription)")
            // Even on error, mark as complete so user can access the app
            withAnimation(.easeInOut(duration: 0.3)) {
                isComplete = true
            }
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
                FirstRunDataLoadingView(isComplete: $isComplete)
            }
        }
    }

    return PreviewWrapper()
}
