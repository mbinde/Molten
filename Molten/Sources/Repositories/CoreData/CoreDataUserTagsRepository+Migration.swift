//
//  CoreDataUserTagsRepository+Migration.swift
//  Flameworker
//
//  Created by Assistant on 10/16/25.
//
//  Schema migration support for UserTags (Old schema → New schema)
//  Migrates from item_stable_id-only to owner_type+owner_id
//

@preconcurrency import CoreData
import Foundation
import OSLog

extension CoreDataUserTagsRepository {

    // MARK: - Migration Support (Old Schema → New Schema)

    /// Check if a UserTags entity needs migration
    static func needsMigration(_ entity: NSManagedObject) -> Bool {
        return entity.value(forKey: "owner_type") == nil
    }

    /// Migrate a single UserTags entity from old to new schema
    /// Old schema: item_stable_id only
    /// New schema: owner_type + owner_id
    static func migrateEntity(_ entity: NSManagedObject, context: NSManagedObjectContext, log: Logger) throws {
        guard needsMigration(entity) else { return }

        // Old records only have item_stable_id, so they're all glass items
        if let itemKey = entity.value(forKey: "item_stable_id") as? String {
            entity.setValue("glassItem", forKey: "owner_type")
            entity.setValue(itemKey, forKey: "owner_id")
            log.debug("Migrated UserTag: \(itemKey)")
        } else {
            // Invalid record (no item_stable_id), delete it
            context.delete(entity)
            log.warning("Deleted invalid UserTag record (no item_stable_id)")
        }
    }

    /// Migrate all unmigrated UserTags records (runs in background on init)
    static func migrateAllRecordsIfNeeded(context: NSManagedObjectContext) async throws {
        let log = Logger(subsystem: "com.flameworker.app", category: "usertags-migration")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.perform {
                do {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                    fetchRequest.predicate = NSPredicate(format: "owner_type == nil")

                    let unmigrated = try context.fetch(fetchRequest)

                    guard !unmigrated.isEmpty else {
                        continuation.resume()
                        return
                    }

                    log.info("Migrating \(unmigrated.count) UserTags records...")

                    for entity in unmigrated {
                        try self.migrateEntity(entity, context: context, log: log)
                    }

                    try context.save()
                    log.info("UserTags migration complete: \(unmigrated.count) records migrated")

                    continuation.resume()
                } catch {
                    log.error("UserTags migration failed: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Migrate entities on-demand when accessed (lazy migration fallback)
    func migrateEntitiesIfNeeded(_ entities: [NSManagedObject], context: NSManagedObjectContext, log: Logger) throws {
        var needsSave = false

        for entity in entities {
            if Self.needsMigration(entity) {
                try Self.migrateEntity(entity, context: context, log: log)
                needsSave = true
            }
        }

        if needsSave {
            try context.save()
        }
    }
}
