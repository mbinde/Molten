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
    @State private var showAlphaDisclaimer = false
    @State private var userSettings = UserSettings.shared
    @State private var syncMonitor: CloudKitSyncMonitor?
    @State private var importPlanURL: URL?
    @State private var showingImportPlan = false
    @State private var importInventoryURL: URL?
    @State private var showingImportInventory = false
    @State private var deepLinkGlassItemStableId: String?
    @State private var showingDeepLinkedItem = false

    // Detect if we're running in test environment
    private var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // Detect if we're running UI tests specifically
    private var isRunningUITests: Bool {
        return ProcessInfo.processInfo.arguments.contains("UI-Testing")
    }

    var body: some Scene {
        WindowGroup {
            // CRITICAL: Show LaunchScreenView IMMEDIATELY by avoiding complex conditionals
            // This prevents SwiftUI from evaluating the entire view tree on first launch
            Group {
                if isRunningTests || isRunningUITests {
                    // During tests, show main content with test configuration
                    uiTestContentView
                } else {
                    mainContentView
                }
            }
            .preferredColorScheme(userSettings.colorScheme)
        }
    }

    @ViewBuilder
    private var uiTestContentView: some View {
        // For UI tests: Skip launch sequence, go straight to main content
        createMainTabView()
            .onAppear {
                configureUITestEnvironment()
            }
    }

    @ViewBuilder
    private var mainContentView: some View {
        ZStack {
            // Set black background only during launch to prevent white flash
            if isLaunching || (showFirstRunDataLoading && !firstRunDataLoadingComplete) {
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
                    .sheet(isPresented: $showAlphaDisclaimer) {
                        AlphaDisclaimerView()
                    }
                    .sheet(isPresented: $showingImportPlan) {
                        if let url = importPlanURL {
                            ImportPlanView(fileURL: url) { _ in
                                // Plan imported successfully
                                // Could navigate to Plans view here if desired
                            }
                        } else {
                            Text("No URL available")
                                .foregroundColor(.red)
                                .onAppear {
                                    print("❌ MoltenApp: Sheet presented but importPlanURL is nil!")
                                }
                        }
                    }
                    .sheet(isPresented: $showingImportInventory) {
                        if let url = importInventoryURL {
                            ImportInventoryView(fileURL: url)
                        } else {
                            Text("No URL available")
                                .foregroundColor(.red)
                                .onAppear {
                                    print("❌ MoltenApp: Sheet presented but importInventoryURL is nil!")
                                }
                        }
                    }
                    .sheet(isPresented: $showingDeepLinkedItem) {
                        if let stableId = deepLinkGlassItemStableId {
                            DeepLinkedItemView(stableId: stableId)
                        } else {
                            Text("No item ID available")
                                .foregroundColor(.red)
                                .onAppear {
                                    print("❌ MoltenApp: Sheet presented but deepLinkGlassItemStableId is nil!")
                                }
                        }
                    }
                    .onChange(of: showingImportPlan) { oldValue, newValue in
                        print("🔄 MoltenApp: showingImportPlan changed from \(oldValue) to \(newValue)")
                        if newValue {
                            print("📂 MoltenApp: About to show import sheet with URL: \(importPlanURL?.path ?? "nil")")
                        }
                    }
                    .onChange(of: showingImportInventory) { oldValue, newValue in
                        print("🔄 MoltenApp: showingImportInventory changed from \(oldValue) to \(newValue)")
                        if newValue {
                            print("📂 MoltenApp: About to show inventory import sheet with URL: \(importInventoryURL?.path ?? "nil")")
                        }
                    }
                    .onOpenURL { url in
                        handleOpenURL(url)
                    }
                    .onAppear {
                        checkOnboardingAndDisclaimer()
                    }
                    .onChange(of: showTerminologyOnboarding) { oldValue, newValue in
                        // When terminology onboarding closes, check if we need to show alpha disclaimer
                        if oldValue && !newValue {
                            checkAlphaDisclaimer()
                        }
                    }
                #else
                createMainTabView()
                    .sheet(isPresented: $showTerminologyOnboarding) {
                        FirstRunTerminologyView()
                    }
                    .sheet(isPresented: $showAlphaDisclaimer) {
                        AlphaDisclaimerView()
                    }
                    .sheet(isPresented: $showingImportPlan) {
                        if let url = importPlanURL {
                            ImportPlanView(fileURL: url) { _ in
                                // Plan imported successfully
                            }
                        } else {
                            Text("No URL available")
                                .foregroundColor(.red)
                                .onAppear {
                                    print("❌ MoltenApp: Sheet presented but importPlanURL is nil!")
                                }
                        }
                    }
                    .sheet(isPresented: $showingImportInventory) {
                        if let url = importInventoryURL {
                            ImportInventoryView(fileURL: url)
                        } else {
                            Text("No URL available")
                                .foregroundColor(.red)
                                .onAppear {
                                    print("❌ MoltenApp: Sheet presented but importInventoryURL is nil!")
                                }
                        }
                    }
                    .onChange(of: showingImportPlan) { oldValue, newValue in
                        print("🔄 MoltenApp: showingImportPlan changed from \(oldValue) to \(newValue)")
                        if newValue {
                            print("📂 MoltenApp: About to show import sheet with URL: \(importPlanURL?.path ?? "nil")")
                        }
                    }
                    .onChange(of: showingImportInventory) { oldValue, newValue in
                        print("🔄 MoltenApp: showingImportInventory changed from \(oldValue) to \(newValue)")
                        if newValue {
                            print("📂 MoltenApp: About to show inventory import sheet with URL: \(importInventoryURL?.path ?? "nil")")
                        }
                    }
                    .onOpenURL { url in
                        handleOpenURL(url)
                    }
                    .onAppear {
                        checkOnboardingAndDisclaimer()
                    }
                    .onChange(of: showTerminologyOnboarding) { oldValue, newValue in
                        // When terminology onboarding closes, check if we need to show alpha disclaimer
                        if oldValue && !newValue {
                            checkAlphaDisclaimer()
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

        // Create sync monitor if needed (only in production with CloudKit)
        if syncMonitor == nil, let container = RepositoryFactory.persistentContainer as? NSPersistentCloudKitContainer {
            syncMonitor = CloudKitSyncMonitor(container: container)
        }

        return MainTabView(
            catalogService: catalogService,
            purchaseService: purchaseService,
            syncMonitor: syncMonitor
        )
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

    /// Check if user needs to see onboarding screens (terminology, then alpha disclaimer)
    private func checkOnboardingAndDisclaimer() {
        // Show terminology onboarding first if needed
        if !GlassTerminologySettings.shared.hasCompletedOnboarding {
            showTerminologyOnboarding = true
        } else {
            // After terminology is done (or skipped), check alpha disclaimer
            checkAlphaDisclaimer()
        }
    }

    /// Check if user needs to acknowledge the alpha disclaimer
    /// NOTE: Currently set to show on EVERY launch during alpha testing
    private func checkAlphaDisclaimer() {
        // Always show alpha disclaimer during alpha testing (ignoring UserDefaults)
        // Small delay to avoid showing immediately after terminology onboarding
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showAlphaDisclaimer = true
        }
    }

    /// Configure environment for UI testing
    @MainActor
    private func configureUITestEnvironment() {
        print("🧪 Configuring UI Test Environment")

        // Skip all onboarding screens
        GlassTerminologySettings.shared.hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedAlphaDisclaimer")

        // Configure RepositoryFactory for production (with real Core Data)
        // UI tests need to test the full stack, not mocks
        RepositoryFactory.configureForProduction()

        print("✅ UI Test Environment configured")
    }

    /// Handle URLs opened from outside the app (e.g., .molten files, deep links)
    @MainActor
    private func handleOpenURL(_ url: URL) {
        print("📥 MoltenApp: Received URL: \(url)")
        print("📥 MoltenApp: Scheme: \(url.scheme ?? "none")")
        print("📥 MoltenApp: Host: \(url.host ?? "none")")
        print("📥 MoltenApp: Path: \(url.path)")

        // Handle molten:// URL scheme (deep links from QR codes)
        if url.scheme == "molten" {
            handleDeepLink(url)
            return
        }

        // Handle file URLs (.molten files)
        print("📥 MoltenApp: Path extension: \(url.pathExtension)")
        print("📥 MoltenApp: File exists: \(FileManager.default.fileExists(atPath: url.path))")

        // Check if it's a .molten file (or .json for backward compatibility)
        if url.pathExtension == "molten" || url.pathExtension == "json" {
            // Detect file type by examining content
            let fileType = detectFileType(at: url)

            switch fileType {
            case .inventoryImport:
                print("✅ MoltenApp: Detected inventory import file")
                importInventoryURL = url
                showingImportInventory = true
                print("✅ MoltenApp: showingImportInventory = \(showingImportInventory)")

            case .projectPlan:
                print("✅ MoltenApp: Detected project plan file")
                importPlanURL = url
                showingImportPlan = true
                print("✅ MoltenApp: showingImportPlan = \(showingImportPlan)")

            case .unknown:
                print("❌ MoltenApp: Could not detect file type")
            }
        } else {
            print("❌ MoltenApp: Not a supported file (extension: \(url.pathExtension))")
        }
    }

    /// Handle deep links from QR codes (molten://glass/{naturalKey})
    @MainActor
    private func handleDeepLink(_ url: URL) {
        print("🔗 MoltenApp: Handling deep link: \(url)")

        // Parse URL: molten://glass/bullseye-clear-001
        guard url.host == "glass" else {
            print("❌ MoltenApp: Unknown deep link host: \(url.host ?? "none")")
            return
        }

        // Extract natural key from path
        let path = url.path
        let naturalKey = path.hasPrefix("/") ? String(path.dropFirst()) : path

        guard !naturalKey.isEmpty else {
            print("❌ MoltenApp: No natural key in deep link")
            return
        }

        print("✅ MoltenApp: Deep link to glass item: \(naturalKey)")
        deepLinkGlassItemStableId = naturalKey
        showingDeepLinkedItem = true
    }

    /// Detect file type by examining JSON content
    private func detectFileType(at url: URL) -> FileType {
        // Start accessing security-scoped resource if needed
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Try to read as JSON first
        guard let data = try? Data(contentsOf: url) else {
            // If we can't read as data, try to unzip (might be a zipped plan)
            return .projectPlan
        }

        // Try to decode as JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Not JSON, assume it's a zipped plan file
            return .projectPlan
        }

        // Check for inventory import structure (has "items" array with inventory data)
        if let items = json["items"] as? [[String: Any]],
           let version = json["version"] as? String,
           version == "1.0",
           let firstItem = items.first,
           firstItem["code"] != nil,
           firstItem["quantity"] != nil {
            return .inventoryImport
        }

        // Otherwise assume it's a project plan
        return .projectPlan
    }

    /// File types that can be imported
    private enum FileType {
        case inventoryImport
        case projectPlan
        case unknown
    }
}



