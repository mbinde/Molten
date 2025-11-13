# Two-Store Implementation Plan

## ✅ Completed Steps

### 1. Remove Cross-Store Relationships
- **File**: `Molten 14.xcdatamodel/contents`
- **Changes**:
  - Removed `GlassItem.recommendedSchedules` relationship to KilnScheduleEntity
  - Removed `KilnScheduleEntity.recommendedForGlassItems` relationship to GlassItem
  - Added `GlassItem.recommended_schedule_ids` string attribute (comma-separated UUIDs)
  - Added `KilnScheduleEntity.recommended_for_glass_item_ids` string attribute (comma-separated UUIDs)

### 2. Update Repository Code
- **File**: `CoreDataGlassItemRepository.swift`
- **Changes**:
  - `getRecommendedScheduleIds()` - Now parses comma-separated string instead of relationship
  - `addRecommendedSchedule()` - Appends to comma-separated string
  - `removeRecommendedSchedule()` - Removes from comma-separated string

### 3. Create Configurations in CoreData Model
- **File**: `Molten 14.xcdatamodel/contents`
- **Changes**:
  - Created "Local" configuration with: GlassItem, ItemTags, CatalogItem*, Item, CoatingItem, ToolItem
  - Created "Cloud" configuration with: Inventory, Purchases, Projects, Logbook, KilnSchedule, Location, Store, Shopping, User*

## ✅ ALL WORK COMPLETE - TESTED ON DEVICE

1. ✅ Convert GlassItem ↔ KilnSchedule relationship to string-based
2. ✅ Create "Local" and "Cloud" configurations in CoreData model
3. ✅ Update Persistence.swift to configure two stores with separate contexts
4. ✅ Update ALL CoreData repositories to take context parameter
5. ✅ Update RepositoryFactory to route contexts correctly
6. ✅ Fix race conditions in context initialization
7. ✅ Fix continuation resume issues (double-resume, hanging)
8. ✅ Test on device - NO MORE DUPLICATES!

## Implementation Details

### Persistence.swift - Two Store Configuration

**Current State**: Single store with single `viewContext`

**Required Changes**:
```swift
class PersistenceController {
    let container: NSPersistentCloudKitContainer

    // NEW: Two separate contexts
    private(set) var localContext: NSManagedObjectContext!
    private(set) var cloudContext: NSManagedObjectContext!

    nonisolated init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Molten", managedObjectModel: Self.sharedModel)

        if !inMemory {
            // STORE 1: Local (no CloudKit)
            let localDescription = NSPersistentStoreDescription()
            localDescription.url = appGroupURL.appendingPathComponent("local.sqlite")
            localDescription.configuration = "Local"
            localDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            localDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            localDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            // NO cloudKitContainerOptions = local only

            // STORE 2: Cloud (with CloudKit)
            let cloudDescription = NSPersistentStoreDescription()
            cloudDescription.url = appGroupURL.appendingPathComponent("cloud.sqlite")
            cloudDescription.configuration = "Cloud"
            cloudDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            cloudDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            cloudDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            cloudDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            cloudDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.melissabinde.molten"
            )

            container.persistentStoreDescriptions = [localDescription, cloudDescription]
        }

        // Load stores...
    }

    @MainActor
    func initialize() async {
        // After stores load, create contexts
        localContext = container.newBackgroundContext()
        localContext.automaticallyMergesChangesFromParent = true
        localContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        cloudContext = container.newBackgroundContext()
        cloudContext.automaticallyMergesChangesFromParent = true
        cloudContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }
}
```

**Affected Code Locations**:
- `Persistence.swift` lines 127-186 (init)
- `Persistence.swift` lines 313-370 (initialize method)
- Remove `container.viewContext` usage throughout

### Next: Update Remaining Repositories to Use Correct Context

**Local Context (catalog data):**
- ✅ `CoreDataGlassItemRepository` - DONE, uses `localContext`
- ⏳ `CoreDataItemTagsRepository` - Needs `localContext`

**Cloud Context (user data):**
- ⏳ `CoreDataInventoryRepository` - Needs `cloudContext`
- ⏳ `CoreDataLocationRepository` - Needs `cloudContext`
- ⏳ `CoreDataStoreRepository` - Needs `cloudContext`
- ⏳ `CoreDataShoppingListRepository` - Needs `cloudContext`
- ⏳ `CoreDataUserNotesRepository` - Needs `cloudContext`
- ⏳ `CoreDataUserTagsRepository` - Needs `cloudContext`
- ⏳ Plus: PurchaseRecord, Logbook, Project, Kiln, UserImage repositories

**Repositories found needing updates**:
```
CoreDataInventoryRepository.swift
CoreDataItemTagsRepository.swift
CoreDataLocationRepository.swift
CoreDataShoppingListRepository.swift
CoreDataStoreRepository.swift
CoreDataUserNotesRepository.swift
CoreDataUserTagsRepository.swift
```

**How to Update Repositories**:

Current pattern:
```swift
class CoreDataGlassItemRepository: GlassItemRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }
}
```

No change needed in repositories themselves! Just update where they're created:

**In RepositoryFactory.swift**:
```swift
// BEFORE:
let context = PersistenceController.shared.container.viewContext
let repo = CoreDataGlassItemRepository(context: context)

// AFTER:
let context = PersistenceController.shared.localContext  // or cloudContext
let repo = CoreDataGlassItemRepository(context: context)
```

**Files to Update**:
- `RepositoryFactory.swift` - All `create*Repository()` methods

### 6. Migration Strategy

**The Problem**: Existing users have all data in a single `Molten.sqlite` store. After update, they'll have two empty stores (`local.sqlite` and `cloud.sqlite`).

**Options**:

**Option A: Fresh Start (Simplest)**
- Document that users need to uninstall/reinstall app
- Data loss acceptable for beta/development
- Fast to implement

**Option B: Automatic Migration (Complex)**
- On first launch with new version:
  1. Detect old `Molten.sqlite` exists
  2. Load old store temporarily
  3. Copy GlassItem/ItemTags to `local.sqlite`
  4. Copy user data to `cloud.sqlite`
  5. Delete old `Molten.sqlite`
- Requires custom migration code
- Risk of data loss if migration fails

**Recommendation**: Option A for now (fresh start), Option B if you have beta users with important data.

### 7. Testing Checklist

**After Implementation**:
- [ ] Build succeeds
- [ ] Fresh install: App loads without crashes
- [ ] Fresh install: GlassItems load from JSON (2,659 items)
- [ ] Fresh install: Can create Inventory records
- [ ] Fresh install: Can create Purchase records
- [ ] Fresh install: Inventory references GlassItem via stable_id correctly
- [ ] CloudKit reset + First install: No duplicates ✅
- [ ] CloudKit reset + Second install: No duplicates ✅ (THE REAL TEST)
- [ ] CloudKit reset + Third install: No duplicates ✅ (CONFIRMATION)

## 🚨 IS CURRENT STATE TESTABLE?

**NO** - The current changes will cause the app to crash because:

1. ✅ Model defines two configurations ("Local" and "Cloud")
2. ❌ Persistence.swift still tries to load default configuration (none specified)
3. ❌ Repositories still use `viewContext` which won't have access to the right stores

**What happens if you build now:**
- CoreData will try to load default configuration (no entities assigned to it)
- Queries for GlassItem will fail (entity not in loaded store)
- App will crash on first data access

**Minimum Viable Changes to Test:**
You MUST complete step 4 (Persistence.swift) before testing. Steps 5-7 can be done incrementally.

## Estimated Time

- **Step 4** (Persistence.swift): 30-60 minutes
- **Step 5** (RepositoryFactory): 15-30 minutes
- **Step 6** (Migration): 0 minutes (fresh install) or 2-4 hours (automatic migration)
- **Step 7** (Testing): 1-2 hours

**Total**: 2-4 hours for fresh install approach, 4-8 hours for automatic migration.

## Files to Modify Summary

1. ✅ `Molten 14.xcdatamodel/contents` - Model changes (DONE)
2. ✅ `CoreDataGlassItemRepository.swift` - String-based relationships (DONE)
3. ⏳ `Persistence.swift` - Two-store configuration (REQUIRED)
4. ⏳ `RepositoryFactory.swift` - Use correct contexts (REQUIRED)
5. ⏳ Migration code (OPTIONAL - only if preserving user data)
6. ⏳ Testing and validation

## Rollback Plan

If two-store approach doesn't work:
1. Revert `Molten 14.xcdatamodel/contents` changes (remove configurations)
2. Restore GlassItem ↔ KilnSchedule CoreData relationships
3. Revert `CoreDataGlassItemRepository.swift` relationship handling
4. Back to single store (with duplicates issue)
