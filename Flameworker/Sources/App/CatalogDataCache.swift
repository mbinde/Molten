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

/// Singleton cache for catalog data to improve performance
/// Prevents repeated expensive Core Data queries when switching tabs
@MainActor
class CatalogDataCache: ObservableObject {
    static let shared = CatalogDataCache()

    @Published private(set) var items: [CompleteInventoryItemModel] = []
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var isLoading: Bool = false

    private var loadTask: Task<Void, Never>?

    private init() {}

    /// Load catalog data if not already loaded
    /// Returns immediately if data is already loaded or loading
    func loadIfNeeded(catalogService: CatalogService) async {
        // If already loaded or currently loading, return immediately
        guard !isLoaded && !isLoading else {
            print("📦 Cache: Data already loaded or loading, skipping")
            return
        }

        // If there's an existing load task, wait for it
        if let existingTask = loadTask {
            print("📦 Cache: Waiting for existing load task...")
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
        print("📦 Cache: Force reload requested")
        isLoaded = false
        await loadIfNeeded(catalogService: catalogService)
    }

    /// Clear the cache (for testing or logout scenarios)
    func clear() {
        print("📦 Cache: Clearing cache")
        items = []
        isLoaded = false
        isLoading = false
        loadTask?.cancel()
        loadTask = nil
    }

    private func performLoad(catalogService: CatalogService) async {
        print("📦 Cache: Starting load...")
        isLoading = true

        do {
            let loadedItems = try await catalogService.getAllGlassItems()
            print("📦 Cache: Loaded \(loadedItems.count) items")

            items = loadedItems
            isLoaded = true
        } catch {
            print("📦 Cache: Load failed: \(error)")
            // Keep cache in "not loaded" state so it will retry
            items = []
            isLoaded = false
        }

        isLoading = false
    }
}
