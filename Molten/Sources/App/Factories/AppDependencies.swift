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

    let persistenceController: PersistenceController
    let mode: RepositoryMode

    var isReady: Bool { persistenceController.isReady }

    // MARK: - Lazy Instance Cache

    /// Generic lazy loader - creates instance on first access, caches by type
    private var cache: [ObjectIdentifier: Any] = [:]

    private func lazy<T>(_ factory: () -> T) -> T {
        let key = ObjectIdentifier(T.self)
        if let existing = cache[key] as? T { return existing }
        let instance = factory()
        cache[key] = instance
        return instance
    }

    // MARK: - SQLite Repositories (initialized eagerly - no Core Data dependency)

    let glassItemRepository: GlassItemRepository
    let coatingItemRepository: CoatingItemRepository
    let toolItemRepository: ToolItemRepository
    let itemTagsRepository: ItemTagsRepository
    let userPreferencesRepository: UserPreferencesRepository

    // MARK: - Core Data Repositories (lazy - created after initialization)

    var inventoryRepository: InventoryRepository {
        lazy { CoreDataInventoryRepository(context: persistenceController.cloudContext) }
    }
    var storageLocationRepository: StorageLocationRepository {
        lazy { CoreDataStorageLocationRepository(context: persistenceController.cloudContext) }
    }
    var userTagsRepository: UserTagsRepository {
        lazy { CoreDataUserTagsRepository(context: persistenceController.cloudContext) }
    }
    var userNotesRepository: UserNotesRepository {
        lazy { CoreDataUserNotesRepository(context: persistenceController.cloudContext) }
    }
    var shoppingListRepository: ShoppingListRepository {
        lazy { CoreDataShoppingListRepository(context: persistenceController.cloudContext) }
    }
    var itemMinimumRepository: ItemMinimumRepository {
        lazy { CoreDataItemMinimumRepository(context: persistenceController.cloudContext) }
    }
    var projectRepository: ProjectRepository {
        lazy { CoreDataProjectRepository(context: persistenceController.cloudContext) }
    }
    var logbookRepository: LogbookRepository {
        lazy { CoreDataLogbookRepository(context: persistenceController.cloudContext) }
    }
    var purchaseRecordRepository: PurchaseRecordRepository {
        lazy { CoreDataPurchaseRecordRepository(context: persistenceController.cloudContext) }
    }
    var projectImageRepository: ProjectImageRepository {
        lazy { CoreDataProjectImageRepository(context: persistenceController.cloudContext) }
    }
    var kilnScheduleRepository: KilnScheduleRepository {
        lazy { CoreDataKilnScheduleRepository(context: persistenceController.cloudContext) }
    }
    var recipeRepository: RecipeRepository {
        lazy { CoreDataRecipeRepository(context: persistenceController.cloudContext) }
    }
    var unifiedLocationRepository: UnifiedLocationRepository {
        lazy { CoreDataUnifiedLocationRepository(persistenceController: persistenceController) }
    }
    var ratingRepository: RatingRepository {
        lazy { CoreDataRatingRepository(localContext: persistenceController.localContext, cloudContext: persistenceController.cloudContext) }
    }
    var workspaceRepository: WorkspaceRepository {
        lazy { CoreDataWorkspaceRepository(context: persistenceController.cloudContext) }
    }
    var storageLocationDefinitionRepository: StorageLocationDefinitionRepository {
        lazy { CoreDataStorageLocationDefinitionRepository(context: persistenceController.cloudContext) }
    }
    #if os(iOS)
    var userImageRepository: UserImageRepository {
        lazy { CoreDataUserImageRepository(context: persistenceController.cloudContext) }
    }
    #endif

    // MARK: - Services (lazy)

    let loggingService: LoggingService
    private let _subscriptionService: SubscriptionServiceProtocol
    var subscriptionService: SubscriptionServiceProtocol { _subscriptionService }

    var defaultWorkspaceProvider: DefaultWorkspaceProvider {
        lazy { DefaultWorkspaceProvider(workspaceRepository: workspaceRepository) }
    }
    var inventoryTrackingService: InventoryTrackingService {
        lazy { InventoryTrackingService(
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            inventoryRepository: inventoryRepository,
            itemTagsRepository: itemTagsRepository
        )}
    }
    var ratingService: RatingService {
        lazy { RatingService(repository: ratingRepository, logger: loggingService) }
    }
    var catalogService: CatalogService {
        lazy { CatalogService(
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: itemMinimumRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository,
            ratingService: ratingService
        )}
    }
    var shoppingListService: ShoppingListService {
        lazy { ShoppingListService(
            itemMinimumRepository: itemMinimumRepository,
            shoppingListRepository: shoppingListRepository,
            inventoryRepository: inventoryRepository,
            glassItemRepository: glassItemRepository,
            coatingItemRepository: coatingItemRepository,
            toolItemRepository: toolItemRepository,
            itemTagsRepository: itemTagsRepository,
            userTagsRepository: userTagsRepository
        )}
    }
    var projectService: ProjectService {
        lazy { ProjectService(
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            userTagsRepository: userTagsRepository
        )}
    }
    var purchaseRecordService: PurchaseRecordService {
        lazy { PurchaseRecordService(repository: purchaseRecordRepository) }
    }
    var kilnScheduleService: KilnScheduleService {
        lazy { KilnScheduleService(repository: kilnScheduleRepository) }
    }
    var storageLocationService: StorageLocationService {
        lazy { StorageLocationService(
            definitionRepository: storageLocationDefinitionRepository,
            storageLocationRepository: storageLocationRepository
        )}
    }
    var recipeService: RecipeService {
        lazy { RecipeService(repository: recipeRepository) }
    }
    var unifiedLocationService: UnifiedLocationService {
        lazy { UnifiedLocationService(repository: unifiedLocationRepository) }
    }
    var entitlementService: EntitlementService {
        lazy { EntitlementService() }
    }
    var manufacturerFilterService: ManufacturerFilterService {
        lazy { ManufacturerFilterService(
            repository: userPreferencesRepository,
            availableManufacturers: GlassManufacturers.allCodes
        )}
    }
    var catalogUpdateService: CatalogUpdateService {
        lazy { CatalogUpdateService(
            apiClient: CatalogAPIClient(),
            storageService: try! CatalogStorageService(),
            databaseManager: CatalogDatabaseManager.shared,
            networkMonitor: NetworkMonitor.shared
        )}
    }
    var backgroundUpdateService: BackgroundUpdateService {
        lazy { BackgroundUpdateService(
            updateService: catalogUpdateService,
            networkMonitor: NetworkMonitor.shared
        )}
    }
    var inventorySharingManager: InventorySharingManager {
        lazy { InventorySharingManager(deps: self) }
    }
    var backupService: BackupService {
        lazy { BackupService(inventoryRepository: inventoryRepository) }
    }
    #if os(iOS)
    var dataExportService: DataExportService {
        lazy { DataExportService(
            catalogService: catalogService,
            inventoryService: inventoryTrackingService,
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            purchaseRecordRepository: purchaseRecordRepository,
            userNotesRepository: userNotesRepository,
            userImageRepository: userImageRepository
        )}
    }
    #else
    var dataExportService: DataExportService {
        lazy { DataExportService(
            catalogService: catalogService,
            inventoryService: inventoryTrackingService,
            projectRepository: projectRepository,
            logbookRepository: logbookRepository,
            purchaseRecordRepository: purchaseRecordRepository,
            userNotesRepository: userNotesRepository
        )}
    }
    #endif

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
        } else {
            // Production: Use CatalogDatabaseManager (copies to Documents, handles OTA updates)
            // Note: CatalogDatabaseManager will be initialized lazily on first use
            self.glassItemRepository = SQLiteGlassItemRepository(databaseManager: CatalogDatabaseManager.shared)
            self.itemTagsRepository = SQLiteItemTagsRepository(databaseManager: CatalogDatabaseManager.shared)
            self.coatingItemRepository = SQLiteCoatingItemRepository(databaseManager: CatalogDatabaseManager.shared)
            self.toolItemRepository = SQLiteToolItemRepository(databaseManager: CatalogDatabaseManager.shared)
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
