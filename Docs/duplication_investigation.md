# GlassItem Duplication Bug Investigation - SOLVED ✅

## 📋 TL;DR - THE REAL PROBLEM

**Catalog data (GlassItem) should NEVER be synced via CloudKit.**

**What was happening:**
1. First install: Load 2,659 GlassItems from JSON → Upload to CloudKit ✅
2. Second install: Load 2,659 from JSON + Download 2,659 from CloudKit = 5,318 duplicates ❌
3. Each device multiplies the catalog data because CloudKit thinks it's unique user data

**The Solution:**
- **Split into TWO persistent stores:**
  - Local store (no CloudKit): GlassItem, ItemTags, catalog data
  - Cloud store (CloudKit): Inventory, Projects, Purchases, user data
- **Use string-based references (`stable_id`)** between stores, not CoreData relationships

**Implementation Status**: ✅ **COMPLETE AND TESTED**
- ✅ Model changes complete (configurations, string-based relationships)
- ✅ Persistence.swift two-store setup (local.sqlite + cloud.sqlite)
- ✅ RepositoryFactory context routing (localContext for catalog, cloudContext for user data)
- ✅ All repositories updated to use context parameter
- ✅ Fixed race conditions and continuation resume issues
- ✅ Tested on device - NO MORE DUPLICATES!

**Key Learning:**
- Catalog data = Read-only reference data shipped with app → Local only
- User data = Created/modified by user → CloudKit sync
- Never mix them in the same CloudKit-enabled store

---

## 🎉 ROOT CAUSE IDENTIFIED (Day 5)

**The Bug**: Purging persistent history transactions causes CloudKit to lose sync state and re-import all data, creating duplicates.

**Evidence**:
- JSON loads 2,659 items correctly
- COUNT BEFORE PURGE: 3,659 items (+1,000 duplicates already appearing)
- COUNT AFTER PURGE: 5,259 items (+1,600 MORE duplicates created DURING purge)
- Purge was deleting 2,662 transactions, triggering CloudKit to think it needed to re-sync everything

## Previous hypothesis (INCORRECT)

**The Bug**: CloudKit is syncing GlassItem entities even though they are marked `syncable="NO"` in the current model version. This happens because:
1. GlassItem WAS `syncable="YES"` in model versions 4-13
2. Changed to `syncable="NO"` in version 14
3. CloudKit still has the old GlassItem records in the database
4. CloudKit continuously tries to sync those records down, creating duplicates (up to 7+ copies)
5. Evidence: `NSCKRecordMetadata` entities created alongside GlassItems in background context

**The ACTUAL Fix** (based on web research):

### CloudKit + Persistent History Best Practices

When using `NSPersistentCloudKitContainer`, you MUST follow these rules:

1. **✅ NEVER manually purge persistent history**
   - CloudKit uses persistent history tokens to track sync state
   - Deleting history causes CloudKit to lose track of what's been synced
   - This triggers re-imports and duplicates
   - Source: https://stackoverflow.com/questions/72557060/
   - Apple engineer quote (WWDC22): "We don't recommend it. NSPersistentCloudKitContainer uses the persistent history token to track what to sync."

2. **✅ ALWAYS use `automaticallyMergesChangesFromParent = true`**
   - Required for CloudKit to properly track processed changes
   - Setting to `false` causes CloudKit to think changes haven't been processed
   - Leads to repeated import attempts
   - This is NOT optional when using CloudKit

3. **✅ Let CloudKit manage all entities or use separate store configurations**
   - Don't try to exclude entities via `syncable="NO"` in a CloudKit-enabled store
   - Either sync the entity OR move it to a separate non-CloudKit store
   - Mixing syncable and non-syncable in same store causes confusion

4. **✅ Let CloudKit manage its own history tokens**
   - Don't try to manipulate `transactionAuthor` to prevent history tracking
   - CloudKit needs complete history to maintain sync state

### Changes Applied

**Persistence.swift** (line 185):
- Set `automaticallyMergesChangesFromParent = true` (was `false`)
- Added comment explaining why this is required for CloudKit

**FirstRunDataLoadingView.swift** (line 207):
- Removed `purgeGlassItemHistory()` call after JSON load
- Let CloudKit manage history naturally

**Data Model** (Molten 14.xcdatamodel):
- Set GlassItem `syncable="YES"` (was "NO")
- Set ItemTags `syncable="YES"` (was "NO")
- Let CloudKit sync all entities to avoid conflicts

**CoreDataGlassItemRepository.swift**:
- Removed `transactionAuthor = nil` manipulation
- Let normal history tracking work

**Why This Happens**:
1. `NSPersistentCloudKitContainer` automatically enables persistent history tracking
2. Every save creates a persistent history transaction
3. With `automaticallyMergesChangesFromParent = false`, the view context doesn't consume these transactions
4. Transactions accumulate in persistent history
5. System repeatedly replays unconsumed transactions, creating duplicates
6. Each replay triggers `NSPersistentStoreRemoteChange` notifications (2600+ notifications observed)
7. The count grows: 2659 → 2760 → 2960 → 3160 → ... → 7977 (in jumps of ~200)

**Evidence**:
- 📡 2760+ `NSPersistentStoreRemoteChange` notifications fired after initial load
- Count grew from 2659 to 7977 in batches during remote change notifications
- No duplicate saves in our code (each item saved exactly once)
- 7977 entities with only 2659 unique stable_ids (each duplicated 3x)

## Summary
GlassItems are being duplicated in CoreData. Initial JSON load creates 2,659 items correctly, but over time (30-60 seconds), the count grows to 7,977+ items (exactly 3x multiplication).

## Confirmed Facts
1. ✅ Initial JSON load completes correctly: 2,659 items created
2. ✅ A background process continues creating duplicates AFTER the load finishes
3. ✅ The duplication happens WITHOUT any user interaction (confirmed via test)
4. ✅ The duplication is time-based: longer wait = more duplicates (60s = 3x, longer = 4x-10x+)
5. ✅ The duplication stops when user interacts with the app
6. ✅ Each item is created exactly ONCE in our code (confirmed via logs)
7. ✅ Each stable_id appears multiple times (3 copies each: 2,659 unique → 7,977 total)
8. ✅ No ☁️ context insertion messages appear after JSON load completes
9. ✅ The VIEW context saves each item exactly once (2,658 saves logged)

## What It's NOT
- ❌ NOT related to ItemTags background context (disabled, still duplicates)
- ❌ NOT related to Inventory background context (disabled, still duplicates)
- ❌ NOT related to CloudKit syncing old data (CloudKit was reset)
- ❌ NOT related to syncable="YES"→"NO" migration (that was us debugging)
- ❌ NOT related to user interaction triggering duplicates (happens without interaction)
- ❌ NOT related to our code calling createItem multiple times (each stable_id created once)
- ❌ NOT related to JSON loader running multiple times (only runs once)

## Current Hypothesis (Latest)

**The duplicates are being written directly to the SQLite persistent store, bypassing the view context entirely.**

Evidence:
1. No ☁️ insertion messages after JSON load = view context not seeing the insertions
2. But fetch returns 7,977 entities with duplicate stable_ids
3. Since `automaticallyMergesChangesFromParent = false`, the view context doesn't see persistent store changes until we fetch
4. The duplicates appear when we navigate/fetch, not when they're inserted

**Possible causes:**
1. **Persistent history transactions being replayed multiple times**
   - Each save creates a persistent history transaction
   - Something is causing those 2,659 transactions to be applied 3 times
   - This would create 3 copies of each entity directly in the store

2. **CloudKit import coordinator writing duplicates**
   - Even though GlassItem is `syncable="NO"` now, CloudKit might be confused
   - Could be importing from persistent history multiple times
   - The 📡 remote change notification will confirm this

3. **Multiple persistent store coordinators**
   - If there are somehow multiple coordinators accessing the same SQLite file
   - Each coordinator's saves would create separate entities
   - The ObjectID analysis will show if entities have different persistent stores

## Call Stack Evidence

All createItem calls have identical stacks:
```
CoreDataGlassItemRepository.createItem
→ CoreData (context.perform)
→ libdispatch (dispatch_main_queue)
→ CoreFoundation (run loop)
→ UIApplicationMain
```

**Missing from stack**: No GlassItemDataLoadingService, CatalogService, or any business logic!

This means the createItem calls are executing from **queued closures that were scheduled earlier**, not from active code execution. The async `context.perform` blocks are running after the JSON loader reports "COMPLETED".

## ❌ Previous Hypotheses (All INCORRECT)

During the 5-day investigation, we tried many approaches that didn't work:

1. **❌ Background contexts creating duplicates**
   - Disabled ItemTags background context - still duplicated
   - Disabled Inventory background context - still duplicated
   - Reality: Background contexts only create ItemTags/Inventory, not GlassItems

2. **❌ Persistent history replay creating batches of 200**
   - Saw batches of 200 GlassItems appearing in logs
   - Thought this was the root cause
   - Reality: This was a SYMPTOM of purging history, not the cause

3. **❌ CloudKit syncing despite `syncable="NO"`**
   - Set GlassItem and ItemTags to `syncable="NO"`
   - Did CloudKit schema resets
   - Reality: The issue was purging history and `automaticallyMergesChangesFromParent=false`, not the syncable setting

4. **❌ Need to disable CloudKit entirely**
   - Tried disabling CloudKit container options
   - Reality: CloudKit works fine when you follow best practices

5. **❌ Need unique constraints on stable_id**
   - Considered forcing uniqueness in database
   - Reality: This would break CloudKit sync and was treating symptoms, not root cause

## ✅ FINAL SOLUTION (Day 5 - After Web Research)

The solution is to follow CloudKit best practices (see "CloudKit + Persistent History Best Practices" section above):

1. Set `automaticallyMergesChangesFromParent = true`
2. Remove all persistent history purging code
3. Let CloudKit sync all entities (set all to `syncable="YES"`)
4. Let CloudKit manage its own history tokens

**Key Insight from Web Research**:
- Purging history causes CloudKit to lose sync state
- CloudKit then tries to re-import everything from scratch
- This creates duplicates because local data + re-imported data both exist
- Evidence: COUNT AFTER PURGE was higher than BEFORE PURGE (5,259 vs 3,659)

## Timeline of Investigation (5 days)

**Day 1-2**: Thought it was CloudKit sync, tried disabling CloudKit, changing syncable settings
**Day 3**: Suspected background contexts (ItemTags, Inventory), disabled them - still duplicated
**Day 4**: Added extensive logging, discovered no duplicate saves in our code, but duplicates appearing in store
**Day 5**: Added `NSPersistentStoreRemoteChange` notification logging → **FOUND THE BUG!**
  - 2760+ remote change notifications firing continuously
  - Count growing in batches of 200 during these notifications
  - Realized `automaticallyMergesChangesFromParent = false` was preventing persistent history consumption

## Files Modified for Debugging

- `Persistence.swift`: Added logging for context saves, remote changes, object insertions
- `CoreDataGlassItemRepository.swift`: Added stack traces, duplicate detection, ObjectID analysis, save timing
- `InventoryTrackingService.swift`: Disabled ItemTags and Inventory creation for testing

## Key Log Patterns

- 🔴🔴🔴 = createItem called (with stack trace)
- 🚨 = Context save operations
- ☁️☁️☁️ = Objects inserted into view context
- 📡📡📡 = Persistent store remote change (CloudKit import)
- ⚠️⚠️⚠️ = Duplicate stable_ids detected in fetch
- 🔍 = ObjectID analysis
