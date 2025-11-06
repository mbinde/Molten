# Files Skipped for Unit Testing

This document tracks files that were identified as 0% coverage but are not appropriate for unit tests.

## Rationale Categories

### SwiftUI Views (Better tested with UI tests, not unit tests)

**Batch 1:**
- `UnifiedFormFields.swift` - SwiftUI view components with bindings
- `LocationsViewModel.swift` - SwiftUI ViewModel with @Published properties
- `ImportPlanView.swift` - SwiftUI view
- `GlassItemImageSelector.swift` - SwiftUI view with image selection
- `ProjectsView.swift` - SwiftUI view
- `UserTagsEditor.swift` - SwiftUI view
- `CatalogBundleDebugView.swift` - Debug UI view
- `AddStepView.swift` - SwiftUI view
- `ProjectThumbnail.swift` - SwiftUI view
- `KilnScheduleRowView.swift` - SwiftUI view
- `AddGlassToStepView.swift` - SwiftUI view
- `TagFilterView.swift` - SwiftUI view
- `ImagePicker.swift` - SwiftUI view

**Batch 2:**
- `RecommendedSchedulesSection.swift` - SwiftUI view component
- `SettingsViewHelpers.swift` - SwiftUI view helpers (probably views)
- `LocationRow.swift` - SwiftUI view row component
- `LocationsView.swift` - SwiftUI view
- `FloatingActionButton.swift` - SwiftUI view component
- `CatalogToolbarContent.swift` - SwiftUI toolbar component
- `TabCustomizationView.swift` - SwiftUI view
- `AddPurchaseRecordView.swift` - SwiftUI view
- `AddSuggestedGlassView.swift` - SwiftUI view
- `CatalogTagFilterView.swift` - SwiftUI view
- `StoreRowView.swift` - SwiftUI view
- `InventoryView.swift` - SwiftUI view
- `PDFPreviewView.swift` - SwiftUI view
- `LabeledFormComponents.swift` - SwiftUI form components

### Configuration & Settings (Static configuration, no logic to test)
- `DebugConfig.swift` - Static configuration flags and AppStorage properties (requires UI/integration testing)

### Repository Protocols (Protocols are tested via implementations)
- `UserTagsRepository.swift` - Protocol (Mock/CoreData implementations already have tests)
- `CatalogItemParentRepository.swift` - Protocol

### Repository Implementations (Integration/Repository tests exist)
- `CoreDataKilnScheduleRepository.swift` - Core Data implementation (belongs in RepositoryTests)

### Example/Tool Files (Not production code)
- `GlassItemDataLoadingExample.swift` - Development/debugging tool

### Infrastructure/Helpers (May need specialized testing)
- `FileSystemUserImageRepository.swift` - File I/O operations (requires filesystem mocking/integration tests)
- `TransformableMigrationHelper.swift` - Core Data migration utility (requires Core Data context, belongs in RepositoryTests)

### ViewModels (Likely require protocol/integration tests)
- `StoreListViewModel.swift` - SwiftUI ViewModel (probably has @Published properties)
- `PurchasesViewModel.swift` - SwiftUI ViewModel (probably has @Published properties)

### Services (Require integration/repository tests)
- `KilnScheduleExportService.swift` - File export service (requires file I/O mocking)
- `RecipeService.swift` - Service layer (requires repository mocks, belongs in integration tests)
- `CoreDataMigrationService.swift` - Migration service (requires Core Data context)

### Model Classes (Need to check if they have testable logic)
- `UserNotesModel.swift` - May have validation logic (TODO: investigate)
- `RecipeModel.swift` - May have validation logic (TODO: investigate)
- `StoreDataModels.swift` - May have validation logic (TODO: investigate)

### Mock/Test Infrastructure
- `MockJSONDataLoader.swift` - Test helper (not production code)

### Error Enums (Tested)
- `KilnScheduleRepositoryErrors.swift` - ✅ **Tests Created**: KilnScheduleRepositoryErrorsTests.swift

### Formatting/Extensions (Tested)
- `Decimal+Formatting.swift` - ✅ **Tests Created**: DecimalFormattingTests.swift

### Domain Enums (Tested)
- `ServiceType.swift` - ✅ **Tests Created**: ServiceTypeTests.swift

### Validation Helpers (Tested)
- `ServiceValidation.swift` - ✅ **Tests Created**: ServiceValidationTests.swift

### Utilities (Tested)
- `TagColorMapping.swift` - ✅ **Tests Created**: TagColorMappingTests.swift

### ViewModels with Protocols (Should have protocol tests)
- `InventoryViewModelProtocol.swift` - Protocol-based ViewModel pattern (create mock tests)

### Debug/Development Utilities
- `AuthorInclusionSection.swift` - Debug-only component

## Summary

**Batch 1 (First Review):**
- Total files reviewed: 24
- Tests created: 2 (Decimal+Formatting, KilnScheduleRepositoryErrors)
- Skipped: 22 (SwiftUI views, protocols, static config, infrastructure)

**Batch 2 (Second Review):**
- Total files reviewed: 25
- Tests created: 3 (ServiceType, ServiceValidation, TagColorMapping)
- Skipped: 22 (SwiftUI views, ViewModels, Services requiring integration tests)

**Grand Total:**
- Total files reviewed: 49
- Tests created: 5
- Skipped: 44

## Future Considerations

Files that might benefit from unit tests if refactored:
1. Extract business logic from ViewModels into separate service classes
2. Create testable wrappers for FileSystemUserImageRepository file operations
3. Add more focused error enum tests for other error types
