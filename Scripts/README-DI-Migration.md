# DI Migration Scripts - Usage Guide

This directory contains automation tools for migrating views from `RepositoryFactory` to `AppDependencies` dependency injection.

## Scripts Overview

### 1. `plan-di-migration.sh` - Migration Planner
Scans the codebase and generates a migration plan organized by batches.

**Usage:**
```bash
./Scripts/plan-di-migration.sh [directory]
```

**Default:** Scans `Molten/Sources/Views`

**Output:**
- Total files and usages count
- Files organized by feature batches
- Most frequently used services
- Suggested migration order

**Example:**
```bash
./Scripts/plan-di-migration.sh

📊 Found 44 files with 141 total usages

📁 Batch 1: Main Navigation Views
  - CatalogView.swift (10 usages)
  - InventoryView.swift (8 usages)
  ...
```

---

### 2. `migrate-di.py` - Advanced Migration Tool
Python tool with three modes for automated transformations.

#### Mode 1: Analyze (Dry-Run)
Shows detailed migration plan without making changes.

**Usage:**
```bash
python3 Scripts/migrate-di.py --analyze <file>
```

**Example:**
```bash
python3 Scripts/migrate-di.py --analyze Molten/Sources/Views/Locations/LocationsView.swift

============================================================
DI Migration Analysis: LocationsView.swift
============================================================

📊 Total RepositoryFactory usages: 1
   - Default parameters: 0
   - Direct calls: 1

🔄 Direct Calls to Replace:
   Line 21: RepositoryFactory.createUnifiedLocationService()
            → dependencies.unifiedLocationService

📦 Services Used:
   - dependencies.unifiedLocationService
```

#### Mode 2: Migrate Single File
Applies automated transformations to a single file.

**Usage:**
```bash
python3 Scripts/migrate-di.py --migrate <file>
```

**What it does:**
1. Removes default parameters: `service: MyService = RepositoryFactory.createService()` → `service: MyService`
2. Replaces direct calls: `RepositoryFactory.createService()` → `dependencies.service`
3. Adds `@Environment(\.appDependencies)` if needed
4. Creates backup: `<file>.backup`

**Example:**
```bash
python3 Scripts/migrate-di.py --migrate Molten/Sources/Views/Locations/LocationsView.swift

✅ Migration completed!
   - Default parameters removed: 0
   - Direct calls replaced: 1
   - Environment added: Yes

💾 Backup saved: LocationsView.swift.backup
```

#### Mode 3: Batch Migration
Migrates all files in a directory.

**Usage:**
```bash
python3 Scripts/migrate-di.py --batch <directory>
```

**Example:**
```bash
python3 Scripts/migrate-di.py --batch Molten/Sources/Views/Locations

Scanning 3 Swift files in Molten/Sources/Views/Locations...

Migrating: LocationsView.swift
  ✅ Migrated (1 changes)

Batch migration complete: 1 files migrated
```

---

### 3. `migrate-to-di.sh` - Bash Migration Tool
Simple bash script for quick migrations.

**Usage:**
```bash
./Scripts/migrate-to-di.sh [--dry-run] <file>
```

**Features:**
- Shows what will be changed before applying
- Creates timestamped backups
- Provides next steps checklist

**Example:**
```bash
# Dry-run (see changes without applying)
./Scripts/migrate-to-di.sh --dry-run Molten/Sources/Views/Locations/LocationsView.swift

# Apply changes
./Scripts/migrate-to-di.sh Molten/Sources/Views/Locations/LocationsView.swift
```

---

## Service Mappings

The scripts automatically map RepositoryFactory methods to AppDependencies properties:

| RepositoryFactory Method | AppDependencies Property |
|--------------------------|--------------------------|
| `createCatalogService()` | `catalogService` |
| `createInventoryTrackingService()` | `inventoryTrackingService` |
| `createShoppingListService()` | `shoppingListService` |
| `createPurchaseRecordService()` | `purchaseRecordService` |
| `createProjectService()` | `projectService` |
| `createKilnScheduleService()` | `kilnScheduleService` |
| `createRecipeService()` | `recipeService` |
| `createUnifiedLocationService()` | `unifiedLocationService` |
| `createEntitlementService()` | `entitlementService` |
| `createGlassItemRepository()` | `glassItemRepository` |
| `createInventoryRepository()` | `inventoryRepository` |
| `createLocationRepository()` | `locationRepository` |
| `createUserImageRepository()` | `userImageRepository` |
| `createProjectRepository()` | `projectRepository` |
| `createLogbookRepository()` | `logbookRepository` |
| `createPurchaseRecordRepository()` | `purchaseRecordRepository` |
| `createItemTagsRepository()` | `itemTagsRepository` |
| `createUserTagsRepository()` | `userTagsRepository` |
| `createShoppingListRepository()` | `shoppingListRepository` |

---

## Migration Workflow

### Step 1: Plan the Migration
```bash
./Scripts/plan-di-migration.sh
```

Review the output and decide which batch to start with.

### Step 2: Analyze a File
```bash
python3 Scripts/migrate-di.py --analyze Molten/Sources/Views/Locations/LocationsView.swift
```

Review what changes will be made.

### Step 3: Apply Automated Migration
```bash
python3 Scripts/migrate-di.py --migrate Molten/Sources/Views/Locations/LocationsView.swift
```

The script handles:
- ✅ Removing default parameters
- ✅ Replacing direct RepositoryFactory calls
- ✅ Adding @Environment(\.appDependencies)

### Step 4: Manual Fixes Required

The automated scripts **cannot** handle:

#### A. Update Parent Views
If a view had default parameters, parent views must now pass services explicitly:

**Before:**
```swift
LocationsView()  // Used default parameter
```

**After:**
```swift
LocationsView(viewModel: LocationsViewModel(
    locationService: dependencies.unifiedLocationService
))
```

#### B. Update Previews
**Before:**
```swift
#Preview {
    LocationsView()
}
```

**After:**
```swift
#Preview {
    let deps = AppDependencies(forTesting: true)
    return LocationsView(viewModel: LocationsViewModel(
        locationService: deps.unifiedLocationService
    ))
}
```

#### C. Add @Environment if Needed
If the script added `@Environment(\.appDependencies) private var dependencies`, verify it's in the correct location (after `@State` properties, before `init`).

### Step 5: Build and Test
```bash
xcodebuild build -project Molten.xcodeproj -scheme Molten
```

Fix any compilation errors.

### Step 6: Commit the Batch
```bash
git add .
git commit -m "refactor(di): migrate Locations views to AppDependencies"
```

---

## Example: Simple Migration

Let's migrate **LocationsView.swift** (1 usage):

### 1. Analyze
```bash
python3 Scripts/migrate-di.py --analyze Molten/Sources/Views/Locations/LocationsView.swift
```

Output shows:
- 1 direct call at line 21
- Will replace with `dependencies.unifiedLocationService`
- Will add `@Environment(\.appDependencies)`

### 2. Apply Migration
```bash
python3 Scripts/migrate-di.py --migrate Molten/Sources/Views/Locations/LocationsView.swift
```

**Changes made:**
```diff
- init(viewModel: LocationsViewModel = LocationsViewModel(
-     locationService: RepositoryFactory.createUnifiedLocationService()
- )) {
+ @Environment(\.appDependencies) private var dependencies
+
+ init(viewModel: LocationsViewModel = LocationsViewModel(
+     locationService: dependencies.unifiedLocationService
+ )) {
```

### 3. Manual Fix: Update Preview
The script can't update the Preview, so you must manually change:

**Before:**
```swift
#Preview {
    LocationsView()
}
```

**After:**
```swift
#Preview {
    let deps = AppDependencies(forTesting: true)
    return LocationsView(viewModel: LocationsViewModel(
        locationService: deps.unifiedLocationService
    ))
}
```

### 4. Build and Test
```bash
xcodebuild build -project Molten.xcodeproj -scheme Molten
```

### 5. Commit
```bash
git add Molten/Sources/Views/Locations/LocationsView.swift
git commit -m "refactor(di): migrate LocationsView to AppDependencies"
```

---

## Example: Complex Migration

Let's migrate **CatalogView.swift** (10 usages):

### 1. Analyze
```bash
python3 Scripts/migrate-di.py --analyze Molten/Sources/Views/Catalog/CatalogView.swift
```

Output shows:
- 1 default parameter at line 69
- 10 direct calls (lines 262-275, 742)
- 7 services used

### 2. Apply Migration
```bash
python3 Scripts/migrate-di.py --migrate Molten/Sources/Views/Catalog/CatalogView.swift
```

**Changes made:**
```diff
+ @Environment(\.appDependencies) private var dependencies
+
- init(catalogService: CatalogService = RepositoryFactory.createCatalogService()) {
+ init(catalogService: CatalogService) {

- inventoryTrackingService: RepositoryFactory.createInventoryTrackingService(),
+ inventoryTrackingService: dependencies.inventoryTrackingService,

- let catalogService = RepositoryFactory.createCatalogService()
+ let catalogService = dependencies.catalogService
```

### 3. Manual Fixes Required

#### A. Update MoltenApp.swift (Parent View)
**Before:**
```swift
CatalogView()  // Used default parameter
```

**After:**
```swift
CatalogView(catalogService: dependencies.catalogService)
```

#### B. Update Preview
**Before:**
```swift
#Preview {
    let catalogService = RepositoryFactory.createCatalogService()
    return CatalogView(catalogService: catalogService)
}
```

**After:**
```swift
#Preview {
    let deps = AppDependencies(forTesting: true)
    return CatalogView(catalogService: deps.catalogService)
}
```

#### C. Remove Convenience Init (Optional)
If the convenience init no longer has default parameters, consider removing it:

```diff
- /// Convenience initializer - creates ViewModel with service
- init(catalogService: CatalogService) {
-     let viewModel = CatalogViewModel(catalogService: catalogService)
-     self.init(viewModel: viewModel, catalogService: catalogService)
- }
```

### 4. Build and Test
```bash
xcodebuild build -project Molten.xcodeproj -scheme Molten
```

### 5. Commit
```bash
git add Molten/Sources/Views/Catalog/CatalogView.swift Molten/Sources/App/MoltenApp.swift
git commit -m "refactor(di): migrate CatalogView to AppDependencies"
```

---

## Batch Migration Workflow

For migrating entire directories:

```bash
# 1. Plan the work
./Scripts/plan-di-migration.sh

# 2. Batch migrate a feature
python3 Scripts/migrate-di.py --batch Molten/Sources/Views/Locations

# 3. Manual fixes for each file:
#    - Update parent views
#    - Update previews
#    - Remove unnecessary convenience inits

# 4. Build and test
xcodebuild build -project Molten.xcodeproj -scheme Molten

# 5. Commit the batch
git add Molten/Sources/Views/Locations/
git commit -m "refactor(di): migrate Locations feature to AppDependencies"
```

---

## Troubleshooting

### Script Shows Syntax Warnings
```
SyntaxWarning: invalid escape sequence '\.'
```

**Fix:** Ignore these warnings. They're from regex patterns and don't affect functionality.

### Migration Creates Invalid Code
**Problem:** Script replaces code incorrectly

**Solution:**
1. Restore from backup: `mv <file>.backup <file>`
2. Review the analysis output
3. Report the issue with the specific file pattern

### Build Fails After Migration
**Common issues:**

1. **Missing @Environment declaration**
   - Verify `@Environment(\.appDependencies) private var dependencies` was added
   - Check it's before `init()` and after `@State` properties

2. **Parent view not updated**
   - Find all call sites: `grep -r "ViewName()" Molten/Sources/`
   - Update to pass required services

3. **Preview not updated**
   - Search for `#Preview` in the migrated file
   - Update to use `AppDependencies(forTesting: true)`

### Tests Fail After Migration
Run tests to verify changes:

```bash
xcodebuild test -project Molten.xcodeproj -scheme Molten
```

If tests fail:
1. Check test setup uses `AppDependencies(forTesting: true)`
2. Verify mock services are properly configured
3. Update test fixtures to match new init signatures

---

## Next Steps

After migrating all views (Phase 2), continue with:

**Phase 3:** Migrate remaining services & utilities
**Phase 4:** Update test infrastructure
**Phase 5:** Remove RepositoryFactory.swift

See `DI-Migration-Progress.md` for detailed progress tracking.

---

## Quick Reference

```bash
# Plan migration
./Scripts/plan-di-migration.sh

# Analyze a file
python3 Scripts/migrate-di.py --analyze <file>

# Migrate a file
python3 Scripts/migrate-di.py --migrate <file>

# Batch migrate
python3 Scripts/migrate-di.py --batch <directory>

# Build and test
xcodebuild build -project Molten.xcodeproj -scheme Molten
xcodebuild test -project Molten.xcodeproj -scheme Molten
```
