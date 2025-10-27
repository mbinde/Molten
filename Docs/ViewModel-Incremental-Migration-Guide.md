# ViewModel Incremental Migration Guide (Approach B)

This document outlines the strategy for incrementally migrating complex views (CatalogView, InventoryView) to use their existing ViewModels without breaking working functionality.

## Overview

**Current Situation:**
- CatalogViewModel and InventoryViewModel exist with full test coverage
- CatalogView (1153 lines) and InventoryView manage their own state
- Both views work correctly but have duplicate logic with their ViewModels

**Goal:** Migrate views to use ViewModels piece by piece, testing after each step.

## Incremental Migration Steps

### Phase 1: Add ViewModel Alongside Existing Logic (No Breaking Changes)

1. **Add ViewModel as property**
   ```swift
   struct CatalogView: View {
       @State private var searchText = ""  // Keep existing
       @State private var isLoading = false  // Keep existing

       // NEW: Add ViewModel but don't use it yet
       @StateObject private var viewModel: CatalogViewModel

       init(catalogService: CatalogService = ...) {
           self.catalogService = catalogService
           self._viewModel = StateObject(wrappedValue: CatalogViewModel(catalogService: catalogService))
       }
   }
   ```

2. **Run tests** - Verify nothing broke

### Phase 2: Migrate One Feature at a Time

Pick features from simplest to most complex:

#### Example: Migrate Search First

1. **Replace search state**
   ```swift
   // BEFORE:
   @State private var searchText = ""

   // AFTER:
   var searchText: String {
       get { viewModel.searchText }
       nonmutating set { viewModel.searchText = newValue }
   }
   ```

2. **Remove old search logic**
   - Delete local filtering code
   - Use `viewModel.filteredItems` instead

3. **Run tests** - Verify search works

#### Example: Migrate Loading State

1. **Replace loading state**
   ```swift
   // BEFORE:
   @State private var isLoading = false

   // AFTER: Use viewModel.isLoading directly
   ```

2. **Remove old loading logic**

3. **Run tests**

#### Example: Migrate Filtering

1. **Replace filter state** (tags, COEs, manufacturers)
2. **Remove old filter logic**
3. **Use `viewModel.filteredItems`**
4. **Run tests**

### Phase 3: Migrate Data Loading

1. **Replace `.task` logic**
   ```swift
   // BEFORE:
   .task {
       await catalogService.loadItems()
       items = await catalogService.getAll()
   }

   // AFTER:
   .task {
       await viewModel.loadItems()
   }
   ```

2. **Run tests**

### Phase 4: Clean Up

1. **Remove all duplicate @State properties**
2. **Remove helper methods that ViewModel now handles**
3. **Simplify view body to use ViewModel properties**
4. **Run full test suite**

## Testing Strategy

After **each phase:**
1. Run unit tests
2. Manually test the feature in simulator
3. Verify UI still works as expected
4. Only proceed if tests pass

## Rollback Plan

If any phase breaks functionality:
1. Git revert to previous commit
2. Re-evaluate what went wrong
3. Try smaller incremental step

## Benefits of This Approach

✅ **Low risk** - Can revert any single step
✅ **Testable** - Test after each change
✅ **Incremental** - Make progress without breaking working code
✅ **Flexible** - Can pause and resume migration

## When to Use This Approach

- ✅ Complex views (1000+ lines)
- ✅ Views with extensive state management
- ✅ Production-critical views that must keep working
- ❌ Simple views (use full rewrite instead)

## Example: CatalogView Migration Order

1. Search text → ViewModel
2. Loading state → ViewModel
3. Tag filtering → ViewModel
4. COE filtering → ViewModel
5. Manufacturer filtering → ViewModel
6. Sorting → ViewModel
7. Data loading → ViewModel
8. Caching logic → ViewModel
9. Clean up duplicate code

Each step tested before moving to next.

## Related Files

- **Pattern Examples:**
  - `PurchasesViewModel` - Simple complete pattern
  - `CatalogViewModel` - Complex ViewModel ready for integration
  - `InventoryViewModel` - Complex ViewModel ready for integration

- **Test Examples:**
  - `PurchasesViewModelTests` - 15 tests showing mock + integration pattern
  - `CatalogViewModelTests` - 40+ tests for complex ViewModel
  - `InventoryViewModelTests` - 29 tests for complex ViewModel
