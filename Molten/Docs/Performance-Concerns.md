# Performance Concerns

## Catalog View Memory & Performance Analysis

### Current State

The app fetches all 2,500 catalog items at once and loads them into memory as arrays.

**Implementation Details** (as of 2025-11-20):

- **CatalogViewModel.swift:109-111**: Three array copies in memory
  ```swift
  var items: [CompleteInventoryItemModel] = []
  var filteredItems: [CompleteInventoryItemModel] = []
  var sortedFilteredItems: [CompleteInventoryItemModel] = []
  ```

- **CatalogView.swift:681**: Passes entire sorted array to view
  ```swift
  CatalogListView(items: sortedFilteredItems)
  ```

- **CatalogListView.swift:14**: Uses `List` with `ForEach` over full array
  ```swift
  List {
      ForEach(items, id: \.id) { item in
          NavigationLink(value: ...) {
              GlassItemRowView.catalog(item: item)
          }
      }
  }
  ```

### What Works

✅ **`List` lazy rendering**: SwiftUI's `List` only renders visible rows and recycles views as you scroll - this is good for UI performance.

### What Doesn't Work

❌ **All 2,500+ items loaded into memory upfront**: The entire catalog is materialized as `CompleteInventoryItemModel` objects before rendering.

❌ **Three copies in memory**: Original items, filtered items, sorted filtered items - all kept in RAM.

❌ **No Core Data lazy loading**: Not using `@FetchRequest` or `NSFetchedResultsController`, which would fault objects on demand.

❌ **Filter/sort operations on full dataset**: Every filter change processes all 2,500 items in memory.

### Performance Impact

**Potential Issues**:

1. **Initial fetch time**: Even if Core Data is smart about memory, the initial fetch request for 2,500 items might have noticeable latency on older devices.

2. **Memory pressure**: On devices with limited RAM (iPhone SE 2020 has 3GB), holding 2,500+ model objects could contribute to memory pressure.

3. **Search performance**: Filtering 2,500 items in memory on every keystroke (even with 300ms debounce) might be slower than database-level filtering.

4. **Triple buffering overhead**: Maintaining three separate arrays (`items`, `filteredItems`, `sortedFilteredItems`) wastes memory.

### Arguments AGAINST Pagination (Pre-Measurement)

1. **One-time load**: Catalog data is read-only, shipped with the app. It's loaded once when you enter the catalog view, then cached in memory. Not continuously re-fetched.

2. **Core Data could be optimized for this**: With proper fetch request configuration (batch sizes, faulting), Core Data doesn't need to load all 2,500 objects into memory at once - it fetches objects as needed.

3. **Added complexity**: Pagination adds state management, loading indicators, edge cases (search while paginating, etc.).

### Arguments FOR Optimization

1. **Actual memory usage**: Currently materializing all 2,500 items in RAM is wasteful when only 10-20 are visible.

2. **Initial load latency**: Users might experience noticeable delay on app launch while building the full catalog.

3. **Search responsiveness**: Filtering in-memory arrays is O(n) on every keystroke - could be slow.

## Recommendation

**Before adding pagination or major refactoring, instrument the current implementation:**

### Step 1: Add Performance Metrics

```swift
let start = CFAbsoluteTimeGetCurrent()
let items = try await catalogService.fetchAllItems()
let duration = CFAbsoluteTimeGetCurrent() - start
logger.info("Catalog fetch took \(duration)s for \(items.count) items")
```

### Step 2: Measure Memory Usage

Use Instruments (Memory Profiler) to see:
- Peak memory usage when loading catalog
- Memory footprint of 2,500 `CompleteInventoryItemModel` objects
- Memory pressure on iPhone SE (2020) or similar low-RAM device

### Step 3: Decision Criteria

**If initial load is < 300ms and search is responsive**, current approach is fine.

**If you see measurable performance problems**, consider:

1. **Core Data NSFetchedResultsController**: Lazy object faulting, automatic UI updates
2. **Pagination**: Fetch 100 items at a time, lazy load on scroll
3. **Virtual scrolling**: Only materialize visible objects
4. **Database-level filtering**: Push search/filter to Core Data predicates instead of in-memory array operations

## Alternative Approaches

### Option 1: NSFetchedResultsController (Recommended First)

Replace array-based `items` with Core Data controller that faults objects on demand:

```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \GlassItem.name, ascending: true)],
    animation: .default
)
private var glassItems: FetchedResults<GlassItem>
```

**Pros**:
- Automatic lazy loading
- Automatic UI updates on data changes
- Built-in sectioning/sorting

**Cons**:
- Harder to test (Core Data dependency)
- Requires refactoring ViewModel

### Option 2: Pagination

Fetch items in chunks (100 at a time), load more on scroll.

**Pros**:
- Reduces initial load time
- Limits memory footprint

**Cons**:
- Complex state management (page offsets, loading states)
- Search/filter UX complications (what happens mid-pagination?)
- More code to maintain

### Option 3: Database-Level Filtering

Push search/filter predicates to Core Data instead of filtering in memory:

```swift
let predicate = NSPredicate(format: "name CONTAINS[cd] %@ AND manufacturer IN %@", searchText, manufacturers)
fetchRequest.predicate = predicate
```

**Pros**:
- Leverages SQLite indexing (fast)
- Only materializes matching objects

**Cons**:
- Complex predicate building for combined filters
- Still need to handle sorting in memory or via sort descriptors

## Status

**As of 2025-11-20**: No performance metrics collected. Need baseline measurements before optimizing.

**Next Steps**:
1. Add instrumentation to measure fetch time, filter time, memory usage
2. Test on iPhone SE (2020) or equivalent low-RAM device
3. Profile with Instruments (Time Profiler, Allocations)
4. Make data-driven decision about optimization approach
