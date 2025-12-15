//
//  CatalogDataCache.swift
//  Flameworker
//
//  Created by Assistant on 10/18/25.
//  App-level singleton cache for catalog data to avoid repeated Core Data queries
//

import Foundation
import SwiftUI
import Combine
import CoreData
import OSLog

/// Singleton cache for catalog data to improve performance
/// Prevents repeated expensive Core Data queries when switching tabs
@MainActor
class CatalogDataCache: ObservableObject {
    static let shared = CatalogDataCache()

    @Published private(set) var items: [CompleteInventoryItemModel] = []
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var isLoading: Bool = false

    /// Items after applying filters (manufacturer, COE, tags, product type) but BEFORE search.
    /// Used by GlobalSearchOverlay to constrain search to filtered results.
    /// Updated by CatalogViewModel when filters change.
    @Published var filteredItemsWithoutSearch: [CompleteInventoryItemModel]?

    private var loadTask: Task<Void, Never>?
    private weak var catalogService: CatalogService?

    // Non-isolated storage for Combine subscriptions (safe because Combine is thread-safe)
    nonisolated(unsafe) private var cancellables = Set<AnyCancellable>()

    private init() {
        setupDataChangeObserver()
    }

    /// Load catalog data if not already loaded
    /// Returns immediately if data is already loaded or loading
    func loadIfNeeded(catalogService: CatalogService) async {
        // Store reference to catalog service for auto-reload
        if self.catalogService == nil {
            self.catalogService = catalogService
        }

        // If already loaded or currently loading, return immediately
        guard !isLoaded && !isLoading else {
            return
        }

        // If there's an existing load task, wait for it
        if let existingTask = loadTask {
            await existingTask.value
            return
        }

        // Start new load task
        let task = Task {
            await performLoad(catalogService: catalogService)
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// Force reload of catalog data
    func reload(catalogService: CatalogService) async {
        // Cancel any existing load task to ensure we get fresh data
        loadTask?.cancel()
        loadTask = nil
        isLoaded = false
        isLoading = false

        // Now start a fresh load
        await loadIfNeeded(catalogService: catalogService)
    }

    /// Clear the cache (for testing or logout scenarios)
    func clear() {
        items = []
        isLoaded = false
        isLoading = false
        loadTask?.cancel()
        loadTask = nil
    }

    // MARK: - Auto-Invalidation

    /// Setup observer for Core Data changes to auto-invalidate cache
    /// This ensures the cache stays fresh when inventory, tags, or other data changes
    /// Note: Auto-reload is disabled in test environments to avoid race conditions
    nonisolated private func setupDataChangeObserver() {
        // Skip auto-reload in tests to avoid race conditions with test setup
        // Tests should explicitly call reload() when they need fresh data
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }
        #endif

        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                // Check if the notification contains changes to entities we care about
                guard let userInfo = notification.userInfo else { return }

                // Check for changes to Inventory, UserTags, UserNotes, or ItemTags
                let relevantEntityNames = ["Inventory", "UserTags", "UserNotes", "ItemTags", "ItemRating"]
                var hasRelevantChanges = false

                for key in [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey] {
                    if let objects = userInfo[key] as? Set<NSManagedObject> {
                        for object in objects {
                            if relevantEntityNames.contains(object.entity.name ?? "") {
                                hasRelevantChanges = true
                                break
                            }
                        }
                    }
                    if hasRelevantChanges { break }
                }

                // If we have relevant changes, invalidate and reload cache
                // Use MainActor.run to properly isolate the state updates
                if hasRelevantChanges {
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if let service = self.catalogService {
                            await self.reload(catalogService: service)
                        } else {
                            // Just invalidate if we don't have a service reference yet
                            self.isLoaded = false
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func performLoad(catalogService: CatalogService) async {
        isLoading = true

        #if DEBUG
        let log = Logger(subsystem: "com.motleywoods.molten", category: "uitest-debug")
        log.warning("📦 [CatalogDataCache] performLoad starting...")
        #endif

        do {
            let loadedItems = try await catalogService.getAllGlassItems()

            #if DEBUG
            let itemsWithInventory = loadedItems.filter { $0.totalQuantity > 0 }
            log.warning("📦 [CatalogDataCache] Loaded \(loadedItems.count) items, \(itemsWithInventory.count) with inventory")
            #endif

            items = loadedItems
            isLoaded = true
        } catch {
            #if DEBUG
            log.error("❌ [CatalogDataCache] performLoad failed: \(error.localizedDescription)")
            #endif
            // Keep cache in "not loaded" state so it will retry
            items = []
            isLoaded = false
        }

        isLoading = false
    }

    // MARK: - Convenience Helper

    /// Convenience method to load items using the cache
    /// Always use this instead of calling catalogService.getAllGlassItems() directly
    /// to ensure consistent cache usage across the app
    /// IMPORTANT: Must be @MainActor to ensure thread-safe access to shared instance and items
    @MainActor
    static func loadItems(using catalogService: CatalogService) async -> [CompleteInventoryItemModel] {
        let cache = CatalogDataCache.shared
        await cache.loadIfNeeded(catalogService: catalogService)
        return cache.items
    }
}
