# Molten App - GlassItem CoreData Entity & Persistence Analysis

## Executive Summary

The Molten app uses a modern Swift CoreData architecture with CloudKit sync enabled to manage glass items and related inventory. The system is built around a **stable_id** primary key (6-character hash) for deduplication and uniqueness. JSON data containing **2,782 items** is loaded from the bundle and persisted to CoreData with automatic deduplication based on stable_id matching.

---

## 1. GlassItem CoreData Entity Definition

### Location
**File:** `/Users/binde/projects/molten-xcode/Molten/Molten.xcdatamodeld/Molten 10.xcdatamodel/contents`

### Entity Hierarchy
```
Item (Abstract Parent Entity)
├── GlassItem (Concrete Entity - inherits from Item)
├── CoatingItem (Concrete Entity - inherits from Item)
├── ToolItem (Concrete Entity - inherits from Item)
└── UserItem (Concrete Entity - inherits from Item)
```

### GlassItem Entity Definition (XML)
```xml
<entity name="GlassItem" representedClassName="GlassItem" parentEntity="Item" 
         syncable="YES" codeGenerationType="category">
    <attribute name="coe" optional="YES" attributeType="Integer 16" 
               defaultValueString="0" usesScalarValueType="YES"/>
</entity>
```

### Item Parent Entity Attributes (inherited by GlassItem)
```xml
<entity name="Item" representedClassName="Item" isAbstract="YES" 
         syncable="YES" codeGenerationType="category">
    <attribute name="image_path" optional="YES" attributeType="String"/>
    <attribute name="image_url" optional="YES" attributeType="URI"/>
    <attribute name="last_seen" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
    <attribute name="manufacturer" optional="YES" attributeType="String"/>
    <attribute name="mfr_notes" optional="YES" attributeType="String"/>
    <attribute name="mfr_status" optional="YES" attributeType="String"/>
    <attribute name="name" optional="YES" attributeType="String"/>
    <attribute name="sku" optional="YES" attributeType="String"/>
    <attribute name="stable_id" optional="YES" attributeType="String"/>
    <attribute name="uri" optional="YES" attributeType="URI"/>
    <attribute name="url" optional="YES" attributeType="String"/>
</entity>
```

### Complete GlassItem Fields
| Field | Type | Purpose | Notes |
|-------|------|---------|-------|
| **stable_id** | String | PRIMARY KEY | 6-char hash identifier (e.g., "4CzH9v"), mandatory unique identifier |
| name | String | Display name | Item name (e.g., "Beeswax") |
| manufacturer | String | Manufacturer code | 2-3 char abbreviation (e.g., "BB", "CiM", "EF") |
| sku | String (Optional) | Stock keeping unit | Full code (e.g., "BB-40-T-Beeswax"), optional for some manufacturers |
| coe | Integer 16 | Coefficient of Expansion | Glass COE value (33, 90, 96, etc.) |
| mfr_notes | String (Optional) | Manufacturer notes | Detailed description from manufacturer |
| url | String (Optional) | Manufacturer URL | Link to product page |
| uri | String | Computed URI | Auto-generated as "moltenglass:item?{stable_id}" |
| mfr_status | String | Status | "available", "discontinued", etc. |
| image_url | URI (Optional) | Image URL | CDN image URL |
| image_path | String (Optional) | Local image path | Filename for cached images |
| last_seen | Date (Optional) | Last seen date | Tracking when item was last seen in JSON |

### CloudKit Configuration
**In Entitlements File:** `/Users/binde/projects/molten-xcode/Molten/Molten.entitlements`
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.motleywoods.molten</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

**Model Configuration:** The CoreData model has `usedWithCloudKit="YES"` set, enabling CloudKit sync for all entities.

---

## 2. JSON Data Loading & Persistence

### JSON Source File
**Location:** `/Users/binde/projects/molten-xcode/Molten/Sources/Resources/glassitems.json`
- **Total Items:** 2,782 (per `item_count` field in JSON)
- **File Size:** ~63,865 lines
- **Format:** JSON with metadata wrapper

### JSON Structure Example
```json
{
  "version": "1.0",
  "generated": "2025-10-28T02:31:52.347429",
  "item_count": 2782,
  "glassitems": [
    {
      "status": "available",
      "added_date": "2025-10-19",
      "last_seen": "2025-10-28",
      "discontinued_date": null,
      "manufacturer": "BB",
      "code": "BB-40-T-Beeswax",
      "name": "Beeswax",
      "manufacturer_description": "We're back from the lab...",
      "tags": ["striker"],
      "synonyms": [],
      "coe": "33",
      "type": "rod",
      "manufacturer_url": "https://store.borobatch.com/...",
      "image_path": "4CzH9v.png",
      "image_url": "https://cdn.shopify.com/...",
      "stock_type": "",
      "stable_id": "4CzH9v"
    },
    ...
  ]
}
```

### Data Loading Components

#### 1. JSONDataLoader
**File:** `/Users/binde/projects/molten-xcode/Molten/Sources/Services/DataLoading/JSONDataLoader.swift`

**Responsibilities:**
- Locate and load `glassitems.json` from app bundle
- Decode JSON into `CatalogItemData` objects
- Support demo data mode filtering
- Store metadata for version tracking

**Key Methods:**
```swift
func findCatalogJSONData(catalogType: String = "glass") throws -> Data
func decodeCatalogItems(from data: Data, catalogType: String = "glass") throws -> [CatalogItemData]
```

#### 2. GlassItemDataLoadingService
**File:** `/Users/binde/projects/molten-xcode/Molten/Sources/Services/Core/GlassItemDataLoadingService.swift`

**Responsibilities:**
- Orchestrate JSON loading into CoreData
- Handle JSON change detection via checksums
- Manage item comparison (create vs update vs skip)
- Batch processing with error recovery
- Tag extraction and synchronization

**Key Methods:**
```swift
func loadGlassItemsFromJSON(options: LoadingOptions) async throws -> GlassItemLoadingResult
func loadGlassItemsFromJSONIfEmpty(options: LoadingOptions) async throws -> GlassItemLoadingResult?
func loadGlassItemsAndUpdateExisting(options: LoadingOptions) async throws -> GlassItemLoadingResult
func migrateFromLegacySystem() async throws -> GlassItemLoadingResult
func validateJSONData() async throws -> JSONValidationResult
```

**Loading Options:**
```swift
struct LoadingOptions {
    let skipExistingItems: Bool          // Skip existing items
    let createInitialInventory: Bool     // Create starter inventory
    let defaultInventoryType: String     // Type for initial inventory
    let defaultInventoryQuantity: Double // Quantity for initial inventory
    let enableTagExtraction: Bool        // Extract tags from JSON
    let enableSynonymTags: Bool          // Include synonym tags
    let validateNaturalKeys: Bool        // Validate unique keys
    let batchSize: Int                   // Processing batch size
}
```

**Pre-defined Options:**
- `.default` - Safe production loading (skip existing, no inventory, batch=50)
- `.migration` - Legacy migration (update existing, inventory=1.0, batch=25)
- `.testing` - Development/testing (update existing, inventory=10.0, batch=10)
- `.appUpdate` - App update handling (process all, no inventory, batch=25)

#### 3. CoreDataGlassItemRepository
**File:** `/Users/binde/projects/molten-xcode/Molten/Sources/Repositories/Protocols/CoreDataGlassItemRepository.swift`

**Responsibilities:**
- Implement GlassItemRepository protocol
- Perform CRUD operations on GlassItem entities
- Deduplication enforcement via stable_id
- Search and filter operations
- Batch create operations

**Key Method - Deduplication on Create:**
```swift
func createItem(_ item: GlassItemModel) async throws -> GlassItemModel {
    // 1. Check if item already exists by stable_id (PRIMARY KEY)
    let existingRequest = NSFetchRequest<NSManagedObject>(entityName: "GlassItem")
    existingRequest.predicate = NSPredicate(format: "stable_id == %@", item.stable_id)
    existingRequest.fetchLimit = 1
    
    let existing = try self.context.fetch(existingRequest)
    if let existingEntity = existing.first {
        // If exists: UPDATE rather than create duplicate
        self.updateEntity(existingEntity, with: item)
        try self.context.save()
        return self.convertToGlassItemModel(existingEntity) ?? item
    }
    
    // If new: CREATE fresh entity
    let entity = NSManagedObject(entity: entityDescription, insertInto: self.context)
    self.updateEntity(entity, with: item)
    try self.context.save()
    return self.convertToGlassItemModel(entity) ?? item
}
```

#### 4. CatalogService
**File:** `/Users/binde/projects/molten-xcode/Molten/Sources/Services/Core/CatalogService.swift`

**Responsibilities:**
- High-level catalog business logic
- Glass item creation with inventory setup
- Item updates with tag synchronization
- Batch operations coordination

**Key Method - Create with Inventory:**
```swift
func createGlassItem(
    _ glassItem: GlassItemModel,
    initialInventory: [InventoryModel],
    tags: [String]
) async throws -> CompleteInventoryItemModel
```

### Persistence Implementation
**File:** `/Users/binde/projects/molten-xcode/Molten/Sources/Repositories/CoreData/Persistence.swift`

**Key Features:**
- `NSPersistentCloudKitContainer` for CloudKit sync
- Async store loading (non-blocking)
- Automatic lightweight migration
- App Group container for sharing with extensions
- Comprehensive error recovery with retry logic

**CloudKit Configuration:**
```swift
// Enable persistent history tracking for CloudKit sync
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

// Enable automatic migration for model changes
description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
```

**Store Location:** App Group container (`group.com.melissabinde.molten`)

---

## 3. Deduplication Logic (Stable_ID Matching)

### Primary Key Strategy
**The stable_id is the ONLY primary key.** It is:
- A 6-character hash (e.g., "4CzH9v", "28mqWb")
- Generated from JSON data
- Mandatory and immutable
- Used for all lookups and comparisons

### Critical Warning (from source code)
```swift
/// ⚠️ CRITICAL WARNING TO FUTURE DEVELOPERS:
/// - stable_id is the ONLY primary key (6-char hash like "abc123")
/// - DO NOT add a "natural_key" field - it was deleted and should NEVER come back
/// - DO NOT create any "bullseye-001-001" format keys - those are legacy garbage
/// - If you see natural_key in old tests, DELETE IT from the tests
```

### Deduplication Workflow

1. **JSON Data Has stable_id**
   - Each item in JSON includes `"stable_id": "abc123"`
   - This is the primary identifier from the scraper database

2. **Loading Process**
   ```
   For each JSON item:
   ├─ Generate naturalKey from stable_id
   ├─ Check if glassItem exists with this stable_id
   ├─ If exists:
   │  └─ UPDATE existing item with new values
   └─ If not exists:
      └─ CREATE new GlassItem entity
   ```

3. **Duplicate Prevention in Repository**
   ```swift
   // Always check by stable_id (PRIMARY KEY)
   NSPredicate(format: "stable_id == %@", stableId)
   
   // If found: UPDATE (upsert pattern)
   // If not found: CREATE
   ```

4. **Equatable Implementation**
   ```swift
   static func == (lhs: GlassItemModel, rhs: GlassItemModel) -> Bool {
       if let lhsSku = lhs.sku, let rhsSku = rhs.sku {
           // Compare by business key (manufacturer + SKU) if available
           return lhs.manufacturer == rhs.manufacturer && lhsSku == rhsSku
       }
       // Fallback to stable_id when SKU missing
       return lhs.stable_id == rhs.stable_id
   }
   ```

### Deduplication Test
**File:** `/Users/binde/projects/molten-xcode/Molten/Sources/Tests/RepositoryTests/CoreDataGlassItemRepositoryStableIdTests.swift`

```swift
@Test("Creating item with duplicate stable_id updates existing item")
func testCreateWithDuplicateStableIdUpdatesExisting() async throws {
    // Create initial item with stable_id "dup50"
    let original = GlassItemModel(
        stable_id: "dup50",
        name: "Original Item",
        sku: "050",
        manufacturer: "bullseye",
        coe: 90,
        mfr_status: "available"
    )
    _ = try await repository.createItem(original)

    // Create "duplicate" with same stable_id but different data
    let duplicate = GlassItemModel(
        stable_id: "dup50",
        name: "Updated Item",
        sku: "050",
        manufacturer: "bullseye",
        coe: 96,
        mfr_status: "discontinued"
    )
    _ = try await repository.createItem(duplicate)

    // Verify: only ONE item with this stable_id exists
    let allItems = try await repository.fetchItems(matching: nil)
    let matchingItems = allItems.filter { $0.stable_id == "dup50" }
    
    #expect(matchingItems.count == 1, "Should only have one item with this stable_id")
    #expect(matchingItems[0].name == "Updated Item")  // Updated values
    #expect(matchingItems[0].coe == 96)
}
```

### Data Comparison Strategy
**File:** `GlassItemDataLoadingService.swift` (lines 841-908)

```swift
/// Compare existing GlassItem with JSON data to detect changes
private func compareItems(existing: GlassItemModel, jsonItem: CatalogItemData) -> [String] {
    var differences: [String] = []
    
    // Compare: name, mfr_notes, manufacturer, coe, url, image_url, image_path
    // If ANY field differs → UPDATE required
    // If ALL fields match → unchanged (skip)
    
    return differences  // Empty = no update needed
}
```

Items marked as "unchanged" still get tag syncing, since tags may change even if glass item fields don't.

---

## 4. CloudKit Sync Configuration

### Architecture
The app uses **NSPersistentCloudKitContainer** for automatic CloudKit synchronization:

```swift
let container: NSPersistentCloudKitContainer
container = NSPersistentCloudKitContainer(name: "Molten", managedObjectModel: Self.sharedModel)
```

### CloudKit Features Enabled
1. **Persistent History Tracking** - Tracks all changes for sync
   ```swift
   description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
   ```

2. **Remote Change Notifications** - Notifies on remote updates
   ```swift
   description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
   ```

3. **Automatic Lightweight Migration** - Handles model schema changes
   ```swift
   description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
   description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
   ```

### CloudKit Container Configuration
**CloudKit Container Identifier:** `iCloud.com.motleywoods.molten`

**CloudKit Services:** `CloudKit`

### Sync Monitoring
**File:** `/Users/binde/projects/molten-xcode/Molten/Sources/App/MoltenApp.swift`

```swift
@State private var syncMonitor: CloudKitSyncMonitor?

if let container = RepositoryFactory.persistentContainer as? NSPersistentCloudKitContainer {
    syncMonitor = CloudKitSyncMonitor(container: container)
}
```

**UI Component:** `CloudKitSyncStatusView` - displays CloudKit sync status in UI

### Store Persistence Strategy
- **Location:** App Group container at `group.com.melissabinde.molten/Molten.sqlite`
- **Timeout:** 30 seconds for store operations
- **Merge Policy:** NSMergeByPropertyStoreTrumpMergePolicy
- **Auto-merge:** viewContext automatically merges changes from parent

---

## 5. Data Model Structure

### GlassItemModel (Swift)
**File:** `/Users/binde/projects/molten-xcode/Molten/Sources/Services/Core/SharedModels.swift`

```swift
struct GlassItemModel: Identifiable, Equatable, Hashable, Sendable {
    let stable_id: String           // PRIMARY KEY: MANDATORY 6-char hash
    let name: String                // Item name
    let sku: String?                // Optional SKU
    let manufacturer: String        // Mfr code (2-3 chars)
    let mfr_notes: String?          // Manufacturer description
    let coe: Int32                  // Coefficient of Expansion
    let url: String?                // Manufacturer URL
    let uri: String                 // Computed: "moltenglass:item?{stable_id}"
    let mfr_status: String          // "available", "discontinued"
    let image_url: String?          // CDN image URL
    let image_path: String?         // Local image filename
}
```

### Related Models

#### InventoryModel
Tracks quantities by type/subtype/dimensions
- Links to glass items via `item_stable_id`
- Supports hierarchical types (rod/sheet, gauge sizes, etc.)

#### CompleteInventoryItemModel
Combines GlassItem with:
- All related inventory records
- Associated tags
- Total quantities by type

---

## 6. JSON Loading Examples

### Scenario 1: Initial Load (Empty Database)
```swift
// Loading service automatically:
// 1. Loads glassitems.json (2,782 items)
// 2. Fetches existing items from CoreData (0 items)
// 3. Compares: all 2,782 items marked as "to create"
// 4. Creates all 2,782 items in batches
// 5. Saves checksum to prevent reload

let service = GlassItemDataLoadingService(catalogService: catalogService)
let result = try await service.loadGlassItemsFromJSONIfEmpty()

// Result:
// itemsCreated: 2782
// itemsSkipped: 0
// itemsUpdated: 0
// itemsFailed: 0
```

### Scenario 2: Update with Deduplication
```swift
// Database has 2,782 items
// JSON still has 2,782 items
// 2,500 unchanged
// 200 updated (field changes)
// 82 are new (added to JSON)

let result = try await service.loadGlassItemsFromJSON(options: .appUpdate)

// Deduplication process:
// 1. For each JSON item, check if stable_id exists
// 2. If exists + unchanged → skip
// 3. If exists + changed → update
// 4. If not exists → create
// Result:
// itemsCreated: 82
// itemsUpdated: 200
// itemsSkipped: 2500
// itemsFailed: 0
```

### Scenario 3: Duplicate stable_id in create
```swift
// Try to create item with stable_id "4CzH9v" twice
let item1 = GlassItemModel(stable_id: "4CzH9v", name: "Item A", ...)
let item2 = GlassItemModel(stable_id: "4CzH9v", name: "Item B", ...)

try await repository.createItem(item1)  // Creates new
try await repository.createItem(item2)  // Updates existing!

// Result: Only ONE item exists with stable_id "4CzH9v"
// Properties reflect item2 (the update)
```

---

## 7. Important Files Reference

| File | Purpose |
|------|---------|
| `Molten.xcdatamodeld/Molten 10.xcdatamodel/contents` | CoreData entity definitions |
| `Sources/Resources/glassitems.json` | 2,782 glass items in JSON format |
| `Sources/Services/Core/GlassItemDataLoadingService.swift` | Main orchestrator for JSON loading |
| `Sources/Services/DataLoading/JSONDataLoader.swift` | JSON file loading and decoding |
| `Sources/Repositories/Protocols/CoreDataGlassItemRepository.swift` | CoreData CRUD + deduplication |
| `Sources/Services/Core/CatalogService.swift` | High-level business logic |
| `Sources/Repositories/CoreData/Persistence.swift` | CloudKit container setup |
| `Sources/Services/Core/SharedModels.swift` | GlassItemModel definition |
| `Sources/Tests/RepositoryTests/CoreDataGlassItemRepositoryStableIdTests.swift` | Deduplication tests |
| `Molten.entitlements` | CloudKit & App Group configuration |

---

## 8. Loading Workflow Summary

```
┌─────────────────────────────────────────────────────────┐
│ App Startup / User Initiates Load                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────┐
        │ GlassItemDataLoadingService│
        └────────────┬───────────────┘
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
    ┌──────────────┐  ┌─────────────────┐
    │ JSONDataLoader│  │ CatalogService  │
    │ (Find & Load) │  │ (Coordinate)    │
    └──────┬────────┘  └────────┬────────┘
           │                    │
           ▼                    ▼
    Load glassitems.json   Get existing items
           │                    │
           ▼                    ▼
    Decode CatalogItemData  Fetch from CoreData
           │                    │
           └────────┬───────────┘
                    ▼
           ┌────────────────────────┐
           │ Compare & Categorize   │
           │ (by stable_id)         │
           └────┬────┬───────┬──────┘
                │    │       │
         ┌──────▼┐ ┌─▼──┐ ┌──▼────┐
         │Create │ │Upd │ │Unchanged
         │(82)   │ │ate │ │(2500)
         │       │ │(20)│
         └───┬───┘ └─┬──┘ └───┬────┘
             │      │        │
             └──────┼────────┘
                    │
    ┌───────────────▼────────────────┐
    │ CoreDataGlassItemRepository    │
    │ (Execute Creates/Updates)      │
    └───────┬──────────────┬─────────┘
            │              │
         CREATE          UPDATE
         by              by
         stable_id       stable_id
            │              │
            └──────┬───────┘
                   ▼
          ┌────────────────────┐
          │ NSPersistentStore  │
          │ (SQLite)           │
          └────┬───────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ CloudKit Sync            │
    │ (via NSPersistentCloudKit│
    │  Container)              │
    └──────────────────────────┘
```

---

## Key Takeaways

1. **Primary Key: stable_id** - A 6-character hash, mandatory, unique, immutable
2. **JSON Source: 2,782 Items** - Loaded from bundle at `/Sources/Resources/glassitems.json`
3. **Upsert Pattern** - Creates if new, updates if stable_id exists
4. **CloudKit Enabled** - All data syncs to `iCloud.com.motleywoods.molten` container
5. **Batch Processing** - Configurable batch sizes, error recovery, progress tracking
6. **Change Detection** - JSON checksums prevent redundant reloads
7. **Tag Syncing** - Tags update even for "unchanged" glass items
8. **App Group Storage** - Shared container at `group.com.melissabinde.molten`

