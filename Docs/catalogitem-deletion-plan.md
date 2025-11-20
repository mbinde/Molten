# CatalogItem Legacy Code Deletion Plan

## Summary
CatalogItem is legacy code that has been fully replaced by the Item hierarchy (GlassItem, CoatingItem, ToolItem). All production code now uses GlassItemRepository and GlassItemModel. This document outlines what can be safely deleted.

## Analysis Results

### ✅ SAFE TO DELETE - Not Used in Production

#### Models
- `/Molten/Sources/Models/Domain/CatalogItemModel.swift`
- `/Molten/Sources/Models/Domain/CatalogItemParentModel.swift`
- `/Molten/Sources/Models/Helpers/CatalogItemHelpers.swift`

#### Repositories
- `/Molten/Sources/Repositories/CoreData/CoreDataCatalogRepository.swift`
- `/Molten/Sources/Repositories/Protocols/CatalogItemRepository.swift`
- `/Molten/Sources/Repositories/Protocols/CatalogItemParentRepository.swift`

#### Views (Unused Components)
- `/Molten/Sources/Views/Catalog/Components/TagFilterView.swift` - NOT used by CatalogView (which was migrated)
- `/Molten/Sources/Views/Shared/Components/QuantityInputField.swift` - Only referenced in its own preview

#### Test Files
- `/Molten/Tests/RepositoryTests/CoreData/CoreDataCatalogRepositoryTests.swift`
- `/Molten/Tests/MoltenTests/Models/CatalogItemEntityTests.swift`
- `/Molten/Tests/MoltenTests/Models/CatalogItemHelpersTests.swift`
- `/Molten/Tests/MoltenTests/Models/CatalogItemParentModelTests.swift`
- `/Molten/Tests/MoltenTests/Models/CatalogBuildModelTests.swift`
- `/Molten/Tests/MoltenTests/Models/CatalogItemModelPhase1Tests.swift`
- `/Molten/Tests/MoltenTests/Utilities/FilterUtilitiesTests.swift` (if it only tests CatalogItemModel)

#### Project Files (Apparently Orphaned)
- `/Molten.xcodeproj/RealisticLoadTests.swift`
- `/Molten.xcodeproj/ResourceManagementTests.swift`
- `/Molten.xcodeproj/ServiceCoordinationTests.swift`
- `/Molten.xcodeproj/CatalogServiceAdvancedTests.swift`

### ⚠️  NEEDS CLEANUP - Remove CatalogItem References

#### Core Data Files
- `/Molten/Sources/Repositories/CoreData/Persistence.swift`
  - Line 102-104: Remove CatalogItem entity validation
  - Line 130-146: Remove preview data creation for CatalogItem

- `/Molten/Sources/Repositories/CoreData/CoreDataEntities.swift`
  - Remove `CatalogItem` class declaration
  - Remove `CatalogItemParent` class declaration
  - Remove `CatalogItemUser` class declaration

- `/Molten/Sources/Repositories/CoreData/CoreDataMigrationService.swift`
  - Remove all CatalogItem backup/migration logic
  - This file has extensive CatalogItem handling that needs to be removed

- `/Molten/Sources/Repositories/CoreData/CoreDataRecoveryUtility.swift`
  - Check for CatalogItem recovery logic

- `/Molten/Sources/Repositories/CoreData/CoreDataEntityHelpers.swift`
  - Remove CatalogItem helper methods

#### Repository Protocol Files
- `/Molten/Sources/Repositories/Protocols/CoreDataGlassItemRepository.swift`
  - Check for CatalogItem references (might have migration comments)

- `/Molten/Sources/Repositories/Protocols/CoreDataCoatingItemRepository.swift`
  - Check for CatalogItem references

#### Service Files
- `/Molten/Sources/Models/Helpers/ServiceValidation.swift`
  - Remove CatalogItemModel validation if present

#### Debug/Settings Views
- `/Molten/Sources/Views/Settings/Debug/CoreDataDiagnosticView.swift`
  - Remove CatalogItem diagnostics

### 🚨 MUST KEEP - Still Used

#### Views
- `/Molten/Sources/Views/Catalog/CatalogView.swift` - ✅ MIGRATED to GlassItem (keep!)
- `/Molten/Sources/Views/Catalog/Components/CatalogTagFilterView.swift` - Check if used

### 📋 Core Data Model Changes

**Entities to Delete** (in `.xcdatamodel`):
1. `CatalogItem`
2. `CatalogItemParent`
3. `CatalogItemUser`

**Model Version**: Will need to create Molten 22.xcdatamodel

## Deletion Order (Safest → Riskiest)

### Phase 1: Delete Test Files (Safest)
1. Delete all CatalogItem test files
2. Run tests to ensure no dependencies

### Phase 2: Delete Unused Source Files
1. Delete `CatalogItemModel.swift`
2. Delete `CatalogItemParentModel.swift`
3. Delete `CatalogItemHelpers.swift`
4. Delete `CoreDataCatalogRepository.swift`
5. Delete `CatalogItemRepository.swift` protocol
6. Delete `CatalogItemParentRepository.swift` protocol
7. Delete `TagFilterView.swift`
8. Delete `QuantityInputField.swift`

### Phase 3: Clean Up References in Existing Files
1. Clean `Persistence.swift` - remove CatalogItem validation and preview data
2. Clean `CoreDataMigrationService.swift` - remove CatalogItem backup/migration
3. Clean `CoreDataEntities.swift` - remove entity declarations
4. Clean `CoreDataRecoveryUtility.swift` - remove CatalogItem recovery
5. Clean `CoreDataEntityHelpers.swift` - remove CatalogItem helpers
6. Clean `CoreDataDiagnosticView.swift` - remove CatalogItem diagnostics
7. Clean `ServiceValidation.swift` - remove CatalogItemModel validation

### Phase 4: Core Data Model Changes (Riskiest)
1. User creates new model version (Molten 22)
2. Delete CatalogItem entities from model
3. Set new version as current
4. Test migration

### Phase 5: Verification
1. Build project
2. Run full test suite (UnitTestsOnly + RepositoryTests)
3. Verify CatalogView still works
4. Commit changes

## Expected Deletions Summary

**Files to Delete**: ~20 files
**Files to Modify**: ~8 files
**Core Data Entities to Remove**: 3 entities

## Risks & Mitigations

**Risk**: Migration helper code might still reference CatalogItem for old data
**Mitigation**: Keep migration code temporarily, add deprecation comments

**Risk**: Tests might break due to shared test data builders
**Mitigation**: Delete test files first, verify tests pass before proceeding

**Risk**: Core Data model change might break existing stores
**Mitigation**: Create new model version, test thoroughly before deployment
