# Rating System: Core Data Entities

The rating system requires three new Core Data entities. These must be manually added to `Molten.xcdatamodeld` in Xcode.

---

## Entity 1: ItemRating (Local Store)

**Configuration:**
- Store: Local Store (no CloudKit sync)
- Code Generation: Category
- Module: (leave empty for Global Namespace)

**Attributes:**
- `itemStableId` (String, non-optional)
  - Indexed: Yes
- `averageRating` (Double, non-optional)
  - Default: 0.0
- `totalRatings` (Integer 64, non-optional)
  - Default: 0
- `lastUpdated` (Date, non-optional)

**Purpose:**
Caches aggregated rating data fetched from server. Stored in Local Store (no CloudKit sync) because it's read-only server data.

---

## Entity 2: ItemRatingWord (Local Store)

**Configuration:**
- Store: Local Store (no CloudKit sync)
- Code Generation: Category
- Module: (leave empty for Global Namespace)

**Attributes:**
- `itemStableId` (String, non-optional)
- `word` (String, non-optional)
- `frequency` (Integer 64, non-optional)
  - Default: 0
- `rank` (Integer 16, non-optional)
  - Default: 0

**Indexes:**
- Compound index on: `itemStableId`, `rank`

**Purpose:**
Stores top words for an item. Follows same pattern as `ItemTags` entity (separate rows, not JSON). Stored in Local Store because it's read-only server data.

---

## Entity 3: PendingRatingSubmission (Cloud Store)

**Configuration:**
- Store: Cloud Store (CloudKit sync enabled)
- Code Generation: Category
- Module: (leave empty for Global Namespace)

**Attributes:**
- `id` (UUID, non-optional)
- `itemStableId` (String, non-optional)
- `starRating` (Integer 16, non-optional)
- `word1` (String, non-optional)
- `word2` (String, non-optional)
- `word3` (String, non-optional)
- `word4` (String, non-optional)
- `word5` (String, non-optional)
- `createdAt` (Date, non-optional)
- `attempts` (Integer 16, non-optional)
  - Default: 0

**Purpose:**
Offline queue for rating submissions. Stored in Cloud Store so submissions sync across user's devices. Once submitted to server successfully, removed from queue.

---

## Adding Entities to Core Data

### Steps:
1. Open `Molten.xcodeproj` in Xcode
2. Navigate to `Molten/Molten.xcdatamodeld/Molten 16.xcdatamodel`
3. Click "+" at bottom to add entity
4. Name it (e.g., "ItemRating")
5. Add attributes as specified above
6. Set configurations:
   - **Local Store entities**: Editor → Add Configuration → Select "Local"
   - **Cloud Store entities**: Editor → Add Configuration → Select "Cloud"
7. Add indexes as specified
8. Repeat for all three entities
9. Build project to generate Core Data classes

### Verifying Configuration

After adding entities, verify with:
```bash
grep -A 20 "entity name=\"ItemRating\"" Molten/Molten.xcdatamodeld/Molten\ 16.xcdatamodel/contents
```

Should show the entity with all attributes and correct configuration.

---

## Two-Store Architecture Reminder

**Why separate stores?**
- **Local Store**: Read-only data that's identical for all users (catalog, aggregated ratings from server)
- **Cloud Store**: User-specific data that syncs via CloudKit (inventory, pending submissions)

Mixing them would cause CloudKit to duplicate catalog/rating data across devices.
