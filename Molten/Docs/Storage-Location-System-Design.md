# Storage Location System Design

## Goal

Users can easily track their inventory (quantities), understand where they put it (locations), and print labels (dates) without having to remember "how many new rods did I add that need labels?" or "how many are upstairs versus downstairs?"

## Design Constraints

1. **CloudKit compatibility:** No unique constraints at Core Data level. Use relationships and code-level validation.
2. **Human scale:** Personal inventory, not warehouse management. No need for denormalized aggregates.

## Core Entities

### StorageLocationDefinition
Canonical source of truth for location names.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| name | String | e.g., "Shelf A", "Studio" |
| notes | String? | Optional description |
| createdAt | Date | |
| modifiedAt | Date | |
| deletedAt | Date? | Soft delete |
| workspaceId | UUID? | Future |

**Status:** Exists, correctly implemented.

### Inventory
Defines *what* the inventory is - physical characteristics.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| item_stable_id | String | References GlassItem |
| type | String | rod, tube, frit, etc. |
| subtype | String? | |
| subsubtype | String? | |
| dimensions | [String: Double]? | |
| date_modified | Date | |
| workspace_id | UUID? | |
| quantity | Double | **DEPRECATED** - compute from StorageLocations |
| containerCount | Double? | **DEPRECATED** - moved to StorageLocation |
| date_added | Date | **DEPRECATED** - use StorageLocation.date_added |
| location | String? | **DEPRECATED** - use StorageLocation relationship |

**Uniqueness (code-enforced):** `(item_stable_id, type, subtype, subsubtype, dimensions)`

### StorageLocation
Tracks *where*, *when*, and *how much* inventory exists.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| inventory_id | UUID | References Inventory |
| location_definition_id | UUID? | References StorageLocationDefinition. nil = unassigned |
| quantity | Double | Current amount at this location (>= 0) |
| containerCount | Double? | For weight-based types: jars at this location |
| date_added | Date | When placed here |
| date_modified | Date | |
| workspace_id | UUID? | |

**Quantity mutations:**
- Consume: decrement `quantity`, create `InventoryConsumptionRecord`
- Move out: decrement `quantity`, create `InventoryMoveRecord`
- Move in: increment `quantity` on existing record, or create new `StorageLocation`

**No location sentinel:** Use `__MLTN_NO_LOCATION__` internally if Core Data requires non-nil. Never display to users.

**Status:** Exists but needs: `date_added`, `date_modified`, `containerCount`. Remove: `locationName` cache.

### InventoryMoveRecord
Audit log for moves between locations.

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| from_storage_location_id | UUID | References source StorageLocation |
| to_storage_location_id | UUID | References destination StorageLocation |
| quantity | Double | Amount moved (weight or count) |
| containerCount | Double? | Jars moved (for weight-based types) |
| date | Date | Date of move |

**Deduplication:** Same `(from_storage_location_id, to_storage_location_id, date)` increments quantity/containerCount rather than creating new record.

**Status:** Does not exist yet.

### InventoryConsumptionRecord
Audit log for consumed inventory (used up, not moved).

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | Primary key |
| storage_location_id | UUID | References StorageLocation it came from |
| quantity | Double | Amount consumed (weight or count) |
| containerCount | Double? | Jars consumed (for weight-based types) |
| date | Date | Date of consumption |

**Deduplication:** Same `(storage_location_id, date)` increments quantity/containerCount rather than creating new record.

**Status:** Does not exist yet.

## Data Model Example

User has 10 rods: 5 on Shelf A (Monday), 3 in Garage (Monday), 2 on Shelf A (Wednesday). Consumes 1 from Shelf A Thursday. Moves 2 from Shelf A to Garage Friday.

**Inventory:** Single record for "Bullseye Ruby Red / rod / nil / nil"

**StorageLocation records:**
| id | location | qty | date_added |
|----|----------|-----|------------|
| sl-1 | Shelf A | 4 | Mon |
| sl-2 | Garage | 5 | Mon |
| sl-3 | Shelf A | 2 | Wed |

Note: sl-1 started at 5, decremented to 4 (consumed 1). sl-2 started at 3, incremented to 5 (received 2 from move).

**InventoryConsumptionRecord:**
| storage_location_id | qty | date |
|---------------------|-----|------|
| sl-1 | 1 | Thu |

**InventoryMoveRecord:**
| from | to | qty | date |
|------|-----|-----|------|
| sl-1 | sl-2 | 2 | Fri |

**Computed totals:**
- Total: 4 + 5 + 2 = 11... wait, that's wrong.

Actually: Started with 10, consumed 1 = 9. The move is internal (doesn't change total).
- sl-1: 5 - 1 (consumed) - 2 (moved out) = 2
- sl-2: 3 + 2 (moved in) = 5
- sl-3: 2
- Total: 2 + 5 + 2 = 9 ✓

**Corrected StorageLocation records:**
| id | location | qty | date_added |
|----|----------|-----|------------|
| sl-1 | Shelf A | 2 | Mon |
| sl-2 | Garage | 5 | Mon |
| sl-3 | Shelf A | 2 | Wed |

## Key Operations

### Add Inventory
1. Find/create Inventory for `(item, type, subtype, subsubtype, dimensions)`
2. Create StorageLocation with quantity, location_definition_id, today

### Consume Inventory
1. Decrement `StorageLocation.quantity`
2. Create `InventoryConsumptionRecord` with storage_location_id, quantity, today

### Move Inventory
1. Decrement source `StorageLocation.quantity`
2. Increment destination `StorageLocation.quantity` (or create new record)
3. Create `InventoryMoveRecord` linking source, destination, quantity, today

### Rename Location
1. Update StorageLocationDefinition.name
2. Done (all references are by ID)

### Delete Location
1. Find StorageLocation records with this location_definition_id
2. Prompt user for destination (another location or nil)
3. Update location_definition_id on those records
4. Soft-delete the StorageLocationDefinition

### Query: Added Today (for label printing)
`StorageLocation WHERE date(date_added) = today`

### Query: Current Quantity at Location
`SUM(StorageLocation.quantity) WHERE location_definition_id = X`

### Query: Total Quantity
`SUM(StorageLocation.quantity) WHERE inventory_id = X`

## Migration Notes

Existing data has:
- `Inventory.location` as raw string
- `Inventory.quantity` as aggregate
- `Inventory.date_added` as single date
- Some `StorageLocation` records possibly exist but are inconsistent

Migration must:
1. Add new fields to StorageLocation entity
2. Add InventoryMoveRecord entity
3. Add InventoryConsumptionRecord entity
4. For each Inventory with non-nil location string:
   - Find/create StorageLocationDefinition for that name
   - Create StorageLocation record linking them
5. Mark deprecated fields as ignored in code
