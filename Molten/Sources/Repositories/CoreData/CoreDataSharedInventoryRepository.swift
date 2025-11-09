//
//  CoreDataSharedInventoryRepository.swift
//  Molten
//
//  Repository for shared inventory snapshots stored in Core Data (Local store)
//

import Foundation
import CoreData

/// Repository for managing shared inventory snapshots in Core Data
@MainActor
class CoreDataSharedInventoryRepository {

    // MARK: - Supporting Types

    private struct ShareCodeStableIdPair: Hashable {
        let shareCode: String
        let stableId: String
    }

    // MARK: - Properties

    private let context: NSManagedObjectContext
    private let catalogRepository: GlassItemRepository

    // MARK: - Initialization

    init(context: NSManagedObjectContext, catalogRepository: GlassItemRepository) {
        self.context = context
        self.catalogRepository = catalogRepository
    }

    // MARK: - CRUD Operations

    /// Save inventory snapshot for a shared inventory (replaces existing)
    /// - Parameters:
    ///   - shareCode: Share code
    ///   - items: Array of inventory item snapshots
    func saveSnapshot(shareCode: String, items: [InventoryItemSnapshot]) throws {
        // Delete existing snapshots for this share
        try deleteSnapshot(shareCode: shareCode)

        // Create new snapshots (normalized - catalog data looked up via stable_id)
        for item in items {
            let entity = SharedInventoryItem(context: context)
            entity.setValue(shareCode, forKey: "share_code")
            entity.setValue(item.stableId, forKey: "stable_id")
            entity.setValue(item.quantity, forKey: "quantity")
            entity.setValue(item.unit, forKey: "unit")
            entity.setValue(item.location, forKey: "location")
            entity.setValue(Date(), forKey: "last_updated")

            // Save tags separately
            if let tags = item.tags {
                for tag in tags {
                    let tagEntity = SharedUserTags(context: context)
                    tagEntity.setValue(shareCode, forKey: "share_code")
                    tagEntity.setValue(item.stableId, forKey: "stable_id")
                    tagEntity.setValue(tag, forKey: "tag")
                }
            }
        }

        try context.save()
    }

    /// Get inventory snapshot for a share
    /// - Parameter shareCode: Share code
    /// - Returns: Array of inventory item snapshots
    func getSnapshot(shareCode: String) async throws -> [InventoryItemSnapshot] {
        // Fetch inventory items
        let fetchRequest: NSFetchRequest<SharedInventoryItem> = SharedInventoryItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "share_code == %@", shareCode)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "stable_id", ascending: true)]

        let items = try context.fetch(fetchRequest)

        // Fetch all tags for this share in one query
        let tagFetchRequest: NSFetchRequest<SharedUserTags> = SharedUserTags.fetchRequest()
        tagFetchRequest.predicate = NSPredicate(format: "share_code == %@", shareCode)
        let allTags = try context.fetch(tagFetchRequest)

        // Group tags by stable_id
        var tagsByStableId: [String: [String]] = [:]
        for tag in allTags {
            if let stableId = tag.value(forKey: "stable_id") as? String,
               let tagValue = tag.value(forKey: "tag") as? String {
                tagsByStableId[stableId, default: []].append(tagValue)
            }
        }

        // Convert to snapshots, looking up catalog data
        var snapshots: [InventoryItemSnapshot] = []
        for item in items {
            guard let stableId = item.value(forKey: "stable_id") as? String,
                  let unit = item.value(forKey: "unit") as? String else {
                continue
            }

            // Look up catalog data from GlassItem
            guard let glassItem = try? await catalogRepository.fetchItem(byStableId: stableId) else {
                // Item not in catalog - skip it
                continue
            }

            let quantity = item.value(forKey: "quantity") as? Double ?? 0.0
            let location = item.value(forKey: "location") as? String

            snapshots.append(InventoryItemSnapshot(
                stableId: stableId,
                manufacturer: glassItem.manufacturer ?? "",
                sku: glassItem.sku ?? "",
                quantity: quantity,
                unit: unit,
                location: location,
                tags: tagsByStableId[stableId]
            ))
        }
        return snapshots
    }

    /// Delete inventory snapshot for a share
    /// - Parameter shareCode: Share code
    func deleteSnapshot(shareCode: String) throws {
        // Use regular delete instead of batch delete since we're operating on the same context
        // that will immediately create new objects (batch delete causes cache issues)

        // Delete inventory items
        let itemFetchRequest: NSFetchRequest<SharedInventoryItem> = SharedInventoryItem.fetchRequest()
        itemFetchRequest.predicate = NSPredicate(format: "share_code == %@", shareCode)
        let items = try context.fetch(itemFetchRequest)
        for item in items {
            context.delete(item)
        }

        // Delete tags
        let tagFetchRequest: NSFetchRequest<SharedUserTags> = SharedUserTags.fetchRequest()
        tagFetchRequest.predicate = NSPredicate(format: "share_code == %@", shareCode)
        let tags = try context.fetch(tagFetchRequest)
        for tag in tags {
            context.delete(tag)
        }

        // Note: saveSnapshot will call context.save() after creating new objects
    }

    /// Get all items with a specific tag from any shared inventory
    /// - Parameter tag: Tag to search for
    /// - Returns: Array of snapshots with that tag
    func getItemsWithTag(tag: String) async throws -> [InventoryItemSnapshot] {
        // Fetch all tags matching this tag
        let tagFetchRequest: NSFetchRequest<SharedUserTags> = SharedUserTags.fetchRequest()
        tagFetchRequest.predicate = NSPredicate(format: "tag == %@", tag)

        let tags = try context.fetch(tagFetchRequest)

        // Get unique combinations of (share_code, stable_id)
        let uniqueItems = Set(tags.compactMap { tag -> ShareCodeStableIdPair? in
            guard let shareCode = tag.value(forKey: "share_code") as? String,
                  let stableId = tag.value(forKey: "stable_id") as? String else { return nil }
            return ShareCodeStableIdPair(shareCode: shareCode, stableId: stableId)
        })

        // Fetch full inventory items for these combinations
        var results: [InventoryItemSnapshot] = []
        for pair in uniqueItems {
            let itemFetchRequest: NSFetchRequest<SharedInventoryItem> = SharedInventoryItem.fetchRequest()
            itemFetchRequest.predicate = NSPredicate(format: "share_code == %@ AND stable_id == %@", pair.shareCode, pair.stableId)
            itemFetchRequest.fetchLimit = 1

            if let item = try context.fetch(itemFetchRequest).first,
               let itemStableId = item.value(forKey: "stable_id") as? String,
               let unit = item.value(forKey: "unit") as? String,
               let glassItem = try? await catalogRepository.fetchItem(byStableId: itemStableId) {

                // Get all tags for this item
                let itemTagFetchRequest: NSFetchRequest<SharedUserTags> = SharedUserTags.fetchRequest()
                itemTagFetchRequest.predicate = NSPredicate(format: "share_code == %@ AND stable_id == %@", pair.shareCode, pair.stableId)
                let itemTags = try context.fetch(itemTagFetchRequest).compactMap {
                    $0.value(forKey: "tag") as? String
                }

                let quantity = item.value(forKey: "quantity") as? Double ?? 0.0
                let location = item.value(forKey: "location") as? String

                results.append(InventoryItemSnapshot(
                    stableId: itemStableId,
                    manufacturer: glassItem.manufacturer ?? "",
                    sku: glassItem.sku ?? "",
                    quantity: quantity,
                    unit: unit,
                    location: location,
                    tags: itemTags.isEmpty ? nil : itemTags
                ))
            }
        }

        return results
    }

    /// Get items that a shared inventory has but you don't
    /// - Parameters:
    ///   - shareCode: Share code
    ///   - myStableIds: Set of your inventory stable IDs
    /// - Returns: Array of items in shared inventory that you don't have
    func getItemsSharedHasThatIDont(shareCode: String, myStableIds: Set<String>) async throws -> [InventoryItemSnapshot] {
        let allSharedItems = try await getSnapshot(shareCode: shareCode)
        return allSharedItems.filter { !myStableIds.contains($0.stableId) }
    }
}
