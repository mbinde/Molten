//
//  CloudKitResyncMigration.swift
//  Molten
//
//  One-time migration to force CloudKit sync for all existing records.
//  This is needed because records created before CloudKit schema was properly
//  initialized have no persistent history entries and won't sync.
//
//  This migration "touches" all records by updating a timestamp field,
//  which creates history entries and triggers CloudKit export.
//

import Foundation
import CoreData
import OSLog

/// One-time migration to force all existing Cloud records to sync to CloudKit
enum CloudKitResyncMigration {

    nonisolated private static let log = Logger(subsystem: "com.motleywoods.molten", category: "cloudkit-resync")
    nonisolated private static let migrationKey = "cloudkit-resync-migration-v1"

    /// All entity names in the Cloud configuration that need to be resynced
    nonisolated private static let cloudEntities: [String] = [
        "Inventory",
        "InventoryConsumptionRecord",
        "InventoryItem",
        "InventoryMoveRecord",
        "ItemDimensions",
        "ItemMinimum",
        "ItemShopping",
        "KilnScheduleEntity",
        "KilnSegmentEntity",
        "StorageLocation",
        "Logbook",
        "LogbookGlassItem",
        "Project",
        "ProjectGlassItem",
        "ProjectImage",
        "ProjectReferenceUrl",
        "ProjectStep",
        "ProjectStepGlassItem",
        "ProjectTechnique",
        "PurchaseRecord",
        "PurchaseRecordItem",
        "Recipe",
        "RecipeIngredient",
        "ShareRecord",
        "UserImage",
        "UserItem",
        "UserNotes",
        "UserTags",
        "PendingRatingSubmission",
        "LabelPresetEntity",
        "ExpiringShareRecord",
        "SharedInventoryItem",
        "SharedUserTags",
        "StorageLocationDefinition",
        "Workspace",
        "GlassPalette",
        "WigWagTwistPattern",
        "TwistCane",
        "Location",
        "LocationEducation",
        "LocationRetail",
        "LocationServices",
        "ItemRating",
        "ItemRatingWord"
    ]

    /// Run the migration if it hasn't been run before
    /// - Parameter context: The cloud context to use for the migration
    nonisolated static func runIfNeeded(context: NSManagedObjectContext) async {
        // Check if already run
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            log.debug("CloudKit resync migration already completed, skipping")
            return
        }

        log.info("🔄 Starting CloudKit resync migration...")

        let result: (touched: Int, success: Bool) = await context.perform {
            var totalRecordsTouched = 0

            for entityName in cloudEntities {
                do {
                    let count = try touchAllRecords(entityName: entityName, context: context)
                    if count > 0 {
                        log.info("   ✓ \(entityName): \(count) records")
                        totalRecordsTouched += count
                    }
                } catch {
                    // Entity might not exist in older model versions, just skip
                    log.debug("   - \(entityName): skipped (\(error.localizedDescription))")
                }
            }

            // Save all changes
            if context.hasChanges {
                do {
                    try context.save()
                    log.info("✅ CloudKit resync migration saved \(totalRecordsTouched) records")
                    return (totalRecordsTouched, true)
                } catch {
                    log.error("❌ CloudKit resync migration save failed: \(error.localizedDescription)")
                    return (totalRecordsTouched, false)
                }
            }

            return (totalRecordsTouched, true)
        }

        guard result.success else { return }

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)
        log.info("✅ CloudKit resync migration completed - \(result.touched) total records touched")
    }

    /// Touch all records of a given entity type to trigger CloudKit sync
    /// - Parameters:
    ///   - entityName: The Core Data entity name
    ///   - context: The managed object context
    /// - Returns: Number of records touched
    nonisolated private static func touchAllRecords(entityName: String, context: NSManagedObjectContext) throws -> Int {
        // Check if entity exists in the model before attempting fetch
        // This prevents crashes on older model versions that don't have newer entities
        guard let model = context.persistentStoreCoordinator?.managedObjectModel,
              model.entitiesByName[entityName] != nil else {
            return 0
        }

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        let records = try context.fetch(fetchRequest)

        guard !records.isEmpty else { return 0 }

        // Find a suitable field to touch
        // Most entities have 'updated_at', 'date_modified', or similar
        // If not, we can touch any optional field

        for record in records {
            // Try common timestamp fields first
            if touchTimestampField(record, fieldName: "updated_at") { continue }
            if touchTimestampField(record, fieldName: "date_modified") { continue }
            if touchTimestampField(record, fieldName: "modified_at") { continue }
            if touchTimestampField(record, fieldName: "last_modified") { continue }

            // If no timestamp field, try to find any date field we can touch
            if touchTimestampField(record, fieldName: "date_added") { continue }
            if touchTimestampField(record, fieldName: "created_at") { continue }

            // Last resort: touch the record by setting any existing value to itself
            // This still marks it as dirty
            touchAnyField(record)
        }

        return records.count
    }

    /// Attempt to touch a timestamp field by setting it to current date
    /// - Returns: true if the field exists and was touched
    nonisolated private static func touchTimestampField(_ record: NSManagedObject, fieldName: String) -> Bool {
        guard record.entity.attributesByName[fieldName] != nil else {
            return false
        }

        // Set to current date to mark as modified
        record.setValue(Date(), forKey: fieldName)
        return true
    }

    /// Touch any field to mark the record as dirty
    nonisolated private static func touchAnyField(_ record: NSManagedObject) {
        // Find the first attribute and set it to its current value
        // This marks the record as dirty without changing data
        for (name, _) in record.entity.attributesByName {
            let currentValue = record.value(forKey: name)
            record.setValue(currentValue, forKey: name)
            break // Only need to touch one field
        }
    }

    /// Reset the migration flag (for testing purposes)
    nonisolated static func resetMigrationFlag() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        log.info("CloudKit resync migration flag reset")
    }
}
