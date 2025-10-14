# Core Data Model Verification Checklist

## 🎯 Purpose
This document helps verify that all required entities for the catalog redesign are properly defined in your Core Data model (.xcdatamodeld file).

## ✅ Required Entities

### 1. Abstract Entity: `Item`
**Purpose**: Base entity for inheritance hierarchy

**Properties to verify**:
- This should be marked as "Abstract Entity" in Core Data
- May contain common properties shared by all item types

**Status**: ⏳ Needs verification

---

### 2. Entity: `GlassItem` (inherits from Item)
**Purpose**: Replaces current InventoryItem, represents glass inventory items

**Inheritance**: 
- Parent Entity: `Item`

**Properties to verify**:
- `natural_key` (String) - computed as {manufacturer}-{sku}-{sequence}
- `name` (String) - display name
- `sku` (String) - manufacturer's SKU (note: string, not integer)
- `manufacturer` (String) - manufacturer identifier
- `mfr_notes` (String, Optional) - manufacturer notes
- `coe` (Integer 32) - coefficient of expansion
- `url` (String, Optional) - manufacturer URL
- `uri` (String) - format: moltenglass:item?{natural_key}
- `mfr_status` (String) - availability status

**Status**: ⏳ Needs verification

---

### 3. Entity: `ItemTags`
**Purpose**: Normalized tagging system (many tags per item)

**Properties to verify**:
- `item_natural_key` (String) - foreign key to GlassItem
- `tag` (String) - individual tag value

**Relationships to verify**:
- Many-to-one relationship with GlassItem via item_natural_key

**Status**: ⏳ Needs verification

---

### 4. Entity: `Inventory`
**Purpose**: Tracks inventory quantities by type

**Properties to verify**:
- `id` (UUID) - primary key
- `item_natural_key` (String) - foreign key to GlassItem
- `type` (String) - inventory type (rod, frit, etc.)
- `quantity` (Double) - quantity amount

**Relationships to verify**:
- Many-to-one relationship with GlassItem via item_natural_key
- One-to-many relationship with Location

**Status**: ⏳ Needs verification

---

### 5. Entity: `Location`
**Purpose**: Tracks where inventory is stored

**Properties to verify**:
- `inventory_id` (UUID) - foreign key to Inventory
- `location` (String) - location name (auto-complete)
- `quantity` (Double) - quantity at this location

**Relationships to verify**:
- Many-to-one relationship with Inventory via inventory_id

**Status**: ⏳ Needs verification

---

### 6. Entity: `ItemMinimum`
**Purpose**: Shopping list and low water mark tracking

**Properties to verify**:
- `item_natural_key` (String) - foreign key to GlassItem
- `quantity` (Double) - minimum quantity threshold
- `type` (String) - inventory type
- `store` (String) - preferred store (auto-complete)

**Relationships to verify**:
- Many-to-one relationship with GlassItem via item_natural_key

**Status**: ⏳ Needs verification

---

## 🛠️ Verification Steps

### In Xcode Core Data Model Editor:

1. **Open your .xcdatamodeld file** in Xcode
2. **Check each entity exists** with exact names listed above
3. **Verify inheritance**: GlassItem should show "Item" as Parent Entity
4. **Confirm properties**: Each entity should have all listed properties with correct types
5. **Check relationships**: Verify foreign key relationships are properly configured
6. **Validate constraints**: Ensure required fields are marked as non-optional where appropriate

### Test Auto-Generation:
1. **Build your project** to trigger Core Data code generation
2. **Verify no build errors** related to Core Data entities
3. **Check generated files**: Auto-generated entity classes should appear

## 🚨 Common Issues to Watch For

- **Property type mismatches**: Ensure `sku` is String, `coe` is Integer 32, quantities are Double
- **Missing inheritance**: GlassItem must inherit from Item abstract entity
- **Relationship configuration**: Foreign keys should be properly set up as relationships
- **Optional vs Required**: Check which properties should be optional
- **Entity naming**: Exact case-sensitive names are required

## ✅ Completion Checklist

After verifying your Core Data model:

- [ ] All 6 entities exist in .xcdatamodeld
- [ ] GlassItem inherits from abstract Item entity
- [ ] All properties have correct names and types
- [ ] Relationships are properly configured
- [ ] Project builds without Core Data errors
- [ ] Auto-generated classes are available

Once this checklist is complete, we can proceed to Phase 2: Repository Layer implementation.

---

## 📝 Notes

**Current Status**: Starting verification of existing Core Data model

**Next Step**: Create first repository protocol and implementation once entities are confirmed