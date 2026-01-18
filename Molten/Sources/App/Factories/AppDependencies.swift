//
//  AppDependencies.swift
//  Molten
//
//  Created by Assistant on 2025-11-10.
//  Provides application-wide dependency injection for all services and repositories
//

import Foundation
import CoreData
import SwiftUI

/// Application-wide dependency container
/// Created once at app startup, provides all services and repositories
/// Thread-safe via MainActor isolation
@MainActor
@Observable
class AppDependencies {

    // MARK: - Shared Instance

    /// Shared instance that automatically detects test vs production environment
    /// - In tests: Uses in-memory Core Data (isolated per-test instances)
    /// - In production: Uses persistent Core Data repositories
    static let shared: AppDependencies = {
        if isRunningInTestBundle() {
            // Tests get a fresh in-memory Core Data controller (isolated)
            return AppDependencies(persistenceController: .createTestController())
        } else {
            // Production uses the shared persistent controller
            return AppDependencies()
        }
    }()

    /// Detect if we're running in a test bundle
    private nonisolated static func isRunningInTestBundle() -> Bool {
        NSClassFromString("XCTestCase") != nil
    }

    // MARK: - Core Dependencies

    /// ✅ CRITICAL: Store the PersistenceController to prevent Core Data zombie crashes
    /// The controller owns the NSManagedObjectModel and must stay alive for contexts to work.
    let persistenceController: PersistenceController
    let mode: RepositoryMode

    /// Returns true if Core Data is initialized and ready for use
    /// Check this before accessing Core Data repositories in production
    var isReady: Bool {
        persistenceController.isReady
    }

    // MARK: - SQLite Repositories (always available - no Core Data dependency)

    let glassItemRepository: GlassItemRepository
    let coatingItemRepository: CoatingItemRepository
    let toolItemRepository: ToolItemRepository
    let itemTagsRepository: ItemTagsRepository
    let catalogFlagBundledRepository: CatalogFlagBundledRepository

    // MARK: - UserDefaults Repository (always available)

    let userPreferencesRepository: UserPreferencesRepository

    // MARK: - Core Data Repository Backing Storage (lazy creation after initialization)

    private var _inventoryRepository: InventoryRepository?
    private var _storageLocationRepository: StorageLocationRepository?
    private var _userTagsRepository: UserTagsRepository?
    private var _userNotesRepository: UserNotesRepository?
    private var _shoppingListRepository: ShoppingListRepository?
    private var _itemMinimumRepository: ItemMinimumRepository?
    private var _projectRepository: ProjectRepository?
    private var _logbookRepository: LogbookRepository?
    private var _purchaseRecordRepository: PurchaseRecordRepository?
    private var _projectImageRepository: ProjectImageRepository?
    private var _kilnScheduleRepository: KilnScheduleRepository?
    private var _recipeRepository: RecipeRepository?
    private var _unifiedLocationRepository: UnifiedLocationRepository?
    private var _ratingRepository: RatingRepository?
    private var _workspaceRepository: WorkspaceRepository?
    private var _storageLocationDefinitionRepository: StorageLocationDefinitionRepository?
    private var _inventoryMoveRecordRepository: InventoryMoveRecordRepository?
    private var _inventoryConsumptionRecordRepository: InventoryConsumptionRecordRepository?
    private var _twistPatternRepository: TwistPatternRepository?
    private var _glassPaletteRepository: GlassPaletteRepository?
    private var _twistCaneRepository: TwistCaneRepository?
    private var _catalogFlagAdminRepository: CatalogFlagAdminRepository?
    private var _catalogFlagUserRepository: CatalogFlagUserRepository?
    private var _catalogTagAdminRepository: CatalogTagAdminRepository?
    #if os(iOS)
    private var _userImageRepository: UserImageRepository?
    #endif

    // MARK: - Lazy Core Data Repository Accessors
    // These are created on first access AFTER Core Data initialization completes
    // LaunchScreenView ensures initialization happens before any repository access

    var inventoryRepository: InventoryRepository {
        if let repo = _inventoryRepository { return repo }
        let repo = CoreDataInventoryRepository(context: persistenceController.cloudContext)
        _inventoryRepository = repo
        return repo
    }

    var storageLocationRepository: StorageLocationRepository {
        if let repo = _storageLocationRepository { return repo }
        let repo = CoreDataStorageLocationRepository(context: persistenceController.cloudContext)
        _storageLocationRepository = repo
        return repo
    }

    var userTagsRepository: UserTagsRepository {
        if let repo = _userTagsRepository { return repo }
        let repo = CoreDataUserTagsRepository(context: persistenceController.cloudContext)
        _userTagsRepository = repo
        return repo
    }

    var userNotesRepository: UserNotesRepository {
        if let repo = _userNotesRepository { return repo }
        let repo = CoreDataUserNotesRepository(context: persistenceController.cloudContext)
        _userNotesRepository = repo
        return repo
    }

    var shoppingListRepository: ShoppingListRepository {
        if let repo = _shoppingListRepository { return repo }
        let repo = CoreDataShoppingListRepository(context: persistenceController.cloudContext)
        _shoppingListRepository = repo
        return repo
    }

    var itemMinimumRepository: ItemMinimumRepository {
        if let repo = _itemMinimumRepository { return repo }
        let repo = CoreDataItemMinimumRepository(context: persistenceController.cloudContext)
        _itemMinimumRepository = repo
        return repo
    }

    var projectRepository: ProjectRepository {
        if let repo = _projectRepository { return repo }
        let repo = CoreDataProjectRepository(context: persistenceController.cloudContext)
        _projectRepository = repo
        return repo
    }

    var logbookRepository: LogbookRepository {
        if let repo = _logbookRepository { return repo }
        let repo = CoreDataLogbookRepository(context: persistenceController.cloudContext)
        _logbookRepository = repo
        return repo
    }

    var purchaseRecordRepository: PurchaseRecordRepository {
        if let repo = _purchaseRecordRepository { return repo }
        let repo = CoreDataPurchaseRecordRepository(context: persistenceController.cloudContext)
        _purchaseRecordRepository = repo
        return repo
    }

    var projectImageRepository: ProjectImageRepository {
        if let repo = _projectImageRepository { return repo }
        let repo = CoreDataProjectImageRepository(context: persistenceController.cloudContext)
        _projectImageRepository = repo
        return repo
    }

    var kilnScheduleRepository: KilnScheduleRepository {
        if let repo = _kilnScheduleRepository { return repo }
        let repo = CoreDataKilnScheduleRepository(context: persistenceController.cloudContext)
        _kilnScheduleRepository = repo
        return repo
    }

    var recipeRepository: RecipeRepository {
        if let repo = _recipeRepository { return repo }
        let repo = CoreDataRecipeRepository(context: persistenceController.cloudContext)
        _recipeRepository = repo
        return repo
    }

    var unifiedLocationRepository: UnifiedLocationRepository {
        if let repo = _unifiedLocationRepository { return repo }
        let repo = CoreDataUnifiedLocationRepository(persistenceController: persistenceController)
        _unifiedLocationRepository = repo
        return repo
    }

    var ratingRepository: RatingRepository {
        if let repo = _ratingRepository { return repo }
        let repo = CoreDataRatingRepository(localContext: persistenceController.localContext, cloudContext: persistenceController.cloudContext)
        _ratingRepository = repo
        return repo
    }

    var workspaceRepository: WorkspaceRepository {
        if let repo = _workspaceRepository { return repo }
        let repo = CoreDataWorkspaceRepository(context: persistenceController.cloudContext)
        _workspaceRepository = repo
        return repo
    }

    var storageLocationDefinitionRepository: StorageLocationDefinitionRepository {
        if let repo = _storageLocationDefinitionRepository { return repo }
        let repo = CoreDataStorageLocationDefinitionRepository(context: persistenceController.cloudContext)
        _storageLocationDefinitionRepository = repo
        return repo
    }

    var inventoryMoveRecordRepository: InventoryMoveRecordRepository {
        if let repo = _inventoryMoveRecordRepository { return repo }
        let repo = CoreDataInventoryMoveRecordRepository(context: persistenceController.cloudContext)
        _inventoryMoveRecordRepository = repo
        return repo
    }

    var inventoryConsumptionRecordRepository: InventoryConsumptionRecordRepository {
        if let repo = _inventoryConsumptionRecordRepository { return repo }
        let repo = CoreDataInventoryConsumptionRecordRepository(context: persistenceController.cloudContext)
        _inventoryConsumptionRecordRepository = repo
        return repo
    }

    var twistPatternRepository: TwistPatternRepository {
        if let repo = _twistPatternRepository { return repo }
        let repo = CoreDataTwistPatternRepository(context: persistenceController.cloudContext)
        _twistPatternRepository = repo
        return repo
    }

    var glassPaletteRepository: GlassPaletteRepository {
        if let repo = _glassPaletteRepository { return repo }
        let repo = CoreDataGlassPaletteRepository(context: persistenceController.cloudContext)
        _glassPaletteRepository = repo
        return repo
    }

    var twistCaneRepository: TwistCaneRepository {
        if let repo = _twistCaneRepository { return repo }
        let repo = CoreDataTwistCaneRepository(context: persistenceController.cloudContext)
        _twistCaneRepository = repo
        return repo
    }

    var catalogFlagAdminRepository: CatalogFlagAdminRepository {
        if let repo = _catalogFlagAdminRepository { return repo }
        let repo = CoreDataCatalogFlagAdminRepository(context: persistenceController.cloudContext)
        _catalogFlagAdminRepository = repo
        return repo
    }

    var catalogFlagUserRepository: CatalogFlagUserRepository {
        if let repo = _catalogFlagUserRepository { return repo }
        let repo = CoreDataCatalogFlagUserRepository(context: persistenceController.cloudContext)
        _catalogFlagUserRepository = repo
        return repo
    }

    var catalogTagAdminRepository: CatalogTagAdminRepository {
        if let repo = _catalogTagAdminRepository { return repo }
        let repo = CoreDataCatalogTagAdminRepository(context: persistenceController.cloudContext)
        _catalogTagAdminRepository = repo
        return repo
    }

    #if os(iOS)
    var userImageRepository: UserImageRepository {
        if let repo = _userImageRepository { return repo }
        let repo = CoreDataUserImageRepository(context: persistenceController.cloudContext)
        _userImageRepository = repo
        return repo
    }
    #endif

    // MARK: - Workspace Provider

    /// Provides the default workspace ID, creating the workspace if needed
    private var _defaultWorkspaceProvider: DefaultWorkspaceProvider?
    var defaultWorkspaceProvider: DefaultWorkspaceProvider {
        if let provider = _defaultWorkspaceProvider {
            return provider
        }
        let provider = DefaultWorkspaceProvider(workspaceRepository: workspaceRepository)
        _defaultWorkspaceProvider = provider
        return provider
    }

    // MARK: - Services

    public let loggingService: LoggingService
    private let _subscriptionService: SubscriptionServiceProtocol

    // Core services (created lazily via private backing properties)
    private var _inventoryTrackingService: InventoryTrackingService?
    var inventoryTrackingService: InventoryTrackingService {
        if let service = _inventoryTrackingService {
            return service
        }
        let service = InventoryTrackingService(
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            inventoryRepository: inventoryRepository,
            itemTagsRepository: itemTagsRepository,
            storageLocationDefinitionRepository: storageLocationDefinitionRepository,
            storageLocationRepository: storageLocationRepository,
            storageLocationService: storageLocationService
        )
        _inventoryTrackingService = service
        return service
    }

    private var _ratingService: RatingService?
    var ratingService: RatingService {
        if let service = _ratingService {
            return service
        }
        let service = RatingService(repository: ratingRepository, logger: loggingService)
        _ratingService = service
        return service
    }

    private var _catalogService: CatalogService?
    var catalogService: CatalogService {
        if let service = _catalogService {
            return service
        }
        let service = CatalogService(
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: itemMinimumRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository,
            ratingService: ratingService,
            storageLocationRepository: storageLocationRepository
        )
        _catalogService = service
        return service
    }

    private var _shoppingListService: ShoppingListService?
    var shoppingListService: ShoppingListService {
        if let service = _shoppingListService {
            return service
        }
        let service = ShoppingListService(
            itemMinimumRepository: itemMinimumRepository,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: inventoryRepository,
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository
        )
        _shoppingListService = service
        return service
    }

    private var _projectService: ProjectService?
    var projectService: ProjectService {
        if let service = _projectService {
            return service
        }
        let service = ProjectService(
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            userTagsRepository: userTagsRepository
        )
        _projectService = service
        return service
    }

    private var _purchaseRecordService: PurchaseRecordService?
    var purchaseRecordService: PurchaseRecordService {
        if let service = _purchaseRecordService {
            return service
        }
        let service = PurchaseRecordService(repository: purchaseRecordRepository)
        _purchaseRecordService = service
        return service
    }

    private var _kilnScheduleService: KilnScheduleService?
    var kilnScheduleService: KilnScheduleService {
        if let service = _kilnScheduleService {
            return service
        }
        let service = KilnScheduleService(repository: kilnScheduleRepository)
        _kilnScheduleService = service
        return service
    }

    private var _storageLocationService: StorageLocationService?
    var storageLocationService: StorageLocationService {
        if let service = _storageLocationService {
            return service
        }
        let service = StorageLocationService(
            definitionRepository: storageLocationDefinitionRepository,
            storageLocationRepository: storageLocationRepository,
            moveRecordRepository: inventoryMoveRecordRepository,
            consumptionRecordRepository: inventoryConsumptionRecordRepository
        )
        _storageLocationService = service
        return service
    }

    private var _storageLocationMigrationService: StorageLocationMigrationService?
    var storageLocationMigrationService: StorageLocationMigrationService {
        if let service = _storageLocationMigrationService {
            return service
        }
        let service = StorageLocationMigrationService(
            inventoryRepository: inventoryRepository,
            storageLocationRepository: storageLocationRepository,
            storageLocationDefinitionRepository: storageLocationDefinitionRepository
        )
        _storageLocationMigrationService = service
        return service
    }

    private var _recipeService: RecipeService?
    var recipeService: RecipeService {
        if let service = _recipeService {
            return service
        }
        let service = RecipeService(repository: recipeRepository)
        _recipeService = service
        return service
    }

    private var _unifiedLocationService: UnifiedLocationService?
    var unifiedLocationService: UnifiedLocationService {
        if let service = _unifiedLocationService {
            return service
        }
        let service = UnifiedLocationService(repository: unifiedLocationRepository)
        _unifiedLocationService = service
        return service
    }

    private var _entitlementService: EntitlementService?
    var entitlementService: EntitlementService {
        if let service = _entitlementService {
            return service
        }
        let service = EntitlementService()
        _entitlementService = service
        return service
    }

    var subscriptionService: SubscriptionServiceProtocol {
        _subscriptionService
    }

    private var _manufacturerFilterService: ManufacturerFilterService?
    var manufacturerFilterService: ManufacturerFilterService {
        if let service = _manufacturerFilterService {
            return service
        }
        let service = ManufacturerFilterService(
            repository: userPreferencesRepository,
            availableManufacturers: GlassManufacturers.allCodes
        )
        _manufacturerFilterService = service
        return service
    }

    // Background services (created lazily)
    private var _catalogUpdateService: CatalogUpdateService?
    private var _backgroundUpdateService: BackgroundUpdateService?
    private var _dataExportService: DataExportService?
    private var _inventorySharingManager: InventorySharingManager?
    private var _backupService: BackupService?
    private var _receiptService: ReceiptService?

    // Label update services (created lazily)
    private var _labelDatabaseService: LabelDatabaseService?
    private var _labelStorageService: LabelStorageService?
    private var _labelAPIClient: LabelAPIClient?
    private var _labelUpdateService: LabelUpdateService?

    // MARK: - Initialization

    /// Initialize with custom or default persistence controller
    /// - Parameter persistenceController: Optional persistence controller (defaults to shared production controller)
    ///
    /// IMPORTANT: This initializer does NOT block waiting for Core Data initialization!
    /// Core Data repositories are created lazily on first access.
    /// LaunchScreenView is responsible for calling PersistenceController.shared.initialize()
    /// before any Core Data repositories are accessed.
    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController

        // Determine mode based on whether this is in-memory or persistent
        // In-memory stores use /dev/null paths (either "/dev/null" for single store or "/dev/null/local", "/dev/null/cloud" for two-store)
        let isInMemory = persistenceController.container.persistentStoreDescriptions.first?.url?.path.contains("/dev/null") ?? false
        self.mode = isInMemory ? .mock : .coreData

        // Create SQLite repositories (catalog data - no Core Data dependency)
        // Both production and tests use SQLite for catalog data (read-only)
        if self.mode == .mock {
            // Tests: Use bundled SQLite database directly (no Documents copy)
            guard let bundlePath = Bundle.main.path(forResource: "catalog", ofType: "sqlite") else {
                fatalError("Test mode requires bundled catalog.sqlite")
            }
            let testDbManager = TestCatalogDatabaseManager(databasePath: bundlePath)
            try! testDbManager.initialize()

            self.glassItemRepository = SQLiteGlassItemRepository(databaseManager: testDbManager)
            self.itemTagsRepository = SQLiteItemTagsRepository(databaseManager: testDbManager)
            self.coatingItemRepository = SQLiteCoatingItemRepository(databaseManager: testDbManager)
            self.toolItemRepository = SQLiteToolItemRepository(databaseManager: testDbManager)
            self.catalogFlagBundledRepository = SQLiteCatalogFlagRepository(databaseManager: testDbManager)
        } else {
            // Production: Use CatalogDatabaseManager (copies to Documents, handles OTA updates)
            // Note: CatalogDatabaseManager will be initialized lazily on first use
            self.glassItemRepository = SQLiteGlassItemRepository(databaseManager: CatalogDatabaseManager.shared)
            self.itemTagsRepository = SQLiteItemTagsRepository(databaseManager: CatalogDatabaseManager.shared)
            self.coatingItemRepository = SQLiteCoatingItemRepository(databaseManager: CatalogDatabaseManager.shared)
            self.toolItemRepository = SQLiteToolItemRepository(databaseManager: CatalogDatabaseManager.shared)
            self.catalogFlagBundledRepository = SQLiteCatalogFlagRepository(databaseManager: CatalogDatabaseManager.shared)
        }

        // UserDefaults repository (no Core Data dependency)
        self.userPreferencesRepository = UserDefaultsPreferencesRepository()

        // Create logging service (needed by other services)
        self.loggingService = Self.createLoggingService(isTestMode: self.mode == .mock)

        // Create subscription service (not lazy because it's passed through)
        self._subscriptionService = RevenueCatSubscriptionService()

        // All Core Data repositories are created lazily when first accessed
        // This allows the app to start immediately without blocking for Core Data initialization
        // LaunchScreenView will call PersistenceController.shared.initialize() before any access
    }

    // MARK: - Service Setup Helper

    /// Create logging service with appropriate backends
    /// - Parameter isTestMode: Whether running in test mode (uses MockLogger)
    private static func createLoggingService(isTestMode: Bool) -> LoggingService {
        if isTestMode {
            // In test mode, use mock logger only
            let mockLogger = MockLogger()
            return LoggingService(
                backends: [mockLogger],
                minimumLocalLevel: .debug,
                minimumRemoteLevel: .error
            )
        } else {
            // Production: Use OSLog for local logging
            // Remote error tracking (Sentry) was removed to simplify launch
            // Apple's TestFlight/App Store crash reports provide similar functionality
            return LoggingService(
                backends: [],  // OSLog is used internally by LoggingService
                minimumLocalLevel: .debug,
                minimumRemoteLevel: .error
            )
        }
    }

    // MARK: - Lazy Services

    /// Catalog update service (created lazily)
    var catalogUpdateService: CatalogUpdateService {
        if let service = _catalogUpdateService {
            return service
        }
        let service = CatalogUpdateService(
            apiClient: CatalogAPIClient(),
            storageService: try! CatalogStorageService(),
            databaseManager: CatalogDatabaseManager.shared,
            networkMonitor: NetworkMonitor.shared
        )
        _catalogUpdateService = service
        return service
    }

    /// Background update service (created lazily)
    var backgroundUpdateService: BackgroundUpdateService {
        if let service = _backgroundUpdateService {
            return service
        }
        let service = BackgroundUpdateService(
            updateService: catalogUpdateService,
            labelUpdateService: labelUpdateService,
            networkMonitor: NetworkMonitor.shared
        )
        _backgroundUpdateService = service
        return service
    }

    /// Data export service (created lazily)
    var dataExportService: DataExportService {
        if let service = _dataExportService {
            return service
        }
        #if os(iOS)
        let service = DataExportService(
            catalogService: catalogService,
            inventoryService: inventoryTrackingService,
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            purchaseRecordRepository: purchaseRecordRepository,
            userNotesRepository: userNotesRepository,
            userImageRepository: userImageRepository
        )
        #else
        let service = DataExportService(
            catalogService: catalogService,
            inventoryService: inventoryTrackingService,
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            purchaseRecordRepository: purchaseRecordRepository,
            userNotesRepository: userNotesRepository
        )
        #endif
        _dataExportService = service
        return service
    }

    /// Inventory sharing manager (created lazily)
    var inventorySharingManager: InventorySharingManager {
        if let manager = _inventorySharingManager {
            return manager
        }

        // Use the convenience init which handles all the setup
        let manager = InventorySharingManager(deps: self)

        _inventorySharingManager = manager
        return manager
    }

    /// Backup service (created lazily)
    var backupService: BackupService {
        if let service = _backupService {
            return service
        }
        let service = BackupService(
            inventoryRepository: inventoryRepository,
            storageLocationDefinitionRepository: storageLocationDefinitionRepository
        )
        _backupService = service
        return service
    }

    /// Receipt service (created lazily)
    var receiptService: ReceiptService {
        if let service = _receiptService {
            return service
        }
        let service = ReceiptService()
        _receiptService = service
        return service
    }

    // MARK: - Label Update Services

    /// Label database service (created lazily)
    var labelDatabaseService: LabelDatabaseService {
        if let service = _labelDatabaseService {
            return service
        }
        let service = LabelDatabaseService()
        _labelDatabaseService = service
        return service
    }

    /// Label storage service (created lazily)
    var labelStorageService: LabelStorageService? {
        if let service = _labelStorageService {
            return service
        }
        do {
            let service = try LabelStorageService()
            _labelStorageService = service
            return service
        } catch {
            return nil
        }
    }

    /// Label API client (created lazily)
    var labelAPIClient: LabelAPIClient {
        if let client = _labelAPIClient {
            return client
        }
        let client = LabelAPIClient()
        _labelAPIClient = client
        return client
    }

    /// Label update service (created lazily)
    var labelUpdateService: LabelUpdateService? {
        if let service = _labelUpdateService {
            return service
        }
        guard let storageService = labelStorageService else {
            return nil
        }
        let service = LabelUpdateService(
            apiClient: labelAPIClient,
            storageService: storageService,
            databaseService: labelDatabaseService,
            networkMonitor: NetworkMonitor.shared,
            logger: loggingService
        )
        _labelUpdateService = service
        return service
    }

    // MARK: - Migrations

    /// Location definition migration (created lazily)
    private var _locationDefinitionMigration: LocationDefinitionMigration?

    var locationDefinitionMigration: LocationDefinitionMigration {
        if let migration = _locationDefinitionMigration {
            return migration
        }
        let migration = LocationDefinitionMigration(
            inventoryRepository: inventoryRepository,
            storageLocationDefinitionRepository: storageLocationDefinitionRepository
        )
        _locationDefinitionMigration = migration
        return migration
    }
}

// MARK: - Environment Key

struct AppDependenciesKey: EnvironmentKey {
    /// Default value uses AppDependencies.shared which auto-detects test environment
    static let defaultValue: AppDependencies = AppDependencies.shared
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

// MARK: - Repository Mode

enum RepositoryMode: Sendable, Equatable {
    case mock
    case coreData
}
