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
import CloudKit
import OSLog

/// App delegate for RevenueCat configuration
/// Using UIApplicationDelegate ensures RevenueCat is configured AFTER the run loop starts,
/// avoiding deadlocks that occur when configuring in SwiftUI App.init()
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("🚀 [AppDelegate] didFinishLaunchingWithOptions called")

        // Configure RevenueCat here - this runs after the main run loop starts,
        // preventing deadlocks from dispatchOnMainActor calls during SDK initialization
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: "appl_FrYVVHssDBIlhEAZreHfEgwBJUH")
                .with(entitlementVerificationMode: .informational)
                .build()
        )
        Purchases.shared.delegate = RevenueCatDelegateHandler.shared

        // Mark the RevenueCat guard as initialized
        Task {
            await RevenueCatGuard.shared.markInitialized()
        }

        return true
    }
}

@main
struct MoltenApp: App {

    // MARK: - App Delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
        // Debug: Log all launch arguments to help diagnose UI test issues
        let args = ProcessInfo.processInfo.arguments
        let logger = Logger(subsystem: "com.motleywoods.molten", category: "uitest-debug")
        logger.warning("🚀 [MoltenApp] Launch arguments: \(args, privacy: .public)")
        logger.warning("🚀 [MoltenApp] Contains UI-Testing: \(args.contains("UI-Testing"), privacy: .public)")

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
            print("🚀 [MoltenApp] init() - production mode")
            let prodDeps = AppDependencies.shared
            _dependencies = State(initialValue: prodDeps)

            // Create SubscriptionManager with a DEFERRED RevenueCat service
            // IMPORTANT: RevenueCat.configure() runs in AppDelegate.didFinishLaunchingWithOptions
            // which happens AFTER this init(). Creating RevenueCatSubscriptionService here
            // is safe (it doesn't call the SDK), but SubscriptionManager will wait for
            // RevenueCatGuard.markInitialized() before making any SDK calls.
            //
            // The SubscriptionManager's internal 500ms delay + RevenueCatGuard's initialization
            // wait should be sufficient, but we add an extra safety margin by NOT triggering
            // any subscription checks here. The first check happens in SubscriptionManager.init()
            // with its own delay.
            _subscriptionManager = State(initialValue: SubscriptionManager(
                entitlementService: prodDeps.entitlementService,
                subscriptionService: RevenueCatSubscriptionService(),
                deferInitialCheck: true  // Don't check subscription until SDK is ready
            ))
        }

        // Note: AppDependencies automatically detects test environment
        // and provides appropriate dependencies (mocks for tests, Core Data for production)
    }

    // Launch state - single launch screen handles all initialization
    @State private var isLaunching = true
    @State private var showAlphaDisclaimer = false
    @State private var syncMonitor: CloudKitSyncMonitor?
    @State private var importPlanURL: URL?
    @State private var showingImportPlan = false
    @State private var importInventoryURL: URL?
    @State private var showingImportInventory = false
    @State private var deepLinkGlassItemStableId: String?
    @State private var deepLinkInventoryType: InventoryTypeEncoder.DecodedType?  // Type info from QR code
    @State private var showingDeepLinkedItem = false
    @State private var pendingDeepLinkStableId: String?  // Hold the new ID during refresh
    @State private var pendingDeepLinkType: InventoryTypeEncoder.DecodedType?  // Hold the type during refresh
    @State private var deepLinkViewOnlyStableId: String?
    @State private var showingViewOnlyItem = false
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
                let _ = {
                    let log = Logger(subsystem: "com.motleywoods.molten", category: "uitest-debug")
                    log.warning("🧪 [body] isRunningTests=\(self.isRunningTests), isRunningUITests=\(self.isRunningUITests)")
                }()
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
                } else if newPhase == .active && oldPhase != .active {
                    // Refresh subscription status when app comes to foreground
                    // This catches promo codes redeemed externally in the App Store
                    Task {
                        await subscriptionManager.checkSubscriptionStatus()
                    }
                }
            }
            .onChange(of: isLaunching) { wasLaunching, nowLaunching in
                // When launch screen completes (isLaunching goes from true to false),
                // trigger the deferred subscription check. By this point, RevenueCat
                // has been configured in AppDelegate.didFinishLaunchingWithOptions.
                if wasLaunching && !nowLaunching {
                    Task {
                        // Small delay to ensure RevenueCat is fully ready
                        // (markInitialized is called in didFinishLaunchingWithOptions)
                        try? await Task.sleep(for: .milliseconds(100))
                        await subscriptionManager.loadProducts()
                        await subscriptionManager.checkSubscriptionStatus()
                    }
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
        let _ = {
            let log = Logger(subsystem: "com.motleywoods.molten", category: "uitest-debug")
            log.warning("🧪 [uiTestContentView] mainTabView is nil: \(self.mainTabView == nil)")
        }()
        if mainTabView == nil {
            // Show loading indicator while test data populates
            ProgressView("Loading test data...")
                .task {
                    let log = Logger(subsystem: "com.motleywoods.molten", category: "uitest-debug")
                    log.warning("🧪 [uiTestContentView.task] Starting configuration...")
                    // Configure test-specific settings (skipping onboarding, etc.)
                    // This now awaits test data population before showing main content
                    await configureUITestEnvironmentAsync()
                    log.warning("🧪 [uiTestContentView.task] Configuration complete, creating mainTabView...")
                    // THEN create main view (dependencies already initialized in body)
                    mainTabView = createMainTabView()
                    log.warning("🧪 [uiTestContentView.task] mainTabView created")
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
                deepLinkInventoryType = nil

                // If we have a pending ID, restore it after a short delay
                if let pending = pendingDeepLinkStableId {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        deepLinkGlassItemStableId = pending
                        deepLinkInventoryType = pendingDeepLinkType
                        pendingDeepLinkStableId = nil
                        pendingDeepLinkType = nil
                        // Present the sheet
                        try? await Task.sleep(for: .milliseconds(50))
                        showingDeepLinkedItem = true
                    }
                }
            }) {
                if let stableId = deepLinkGlassItemStableId {
                    DeepLinkedItemView(
                        stableId: stableId,
                        showQuickActions: true,
                        inventoryType: deepLinkInventoryType?.type,
                        inventorySubtype: deepLinkInventoryType?.subtype,
                        inventorySubsubtype: deepLinkInventoryType?.subsubtype
                    )
                } else {
                    Text("No item ID available").foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showingViewOnlyItem, onDismiss: {
                deepLinkViewOnlyStableId = nil
            }) {
                if let stableId = deepLinkViewOnlyStableId {
                    DeepLinkedItemView(stableId: stableId, showQuickActions: false)
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
                        // Store the new ID and type as pending
                        // The .onDismiss handler will detect this and handle the restore + re-present
                        pendingDeepLinkStableId = newValue
                        pendingDeepLinkType = deepLinkInventoryType
                        // Dismiss the current sheet
                        showingDeepLinkedItem = false
                        // Note: .onDismiss will handle restoring the ID and re-presenting
                    } else if !showingDeepLinkedItem {
                        // Case 2: First scan or sheet was closed - just present
                        pendingDeepLinkStableId = nil  // Not a refresh
                        pendingDeepLinkType = nil
                        showingDeepLinkedItem = true
                    }
                    // Case 3: Same item scanned again - do nothing
                }
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMoltenDeepLink)) { notification in
                // Handle QR code scanned from in-app scanner
                if let url = notification.userInfo?["url"] as? URL {
                    handleOpenURL(url)
                }
            }
            .onAppear {
                // Alpha disclaimer disabled
                // checkAlphaDisclaimer()
            }
            .task {
                // Run one-time migrations (with startup delay)
                // Note: Startup tasks that access dependencies need small delays
                // to avoid deadlocking with RevenueCat's initialization.
                // See performBackgroundCatalogUpdate (2s), refreshStaleFriendShares (3s),
                // performBackupIfNeeded (4s) for the established pattern.
                try? await Task.sleep(for: .milliseconds(500))
                await runMigrationsIfNeeded()

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
            // Set black background during launch to prevent white flash
            if isLaunching {
                Color.black
                    .ignoresSafeArea()
            }

            if isLaunching {
                // Single launch screen handles all initialization
                LaunchScreenView(isComplete: Binding(
                    get: { !isLaunching },
                    set: { if $0 { isLaunching = false } }
                ))
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
                    .onReceive(NotificationCenter.default.publisher(for: .openMoltenDeepLink)) { notification in
                        // Handle QR code scanned from in-app scanner
                        if let url = notification.userInfo?["url"] as? URL {
                            handleOpenURL(url)
                        }
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
            inventoryService: inventoryService,
            shoppingListService: shoppingListService,
            kilnScheduleService: kilnScheduleService,
            syncMonitor: syncMonitor
        )
        return tabView
    }
    
    /// Check CloudKit account status and log diagnostics
    @MainActor
    private func checkCloudKitStatus() async {
        let log = Logger(subsystem: "com.motleywoods.molten", category: "cloudkit-diagnostics")

        let container = CKContainer(identifier: "iCloud.com.motleywoods.molten")

        do {
            let status = try await container.accountStatus()

            switch status {
            case .available:
                // Try to fetch user record ID to verify access
                do {
                    let userRecordID = try await container.userRecordID()
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
    /// NOTE: Disabled - leaving alpha, no longer needed
    private func checkAlphaDisclaimer() {
        // DISABLED: Alpha disclaimer no longer needed
        return
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

    /// Run one-time data migrations on app startup
    private func runMigrationsIfNeeded() async {
        // Skip if running tests
        guard !isRunningTests && !isRunningUITests else {
            return
        }

        // Location definition migration: Creates StorageLocationDefinition entries
        // for existing inventory locations that were created before the autocomplete fix
        await dependencies.locationDefinitionMigration.runIfNeeded()
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

    /// Configure environment for UI testing (async version that awaits test data)
    @MainActor
    private func configureUITestEnvironmentAsync() async {
        let log = Logger(subsystem: "com.motleywoods.molten", category: "uitest-debug")

        // Skip all onboarding screens
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedAlphaDisclaimer")

        // CRITICAL: Clear all filters that might hide inventory items
        // These UserDefaults filters could filter out all test data if set from previous runs
        log.warning("🧪 [configureUITest] Clearing UserDefaults filters...")
        UserDefaults.standard.removeObject(forKey: "selectedManufacturerFilter")
        UserDefaults.standard.removeObject(forKey: "selectedCOEFilter")
        UserDefaults.standard.removeObject(forKey: "applyFiltersToInventory")
        // Also clear the COE preference used by COEGlassPreference
        UserDefaults.standard.removeObject(forKey: "preferredCOETypes")
        log.warning("🧪 [configureUITest] Filters cleared")

        // CRITICAL: Enable premium mode for UI tests to unlock all features
        // This uses the DebugConfig subscription tier override
        log.warning("🧪 [configureUITest] Enabling premium mode for testing...")
        UserDefaults.standard.set(true, forKey: "debugOverrideSubscriptionTier")
        UserDefaults.standard.set(1, forKey: "debugSubscriptionTierValue")  // 1 = premium
        log.warning("🧪 [configureUITest] Premium mode enabled")

        // Disable animations for faster, more reliable tests
        if shouldDisableAnimations {
            #if canImport(UIKit)
            UIView.setAnimationsEnabled(false)
            #endif
        }

        // Note: Dependencies already initialized in body via ensureDependenciesInitialized()
        // This method only handles test-specific UI configuration

        // Reset database for clean test state if requested
        if shouldResetDatabase {
            resetCoreDataStore()
        }

        // CRITICAL: Initialize the catalog database before creating test data
        // The normal launch flow does this in LaunchScreenView, but UI tests skip that
        log.warning("🧪 [configureUITest] Initializing Core Data...")
        await PersistenceController.shared.initialize()
        log.warning("🧪 [configureUITest] Core Data initialized")

        log.warning("🧪 [configureUITest] Initializing catalog database...")
        do {
            try await CatalogDatabaseManager.shared.initialize()
            log.warning("🧪 [configureUITest] Catalog database initialized")
        } catch {
            log.error("❌ [configureUITest] Failed to initialize catalog: \(error.localizedDescription)")
        }

        // Populate test data if requested (await to ensure data is ready before UI appears)
        if shouldUseTestData {
            await populateTestData()
        }
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
    /// - molten://i/{naturalKey} - Item detail with quick actions (QR code scan)
    /// - molten://v/{naturalKey} - Item detail view-only (shared links)
    /// - molten://inventory/{shareCode} - Add friend share
    @MainActor
    private func handleDeepLink(_ url: URL) {
        print("🔗 handleDeepLink called with URL: \(url)")
        guard let host = url.host else {
            print("🔗 handleDeepLink: No host in URL")
            return
        }
        print("🔗 handleDeepLink: host = \(host)")

        switch host {
        case "i", "g":  // "g" is legacy, kept for backward compatibility
            // Item detail with quick actions: molten://i/{stableId}/{typeCode}
            // e.g., molten://i/bullseye-clear-001/fc (frit coarse)
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            print("🔗 handleDeepLink: pathComponents = \(pathComponents)")

            guard !pathComponents.isEmpty else {
                print("🔗 handleDeepLink: No path components")
                return
            }

            let stableId = pathComponents[0]
            var decodedType: InventoryTypeEncoder.DecodedType?

            // Parse type code if present (second path component)
            if pathComponents.count >= 2 {
                decodedType = InventoryTypeEncoder.decode(pathComponents[1])
            }

            print("🔗 handleDeepLink: Setting deepLinkGlassItemStableId = \(stableId)")
            deepLinkGlassItemStableId = stableId
            deepLinkInventoryType = decodedType
            print("🔗 handleDeepLink: Done setting state, showingDeepLinkedItem = \(showingDeepLinkedItem)")
            // Note: showingDeepLinkedItem is now managed by .onChange(of: deepLinkGlassItemStableId)
            // This ensures proper handling when scanning multiple QR codes in succession

        case "v":
            // View-only item detail (for shared links): molten://v/bullseye-clear-001
            let path = url.path
            let naturalKey = path.hasPrefix("/") ? String(path.dropFirst()) : path

            guard !naturalKey.isEmpty else {
                return
            }

            deepLinkViewOnlyStableId = naturalKey
            showingViewOnlyItem = true

        case "inventory":
            // Friend share: molten://inventory/ABC123
            let path = url.path
            let shareCode = path.hasPrefix("/") ? String(path.dropFirst()) : path

            guard !shareCode.isEmpty else {
                return
            }

            // Navigate to inventory sharing view and trigger add friend flow
            handleShareDeepLink(shareCode: shareCode)

        case "email-verified":
            // Email verification completed: molten://email-verified
            // Mark the email as verified and refresh the UI
            handleEmailVerifiedDeepLink()

        case "account-recovered":
            // Account recovery completed: molten://account-recovered?user_id=xxx
            // Complete the recovery process with the returned user ID
            handleAccountRecoveredDeepLink(url)

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

    /// Handle email verification deep link from verification success page
    @MainActor
    private func handleEmailVerifiedDeepLink() {
        // Mark the email as verified locally - the server already verified it
        dependencies.receiptService.markEmailVerified()
    }

    /// Handle account recovery deep link from recovery success page
    @MainActor
    private func handleAccountRecoveredDeepLink(_ url: URL) {
        // Extract user_id from query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let userIdItem = components.queryItems?.first(where: { $0.name == "user_id" }),
              let userId = userIdItem.value, !userId.isEmpty else {
            print("⚠️ [Recovery] No user_id in recovery deep link")
            return
        }

        // Complete the recovery - this restores the user's credentials
        dependencies.receiptService.completeAccountRecovery(userId: userId)
        print("✅ [Recovery] Account recovered for user: \(userId)")
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

    /// Populate database with known test data for UI tests
    /// Creates inventory and shopping list items from existing catalog data
    @MainActor
    private func populateTestData() async {
        let log = Logger(subsystem: "com.motleywoods.molten", category: "uitest-debug")
        log.warning("🧪 [populateTestData] Starting test data population...")

        do {
            let catalogService = dependencies.catalogService
            let inventoryService = dependencies.inventoryTrackingService
            let shoppingListService = dependencies.shoppingListService

            // Get existing glass items from catalog
            log.warning("🧪 [populateTestData] Fetching glass items from catalog...")
            let allItems = try await catalogService.getAllGlassItems()
            log.warning("🧪 [populateTestData] Got \(allItems.count) total items")
            let glassItems = allItems.filter { $0.catalogItem.itemType == .glass }
            log.warning("🧪 [populateTestData] Filtered to \(glassItems.count) glass items")

            guard !glassItems.isEmpty else {
                log.warning("⚠️ [populateTestData] No catalog items found - skipping test data population")
                return
            }

            log.warning("🧪 [populateTestData] Creating 10 inventory items...")

            // Generate 10 inventory items for tests
            let types = ["rod", "tube", "frit", "sheet", "stringer"]
            let locations = ["Studio", "Storage Room", "Shelf A", nil]
            var inventoryCreated = 0

            for i in 0..<10 {
                guard let randomItem = glassItems.randomElement(),
                      let type = types.randomElement() else { continue }

                let quantity = Double(Int.random(in: 1...25))
                let location = locations.randomElement() ?? nil

                do {
                    _ = try await inventoryService.addInventory(
                        quantity: quantity,
                        type: type,
                        toItem: randomItem.glassItem.stable_id,
                        atLocation: location
                    )
                    inventoryCreated += 1
                    log.warning("🧪 [populateTestData] Created inventory \(i+1)/10")
                } catch {
                    log.error("❌ [populateTestData] Failed to create inventory \(i+1): \(error.localizedDescription)")
                }
            }

            log.warning("🧪 [populateTestData] Created \(inventoryCreated) inventory items")

            // Generate 5 shopping list items for tests
            let stores = ["Frantz", "Hot Glass Color", "Mountain Glass"]
            var shoppingCreated = 0

            log.warning("🧪 [populateTestData] Creating 5 shopping list items...")

            for i in 0..<5 {
                guard let randomItem = glassItems.randomElement(),
                      let type = types.randomElement(),
                      let store = stores.randomElement() else { continue }

                let neededQuantity = Double(Int.random(in: 1...10))

                let newItem = ItemShoppingModel(
                    item_stable_id: randomItem.glassItem.stable_id,
                    quantity: neededQuantity,
                    store: store,
                    type: type,
                    subtype: nil,
                    subsubtype: nil
                )

                do {
                    _ = try await shoppingListService.shoppingListRepository.createItem(newItem)
                    shoppingCreated += 1
                    log.warning("🧪 [populateTestData] Created shopping item \(i+1)/5")
                } catch {
                    log.error("❌ [populateTestData] Failed to create shopping item \(i+1): \(error.localizedDescription)")
                }
            }

            log.warning("🧪 [populateTestData] Created \(shoppingCreated) shopping list items")

            // CRITICAL: Clear the catalog cache so InventoryView reloads with new inventory data
            // The cache was populated before inventory existed, so items have totalQuantity = 0
            log.warning("🧪 [populateTestData] Clearing CatalogDataCache to include new inventory...")
            CatalogDataCache.shared.clear()

            // Verify the inventory was actually saved by reading it back
            log.warning("🧪 [populateTestData] Verifying inventory was persisted...")
            let allInventory = try await inventoryService.fetchAllInventory(matching: nil)
            log.warning("🧪 [populateTestData] Read back \(allInventory.count) inventory items from Core Data")

            log.warning("✅ [populateTestData] Test data population complete!")

            // Load locations for UI tests (tries bundle first, then fetches from web)
            log.warning("🧪 [populateTestData] Loading locations (hybrid: bundle + web)...")
            let locationService = dependencies.unifiedLocationService
            let locationResult = try await locationService.loadLocationsHybrid()
            log.warning("🧪 [populateTestData] Loaded locations - bundled: \(locationResult.bundled), web: \(locationResult.web), total: \(locationResult.total)")

        } catch {
            log.error("❌ [populateTestData] Failed to populate test data: \(error.localizedDescription)")
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
}

// MARK: - RevenueCat Delegate

/// Handles RevenueCat delegate callbacks for external purchase events (promo codes, etc.)
final class RevenueCatDelegateHandler: NSObject, PurchasesDelegate {
    static let shared = RevenueCatDelegateHandler()

    private override init() {
        super.init()
    }

    /// Called whenever customer info is updated (purchases, promo codes, subscription changes)
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: RevenueCat.CustomerInfo) {
        #if DEBUG
        print("🔐 [RevenueCat] Customer info updated!")
        print("🔐 [RevenueCat] Entitlements: \(customerInfo.entitlements.all.keys)")
        if let pro = customerInfo.entitlements["Pro"] {
            print("🔐 [RevenueCat] Pro entitlement: isActive=\(pro.isActive)")
        }
        #endif

        // Post notification to refresh subscription status throughout the app
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
    }
}



