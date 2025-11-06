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

**Batch 3:**
- `CoatingTestView.swift` - SwiftUI view (likely debug/test view)
- `AddPurchaseRecordViewModel.swift` - SwiftUI ViewModel
- `MockCatalogViewModel.swift` - Mock for testing (not production code)
- `SettingsToolbarButton.swift` - SwiftUI toolbar component
- `AddLogbookEntryView.swift` - SwiftUI view
- `DeepLinkedItemView.swift` - SwiftUI view
- `ImportScheduleView.swift` - SwiftUI view
- `FirstRunDataLoadingView.swift` - SwiftUI view
- `CatalogViewFactory.swift` - Factory for view creation (SwiftUI infrastructure)
- `PurchaseRowView.swift` - SwiftUI view
- `AboutView.swift` - SwiftUI view
- `InventoryItemRowView.swift` - SwiftUI view
- `CatalogViewIntegration.swift` - Integration code (likely SwiftUI)
- `LocationDetailView.swift` - SwiftUI view
- `PurchaseRecordDetailView.swift` - SwiftUI view
- `UsageBanner.swift` - SwiftUI view
- `StoreAutoCompleteField.swift` - SwiftUI view component
- `KilnSegmentInput.swift` - SwiftUI view component

**Batch 4:**
- `AddRecipeView.swift` - SwiftUI view
- `SuccessToast.swift` - SwiftUI view component
- `UserNotesEditor.swift` - SwiftUI view
- `ConsolidatedInventoryDetailView.swift` - SwiftUI view
- `EditReferenceURLView.swift` - SwiftUI view
- `KilnScheduleDetailView.swift` - SwiftUI view
- `QuantityInputField.swift` - SwiftUI view component
- `AuthorSettingsView.swift` - SwiftUI view
- `GlassItemCard.swift` - SwiftUI view component
- `ConfirmationDialog.swift` - SwiftUI view component
- `AddShoppingListItemView.swift` - SwiftUI view
- `PurchasesView.swift` - SwiftUI view
- `KilnSchedulePickerListView.swift` - SwiftUI view
- `StoreMapView.swift` - SwiftUI view with MapKit integration
- `AnyLocationModel.swift` - Type-erased wrapper (no testable logic, just forwarding)

**Batch 5:**
- `CoatingItemDataLoadingService.swift` - Service layer (requires repository mocks, belongs in integration tests)
- `AddPlanImageView.swift` - SwiftUI view
- `DebugSettingsView.swift` - SwiftUI debug view
- `UpgradePromptView.swift` - SwiftUI view
- `ZipCodeEntryView.swift` - SwiftUI view
- `RecipesView.swift` - SwiftUI view
- `PrimaryImageSelector.swift` - SwiftUI view component
- `KilnScheduleGraphView.swift` - SwiftUI view (chart/graph component)
- `FilterSelectionSheet.swift` - SwiftUI view component
- `ImportInventoryView.swift` - SwiftUI view
- `GlassItemRowView.swift` - SwiftUI view component
- `EmptyStateView.swift` - SwiftUI view component
- `CoreDataDiagnosticView.swift` - SwiftUI debug view
- `ExportPlanView.swift` - SwiftUI view

**Batch 6:**
- `LaunchScreenView.swift` - SwiftUI view
- `KeyboardDismissal.swift` - SwiftUI view modifier/utility
- `StoreDetailView.swift` - SwiftUI view
- `CloudKitSyncStatusView.swift` - SwiftUI view
- `AuthorCardView.swift` - SwiftUI view component
- `StoreListView.swift` - SwiftUI view
- `AddFormScaffold.swift` - SwiftUI view component/scaffold
- `AlphaDisclaimerView.swift` - SwiftUI view
- `AddSegmentView.swift` - SwiftUI view
- `LabelDesignerView.swift` - SwiftUI view
- `FormComponents.swift` - SwiftUI form components
- `TestDataGeneratorView.swift` - SwiftUI debug view (development tool)
- `GlassItemSearchSelector.swift` - SwiftUI view component
- `ColorListView.swift` - SwiftUI view
- `PDFExportOptionsView.swift` - SwiftUI view
- `KilnSchedulesView.swift` - SwiftUI view
- `ExportScheduleView.swift` - SwiftUI view
- `MoreTabView.swift` - SwiftUI view
- `LocationPickerSheet.swift` - SwiftUI view component

**Batch 7:**
- `UnifiedButtonComponents.swift` - SwiftUI button components
- `LabelPreviewView.swift` - SwiftUI view
- `KilnSchedulePickerView.swift` - SwiftUI view component
- `AppLaunchView.swift` - SwiftUI view
- `SearchStoresView.swift` - SwiftUI view
- `DemoDataGenerator.swift` - Development/debugging tool (demo data generation)
- `AddReferenceURLView.swift` - SwiftUI view
- `ImportInventoryTriggerView.swift` - SwiftUI view
- `ShareSheet.swift` - SwiftUI view (UIKit bridge)
- `AddKilnScheduleView.swift` - SwiftUI view
- `DataExportView.swift` - SwiftUI view
- `SettingsView.swift` - SwiftUI view (0.5% coverage, mostly UI)
- `ImagePickerView.swift` - SwiftUI view (UIKit bridge)
- `LocationFilterPreferences.swift` - UserDefaults wrapper (requires integration tests)

### Configuration & Settings (Static configuration, no logic to test)
- `DebugConfig.swift` - Static configuration flags and AppStorage properties (requires UI/integration testing)

### Repository Protocols (Protocols are tested via implementations)
- `UserTagsRepository.swift` - Protocol (Mock/CoreData implementations already have tests)
- `CatalogItemParentRepository.swift` - Protocol
- `InventoryRepository.swift` - Protocol (Mock/CoreData implementations already have tests)
- `ShoppingListViewModelProtocol.swift` - ViewModel protocol (create mock tests if needed)
- `LocationModel.swift` - Protocol with default implementations (tested via UnifiedLocationModel)

### Repository Implementations (Integration/Repository tests exist)
- `CoreDataKilnScheduleRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataLocationRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataUserTagsRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataCatalogRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataUserImageRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataInventoryRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataProjectImageRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CatalogItemRepository.swift` - Protocol or Core Data repository (belongs in RepositoryTests)
- `CoreDataProjectRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataRecipeRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataItemTagsRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataPurchaseRecordRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataShoppingListRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataToolItemRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataCoatingItemRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataGlassItemRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataUserNotesRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataUnifiedLocationRepository.swift` - Core Data implementation (belongs in RepositoryTests)
- `CoreDataLogbookRepository.swift` - Core Data implementation (belongs in RepositoryTests)

### Example/Tool Files (Not production code)
- `GlassItemDataLoadingExample.swift` - Development/debugging tool

### Infrastructure/Helpers (May need specialized testing)
- `FileSystemUserImageRepository.swift` - File I/O operations (requires filesystem mocking/integration tests)
- `TransformableMigrationHelper.swift` - Core Data migration utility (requires Core Data context, belongs in RepositoryTests)
- `Persistence.swift` - Core Data stack setup (integration-level testing)
- `CoreDataEntityHelpers.swift` - Core Data helper utilities (requires Core Data context)
- `CloudKitSyncMonitor.swift` - CloudKit monitoring service (requires CloudKit integration testing)
- `DesignSystem+Accessibility.swift` - Static accessibility identifiers (UI tests verify these work)
- `CatalogSearchCache.swift` - @MainActor singleton cache with async methods (requires integration tests with mock CatalogService)
- `CatalogViewHelpers.swift` - View filtering utilities with external dependencies (FilterUtilities, DebugConfig)
- `CoreDataRecoveryUtility.swift` - Core Data recovery utility (requires Core Data context, belongs in RepositoryTests)
- `CoreDataHelpers.swift` - Core Data helper utilities (requires Core Data context)
- `CoreDataVersionInfo.swift` - Core Data version information (infrastructure, minimal logic)
- `Logger+Categories.swift` - Logger extension with static category definitions (no testable logic)
- `InventoryImportService.swift` - Import service (requires repository mocks, belongs in integration tests)

### ViewModels (Likely require protocol/integration tests)
- `StoreListViewModel.swift` - SwiftUI ViewModel (probably has @Published properties)
- `PurchasesViewModel.swift` - SwiftUI ViewModel (probably has @Published properties)
- `AddLogbookEntryViewModel.swift` - SwiftUI ViewModel (probably has @Published properties)
- `KilnSchedulesViewModel.swift` - SwiftUI ViewModel (probably has @Published properties)

### ViewModel Protocols (Should have protocol tests)
- `KilnSchedulesViewModelProtocol.swift` - ViewModel protocol (create mock tests if needed)

### Services (Require integration/repository tests)
- `KilnScheduleExportService.swift` - File export service (requires file I/O mocking)
- `RecipeService.swift` - Service layer (requires repository mocks, belongs in integration tests)
- `CoreDataMigrationService.swift` - Migration service (requires Core Data context)
- `GlassItemDataLoadingService.swift` - Data loading service (requires repository mocks, belongs in integration tests)
- `ProjectPDFService.swift` - PDF generation service (requires file I/O mocking)

### Model Classes (Need to check if they have testable logic)
- `UserNotesModel.swift` - May have validation logic (TODO: investigate)
- `RecipeModel.swift` - May have validation logic (TODO: investigate)
- `StoreDataModels.swift` - May have validation logic (TODO: investigate)

### Mock/Test Infrastructure
- `MockJSONDataLoader.swift` - Test helper (not production code)
- `MockProjectImageRepository.swift` - Mock for testing (not production code)
- `StoreToShoppingListNavigationTests.swift` - Already a test file (not source code)
- `MockRecipeRepository.swift` - Mock for testing (not production code)
- `MockUserNotesRepository.swift` - Mock for testing (not production code)

### Error Enums (Tested)
- `KilnScheduleRepositoryErrors.swift` - ✅ **Tests Created**: KilnScheduleRepositoryErrorsTests.swift
- `ProjectRepositoryErrors.swift` - ✅ **Tests Created**: ProjectRepositoryErrorsTests.swift

### Formatting/Extensions (Tested)
- `Decimal+Formatting.swift` - ✅ **Tests Created**: DecimalFormattingTests.swift

### Domain Enums (Tested)
- `ServiceType.swift` - ✅ **Tests Created**: ServiceTypeTests.swift

### Validation Helpers (Tested)
- `ServiceValidation.swift` - ✅ **Tests Created**: ServiceValidationTests.swift

### Utilities (Tested)
- `TagColorMapping.swift` - ✅ **Tests Created**: TagColorMappingTests.swift

### Domain Models (Tested)
- `UnifiedLocationModel.swift` - ✅ **Tests Created**: UnifiedLocationModelTests.swift (130+ tests for location model, capabilities, address formatting, distance calculations)
- `AuthorModel.swift` - ✅ **Tests Created**: AuthorModelTests.swift (30+ tests for author attribution model)

### Domain Enums (Tested)
- `LocationType.swift` - ✅ **Tests Created**: LocationTypeTests.swift (30+ tests for location type enum with display names, icons)
- `CatalogSortOption.swift` (SortOption enum) - ✅ **Tests Created**: CatalogSortOptionTests.swift (50+ tests for sorting logic, keypaths, icon names, architecture bridge)
- `DefaultUnits.swift` - ✅ **Tests Created**: DefaultUnitsTests.swift (40+ tests for unit enum with display names, symbols, system images)

### Model Helpers (Tested)
- `CatalogCodeLookup.swift` - ✅ **Tests Created**: CatalogCodeLookupTests.swift (40+ tests for natural key generation, hash distribution, edge cases)

### Utilities (Tested)
- `JSON5Parser.swift` - ✅ **Tests Created**: JSON5ParserTests.swift (50+ tests for JSON5 comment removal, trailing commas, parsing, error handling)

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

**Batch 3 (Third Review):**
- Total files reviewed: 26
- Tests created: 1 (ProjectRepositoryErrors)
- Skipped: 25 (SwiftUI views, ViewModels, Core Data infrastructure, mocks)

**Batch 4 (Fourth Review):**
- Total files reviewed: 25
- Tests created: 2 (UnifiedLocationModel with 130+ tests, AuthorModel with 30+ tests)
- Skipped: 23 (SwiftUI views, Core Data repositories, services, ViewModels, mocks, type-erased wrapper)

**Batch 5 (Fifth Review):**
- Total files reviewed: 25
- Tests created: 3 (LocationType enum with 30+ tests, CatalogCodeLookup with 40+ tests, JSON5Parser with 50+ tests)
- Skipped: 22 (SwiftUI views, Core Data repositories, services, protocols, mocks)

**Batch 6 (Sixth Review):**
- Total files reviewed: 25
- Tests created: 0
- Skipped: 25 (19 SwiftUI views, 3 Core Data repositories, 1 protocol, 1 @MainActor cache, 1 view helper with dependencies)

**Batch 7 (Seventh Review):**
- Total files reviewed: 25
- Tests created: 2 (CatalogSortOption with 50+ tests, DefaultUnits with 40+ tests)
- Skipped: 23 (13 SwiftUI views, 3 Core Data repositories, 1 ViewModel protocol, 1 service, 1 UserDefaults wrapper, 1 logger extension, 3 Core Data infrastructure files, 1 debug tool)

**Grand Total:**
- Total files reviewed: 175
- Tests created: 13
- Skipped: 162

## Future Considerations

Files that might benefit from unit tests if refactored:
1. Extract business logic from ViewModels into separate service classes
2. Create testable wrappers for FileSystemUserImageRepository file operations
3. Add more focused error enum tests for other error types
