# Unified Catalog/Inventory/Shopping UI Redesign

## Executive Summary

The Molten app has three tabs (Catalog, Inventory, Shopping) that all show glass items from the same catalog, just filtered and displayed differently. Users report:
- Forgetting which tab they're in
- Having to switch tabs too often for simple tasks
- Same item looking different across tabs
- Filters/search not carrying across tabs

**Goal**: Streamline the experience while preserving all existing functionality.

---

## Current Features (Accurate Understanding)

### Catalog Tab
**Purpose**: Browse and discover glass, search for specific items
- Shows ALL items in the catalog
- Primary actions: View details, add to inventory, add to shopping list
- Row display: Name, SKU, manufacturer, tags, rating (if available)

### Inventory Tab
**Purpose**: See what glass I own, add/remove quantities
- Shows ONLY items that have inventory > 0
- Primary actions: +/- quantities, move between locations, view details
- Row display: Same as catalog PLUS quantity badges (e.g., "12 rods", "3 sheets")
- Extra features: Location filtering, QR scanning, label printing

### Shopping Tab
**Purpose**: Wish list of glass I want to buy, organized by store
- Shows ONLY items on the shopping list
- Each item has: quantity needed, store where I plan to buy it
- **Shopping Mode**: At-the-store checkout flow - check off items, then bulk-add to inventory and remove from list
- Row display: Same as catalog PLUS "need X rods" badge and store name

### Key Insight
All three tabs:
- Use the same underlying data (`CompleteInventoryItemModel`)
- Navigate to the same detail view (`InventoryDetailView`)
- Have nearly identical filter options (tags, COE, manufacturer)
- Use the same row component (`GlassItemRowView`) with different configurations

The detail view already lets you do EVERYTHING:
- Add inventory
- Add to shopping list
- Edit notes and tags
- View all item info

---

## The Real Problems

1. **Three tabs for what feels like one thing** - "show me glass" with different filters
2. **Context switching** - I find a glass in Catalog, then switch to Inventory to see if I have it, then switch to Shopping to add it to my wish list
3. **Inconsistent filtering** - I filter by "opal" tags in Catalog, switch to Inventory, filter is gone
4. **Mental model mismatch** - Users think "I want to look at my glass" not "I want to use the Inventory tab"

---

## Proposed Solution: Single View with Contextual Filters

### Core Idea
Replace three tabs with ONE "Glass" tab that shows all items, with **prominent quick-filter buttons** at the top:

```
┌─────────────────────────────────────────────────────────────┐
│  Glass                                        [🔍] [Filter] │
├─────────────────────────────────────────────────────────────┤
│  ┌─────┐  ┌──────────┐  ┌──────────────┐                    │
│  │ All │  │ My Glass │  │ Want to Buy  │    ← Quick Filters │
│  └─────┘  └──────────┘  └──────────────┘                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [List of glass items, display adapts to context]           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Quick Filters Explained

| Filter | What It Shows | Equivalent To |
|--------|---------------|---------------|
| **All** | Entire catalog | Current Catalog tab |
| **My Glass** | Items I own (inventory > 0) | Current Inventory tab |
| **Want to Buy** | Items on my shopping list | Current Shopping tab |

### Row Display Adapts to Context

**In "All" mode:**
- Basic row: Name, SKU, manufacturer, tags
- If item has inventory: Show small quantity indicator
- If item is on shopping list: Show small "wish list" indicator

**In "My Glass" mode:**
- Show quantity badges prominently (same as current Inventory)
- Show location if filtering by location

**In "Want to Buy" mode:**
- Show "need X" quantity and store (same as current Shopping)
- Shopping Mode button available to start checkout flow

### What Stays the Same
- **Shopping Mode/Checkout** - Still works exactly as today, just accessed from "Want to Buy" filter
- **Location filtering** - Available in "My Glass" mode
- **Store filtering** - Available in "Want to Buy" mode
- **Detail view** - Unchanged, still the hub for all actions
- **All current functionality** - Nothing is removed

### What Changes
- **One tab instead of three** - Frees up tab bar space
- **Filters persist** - Tag/COE/manufacturer filters carry across quick-filter changes
- **Search persists** - Search text carries across quick-filter changes
- **Unified row component** - One smart row that adapts its display

---

## UI Mockups

### "All" Mode (Catalog)
```
┌─────────────────────────────────────────────────────────────┐
│  🔍 Search...                                               │
├─────────────────────────────────────────────────────────────┤
│  [All•]  [My Glass]  [Want to Buy]                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────┬──────────────────────────────────────────────┐    │
│  │ 🟠  │ Red Opal (0001)                        ★ 4.2 │    │
│  │     │ Bullseye • COE 90                            │    │
│  │     │ [opal] [warm] [red]                    🗃️ 12 │    │
│  └─────┴──────────────────────────────────────────────┘    │
│  ┌─────┬──────────────────────────────────────────────┐    │
│  │ 🟡  │ Clear (0100)                                 │    │
│  │     │ Bullseye • COE 90                            │    │
│  │     │ [transparent] [clear]              🛒 wish   │    │
│  └─────┴──────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘

🗃️ = has inventory, 🛒 = on wish list
```

### "My Glass" Mode (Inventory)
```
┌─────────────────────────────────────────────────────────────┐
│  🔍 Search...                                               │
├─────────────────────────────────────────────────────────────┤
│  [All]  [My Glass•]  [Want to Buy]                          │
├─────────────────────────────────────────────────────────────┤
│  📍 Location: [All ▼]                                       │
├─────────────────────────────────────────────────────────────┤
│  ┌─────┬────────────────────────────────────┬─────────┐    │
│  │ 🟠  │ Red Opal (0001)                    │ 12 rods │    │
│  │     │ Bullseye • COE 90                  │  3 frit │    │
│  │     │ [opal] [warm]                      │         │    │
│  └─────┴────────────────────────────────────┴─────────┘    │
│  ┌─────┬────────────────────────────────────┬─────────┐    │
│  │ 🔵  │ Cobalt Blue (0147)                 │  5 rods │    │
│  │     │ Bullseye • COE 90                  │         │    │
│  │     │ [opal] [blue]                      │         │    │
│  └─────┴────────────────────────────────────┴─────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### "Want to Buy" Mode (Shopping List)
```
┌─────────────────────────────────────────────────────────────┐
│  🔍 Search...                                    [🛒 Shop]  │
├─────────────────────────────────────────────────────────────┤
│  [All]  [My Glass]  [Want to Buy•]                          │
├─────────────────────────────────────────────────────────────┤
│  🏪 Store: [All ▼]                                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────┬────────────────────────────────────┬─────────┐    │
│  │ 🟡  │ Clear (0100)                       │    5    │    │
│  │     │ Bullseye • COE 90                  │  rods   │    │
│  │     │ @ Frantz Art Glass                 │         │    │
│  └─────┴────────────────────────────────────┴─────────┘    │
│  ┌─────┬────────────────────────────────────┬─────────┐    │
│  │ 🟢  │ Aventurine Green (1112)            │    3    │    │
│  │     │ Bullseye • COE 90                  │  rods   │    │
│  │     │ @ Arrow Springs                    │         │    │
│  └─────┴────────────────────────────────────┴─────────┘    │
│                                                             │
│                          [🛒 Start Shopping]                │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Approach

### Option A: Refactor in Place (Recommended)
1. Start with `CatalogView` as the base
2. Add quick-filter tabs that change which items are shown
3. Make the row view adapt based on quick-filter context
4. Import location filter from Inventory, store filter from Shopping
5. Import Shopping Mode from Shopping
6. Remove Inventory and Shopping tabs once complete

### Option B: New View from Scratch
1. Create `UnifiedGlassView`
2. Build unified ViewModel combining all three
3. Migrate features one by one
4. Swap tabs when ready

### Recommended: Option A
Less risk, easier to test incrementally, reuses proven code.

---

## What We're NOT Changing

- **Shopping Mode / Checkout flow** - Works well, just moves to unified view
- **Detail view** - Already unified, no changes needed
- **Location management** - Same feature, same UI
- **QR scanning** - Same feature, same UI
- **Label printing** - Same feature, same UI
- **Add to inventory flow** - Same feature
- **Add to shopping list flow** - Same feature

---

## Design Decisions (Confirmed)

1. **Quick filter labels**: "All" / "My Glass" / "Wish List"

2. **Status indicators in "All" mode**: Yes, show both - small icons indicating "I own this" and/or "I want this"

3. **Filter persistence**: Filters persist across quick-filter switches (if I filter by 'opal' tag, keep it when switching modes)

4. **Default view**: Remember last used mode

5. **Tab bar**: Keep current structure, just merge the 3 tabs into 1 "Glass" tab

---

## Implementation Plan

### Phase 1: Create Unified Glass View ✅ COMPLETE
- Created `UnifiedGlassView.swift` with quick-filter tabs
- Created `UnifiedGlassViewModel.swift` combining filtering logic from all 3 ViewModels
- Persisted quick-filter and detailed filters to UserDefaults

### Phase 2: Adaptive Row Display ✅ COMPLETE
- Added `GlassItemRowView.unified()` factory method with status indicators
- Shows archive icon + quantity when item has inventory
- Shows heart icon when item is on wish list

### Phase 3: Context-Specific Features ✅ COMPLETE
- Location filter bar shows in "My Glass" mode
- Store filter bar shows in "Wish List" mode
- "Start Shopping" button in "Wish List" mode
- Full Shopping Mode with checkout flow

### Phase 4: Tab Bar Integration ✅ COMPLETE
- Added `.glass` tab to `DefaultTab` enum
- Updated `MainTabView` to show unified view
- Added `ENABLE_UNIFIED_GLASS_VIEW` feature flag (defaults to true)
- Legacy tabs hidden when unified view enabled

### Phase 5: Cleanup (IN PROGRESS - molten-em8)
- ✅ Marked deprecated files with deprecation notices:
  - `CatalogView.swift`, `CatalogViewModel.swift`, `CatalogViewModelProtocol.swift`
  - `InventoryView.swift` (ViewModel embedded in view file)
  - `ShoppingListView.swift`, `ShoppingListViewModel.swift`, `ShoppingListViewModelProtocol.swift`
- Files NOT deleted yet (keep until unified view is stable in production)
- TODO: Delete deprecated files after production validation
- TODO: Update tests
- TODO: Update documentation

---

## Files Created/Modified

### New Files
- `Molten/Sources/Views/Glass/UnifiedGlassView.swift` (~950 lines)
- `Molten/Sources/Views/Glass/ViewModels/UnifiedGlassViewModel.swift` (~600 lines)

### Modified Files
- `Molten/Sources/App/DefaultTab.swift` - Added `.glass` case
- `Molten/Sources/App/FeatureFlags.swift` - Added `ENABLE_UNIFIED_GLASS_VIEW`
- `Molten/Sources/App/MainTabView.swift` - Added unified view support
- `Molten/Sources/Views/Shared/Components/GlassItemRowView.swift` - Added `.unified()` factory
