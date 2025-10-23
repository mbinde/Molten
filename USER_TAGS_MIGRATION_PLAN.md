# UserTags Migration Plan

## Overview
This document outlines the plan to generalize UserTags from glass-item-only to support multiple entity types (glass items, projects, logbooks) using the owner_type + owner_id pattern, similar to UserImage.

## Changes Made

### 1. Updated UserTagsRepository Protocol (✅ COMPLETE)
**File**: `Molten/Sources/Repositories/Protocols/UserTagsRepository.swift`

**Changes**:
- Added `TagOwnerType` enum with cases: `.glassItem`, `.project`, `.logbook`
- Updated `UserTagModel` to include:
  - `ownerType: TagOwnerType`
  - `ownerId: String` (natural key for glass items, UUID string for projects/logbooks)
- Updated all repository methods to use `ownerType` and `ownerId` parameters
- Added legacy methods for backward compatibility (delegate to new generic methods)

**Example new API**:
```swift
// New generic API
func fetchTags(ownerType: .project, ownerId: projectId) async throws -> [String]
func addTag("in-progress", ownerType: .logbook, ownerId: logbookId) async throws

// Legacy API (still works)
func fetchTags(forItem: "be-clear-000") async throws -> [String]
```

## Required Xcode Changes

### 2. Update Core Data Model in Xcode
**File**: `Molten/Molten.xcdatamodeld`

You need to:

1. **Open Xcdatamodeld in Xcode**

2. **Create New Model Version** (for migration):
   - Editor → Add Model Version...
   - Name it: `Molten 2` (or next version number)
   - Based on: Current version

3. **Update UserTags Entity**:
   - Select the UserTags entity
   - Add new attributes:
     - `owner_type` (String, required, indexed)
     - `owner_id` (String, required, indexed)
   - Keep existing `item_natural_key` attribute temporarily for migration
   - Keep existing `tag` attribute

4. **Create Migration Mapping** (Lightweight migration should work):
   - For existing UserTags records:
     - `owner_type` = "glassItem"
     - `owner_id` = value from `item_natural_key`
     - `tag` = existing value

5. **After Migration Completes**, create another model version:
   - Remove deprecated `item_natural_key` attribute
   - UserTags will have: `id`, `owner_type`, `owner_id`, `tag`

6. **Update Composite Index**:
   - Create compound index on: `owner_type + owner_id + tag` (for uniqueness)
   - This replaces the old `item_natural_key + tag` index

7. **Fix Project and Logbook Tags Relationships**:
   - Select Project entity
   - Find the `tags` relationship
   - **DELETE** the broken tags relationship (currently points to mysterious "I")
   - Projects will now use UserTags via the repository with `ownerType: .project`

   - Select Logbook entity
   - Find the `tags` relationship
   - **DELETE** the broken tags relationship
   - Logbooks will now use UserTags via the repository with `ownerType: .logbook`

8. **Set Current Model Version**:
   - Select `Molten.xcdatamodeld` in file navigator
   - In file inspector, update "Current" to the new version

### 3. Core Data Migration Code (Optional - Lightweight Should Work)

If lightweight migration fails, you may need to add a custom migration in `Persistence.swift`:

```swift
// Add to NSPersistentContainer setup if needed
let mappingModel = NSMappingModel(from: [bundle], forSourceModel: sourceModel, destinationModel: destinationModel)
// Migrate item_natural_key → owner_type="glassItem", owner_id=item_natural_key
```

However, this should NOT be necessary if you follow the steps above. Core Data's lightweight migration should handle:
- Adding new attributes with default values
- Copying data from old attributes to new ones

## Code Changes Needed

### 4. Update Repository Implementations

**CoreDataUserTagsRepository** (Primary work needed):
- Update entity fetch to use `owner_type` and `owner_id`
- Implement new generic methods
- Implement legacy methods as wrappers calling generic methods
- Update all predicates to filter by `owner_type` and `owner_id`

**MockUserTagsRepository** (For testing):
- Update in-memory storage to use `(ownerType, ownerId)` keys
- Implement new generic methods
- Implement legacy methods as wrappers

### 5. Update Services (Minimal changes needed)

**CatalogService** and other services:
- Currently call legacy methods like `fetchTags(forItem:)`
- These will continue to work (backward compatible)
- Gradually migrate to new API: `fetchTags(ownerType: .glassItem, ownerId:)`

**ProjectService** (New functionality):
- Add methods to manage project tags:
  ```swift
  func addTag(_ tag: String, toProject projectId: UUID) async throws {
      try await tagsRepository.addTag(tag, ownerType: .project, ownerId: projectId.uuidString)
  }
  ```

**LogbookService** (New functionality):
- Add methods to manage logbook tags

### 6. Update Views (Minimal changes)

Views that currently use tags will continue to work with legacy API. Gradually migrate to new API when touching those views.

## Testing Plan

1. **Unit Tests** (MockUserTagsRepository):
   - Test new generic methods work for all owner types
   - Test legacy methods still work for glass items
   - Test backward compatibility

2. **Repository Tests** (CoreDataUserTagsRepository):
   - Test migration preserves existing glass item tags
   - Test adding tags to projects and logbooks
   - Test querying by owner type
   - Test tag analytics across owner types

3. **Integration Tests**:
   - Verify existing glass item tags still display correctly
   - Verify project tags can be created and displayed
   - Verify logbook tags can be created and displayed

## Migration Steps (In Order)

1. ✅ Update UserTagsRepository protocol (DONE)
2. ⏳ Create Core Data model version with new attributes (USER ACTION NEEDED)
3. ⏸️ Update CoreDataUserTagsRepository implementation
4. ⏸️ Update MockUserTagsRepository implementation
5. ⏸️ Delete broken tags relationships from Project and Logbook entities
6. ⏸️ Test migration with existing data
7. ⏸️ Update services to add project/logbook tagging support
8. ⏸️ Build and verify all tests pass

## Rollback Plan

If migration fails:
1. Revert to previous Core Data model version
2. Keep old UserTagsRepository protocol (revert changes)
3. Continue with glass-item-only tags

## Benefits After Migration

1. **Unified tagging system** - One repository handles all entity tags
2. **No Core Data relationships needed** - Avoids the mysterious "I" bug
3. **Flexible** - Easy to add new entity types (inventory items, purchases, etc.)
4. **Consistent with UserImage** - Same owner_type/owner_id pattern
5. **Backward compatible** - Existing glass item tags continue to work

## Timeline Estimate

- Core Data model changes: 15 minutes
- Repository implementation: 1-2 hours
- Service updates: 30 minutes
- Testing: 1 hour
- **Total**: ~3-4 hours

## Notes

- This follows the exact same pattern as UserImage (proven to work)
- Migration should be seamless for existing users
- No data loss - all existing glass item tags will be preserved
- The mysterious "I" type error will be resolved by removing Core Data relationships
