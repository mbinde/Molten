# Storage Location Implementation Plan

Reference: `Storage-Location-System-Design.md`

## Current State Gaps

### Core Data Schema

**StorageLocation entity exists but missing:**
- `date_added: Date`
- `date_modified: Date`
- `containerCount: Double?`
- `is_transfer: Bool`

**StorageLocation entity has but should remove:**
- `locationName: String` (cached - should always look up from definition)

**InventoryMoveRecord entity does not exist. Fields needed:**
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| from_storage_location_id | UUID | References source StorageLocation |
| to_storage_location_id | UUID | References destination StorageLocation |
| quantity | Double | Amount moved |
| container_count | Double? | Jars moved (for weight-based types) |
| date | Date | Date of move |

**InventoryConsumptionRecord entity does not exist. Fields needed:**
| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| storage_location_id | UUID | References StorageLocation it came from |
| quantity | Double | Amount consumed |
| container_count | Double? | Jars consumed (for weight-based types) |
| date | Date | Date of consumption |

### Code Gaps

**Writing location strings instead of using entities:**
- `InventoryEditView.saveChanges()` - writes to `Inventory.location` string
- `QuickAddInventoryView.addInventory()` - writes to `Inventory.location` string
- `InventoryTrackingService.addInventory()` - writes to `Inventory.location` string
- `ManageLocationsView` rename/merge/delete - updates `Inventory.location` strings

**Not creating StorageLocation records:**
- Most add/edit flows create/update `Inventory` directly, don't touch `StorageLocation`

**StorageLocation usage is minimal:**
- Only used in import service, one rename operation, and delete cleanup

## Implementation Phases

### Phase 1: Core Data Migration

1. Create new Core Data model version
2. Add to StorageLocation entity:
   - `date_added: Date` (optional for migration)
   - `date_modified: Date` (optional for migration)
   - `containerCount: Double` (optional)
   - `is_transfer: Bool` (default false)
3. Add InventoryMoveRecord entity:
   - `id: UUID`
   - `from_storage_location_id: UUID`
   - `to_storage_location_id: UUID`
   - `quantity: Double`
   - `container_count: Double` (optional)
   - `date: Date`
4. Add InventoryConsumptionRecord entity:
   - `id: UUID`
   - `storage_location_id: UUID`
   - `quantity: Double`
   - `container_count: Double` (optional)
   - `date: Date`
5. Keep `locationName` on StorageLocation for now (remove in Phase 6)
6. Keep all deprecated Inventory fields (remove in future major version)

### Phase 2: Model Layer Updates

1. Update `StorageLocationModel` struct:
   - Add `dateAdded`, `dateModified`, `containerCount`, `isTransfer`
   - Keep `locationName` for reading legacy data
2. Create `InventoryMoveRecordModel` struct (with `containerCount`)
3. Create `InventoryConsumptionRecordModel` struct (with `containerCount`)
4. Update `StorageLocationRepository` protocol:
   - Methods to query by date, by is_transfer flag
5. Create `InventoryMoveRecordRepository` protocol
6. Create `InventoryConsumptionRecordRepository` protocol
7. Implement Core Data repositories for new/updated entities

### Phase 3: Service Layer Updates

1. Update `InventoryTrackingService.addInventory()`:
   - Create StorageLocation record (not just Inventory.location string)
   - Link to StorageLocationDefinition by ID
2. Create consume operation:
   - Decrement StorageLocation.quantity
   - Create InventoryConsumptionRecord with consumed quantity/containerCount
3. Create move operation:
   - Decrement source StorageLocation.quantity
   - Find/create destination StorageLocation with is_transfer=true, increment quantity
   - Create InventoryMoveRecord linking source, destination, quantity/containerCount
4. Update quantity computation:
   - Sum StorageLocation.quantity instead of reading Inventory.quantity
5. Add migration service:
   - Converts legacy Inventory.location strings to proper StorageLocation records

### Phase 4: View Layer Updates

**Dependency order:** InventoryViewModel must be updated before views that depend on it.

#### Writers (stop writing to Inventory.location)

1. `QuickAddInventoryView` - creates new inventory with location
   - Call service to create StorageLocation instead of setting Inventory.location
2. `InventoryEditView` - updates existing inventory location
   - Update StorageLocation record instead of Inventory.location
3. `InventoryTrackingService.createCompleteItem()` - bulk create with locations
   - Create StorageLocation records for each inventory with location
4. `BackupService.restoreInventory()` - restores from backup
   - Create StorageLocation records during restore
5. `InventoryImportService` - imports with locations
   - Already uses StorageLocation in some paths, ensure consistent

#### Readers (switch from Inventory.location to StorageLocation)

1. `InventoryViewModel` (do first - other views depend on it)
   - `applyFilters()` - filter by StorageLocation.storageLocationId
   - `computeLocationCounts()` - count from StorageLocation records
   - `computeManufacturerCounts()` etc - cross-filter logic
2. `CompleteInventoryItemModel` aggregations
   - `inventoryByLocation` - group by StorageLocation
   - `locations` - extract from StorageLocation records
3. `InventoryView` / `GlassItemRowView` - display and filter matching
4. `LabelPrintingService` / `LabelDesignerView` / `LabelPreviewView`
   - Get location from StorageLocation, filter by date_added and is_transfer=false
5. `ManageLocationsView`
   - Rename: just updates StorageLocationDefinition.name
   - Delete: reassign StorageLocation.storageLocationId
   - Merge: same as delete
6. `LocationQuickFilterBar` - filter by storageLocationId
7. `BackupService` - serialize StorageLocation data (not just Inventory.location)
8. `FriendInventoryViewModel` - include location in shared snapshot

### Phase 5: Data Migration (Runtime)

On app launch (once):
1. Find all Inventory records where location string is non-nil
2. For each:
   - Find or create StorageLocationDefinition for that name
   - Create StorageLocation record linking inventory to definition
   - Set quantity from Inventory.quantity
   - Set date_added from Inventory.date_added
   - Set containerCount from Inventory.containerCount
3. Mark migration complete in UserDefaults

### Phase 6: Cleanup (Future Major Version)

1. Remove `locationName` from StorageLocation entity
2. Remove deprecated fields from Inventory entity (or just ignore them forever)

## Test Plan

### Unit Tests
- StorageLocationModel with new fields (dateAdded, dateModified, containerCount, isTransfer)
- InventoryMoveRecordModel (with containerCount)
- InventoryConsumptionRecordModel (with containerCount)
- Quantity computation from StorageLocation records
- Move operation creates correct records

### Integration Tests
- Add inventory creates StorageLocation
- Consume decrements StorageLocation.quantity and creates InventoryConsumptionRecord
- Move decrements source, increments dest (is_transfer=true), creates InventoryMoveRecord
- Rename location only touches definition
- Delete location updates StorageLocation references
- Migration converts legacy data correctly
- Label printing filters by is_transfer=false

### Manual Testing
- Add inventory with location → appears in Manage Locations
- Rename location → all inventory shows new name
- Delete location → reassignment works
- Filter by location works
- Label printing shows only today's non-transfer additions

## Risk Areas

1. **CloudKit sync:** New entities/fields need to sync properly
2. **Migration timing:** Must run before any queries expect new data model
3. **Quantity computation performance:** Summing StorageLocation records on every access - monitor for issues
4. **Existing StorageLocation records:** Some may exist from import service - handle gracefully in migration
