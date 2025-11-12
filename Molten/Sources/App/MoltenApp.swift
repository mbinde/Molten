//
//  MoltenApp.swift
//  Molten
//
//  Created by Melissa Binde on 9/27/25.
//

import SwiftUI
import CoreData
import CryptoKit
import RevenueCat

@main
struct MoltenApp: App {

    // MARK: - Dependency Injection

    /// Application dependencies - created once at app startup
    /// This replaces RepositoryFactory static methods with proper DI
    @State private var dependencies: AppDependencies?

    /// Subscription manager - MUST be initialized immediately to prevent environment crashes
    /// Views use @Environment(SubscriptionManager.self) which force-unwraps
    @State private var subscriptionManager: SubscriptionManager

    init() {
        // Initialize with placeholder - will be replaced with proper one after AppDependencies loads
        let placeholderEntitlement = EntitlementService(tier: .free)
        _subscriptionManager = State(initialValue: SubscriptionManager(entitlementService: placeholderEntitlement))

        print(String(repeating: "=", count: 80))
        print("🚀 MoltenApp.init() STARTING")
        print(String(repeating: "=", count: 80))

        // Note: AppDependencies will be created in .onAppear after view hierarchy is set up
        // This avoids blocking app launch with Core Data initialization

        // TEMPORARY: Configure RepositoryFactory for views not yet migrated to DI
        // This will be removed in Phase 5 after all views are migrated
        if !isRunningTests {
            RepositoryFactory.configureForProduction()
        }

        // Configure RevenueCat SDK
        configureRevenueCat()

        print(String(repeating: "=", count: 80))
        print("🏁 MoltenApp.init() COMPLETE")
        print(String(repeating: "=", count: 80))
    }

    // DO NOT initialize PersistenceController here!
    // It will be initialized lazily during the loading screen
    @State private var isLaunching = true
    @State private var showFirstRunDataLoading = false
    @State private var firstRunDataLoadingComplete = false
    @State private var showAlphaDisclaimer = false
    @State private var userSettings = UserSettings.shared
    @State private var syncMonitor: CloudKitSyncMonitor?
    @State private var importPlanURL: URL?
    @State private var showingImportPlan = false
    @State private var importInventoryURL: URL?
    @State private var showingImportInventory = false
    @State private var deepLinkGlassItemStableId: String?
    @State private var showingDeepLinkedItem = false
    @State private var pendingDeepLinkStableId: String?  // Hold the new ID during refresh
    @State private var mainTabView: MainTabView?

    // Detect if we're running in test environment
    private var isRunningTests: Bool {
        let isTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #if DEBUG
        if isTest {
            print("🧪 Detected test environment via XCTestConfigurationFilePath")
        }
        #endif
        return isTest
    }

    // Detect if we're running UI tests specifically
    private var isRunningUITests: Bool {
        let isUITest = ProcessInfo.processInfo.arguments.contains("UI-Testing")
        #if DEBUG
        if isUITest {
            print("🧪 Detected UI test via UI-Testing argument")
        }
        #endif
        return isUITest
    }

    // UI Test configuration flags
    private var shouldResetDatabase: Bool {
        return ProcessInfo.processInfo.arguments.contains("RESET-DATABASE")
    }

    private var shouldUseTestData: Bool {
        return ProcessInfo.processInfo.arguments.contains("USE-TEST-DATA")
    }

    private var shouldDisableAnimations: Bool {
        return ProcessInfo.processInfo.arguments.contains("DISABLE-ANIMATIONS")
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
            .onAppear {
                // Initialize dependencies when view appears
                // This runs BEFORE child views access environment
                ensureDependenciesInitialized()
            }
            .modifier(DependenciesEnvironmentModifier(dependencies: dependencies))
            .modifier(SubscriptionEnvironmentModifier(subscriptionManager: subscriptionManager))
            .preferredColorScheme(userSettings.colorScheme)
            .tint(DesignSystem.Colors.accentSecondary)
        }
    }

    /// Ensures dependencies are initialized before view tree is created
    /// Called from body to guarantee initialization happens before any view accesses environment
    private func ensureDependenciesInitialized() {
        guard dependencies == nil else { return }

        if isRunningTests || isRunningUITests {
            // Test mode - use mocks
            RepositoryFactory.configureForTesting()
            dependencies = AppDependencies(forTesting: true)
        } else {
            // Production mode - already configured in init()
            dependencies = AppDependencies()
        }

        // Replace placeholder subscription manager with proper one
        if let deps = dependencies {
            subscriptionManager = SubscriptionManager(entitlementService: deps.entitlementService)
        }
    }
}

// MARK: - Helper ViewModifier

struct DependenciesEnvironmentModifier: ViewModifier {
    let dependencies: AppDependencies?

    func body(content: Content) -> some View {
        if let deps = dependencies {
            content.environment(\.appDependencies, deps)
        } else {
            content
        }
    }
}

struct SubscriptionEnvironmentModifier: ViewModifier {
    let subscriptionManager: SubscriptionManager

    func body(content: Content) -> some View {
        content.environment(subscriptionManager)
    }
}

extension MoltenApp {
    @ViewBuilder
    private var uiTestContentView: some View {
        // For UI tests: Skip launch sequence, go straight to main content
        if mainTabView == nil {
            Color.clear
                .onAppear {
                    // Configure test-specific settings (skipping onboarding, etc.)
                    configureUITestEnvironment()
                    // THEN create main view (dependencies already initialized in body)
                    mainTabView = createMainTabView()
                }
        } else {
            mainTabView!
        }
    }

    @ViewBuilder
    private var mainTabViewWithModifiers: some View {
        let tabViewBase = Group {
            if mainTabView == nil {
                Color.clear
                    .onAppear {
                        // Dependencies already initialized in body
                        print("🎬 MoltenApp: Creating cached MainTabView...")
                        mainTabView = createMainTabView()
                    }
            } else {
                mainTabView!
            }
        }

        tabViewBase
            .sheet(isPresented: $showAlphaDisclaimer) {
                AlphaDisclaimerView()
            }
            .sheet(isPresented: $showingImportPlan) {
                if let url = importPlanURL {
                    ImportPlanView(fileURL: url) { _ in }
                } else {
                    Text("No URL available").foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showingImportInventory) {
                if let url = importInventoryURL {
                    ImportInventoryView(fileURL: url)
                } else {
                    Text("No URL available").foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showingDeepLinkedItem, onDismiss: {
                // Always clear on dismiss
                print("🔄 Sheet dismissed - clearing deepLinkGlassItemStableId")
                deepLinkGlassItemStableId = nil

                // If we have a pending ID, restore it after a short delay
                if let pending = pendingDeepLinkStableId {
                    print("🔄 Pending ID exists: '\(pending)' - will restore after dismiss completes")
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        print("🔄 Restoring deepLinkGlassItemStableId = '\(pending)' from pending")
                        deepLinkGlassItemStableId = pending
                        pendingDeepLinkStableId = nil
                        // Present the sheet
                        try? await Task.sleep(for: .milliseconds(50))
                        showingDeepLinkedItem = true
                    }
                }
            }) {
                if let stableId = deepLinkGlassItemStableId {
                    DeepLinkedItemView(stableId: stableId)
                } else {
                    Text("No item ID available").foregroundColor(.red)
                }
            }
            .onChange(of: deepLinkGlassItemStableId) { oldValue, newValue in
                print("🔄 deepLinkGlassItemStableId: '\(oldValue ?? "nil")' → '\(newValue ?? "nil")'")
                print("🔄 showingDeepLinkedItem is currently: \(showingDeepLinkedItem)")

                // CRITICAL: If a new QR code is scanned while the sheet is already open,
                // we need to dismiss and re-present to show the new item.
                // This handles the iOS-appropriate pattern for updating sheet content.
                if let newValue = newValue {
                    if let oldValue = oldValue, oldValue != newValue, showingDeepLinkedItem {
                        // Case 1: Scanning a different item while sheet is already open
                        print("🔄 New QR scanned while sheet open - refreshing sheet...")
                        // Store the new ID as pending
                        // The .onDismiss handler will detect this and handle the restore + re-present
                        pendingDeepLinkStableId = newValue
                        // Dismiss the current sheet
                        showingDeepLinkedItem = false
                        // Note: .onDismiss will handle restoring the ID and re-presenting
                    } else if !showingDeepLinkedItem {
                        // Case 2: First scan or sheet was closed - just present
                        print("🔄 First scan or sheet closed - presenting sheet...")
                        pendingDeepLinkStableId = nil  // Not a refresh
                        showingDeepLinkedItem = true
                    } else {
                        // Case 3: Same item scanned again (do nothing)
                        print("🔄 Same item scanned again - sheet already open")
                    }
                }
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
            .onAppear {
                checkAlphaDisclaimer()
            }
            .task {
                // Perform background catalog update check
                await performBackgroundCatalogUpdate()
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
                mainTabViewWithModifiers
                #else
                Group {
                    if mainTabView == nil {
                        Color.clear
                            .onAppear {
                                // Dependencies already initialized in body
                                print("🎬 MoltenApp: Creating cached MainTabView...")
                                mainTabView = createMainTabView()
                            }
                    } else {
                        mainTabView!
                    }
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
                        checkAlphaDisclaimer()
                    }
                #endif
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Create MainTabView with properly configured services
    /// WARNING: This should only be called ONCE per app launch!
    /// Multiple calls indicate a view lifecycle bug (body re-evaluation creating new instances)
    private func createMainTabView() -> MainTabView {

        // Debug assertion: Detect if we're being called multiple times
        #if DEBUG
        if mainTabView != nil {
            assertionFailure("⚠️ BUG: createMainTabView() called multiple times! This creates duplicate views and causes update loops. MainTabView should be cached in @State and created only once.")
        }
        #endif

        // Get dependencies
        guard let deps = dependencies else {
            fatalError("Dependencies not initialized - cannot create MainTabView")
        }

        // Get services from dependencies
        let catalogService = deps.catalogService
        let purchaseService = deps.purchaseRecordService

        // Create sync monitor if needed (only in production with CloudKit, NOT during UI tests)
        if !isRunningUITests, syncMonitor == nil, let container = deps.persistenceController.container as? NSPersistentCloudKitContainer {
            syncMonitor = CloudKitSyncMonitor(container: container)
        } else if isRunningUITests {
            print("🧪 Skipping CloudKit sync monitor for UI tests")
        }

        let tabView = MainTabView(
            catalogService: catalogService,
            purchaseService: purchaseService,
            syncMonitor: syncMonitor
        )
        return tabView
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

    /// Check if user needs to acknowledge the alpha disclaimer
    /// NOTE: Currently HIDDEN - uncomment to show on every launch during alpha testing
    private func checkAlphaDisclaimer() {
        // Temporarily hidden - uncomment to show alpha disclaimer on every launch
        // Use Task instead of DispatchQueue to avoid update loops
        // Task { @MainActor in
        //     try? await Task.sleep(for: .seconds(0.3))
        //     showAlphaDisclaimer = true
        // }
    }

    /// Perform background catalog update check on app startup
    @MainActor
    private func performBackgroundCatalogUpdate() async {
        // Skip if running tests
        guard !isRunningTests && !isRunningUITests else {
            print("🧪 Skipping catalog update check for tests")
            return
        }

        // Skip if dependencies not initialized yet
        guard let deps = dependencies else {
            print("⚠️ Dependencies not initialized, skipping catalog update check")
            return
        }

        // Small delay to avoid competing with initial data load
        try? await Task.sleep(for: .seconds(2))

        print("📦 Starting background catalog update check...")
        let backgroundUpdateService = deps.backgroundUpdateService
        await backgroundUpdateService.checkForUpdatesIfNeeded()
        print("✅ Background catalog update check completed")
    }

    /// Configure environment for UI testing
    @MainActor
    private func configureUITestEnvironment() {
        print("🧪 configureUITestEnvironment() called - isRunningUITests: \(isRunningUITests)")

        // Skip all onboarding screens
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedAlphaDisclaimer")

        // Disable animations for faster, more reliable tests
        if shouldDisableAnimations {
            #if canImport(UIKit)
            UIView.setAnimationsEnabled(false)
            #endif
        }

        // Note: Dependencies already initialized in body via ensureDependenciesInitialized()
        // This method only handles test-specific UI configuration

        // Note: Database reset and test data population deferred to Phase 4
        // when we properly set up Core Data for UI tests
        if isRunningUITests && (shouldResetDatabase || shouldUseTestData) {
            print("⚠️ Database reset/test data not yet supported with mock dependencies")
            print("⚠️ This will be implemented in Phase 4 of DI migration")
        }

        print("✅ Test Environment UI configuration complete")
    }

    /// Handle URLs opened from outside the app (e.g., .molten files, deep links)
    @MainActor
    private func handleOpenURL(_ url: URL) {
        // Handle molten:// URL scheme (deep links from QR codes)
        if url.scheme == "molten" {
            handleDeepLink(url)
            return
        }

        // Check if it's a .molten file (or .json for backward compatibility)
        if url.pathExtension == "molten" || url.pathExtension == "json" {
            // Detect file type by examining content
            let fileType = detectFileType(at: url)

            switch fileType {
            case .inventoryImport:
                importInventoryURL = url
                showingImportInventory = true

            case .projectPlan:
                importPlanURL = url
                showingImportPlan = true

            case .unknown:
                print("❌ MoltenApp: Could not detect file type")
            }
        } else {
            print("❌ MoltenApp: Not a supported file (extension: \(url.pathExtension))")
        }
    }

    /// Handle deep links from QR codes (molten://g/{naturalKey})
    @MainActor
    private func handleDeepLink(_ url: URL) {
        // Parse URL: molten://g/bullseye-clear-001
        guard url.host == "g" else {
            return
        }

        // Extract natural key from path
        let path = url.path
        let naturalKey = path.hasPrefix("/") ? String(path.dropFirst()) : path

        guard !naturalKey.isEmpty else {
            return
        }

        deepLinkGlassItemStableId = naturalKey
        // Note: showingDeepLinkedItem is now managed by .onChange(of: deepLinkGlassItemStableId)
        // This ensures proper handling when scanning multiple QR codes in succession
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

    // MARK: - UI Test Support Methods

    /// Reset Core Data store for clean test runs
    @MainActor
    private func resetCoreDataStore() {
        guard let deps = dependencies else {
            print("❌ Dependencies not initialized")
            return
        }

        let container = deps.persistenceController.container

        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            print("❌ Could not get store URL")
            return
        }

        do {
            // Remove the store
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)

            // Recreate the store
            try container.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)

            print("✅ Core Data store reset successfully")
        } catch {
            print("❌ Failed to reset Core Data store: \(error)")
        }
    }

    /// Populate database with known test data
    @MainActor
    private func populateTestData() async {
        guard let deps = dependencies else {
            print("❌ Dependencies not initialized")
            return
        }

        do {
            let glassItemRepo = deps.glassItemRepository
            let inventoryRepo = deps.inventoryRepository

            // Create a few known glass items that tests can rely on
            let testItems = [
                GlassItemModel(
                    stable_id: generateStableId(manufacturer: "bullseye", sku: "001"),
                    name: "Clear",
                    sku: "001",
                    manufacturer: "bullseye",
                    coe: 90,
                    mfr_status: "available"
                ),
                GlassItemModel(
                    stable_id: generateStableId(manufacturer: "bullseye", sku: "254"),
                    name: "Pomegranate Red",
                    sku: "254",
                    manufacturer: "bullseye",
                    coe: 90,
                    mfr_status: "available"
                ),
                GlassItemModel(
                    stable_id: generateStableId(manufacturer: "effetre", sku: "006"),
                    name: "Ivory",
                    sku: "006",
                    manufacturer: "effetre",
                    coe: 104,
                    mfr_status: "available"
                )
            ]

            // Add items to database
            for item in testItems {
                try await glassItemRepo.createItem(item)
            }

            // Add some inventory for the first item
            let inventory = InventoryModel(
                item_stable_id: testItems[0].stable_id,
                type: "rod",
                subtype: nil,
                subsubtype: nil,
                dimensions: nil,
                quantity: 10.0
            )
            _ = try await inventoryRepo.createInventory(inventory)
        } catch {
            print("❌ Failed to populate test data: \(error)")
        }
    }

    /// Generate a stable 6-character ID from manufacturer and SKU
    private func generateStableId(manufacturer: String, sku: String) -> String {
        let combined = "\(manufacturer):\(sku)"
        guard let data = combined.data(using: .utf8) else { return "" }

        let hash = CryptoKit.SHA256.hash(data: data)
        let hashBytes = Data(hash)

        let base62Chars = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz"
        var num = UInt32(bigEndian: hashBytes.withUnsafeBytes { $0.load(as: UInt32.self) })
        var stableId = ""

        for _ in 0..<6 {
            let index = Int(num % UInt32(base62Chars.count))
            let char = base62Chars[base62Chars.index(base62Chars.startIndex, offsetBy: index)]
            stableId = String(char) + stableId
            num /= UInt32(base62Chars.count)
        }

        return stableId
    }

    /// Configure RevenueCat SDK with API key and settings
    private func configureRevenueCat() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        Purchases.configure(
            with: Configuration.Builder(withAPIKey: "test_oIPjDwQxUqwuGvJpuCZEuaWmQTL")
                .with(entitlementVerificationMode: .informational) // Recommended for production
                .build()
        )

        print("✅ RevenueCat configured successfully")
    }
}



