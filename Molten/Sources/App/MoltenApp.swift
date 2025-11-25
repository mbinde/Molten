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
import Sentry
import CloudKit
import OSLog

@main
struct MoltenApp: App {

    // MARK: - Dependency Injection

    /// Application dependencies - created once at app startup
    /// Provides all services and repositories with proper dependency injection
    /// MUST be initialized immediately to prevent environment crashes
    @State private var dependencies: AppDependencies

    /// Subscription manager - MUST be initialized immediately to prevent environment crashes
    /// Views use @Environment(SubscriptionManager.self) which force-unwraps
    @State private var subscriptionManager: SubscriptionManager

    /// Appearance mode - using AppStorage for immediate reactivity
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = "system"

    private var colorScheme: ColorScheme? {
        guard let mode = UserSettings.AppearanceMode(rawValue: appearanceModeRawValue) else {
            return nil
        }
        switch mode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    init() {
        // Detect test environment BEFORE initializing dependencies
        let isTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if isTest {
            // Test mode - use mocks
            let testDeps = AppDependencies(persistenceController: .createTestController())
            _dependencies = State(initialValue: testDeps)
            // Skip SubscriptionManager during tests (requires RevenueCat configuration)
            _subscriptionManager = State(initialValue: SubscriptionManager(
                entitlementService: testDeps.entitlementService,
                subscriptionService: MockSubscriptionService()
            ))
        } else {
            // Production mode - real Core Data (will init in background during launch screen)
            let prodDeps = AppDependencies()
            _dependencies = State(initialValue: prodDeps)

            // MUST initialize subscriptionManager before calling instance methods (Swift 6 requirement)
            // Initialize with mock first, will be properly set up after SDK configuration
            _subscriptionManager = State(initialValue: SubscriptionManager(
                entitlementService: prodDeps.entitlementService,
                subscriptionService: MockSubscriptionService()
            ))

            // Configure SDKs now that all @State properties are initialized
            configureSentry()
            configureRevenueCat()

            // Now reinitialize SubscriptionManager with real RevenueCat service
            _subscriptionManager = State(initialValue: SubscriptionManager(entitlementService: prodDeps.entitlementService))
        }

        // Note: AppDependencies automatically detects test environment
        // and provides appropriate dependencies (mocks for tests, Core Data for production)
    }

    // DO NOT initialize PersistenceController here!
    // It will be initialized lazily during the loading screen
    @State private var isLaunching = true
    @State private var showFirstRunDataLoading = false
    @State private var firstRunDataLoadingComplete = false
    @State private var showAlphaDisclaimer = false
    @State private var syncMonitor: CloudKitSyncMonitor?
    @State private var importPlanURL: URL?
    @State private var showingImportPlan = false
    @State private var importInventoryURL: URL?
    @State private var showingImportInventory = false
    @State private var deepLinkGlassItemStableId: String?
    @State private var showingDeepLinkedItem = false
    @State private var pendingDeepLinkStableId: String?  // Hold the new ID during refresh
    @State private var mainTabView: MainTabView?

    // Shake-to-report bug
    #if os(iOS)
    @State private var showingBugReport = false
    #endif

    // Scene phase for background backup
    @Environment(\.scenePhase) private var scenePhase

    // Detect if we're running in test environment
    private var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // Detect if we're running UI tests specifically
    private var isRunningUITests: Bool {
        return ProcessInfo.processInfo.arguments.contains("UI-Testing")
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
            .modifier(DependenciesEnvironmentModifier(dependencies: dependencies))
            .environment(dependencies.entitlementService)
            .modifier(SubscriptionEnvironmentModifier(subscriptionManager: subscriptionManager))
            .preferredColorScheme(colorScheme)
            .tint(DesignSystem.Colors.accentSecondary)
            #if os(iOS)
            .onShake {
                // Only enable shake-to-report in beta/debug builds
                #if DEBUG
                showingBugReport = true
                #endif
            }
            .sheet(isPresented: $showingBugReport) {
                BugReportSheet()
            }
            #endif
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    // Opportunistic backup when app goes to background
                    performBackgroundBackup()
                }
            }
        }
    }

}

// MARK: - Helper ViewModifier

struct DependenciesEnvironmentModifier: ViewModifier {
    let dependencies: AppDependencies

    func body(content: Content) -> some View {
        content.environment(\.appDependencies, dependencies)
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
                deepLinkGlassItemStableId = nil

                // If we have a pending ID, restore it after a short delay
                if let pending = pendingDeepLinkStableId {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
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
                // CRITICAL: If a new QR code is scanned while the sheet is already open,
                // we need to dismiss and re-present to show the new item.
                // This handles the iOS-appropriate pattern for updating sheet content.
                if let newValue = newValue {
                    if let oldValue = oldValue, oldValue != newValue, showingDeepLinkedItem {
                        // Case 1: Scanning a different item while sheet is already open
                        // Store the new ID as pending
                        // The .onDismiss handler will detect this and handle the restore + re-present
                        pendingDeepLinkStableId = newValue
                        // Dismiss the current sheet
                        showingDeepLinkedItem = false
                        // Note: .onDismiss will handle restoring the ID and re-presenting
                    } else if !showingDeepLinkedItem {
                        // Case 2: First scan or sheet was closed - just present
                        pendingDeepLinkStableId = nil  // Not a refresh
                        showingDeepLinkedItem = true
                    }
                    // Case 3: Same item scanned again - do nothing
                }
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
            .onAppear {
                // Alpha disclaimer disabled
                // checkAlphaDisclaimer()
            }
            .task {
                // Perform background catalog update check
                await performBackgroundCatalogUpdate()

                // Refresh stale friend shares (> 24 hours old)
                await refreshStaleFriendShares()

                // Perform automatic backup if enabled and due
                await performBackupIfNeeded()
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
                        }
                    }
                    .sheet(isPresented: $showingImportInventory) {
                        if let url = importInventoryURL {
                            ImportInventoryView(fileURL: url)
                        } else {
                            Text("No URL available")
                                .foregroundColor(.red)
                        }
                    }
                    .onOpenURL { url in
                        handleOpenURL(url)
                    }
                    .onAppear {
                        // Alpha disclaimer disabled
                        // checkAlphaDisclaimer()
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

        // Get services from dependencies
        let catalogService = dependencies.catalogService
        let purchaseService = dependencies.purchaseRecordService
        let inventoryService = dependencies.inventoryTrackingService
        let shoppingListService = dependencies.shoppingListService
        let kilnScheduleService = dependencies.kilnScheduleService

        // Create sync monitor if needed (only in production with CloudKit, NOT during UI tests)
        if !isRunningUITests, syncMonitor == nil, let container = dependencies.persistenceController.container as? NSPersistentCloudKitContainer {
            syncMonitor = CloudKitSyncMonitor(container: container)
        }

        let tabView = MainTabView(
            deps: dependencies,
            catalogService: catalogService,
            purchaseService: purchaseService,
            inventoryService: inventoryService,
            shoppingListService: shoppingListService,
            kilnScheduleService: kilnScheduleService,
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
        // Check CloudKit account status for diagnostics
        await checkCloudKitStatus()

        // Show launch screen VERY briefly - just enough for smooth transition
        // Core Data initialization will happen DURING the loading screen!
        do {
            try await Task.sleep(for: .seconds(0.3))
        } catch {
            // Handle cancellation gracefully
        }

        // Transition to first-run loading view IMMEDIATELY
        // Core Data will be initialized while the loading screen is visible!
        withAnimation(.easeInOut(duration: 0.3)) {
            isLaunching = false
            showFirstRunDataLoading = true
        }
    }

    /// Check CloudKit account status and log diagnostics
    @MainActor
    private func checkCloudKitStatus() async {
        let log = Logger(subsystem: "com.motleywoods.molten", category: "cloudkit-diagnostics")

        log.info("🔍 [CloudKit Diagnostics] Starting CloudKit account status check...")

        let container = CKContainer(identifier: "iCloud.com.motleywoods.molten")

        do {
            let status = try await container.accountStatus()

            switch status {
            case .available:
                log.info("✅ [CloudKit Diagnostics] iCloud account is AVAILABLE")

                // Try to fetch user record ID to verify access
                do {
                    let userRecordID = try await container.userRecordID()
                    log.info("✅ [CloudKit Diagnostics] User Record ID: \(userRecordID.recordName)")
                } catch {
                    log.error("❌ [CloudKit Diagnostics] Failed to fetch user record ID: \(error.localizedDescription)")
                }

            case .noAccount:
                log.warning("⚠️ [CloudKit Diagnostics] No iCloud account signed in")

            case .restricted:
                log.warning("⚠️ [CloudKit Diagnostics] iCloud account is RESTRICTED")

            case .couldNotDetermine:
                log.warning("⚠️ [CloudKit Diagnostics] Could not determine iCloud account status")

            case .temporarilyUnavailable:
                log.warning("⚠️ [CloudKit Diagnostics] iCloud is TEMPORARILY UNAVAILABLE")

            @unknown default:
                log.warning("⚠️ [CloudKit Diagnostics] Unknown account status")
            }
        } catch {
            log.error("❌ [CloudKit Diagnostics] Error checking account status: \(error.localizedDescription)")
        }

        // Check if NSPersistentCloudKitContainer is actually being used
        if let cloudKitContainer = dependencies.persistenceController.container as? NSPersistentCloudKitContainer {
            log.info("✅ [CloudKit Diagnostics] Using NSPersistentCloudKitContainer")

            // Log store descriptions
            for (index, store) in cloudKitContainer.persistentStoreDescriptions.enumerated() {
                if let cloudKitOptions = store.cloudKitContainerOptions {
                    log.info("   ☁️ CloudKit: \(cloudKitOptions.containerIdentifier) (scope: \(cloudKitOptions.databaseScope.rawValue))")
                } else {
                    log.info("   📁 No CloudKit (local only)")
                }
            }
        } else {
            log.error("❌ [CloudKit Diagnostics] NOT using NSPersistentCloudKitContainer!")
        }
    }

    /// Check if user needs to acknowledge the alpha disclaimer
    /// Shows only once per install (or until UserDefaults is cleared)
    private func checkAlphaDisclaimer() {
        // Check if user has already acknowledged the disclaimer
        let hasAcknowledged = UserDefaults.standard.bool(forKey: "hasAcknowledgedAlphaDisclaimer")

        guard !hasAcknowledged else {
            return  // User has already seen and acknowledged
        }

        // Show disclaimer for first-time users
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            showAlphaDisclaimer = true
        }
    }

    /// Perform background catalog update check on app startup
    @MainActor
    private func performBackgroundCatalogUpdate() async {
        // Skip if running tests
        guard !isRunningTests && !isRunningUITests else {
            return
        }

        // Small delay to avoid competing with initial data load
        try? await Task.sleep(for: .seconds(2))

        let backgroundUpdateService = dependencies.backgroundUpdateService
        await backgroundUpdateService.checkForUpdatesIfNeeded()
    }

    /// Refresh my share if stale (not updated in > 24 hours)
    @MainActor
    private func refreshStaleFriendShares() async {
        // Skip if running tests
        guard !isRunningTests && !isRunningUITests else {
            return
        }

        // Small delay to let app finish loading
        try? await Task.sleep(for: .seconds(3))

        let sharingManager = dependencies.inventorySharingManager
        await sharingManager.refreshMyShareIfStale()
    }

    /// Perform automatic backup if enabled and due (20+ hours since last backup, checksum differs)
    @MainActor
    private func performBackupIfNeeded() async {
        // Skip if running tests
        guard !isRunningTests && !isRunningUITests else {
            return
        }

        // Small delay to let app finish loading
        try? await Task.sleep(for: .seconds(4))

        let backupService = dependencies.backupService

        // Only backup if enabled and due
        guard backupService.shouldBackupOnAppOpen() else {
            return
        }

        do {
            let results = try await backupService.backupOnAppOpenIfNeeded()
            for result in results {
                if result.skipped {
                    print("📦 [Backup] \(result.type.rawValue) unchanged (checksum match)")
                } else {
                    print("📦 [Backup] \(result.type.rawValue) backed up successfully at \(result.timestamp ?? "unknown")")
                }
            }
        } catch {
            // Log error but don't disrupt user experience
            print("⚠️ [Backup] Automatic backup failed: \(error.localizedDescription)")
        }
    }

    /// Perform opportunistic backup when app goes to background
    /// Uses UIApplication.beginBackgroundTask to get ~30 seconds to complete
    @MainActor
    private func performBackgroundBackup() {
        // Skip if running tests
        guard !isRunningTests && !isRunningUITests else {
            return
        }

        // Skip if backups not enabled
        guard dependencies.backupService.isSetUp else {
            return
        }

        #if os(iOS)
        // Request background time
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "BackupTask") {
            // Time expired - clean up
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }

        // Perform backup asynchronously
        Task { @MainActor in
            defer {
                // Always end the background task when done
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }

            do {
                let results = try await dependencies.backupService.backupOnBackground()
                for result in results {
                    if result.skipped {
                        print("📦 [Background Backup] \(result.type.rawValue) unchanged")
                    } else {
                        print("📦 [Background Backup] \(result.type.rawValue) backed up at \(result.timestamp ?? "unknown")")
                    }
                }
            } catch {
                print("⚠️ [Background Backup] Failed: \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// Configure environment for UI testing
    @MainActor
    private func configureUITestEnvironment() {

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
                break  // Silently ignore unknown file types
            }
        }
        // Silently ignore unsupported file types
    }

    /// Handle deep links from QR codes
    /// - molten://g/{naturalKey} - Glass item detail
    /// - molten://share/{shareCode} - Add friend share
    @MainActor
    private func handleDeepLink(_ url: URL) {
        guard let host = url.host else { return }

        switch host {
        case "g":
            // Glass item detail: molten://g/bullseye-clear-001
            let path = url.path
            let naturalKey = path.hasPrefix("/") ? String(path.dropFirst()) : path

            guard !naturalKey.isEmpty else {
                return
            }

            deepLinkGlassItemStableId = naturalKey
            // Note: showingDeepLinkedItem is now managed by .onChange(of: deepLinkGlassItemStableId)
            // This ensures proper handling when scanning multiple QR codes in succession

        case "inventory":
            // Friend share: molten://inventory/ABC123
            let path = url.path
            let shareCode = path.hasPrefix("/") ? String(path.dropFirst()) : path

            guard !shareCode.isEmpty else {
                return
            }

            // Navigate to inventory sharing view and trigger add friend flow
            handleShareDeepLink(shareCode: shareCode)

        default:
            break  // Unknown deep link host, silently ignore
        }
    }

    /// Handle share deep link by navigating to inventory sharing and opening add friend sheet
    @MainActor
    private func handleShareDeepLink(shareCode: String) {
        // Post notification to navigate to inventory tab and show sharing view with pre-filled code
        NotificationCenter.default.post(
            name: .navigateToInventorySharingWithCode,
            object: nil,
            userInfo: ["shareCode": shareCode]
        )
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
        let container = dependencies.persistenceController.container

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
        do {
            let glassItemRepo = dependencies.glassItemRepository
            let inventoryRepo = dependencies.inventoryRepository

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

    /// Configure Sentry SDK for error tracking
    private func configureSentry() {
        // Get DSN from AppDependencies (already configured there)
        let sentryDSN = "https://9656fde5615b69579eb41101834237b6@o4510371843932160.ingest.us.sentry.io/4510371846356992"

        // Only initialize if DSN is configured
        guard !sentryDSN.isEmpty && !sentryDSN.contains("your-dsn") else {
            print("⚠️ Sentry DSN not configured - error tracking disabled")
            return
        }

        SentrySDK.start { options in
            options.dsn = sentryDSN
            options.environment = SentryEnvironment.current.rawValue

            // Performance monitoring
            options.tracesSampleRate = 1.0  // Capture 100% of transactions (adjust for production)

            // Session tracking
            options.enableAutoSessionTracking = true

            // Breadcrumbs
            options.maxBreadcrumbs = 100

            // Enable file I/O tracking
            options.enableFileIOTracing = true

            // Enable network tracking
            options.enableNetworkTracking = true

            // Sentry debug logging disabled - too verbose for debug console
            #if DEBUG
            options.debug = false
            #endif
        }
    }

    /// Configure RevenueCat SDK with API key and settings
    private func configureRevenueCat() {
        // RevenueCat logging disabled - too verbose for debug console
        // To re-enable: Purchases.logLevel = .debug

        Purchases.configure(
            with: Configuration.Builder(withAPIKey: "test_oIPjDwQxUqwuGvJpuCZEuaWmQTL")
                .with(entitlementVerificationMode: .informational) // Recommended for production
                .build()
        )
    }
}



