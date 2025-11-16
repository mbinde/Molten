//
//  DeletionHelpers.swift
//  Molten
//
//  Reusable pattern for SwiftUI .onDelete with proper animation handling
//  and immediate UI updates for cached data architectures
//
//  ⚠️ IMPORTANT: ShoppingListView uses its own custom implementation of this pattern
//  due to its complex data structure (dictionary of stores with nested items).
//  Any updates to this protocol or pattern should also be applied to ShoppingListView's
//  deleteShoppingItem() method. See ShoppingListView.swift for details.
//

import Foundation
import SwiftUI

/// Protocol for views that support swipe-to-delete with cached data
///
/// This pattern solves the common issue where:
/// 1. SwiftUI's .onDelete expects the data to update automatically
/// 2. But we use a cache layer (CatalogDataCache, etc.) that doesn't auto-update
/// 3. Immediate reload causes collection view crashes during animation
///
/// The solution:
/// 1. Delete from database
/// 2. Immediately remove from view model (updates counters, UI instantly)
/// 3. Defer full reload (prevents animation conflicts, ensures consistency)
///
/// Conforming Views:
/// - InventoryView (CompleteInventoryItemModel)
/// - ProjectsView (ProjectModel)
/// - LogbookView (LogbookModel)
/// - KilnSchedulesView (KilnSchedule)
/// - RecipesView (RecipeModel)
///
/// ⚠️ Non-conforming (custom implementation):
/// - ShoppingListView - uses custom deleteShoppingItem() due to complex nested data structure
protocol CachedDataDeletion {
    associatedtype Item: Identifiable

    /// Perform the actual database deletion
    func performDeletion(for item: Item) async throws

    /// Immediately remove item from view model cache
    func removeFromCache(_ item: Item) async

    /// Reload data from database (called after delay)
    func reloadData() async

    /// Optional: Update any derived caches (tags, filters, etc.)
    func updateDerivedCaches()
}

extension CachedDataDeletion {
    /// Default implementation - no-op for views without derived caches
    func updateDerivedCaches() {
        // Override in conforming types if needed
    }

    /// Complete deletion pattern with proper timing
    /// Call this from your .onDelete handler
    ///
    /// ⚠️ IMPORTANT: If you modify this timing or pattern, also update:
    /// - ShoppingListView.deleteShoppingItem() - custom implementation
    func deleteItem(_ item: Item) async {
        do {
            // 1. Delete from database
            try await performDeletion(for: item)

            // 2. Immediately update view model to remove the deleted item
            //    This ensures counters and other UI elements update right away
            await removeFromCache(item)

            // 3. Defer full reload to allow .onDelete animation to complete
            //    The view model uses @Observable, but we load data through a cache
            //    rather than direct Core Data observation, so we must manually trigger a reload.
            //    Delaying prevents SwiftUI collection view crashes from competing updates during animation.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
                await reloadData()
                updateDerivedCaches()
            }
        } catch {
            // On error, log and reload to restore consistency
            print("❌ Failed to delete item: \(error)")
            Task { @MainActor in
                await reloadData()
            }
        }
    }
}

/// Helper for creating .onDelete closures with proper error handling
struct DeletionHandler {
    /// Create a standard .onDelete handler
    /// - Parameters:
    ///   - items: The array of items being displayed
    ///   - deleteAction: Async function to delete a single item
    /// - Returns: Closure suitable for .onDelete modifier
    static func createHandler<T>(
        for items: [T],
        deleteAction: @escaping (T) async -> Void
    ) -> (IndexSet) -> Void {
        return { indexSet in
            Task {
                for index in indexSet {
                    await deleteAction(items[index])
                }
            }
        }
    }
}

// MARK: - Usage Example
/*

 Example implementation in a view:

 ```swift
 struct MyView: View, CachedDataDeletion {
     @State private var viewModel: MyViewModel

     var body: some View {
         List {
             ForEach(viewModel.items, id: \.id) { item in
                 ItemRow(item: item)
             }
             .onDelete { indexSet in
                 Task {
                     for index in indexSet {
                         await deleteItem(viewModel.items[index])
                     }
                 }
             }
         }
     }

     // MARK: - CachedDataDeletion Implementation

     func performDeletion(for item: MyItem) async throws {
         // Delete from database
         try await repository.delete(id: item.id)

         // Clean up orphaned entities
         try await relatedRepository.deleteRelated(to: item.id)
     }

     func removeFromCache(_ item: MyItem) async {
         await MainActor.run {
             viewModel.items.removeAll { $0.id == item.id }
         }
     }

     func reloadData() async {
         await viewModel.loadItems()
     }

     func updateDerivedCaches() {
         updateCaches()  // Your existing cache update logic
     }
 }
 ```

 Or use the helper for simpler cases:

 ```swift
 .onDelete(perform: DeletionHandler.createHandler(
     for: viewModel.items,
     deleteAction: deleteItem
 ))
 ```

 */
