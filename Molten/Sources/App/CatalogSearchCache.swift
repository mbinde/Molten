//
//  CatalogSearchCache.swift
//  Flameworker
//
//  Created by Assistant on 10/19/25.
//  Lightweight cache for catalog search operations that only loads GlassItemModel objects
//  without inventory, tags, or location data for maximum performance
//

import Foundation
import SwiftUI
import Combine

/// Lightweight singleton cache for catalog search data
/// Loads all catalog items (glass, coatings, tools) as UnifiedCatalogItem objects (no inventory/tags/ratings)
/// Used by search views for fast autocomplete and item selection
@MainActor
class CatalogSearchCache: ObservableObject {
    static let shared = CatalogSearchCache()

    @Published private(set) var items: [UnifiedCatalogItem] = []
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var isLoading: Bool = false

    private var loadTask: Task<Void, Never>?

    private init() {}

    /// Load catalog search data if not already loaded
    /// Returns immediately if data is already loaded or loading
    func loadIfNeeded(catalogService: CatalogService) async {
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

    /// Force reload of catalog search data
    func reload(catalogService: CatalogService) async {
        isLoaded = false
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

    private func performLoad(catalogService: CatalogService) async {
        isLoading = true

        do {
            let loadedItems = try await catalogService.getAllCatalogItemsLightweight()
            items = loadedItems
            isLoaded = true
        } catch {
            // Keep cache in "not loaded" state so it will retry
            items = []
            isLoaded = false
        }

        isLoading = false
    }

    // MARK: - Convenience Helper

    /// Convenience method to load items using the search cache
    /// Always use this for search/autocomplete functionality
    /// For full item data with inventory/tags, use CatalogDataCache instead
    static func loadItems(using catalogService: CatalogService) async -> [UnifiedCatalogItem] {
        let cache = CatalogSearchCache.shared
        await cache.loadIfNeeded(catalogService: catalogService)
        return cache.items
    }
}
