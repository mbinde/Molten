# Catalog Data Model Redesign

## 🎯 Overview

Transitioning from the current `InventoryItem` based system to a new entity structure with `GlassItem` inheriting from abstract `Item` entity. This redesign provides better data normalization, flexible tagging, location-based inventory tracking, and shopping list functionality.

Instructions to Claude: If you are thinking "I notice that GlassItemRepository.swift isn't in the list, but we created it. Let me create it again since it seems to be missing:" -- or any other file -- it's not, you just need to look again. No one is deleting files underneath you.

Instructions to Claude: While the app is called Molten, the target is still called Flameworker, the old name, until we do a full rename, so you will need to use Flameworker for imports rather than Molten.

## 📊 Data Model Transition

### Current State → New State

| Current Entity | New Entity | Status | Notes |
|----------------|------------|---------|-------|
| InventoryItem | GlassItem | 🔄 Planning | Inherits from abstract `Item` entity |
| Tags (inline) | ItemTags | 🔄 Planning | Normalized many-to-many relationship |
| Inventory (embedded) | Inventory | 🔄 Planning | Separate entity with quantity tracking |
| N/A | Location | 🔄 Planning | Location-based inventory storage |
| N/A | ItemMinimum | 🔄 Planning | Shopping list and low water marks |

## 🏗️ New Entity Specifications

### GlassItem (inherits from Item)
```
Properties:
- natural_key: String (computed: {manufacturer}-{sku}-{sequence})
- name: String
- sku: String (note: string, not integer)
- manufacturer: String
- mfr_notes: String?
- coe: Int32
- url: String?
- uri: String (format: moltenglass:item?{natural_key})
- mfr_status: String

Example:
natural_key: cim-874-0
name: Adamantium
sku: 874
manufacturer: cim
mfr_notes: A brown gray color
coe: 104
url: https://creationismessy.com/color.aspx?id=60
uri: moltenglass:item?cim-874-0
mfr_status: available
```

### ItemTags
```
Properties:
- item_natural_key: String (foreign key)
- tag: String

Relationship: Many tags per item
```

### Inventory
```
Properties:
- id: UUID (primary key)
- item_natural_key: String (foreign key to GlassItem)
- type: String
- quantity: Double

Example:
id: (UUID)
item_natural_key: cim-874-0
type: rod
quantity: 7.0
```

### Location
```
Properties:
- inventory_id: UUID (foreign key to Inventory)
- location: String
- quantity: Double

Notes: Location names will auto-complete from existing entries
```

### ItemMinimum
```
Properties:
- item_natural_key: String (foreign key to GlassItem)
- quantity: Double
- type: String
- store: String

Purpose: Low water marks and shopping lists
Notes: Store names will auto-complete from existing entries
```

## 🔄 Migration Strategy

### Phase 1: Core Data Model Setup ✅
- [x] **Verify all entities are defined in Core Data model**
  - [x] Abstract entity: `Item`
  - [x] Entity: `GlassItem` (inherits from Item)
  - [x] Entity: `ItemTags`
  - [x] Entity: `Inventory`
  - [x] Entity: `Location`
  - [x] Entity: `ItemMinimum`
- [x] **Confirm inheritance relationship**: GlassItem → Item
- [x] **Validate all properties and relationships**
- [x] **Test Core Data model generation**

### Phase 2: Repository Layer
- [x] Create `GlassItemRepository` protocol
- [x] Create mock repositories for testing
- [ ] Implement Core Data repository for GlassItem
- [ ] Create `ItemTagsRepository` protocol and implementation
- [ ] Create `InventoryRepository` protocol and implementation  
- [ ] Create `LocationRepository` protocol and implementation
- [ ] Create `ItemMinimumRepository` protocol and implementation

### Phase 3: Service Layer
- [ ] Update `CatalogService` to work with GlassItem
- [ ] Create new `InventoryTrackingService` for inventory management
- [ ] Create `ShoppingListService` for ItemMinimum functionality
- [ ] Update service layer to aggregate data from multiple repositories

### Phase 4: Model Layer
- [ ] Create GlassItem domain model with business logic
- [ ] Implement natural key generation logic
- [ ] Add validation rules for new entities
- [ ] Create helper models for inventory aggregation

### Phase 5: View Layer Migration
- [ ] Update catalog views to use GlassItem
- [ ] Implement inventory detail views showing all types/locations
- [ ] Create shopping list views
- [ ] Add location management interface
- [ ] Maintain backward compatibility during transition

## 🧪 Testing Strategy

### Repository Tests
- [ ] GlassItem CRUD operations
- [ ] ItemTags many-to-many relationships
- [ ] Inventory quantity tracking
- [ ] Location-based inventory queries
- [ ] ItemMinimum shopping list queries

### Service Tests  
- [ ] GlassItem aggregation with tags
- [ ] Inventory consolidation by natural key
- [ ] Shopping list generation
- [ ] Location-based inventory reporting

### Integration Tests
- [ ] Full item creation with tags
- [ ] Inventory distribution across locations
- [ ] Shopping list workflows
- [ ] Data consistency across entities

## 📋 Key Features & Requirements

### Inventory Aggregation
- **Goal**: Collect all inventory for a given `item_natural_key` in one screen
- **Implementation**: Service layer aggregates from Inventory and Location repositories
- **Future**: Sort/group by type, subtype, and dimensions

### Natural Key Strategy
- **Format**: `{manufacturer}-{sku}-{sequence}`
- **Initial sequence**: 0
- **Purpose**: Handle potential SKU conflicts between manufacturers
- **Example**: `cim-874-0`

### Tagging System
- **Current**: Inline tags in InventoryItem
- **New**: Normalized ItemTags entity
- **Benefits**: Better searching, tag management, future user tags
- **Future**: User tags, tag categories, tag suggestions

### Location Management
- **Auto-complete**: Location names from existing entries
- **Flexible**: Multiple locations per inventory item
- **Tracking**: Exact quantities per location

### Shopping Lists
- **Low water marks**: ItemMinimum quantities per type
- **Store organization**: Group shopping lists by store
- **Auto-complete**: Store names from existing entries

## 🚨 Migration Considerations

### Data Preservation
- [ ] Export current InventoryItem data
- [ ] Map existing tags to ItemTags format
- [ ] Preserve inventory quantities in new structure
- [ ] Maintain historical data integrity

### Backward Compatibility
- [ ] Keep old repositories during transition
- [ ] Feature flags for new vs old data access
- [ ] Gradual migration path for users
- [ ] Rollback strategy if needed

## 📈 Success Metrics

### Functionality
- [ ] All current catalog features work with GlassItem
- [ ] Inventory aggregation works correctly
- [ ] Shopping list functionality is intuitive
- [ ] Location management is user-friendly

### Code Quality
- [ ] Test coverage maintained at current levels
- [ ] Clean architecture principles preserved
- [ ] Repository pattern consistently applied
- [ ] Service layer properly orchestrates data access

---

## 🔄 Status: Planning Phase

**Current Focus**: Understanding requirements and designing migration strategy

**Next Steps**:
1. Verify Core Data model is properly configured
2. Create first repository (GlassItemRepository) with TDD
3. Begin service layer updates
4. Plan view layer transition approach

**Blockers**: None identified

**Timeline**: TBD based on testing and implementation complexity
