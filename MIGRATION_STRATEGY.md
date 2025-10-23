# UserTags Migration Strategy - Optional Attributes + Runtime Migration

## Overview
Since Core Data migrations with non-optional attributes can be problematic, we'll use a two-phase approach:
1. **Phase 1**: Add `owner_type` and `owner_id` as **optional** attributes in Core Data
2. **Phase 2**: Migrate data at runtime when the app starts

## Phase 1: Core Data Model (What You Did)

✅ You've already done this:
- Created new model version
- Added `owner_type` (String, **optional**)
- Added `owner_id` (String, **optional**)
- Kept `item_natural_key` (String, optional)
- Deleted broken `tags` relationships from Project and Logbook

## Phase 2: Runtime Migration Strategy

We'll handle migration in `CoreDataUserTagsRepository` with these approaches:

### Approach A: Lazy Migration (Recommended)
Migrate records on-demand as they're accessed:

```swift
// When fetching tags, check if migration is needed
private func ensureMigrated(_ entity: NSManagedObject) {
    // If owner_type is nil, this is an old record
    if entity.value(forKey: "owner_type") == nil {
        // Migrate: copy item_natural_key → owner_id, set owner_type = "glassItem"
        if let itemKey = entity.value(forKey: "item_natural_key") as? String {
            entity.setValue("glassItem", forKey: "owner_type")
            entity.setValue(itemKey, forKey: "owner_id")
            try? backgroundContext.save()
        }
    }
}
```

**Pros**:
- No upfront migration time
- Migrates only data that's actually used
- Safe and gradual

**Cons**:
- Migration happens over time
- Need to check every record on access

### Approach B: Eager Migration (Alternative)
Migrate all records at app startup:

```swift
func migrateAllRecordsIfNeeded() async throws {
    // Check if migration is needed (look for any records with nil owner_type)
    let unmigrated = try await fetchUnmigratedRecords()

    if !unmigrated.isEmpty {
        print("Migrating \(unmigrated.count) UserTags records...")
        for entity in unmigrated {
            if let itemKey = entity.value(forKey: "item_natural_key") as? String {
                entity.setValue("glassItem", forKey: "owner_type")
                entity.setValue(itemKey, forKey: "owner_id")
            }
        }
        try backgroundContext.save()
        print("Migration complete!")
    }
}
```

**Pros**:
- All data migrated upfront
- Cleaner runtime code (no per-record checks)

**Cons**:
- Startup delay if many records
- All-or-nothing approach

### Approach C: Hybrid (Best of Both Worlds)
Use lazy migration with a background job:

```swift
// Lazy migration on access (immediate)
+
// Background migration task (gradual cleanup)
Task.detached {
    try? await migrateAllRecordsIfNeeded()
}
```

## Recommended Implementation

I'll implement **Approach C (Hybrid)**:

1. **Immediate**: Check and migrate records on access (lazy)
2. **Background**: Kick off a background task to migrate remaining records
3. **Future-proof**: After migration period (e.g., 1-2 app versions), we can:
   - Make attributes non-optional in a future model version
   - Remove migration code

## Code Changes I'll Make

### 1. Add Migration Helpers to CoreDataUserTagsRepository

```swift
// MARK: - Migration Support

/// Check if a UserTags entity needs migration
private func needsMigration(_ entity: NSManagedObject) -> Bool {
    return entity.value(forKey: "owner_type") == nil
}

/// Migrate a single UserTags entity from old to new schema
private func migrateEntity(_ entity: NSManagedObject) throws {
    guard needsMigration(entity) else { return }

    // Old records only have item_natural_key, so they're all glass items
    if let itemKey = entity.value(forKey: "item_natural_key") as? String {
        entity.setValue("glassItem", forKey: "owner_type")
        entity.setValue(itemKey, forKey: "owner_id")
        log.debug("Migrated UserTag: \(itemKey)")
    } else {
        // Invalid record, delete it
        backgroundContext.delete(entity)
        log.warning("Deleted invalid UserTag record (no item_natural_key)")
    }
}

/// Migrate all unmigrated UserTags records (background task)
func migrateAllRecordsIfNeeded() async throws {
    try await withCheckedThrowingContinuation { continuation in
        backgroundContext.perform {
            do {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                fetchRequest.predicate = NSPredicate(format: "owner_type == nil")

                let unmigrated = try self.backgroundContext.fetch(fetchRequest)

                guard !unmigrated.isEmpty else {
                    self.log.info("No UserTags records need migration")
                    continuation.resume()
                    return
                }

                self.log.info("Migrating \(unmigrated.count) UserTags records...")

                for entity in unmigrated {
                    try self.migrateEntity(entity)
                }

                try self.backgroundContext.save()
                self.log.info("UserTags migration complete: \(unmigrated.count) records migrated")

                continuation.resume()
            } catch {
                self.log.error("UserTags migration failed: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### 2. Update Fetch Methods to Auto-Migrate

```swift
// Example: fetchTags now migrates on access
func fetchTags(forItem itemNaturalKey: String) async throws -> [String] {
    return try await withCheckedThrowingContinuation { continuation in
        backgroundContext.perform {
            do {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
                fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@", itemNaturalKey)

                let coreDataItems = try self.backgroundContext.fetch(fetchRequest)

                // Migrate any unmigrated records on access
                var needsSave = false
                for entity in coreDataItems {
                    if self.needsMigration(entity) {
                        try self.migrateEntity(entity)
                        needsSave = true
                    }
                }

                if needsSave {
                    try self.backgroundContext.save()
                }

                let tags = coreDataItems.compactMap { $0.value(forKey: "tag") as? String }
                continuation.resume(returning: tags)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### 3. Call Migration on Repository Initialization

```swift
init(userTagsPersistentContainer persistentContainer: NSPersistentContainer) {
    self.persistentContainer = persistentContainer
    self.backgroundContext = persistentContainer.newBackgroundContext()
    self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

    // Kick off background migration
    Task.detached {
        try? await self.migrateAllRecordsIfNeeded()
    }
}
```

## Validation & Testing

After migration, I'll add validation:

```swift
// Ensure all records have owner_type and owner_id
private func validateMigration() async throws {
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserTags")
    fetchRequest.predicate = NSPredicate(format: "owner_type == nil OR owner_id == nil")

    let unmigrated = try await backgroundContext.perform {
        try self.backgroundContext.fetch(fetchRequest)
    }

    if !unmigrated.isEmpty {
        log.warning("Found \(unmigrated.count) unmigrated UserTags records")
    }
}
```

## Future Cleanup (Version N+2)

After 1-2 app versions, when we're confident all users have migrated:

1. Create new model version
2. Remove `item_natural_key` attribute (no longer needed)
3. Make `owner_type` and `owner_id` non-optional
4. Remove migration code from repository

## Summary

This approach:
- ✅ Avoids Core Data migration issues with non-optional attributes
- ✅ Migrates data safely at runtime
- ✅ Works incrementally (lazy) and comprehensively (background task)
- ✅ Handles edge cases (invalid records)
- ✅ Easy to test and validate
- ✅ Clean migration path to final schema

## Next Steps

I'll now:
1. Update `CoreDataUserTagsRepository` with migration logic
2. Implement new generic methods (`fetchTags(ownerType:ownerId:)`, etc.)
3. Keep legacy methods working (they'll auto-migrate on access)
4. Test the migration with sample data
5. Build and verify everything works
