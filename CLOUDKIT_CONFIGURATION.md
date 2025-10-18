# CloudKit Configuration Guide

This document explains how to configure which entities sync to CloudKit and which stay local-only.

## Why Split Configurations?

**CloudKit Entities** (User Data - Must Sync):
- Inventory - User's inventory quantities
- Location - Where items are stored
- ItemShopping - Shopping list items
- ItemMinimum - Minimum stock levels
- PurchaseRecord - Purchase history
- ProjectLog / ProjectPlan - User projects
- UserNotes - User's notes on items
- UserItem - User-created items

**Local-Only Entities** (Can Be Recreated from JSON):
- CatalogItem - Factory catalog data (re-downloadable)
- CatalogItemParent - Catalog groupings
- GlassItem / Item / ToolItem - Base catalog entities
- ItemTags - Tags from catalog
- ItemDimensions - Dimensions data

## Steps to Configure in Xcode

### 1. Create Configuration Groups

1. Open `Flameworker.xcdatamodeld` in Xcode
2. In the Editor menu → **Add Configuration**
3. Name it: `CloudKit`
4. Add another configuration: **Add Configuration**
5. Name it: `Local`

### 2. Assign Entities to Configurations

For **CloudKit** configuration, add these entities:
- Inventory
- Location
- ItemShopping
- ItemMinimum
- PurchaseRecord
- ProjectLog
- ProjectPlan
- UserNotes
- UserItem

For **Local** configuration, add these entities:
- CatalogItem
- CatalogItemParent
- CatalogItemUser (unless it has user notes - TBD)
- GlassItem
- Item
- ToolItem
- ItemTags
- ItemDimensions
- InventoryItem (if legacy/unused)

### 3. Update Persistence.swift

After creating configurations in Xcode, the code needs to be updated to use two separate stores:
- One store for CloudKit-synced entities
- One local-only store for catalog data

## Alternative: Simple Approach (Recommended for Now)

Instead of splitting configurations, you could:

1. **Keep catalog data in CloudKit** but mark it as public/shared
2. **Let all data sync** - the catalog data is relatively small
3. **Accept the trade-off** - Users pay ~5-10MB of iCloud storage for the convenience

The catalog data (all glass items from manufacturers) is probably only 5-10MB total. This is negligible compared to photos or videos. The benefit of having it sync is:
- Users can add custom items on one device and see them on another
- No complex dual-store setup needed
- Simpler codebase

## Recommendation

**Start with syncing everything.** Monitor the actual data size, and only split if it becomes a problem. The complexity of dual-store configuration is usually not worth the 5-10MB savings for most users.

## If You Still Want to Split (Advanced)

If you decide to implement dual stores, I can help update `Persistence.swift` to:
1. Create two `NSPersistentStoreDescription` instances
2. Assign configurations to each store
3. One uses CloudKit, one is local-only
4. Both share the same `NSManagedObjectContext`

This is more complex but gives you complete control.
