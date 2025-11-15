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
/// Only loads GlassItemModel objects (no inventory/tags/locations)
/// Used by search views for fast autocomplete and item selection
@MainActor
class CatalogSearchCache: ObservableObject {
    static let shared = CatalogSearchCache()

    @Published private(set) var items: [GlassItemModel] = []
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
            let loadedItems = try await catalogService.getGlassItemsLightweight()

            items = loadedItems
            isLoaded = true

            // Debug: Check if "50 Shades" is in the loaded items
            if let fiftyShades = loadedItems.first(where: { $0.name.contains("50 Shades") }) {
                print("🔍 [CACHE] Found '50 Shades' with stable_id: '\(fiftyShades.stable_id)'")
            } else {
                print("❌ [CACHE] '50 Shades' NOT found in loaded items")
            }

            // Debug: Check if stableId '5bfSaX' exists
            if let item = loadedItems.first(where: { $0.stable_id == "5bfSaX" }) {
                print("🔍 [CACHE] Found stableId '5bfSaX': '\(item.name)'")
            } else {
                print("❌ [CACHE] StableId '5bfSaX' NOT found in loaded items")
                // Show a few sample stableIds
                print("📋 [CACHE] Sample stableIds from cache:")
                loadedItems.prefix(5).forEach { item in
                    print("   - '\(item.stable_id)' → '\(item.name)'")
                }
            }
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
    static func loadItems(using catalogService: CatalogService) async -> [GlassItemModel] {
        let cache = CatalogSearchCache.shared
        await cache.loadIfNeeded(catalogService: catalogService)
        return cache.items
    }
}
